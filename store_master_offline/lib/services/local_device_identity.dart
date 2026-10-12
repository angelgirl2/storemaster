import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class LocalDeviceIdentity {
  LocalDeviceIdentity._();
  static final instance = LocalDeviceIdentity._();
  static const _deviceKey = 'local_sync_device_id';
  String? _cached;

  Future<String> get deviceId async {
    if (_cached != null) return _cached!;
    final db = await DatabaseHelper.instance.database;
    return ensureDeviceId(db);
  }

  Future<String> ensureDeviceId(Database db) async {
    if (_cached != null) return _cached!;
    final rows = await db.query('app_settings', columns: const ['value'], where: 'key=?', whereArgs: const [_deviceKey], limit: 1);
    if (rows.isNotEmpty && '${rows.first['value'] ?? ''}'.trim().isNotEmpty) {
      return _cached = '${rows.first['value']}'.trim();
    }
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    final host = Platform.localHostname.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final id = '${base64UrlEncode(bytes).replaceAll('=', '')}-$host';
    await db.insert('app_settings', {'key': _deviceKey, 'value': id}, conflictAlgorithm: ConflictAlgorithm.replace);
    return _cached = id;
  }

  int _hash(String s) {
    var h = 2166136261;
    for (final b in utf8.encode(s)) {
      h ^= b;
      h = (h * 16777619) & 0x7fffffff;
    }
    return h;
  }

  /// Reserves a large, device-specific AUTOINCREMENT range without recursively
  /// opening DatabaseHelper while the database itself is initializing.
  Future<void> reserveIdRange(Database db) async {
    final id = await ensureDeviceId(db);
    final bucket = _hash(id) % 700000;
    final base = 1000000 + bucket * 100000;
    try {
      final rows = await db.rawQuery('SELECT name, seq FROM sqlite_sequence');
      for (final row in rows) {
        final table = '${row['name'] ?? ''}';
        if (table.isEmpty) continue;
        final maxRaw = (await db.rawQuery('SELECT MAX(id) AS m FROM "$table"')).first['m'];
        final maxId = (maxRaw as num?)?.toInt() ?? 0;
        final currentSeq = (row['seq'] as num?)?.toInt() ?? 0;
        final target = [base - 1, currentSeq, maxId].reduce((a, b) => a > b ? a : b);
        if (target > currentSeq) {
          await db.rawUpdate('UPDATE sqlite_sequence SET seq=? WHERE name=?', [target, table]);
        }
      }
    } catch (_) {}
  }
}
