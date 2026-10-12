import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import 'online_api_service.dart';

/// Syncs the local SQLite outbox to the cloud and applies server snapshots.
/// The local database remains the source of truth while offline; sync resumes
/// periodically once a valid online session is available.
class CloudSyncService {
  CloudSyncService._();
  static final instance = CloudSyncService._();

  Timer? _timer;
  bool _syncing = false;

  void startPeriodic({Duration interval = const Duration(seconds: 20)}) {
    if (!OnlineApiService.onlineEnabled || _timer != null) return;
    _timer = Timer.periodic(interval, (_) async {
      try {
        await syncAll();
      } catch (_) {
        // A temporary outage must not affect local operations. The next tick retries.
      }
    });
  }

  void stopPeriodic() {
    _timer?.cancel();
    _timer = null;
  }

  Future<Map<String, dynamic>> syncAll() async {
    if (!OnlineApiService.onlineEnabled ||
        !OnlineApiService.instance.isAuthenticated) {
      return {'pushed': 0, 'pulled': 0, 'skipped': true};
    }
    if (_syncing) return {'pushed': 0, 'pulled': 0, 'skipped': true};
    _syncing = true;
    try {
      final db = await DatabaseHelper.instance.database;
      final outbox = await db.query('sync_outbox', orderBy: 'id ASC', limit: 1000);
      var pushed = 0;
      if (outbox.isNotEmpty) {
        final items = outbox.map((row) => <String, dynamic>{
          'entity': row['entity'],
          'operation': row['operation'],
          'entityId': '${row['entityId']}',
          'payloadJson': row['payloadJson'],
          'sourceVersion': (row['sourceVersion'] as num?)?.toInt() ?? 0,
        }).toList();
        await OnlineApiService.instance.cloudPush(items);
        pushed = items.length;
        final ids = outbox.map((e) => e['id']).whereType<int>().toList();
        if (ids.isNotEmpty) {
          await db.delete('sync_outbox',
              where: 'id IN (${List.filled(ids.length, '?').join(',')})',
              whereArgs: ids);
        }
      }

      final snapshot = await OnlineApiService.instance.cloudSnapshot();
      var pulled = 0;
      if (snapshot.isNotEmpty) {
        await db.transaction((tx) async {
          await tx.insert('sync_flags', {'flag': 'applying', 'value': '1'},
              conflictAlgorithm: ConflictAlgorithm.replace);
          try {
            for (final item in snapshot) {
              final entity = '${item['entity'] ?? ''}';
              if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(entity) ||
                  {'users', 'sync_flags', 'sync_outbox', 'local_sync_log'}
                      .contains(entity)) {
                continue;
              }
              final operation = '${item['operation'] ?? 'UPSERT'}';
              final id = '${item['entityId'] ?? ''}';
              if (entity == 'app_settings') {
                final raw = item['payload'];
                final payload = raw is Map<String, dynamic>
                    ? raw
                    : raw is Map
                        ? Map<String, dynamic>.from(raw)
                        : <String, dynamic>{};
                final key = '${payload['key'] ?? ''}'.trim().toLowerCase();
                if (key == 'local_sync_device_id' ||
                    key.startsWith('license_') ||
                    key.startsWith('local_trial_') ||
                    key.startsWith('online_session') ||
                    key == 'license_expired_latched') {
                  continue;
                }
              }

              final columns = await tx.rawQuery('PRAGMA table_info("$entity")');
              if (columns.isEmpty) continue;
              if (operation == 'DELETE') {
                final pk = columns.any((c) => '${c['name']}' == 'id')
                    ? 'id'
                    : '${columns.firstWhere((c) => (c['pk'] as num? ?? 0) > 0,
                        orElse: () => columns.first)['name']}';
                await tx.delete(entity,
                    where: 'CAST("$pk" AS TEXT)=?', whereArgs: [id]);
              } else {
                final raw = item['payload'];
                final payload = raw is Map<String, dynamic>
                    ? raw
                    : raw is Map
                        ? Map<String, dynamic>.from(raw)
                        : Map<String, dynamic>.from(jsonDecode('$raw') as Map);
                if (payload.isNotEmpty) {
                  await tx.insert(entity, payload,
                      conflictAlgorithm: ConflictAlgorithm.replace);
                }
              }
              pulled++;
            }
          } finally {
            await tx.delete('sync_flags', where: 'flag=?', whereArgs: ['applying']);
          }
        });
      }
      return {'pushed': pushed, 'pulled': pulled, 'skipped': false};
    } finally {
      _syncing = false;
    }
  }
}
