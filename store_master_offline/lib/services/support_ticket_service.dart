import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import 'online_api_service.dart';
import 'online_config.dart';

class SupportTicketService {
  static final instance = SupportTicketService._();
  SupportTicketService._();

  static const _queueKey = 'support_ticket_queue';

  Future<void> submit({
    required String type,
    required String storeCode,
    required String licenseId,
    required String username,
    required String deviceId,
    required String contact,
    required String message,
  }) async {
    final payload = <String, dynamic>{
      'type': type,
      'storeCode': storeCode,
      'licenseId': licenseId,
      'username': username,
      'deviceId': deviceId,
      'contact': contact,
      'message': message,
    };

    if (_configuredOnline()) {
      try {
        await OnlineApiService.instance.createSupportTicket(
          type: type,
          storeCode: storeCode,
          licenseId: licenseId,
          username: username,
          deviceId: deviceId,
          contact: contact,
          message: message,
        );
        return;
      } catch (_) {}
    }

    await _enqueue(payload);
  }

  Future<void> flushPending() async {
    if (!_configuredOnline()) return;

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_settings',
      columns: const ['value'],
      where: 'key = ?',
      whereArgs: const [_queueKey],
      limit: 1,
    );
    if (rows.isEmpty) return;

    List<dynamic> items;
    try {
      final raw = jsonDecode('${rows.first['value'] ?? '[]'}');
      items = raw is List ? raw : <dynamic>[];
    } catch (_) {
      items = <dynamic>[];
    }
    if (items.isEmpty) return;

    final remaining = <dynamic>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      try {
        await OnlineApiService.instance.createSupportTicket(
          type: '${item['type'] ?? 'SUPPORT'}',
          storeCode: '${item['storeCode'] ?? ''}',
          licenseId: '${item['licenseId'] ?? ''}',
          username: '${item['username'] ?? ''}',
          deviceId: '${item['deviceId'] ?? ''}',
          contact: '${item['contact'] ?? ''}',
          message: '${item['message'] ?? ''}',
        );
      } catch (_) {
        remaining.add(item);
      }
    }

    await db.insert(
      'app_settings',
      {'key': _queueKey, 'value': jsonEncode(remaining)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  bool _configuredOnline() =>
      OnlineApiService.onlineEnabled &&
      OnlineConfig.instance.baseUrl.isNotEmpty &&
      !OnlineConfig.instance.baseUrl.contains('YOUR-DOMAIN');

  Future<void> _enqueue(Map<String, dynamic> payload) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_settings',
      columns: const ['value'],
      where: 'key = ?',
      whereArgs: const [_queueKey],
      limit: 1,
    );

    final list = <dynamic>[];
    if (rows.isNotEmpty) {
      try {
        final raw = jsonDecode('${rows.first['value'] ?? '[]'}');
        if (raw is List) list.addAll(raw);
      } catch (_) {}
    }
    list.add(payload);

    await db.insert(
      'app_settings',
      {'key': _queueKey, 'value': jsonEncode(list)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
