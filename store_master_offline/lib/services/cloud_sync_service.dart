import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import 'online_api_service.dart';

/// Local-first cloud sync. Local SQLite remains usable offline; failed requests
/// leave the outbox intact so the next attempt can retry them.
class CloudSyncService {
  CloudSyncService._();
  static final instance = CloudSyncService._();

  Timer? _timer;
  bool _syncing = false;
  bool _syncAgain = false;
  final StreamController<int> _changes = StreamController<int>.broadcast();
  int _changeVersion = 0;

  /// Emits only when the remote snapshot changed local database rows.
  Stream<int> get changes => _changes.stream;

  void startPeriodic({Duration interval = const Duration(seconds: 10)}) {
    if (!OnlineApiService.onlineEnabled || _timer != null) return;
    _timer = Timer.periodic(interval, (_) {
      requestSync();
    });
    // Pull any changes made on another device as soon as the session is ready.
    requestSync();
  }

  /// Fire-and-forget trigger for mutations. Multiple requests are coalesced,
  /// but a request that arrives during an active sync causes another pass.
  void requestSync() {
    if (!OnlineApiService.onlineEnabled ||
        !OnlineApiService.instance.isAuthenticated) {
      return;
    }
    unawaited(syncAll().then<void>((_) {}, onError: (Object _) {}));
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
    if (_syncing) {
      _syncAgain = true;
      return {'pushed': 0, 'pulled': 0, 'skipped': true, 'queued': true};
    }

    _syncing = true;
    var totalPushed = 0;
    var totalPulled = 0;
    try {
      do {
        _syncAgain = false;
        final result = await _syncOnce();
        totalPushed += (result['pushed'] as num?)?.toInt() ?? 0;
        totalPulled += (result['pulled'] as num?)?.toInt() ?? 0;
      } while (_syncAgain &&
          OnlineApiService.onlineEnabled &&
          OnlineApiService.instance.isAuthenticated);
      return {
        'pushed': totalPushed,
        'pulled': totalPulled,
        'skipped': false,
      };
    } finally {
      _syncing = false;
    }
  }

  Future<Map<String, int>> _syncOnce() async {
    final db = await DatabaseHelper.instance.database;
    final outbox = await db.query(
      'sync_outbox',
      orderBy: 'id ASC',
      limit: 1000,
    );
    var pushed = 0;
    if (outbox.isNotEmpty) {
      final items = outbox
          .map((row) => <String, dynamic>{
                'entity': row['entity'],
                'operation': row['operation'],
                'entityId': '${row['entityId']}',
                'payloadJson': row['payloadJson'],
                'sourceVersion': (row['sourceVersion'] as num?)?.toInt() ?? 0,
              })
          .toList();
      final ack = await OnlineApiService.instance.cloudPush(items);
      final accepted = (ack['accepted'] as num?)?.toInt();
      if (ack['success'] != true || (accepted != null && accepted < items.length)) {
        throw StateError('سرور همه تغییرات همگام‌سازی را تأیید نکرد.');
      }
      pushed = items.length;

      // Delete only the entries that were acknowledged by the server.
      final ids = outbox.map((row) => row['id']).whereType<int>().toList();
      if (ids.isNotEmpty) {
        await db.delete(
          'sync_outbox',
          where: 'id IN (${List.filled(ids.length, '?').join(',')})',
          whereArgs: ids,
        );
      }
    }

    final snapshot = await OnlineApiService.instance.cloudSnapshot();
    var pulled = 0;
    if (snapshot.isNotEmpty) {
      await db.transaction((tx) async {
        await tx.insert(
          'sync_flags',
          {'flag': 'applying', 'value': '1'},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
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
            final raw = item['payload'];
            final payload = raw is Map<String, dynamic>
                ? raw
                : raw is Map
                    ? Map<String, dynamic>.from(raw)
                    : raw == null || '$raw'.isEmpty
                        ? <String, dynamic>{}
                        : Map<String, dynamic>.from(jsonDecode('$raw') as Map);
            if (entity == 'app_settings') {
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
            final pk = columns.any((c) => '${c['name']}' == 'id')
                ? 'id'
                : '${columns.firstWhere(
                    (c) => (c['pk'] as num? ?? 0) > 0,
                    orElse: () => columns.first,
                  )['name']}';
            if (operation == 'DELETE') {
              final deleted = await tx.delete(
                entity,
                where: 'CAST("$pk" AS TEXT)=?',
                whereArgs: [id],
              );
              if (deleted > 0) pulled++;
            } else if (payload.isNotEmpty) {
              // Keep columns unknown to the server (for mixed app versions)
              // and avoid replacing local rows when the snapshot is unchanged.
              final columnNames = columns.map((c) => '${c['name']}').toSet();
              final safePayload = <String, dynamic>{
                for (final entry in payload.entries)
                  if (columnNames.contains(entry.key)) entry.key: entry.value,
              };
              final rowId = '${safePayload[pk] ?? id}';
              final existingRows = await tx.query(
                entity,
                where: 'CAST("$pk" AS TEXT)=?',
                whereArgs: [rowId],
                limit: 1,
              );
              final mergedPayload = <String, dynamic>{
                if (existingRows.isNotEmpty) ...existingRows.first,
                ...safePayload,
              };
              final unchanged = existingRows.isNotEmpty &&
                  _sameRow(existingRows.first, mergedPayload);
              if (!unchanged) {
                await tx.insert(
                  entity,
                  mergedPayload,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
                pulled++;
              }
            }
          }
        } finally {
          await tx.delete('sync_flags', where: 'flag=?', whereArgs: ['applying']);
        }
      });
    }
    if (pulled > 0 && !_changes.isClosed) {
      _changeVersion++;
      _changes.add(_changeVersion);
    }
    return {'pushed': pushed, 'pulled': pulled};
  }

  bool _sameRow(Map<String, Object?> current, Map<String, dynamic> incoming) {
    if (current.length != incoming.length) return false;
    for (final entry in incoming.entries) {
      if (!current.containsKey(entry.key)) return false;
      final a = current[entry.key];
      final b = entry.value;
      if (a is num && b is num) {
        if (a != b) return false;
      } else if (a != b) {
        return false;
      }
    }
    return true;
  }
}
