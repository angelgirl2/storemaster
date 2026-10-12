import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/license_models.dart';

class LicenseRepository {
  static final LicenseRepository instance = LicenseRepository._();

  LicenseRepository._();

  static const Map<int, double> defaultPrices = <int, double>{
    30: 990000,
    90: 2490000,
    180: 4490000,
    365: 7990000,
  };

  Future<Directory> _root() async {
    final dir = await getApplicationDocumentsDirectory();

    final root = Directory(
      p.join(
        dir.path,
        'StoreMasterLicenseManager',
      ),
    );

    if (!await root.exists()) {
      await root.create(
        recursive: true,
      );
    }

    return root;
  }

  Future<File> _file() async {
    return File(
      p.join(
        (await _root()).path,
        'issued_licenses.json',
      ),
    );
  }

  Future<File> _pricingFile() async {
    return File(
      p.join(
        (await _root()).path,
        'pricing.json',
      ),
    );
  }

  Future<List<Map<String, dynamic>>> all() async {
    final file = await _file();

    if (!await file.exists()) {
      return <Map<String, dynamic>>[];
    }

    final text = await file.readAsString(
      encoding: utf8,
    );

    if (text.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final data = jsonDecode(text);

      if (data is! List) {
        return <Map<String, dynamic>>[];
      }

      return data
          .whereType<Map>()
          .map(
            (e) => Map<String, dynamic>.from(e),
          )
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _writeHistory(
    List<Map<String, dynamic>> items,
  ) async {
    final file = await _file();

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(items),
      encoding: utf8,
      flush: true,
    );
  }

  Future<void> add(
    LicensePayload payload, {
    String status = 'ACTIVE',
    String note = '',
    double? originalPrice,
    double? finalPrice,
    String? discountCode,
    bool serverSynced = false,
  }) async {
    final items = await all();

    final data = Map<String, dynamic>.from(
      payload.toMap(),
    );

    data['status'] = status;
    data['originalPrice'] = originalPrice ?? payload.priceAtPurchase;
    data['finalPrice'] = finalPrice ?? payload.priceAtPurchase;
    data['discountCode'] = discountCode ?? '';
    data['serverSynced'] = serverSynced;

    if (note.trim().isNotEmpty) {
      data['note'] = note.trim();
    }

    data['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

    items.insert(0, data);

    await _writeHistory(items);


  }

  Future<bool> updateStatus(
    String licenseId,
    String status, {
    String? note,
  }) async {
    final id = licenseId.trim();

    if (id.isEmpty) {
      return false;
    }

    final items = await all();

    final index = items.indexWhere(
      (item) => item['licenseId']?.toString().trim() == id,
    );

    if (index < 0) {
      return false;
    }

    items[index]['status'] = status.toUpperCase();

    if (note != null && note.trim().isNotEmpty) {
      items[index]['note'] = note.trim();
    }

    items[index]['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

    await _writeHistory(items);

    // License Manager is offline-first. Changing local status must never
    // depend on an HTTP request or make the UI wait for a server.
    return true;
  }

  Future<bool> replace(
    String licenseId,
    Map<String, dynamic> data,
  ) async {
    final id = licenseId.trim();
    if (id.isEmpty) return false;
    final items = await all();
    final index = items.indexWhere(
      (item) => item['licenseId']?.toString().trim() == id,
    );
    if (index < 0) return false;
    items[index] = {
      ...items[index],
      ...data,
      'licenseId': id,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await _writeHistory(items);
    return true;
  }

  Future<bool> deleteByLicenseId(
    String licenseId,
  ) async {
    final id = licenseId.trim();

    if (id.isEmpty) {
      return false;
    }

    final items = await all();

    final before = items.length;

    items.removeWhere(
      (item) => item['licenseId']?.toString().trim() == id,
    );

    if (items.length == before) {
      return false;
    }

    await _writeHistory(items);

    return true;
  }

  Future<int> clearHistory() async {
    final items = await all();

    if (items.isEmpty) {
      return 0;
    }

    final count = items.length;

    await _writeHistory(
      <Map<String, dynamic>>[],
    );

    return count;
  }

  Future<Map<int, double>> getPrices() async {
    final file = await _pricingFile();

    if (!await file.exists()) {
      await setPrices(
        defaultPrices,
      );

      return <int, double>{
        ...defaultPrices,
      };
    }

    try {
      final raw = jsonDecode(
        await file.readAsString(
          encoding: utf8,
        ),
      );

      if (raw is Map) {
        final result = <int, double>{};

        for (final entry in raw.entries) {
          final key = int.tryParse(
            entry.key.toString(),
          );

          final value = entry.value is num
              ? (entry.value as num).toDouble()
              : double.tryParse(
                  entry.value.toString(),
                );

          if (key != null && value != null && value >= 0) {
            result[key] = value;
          }
        }

        for (final entry in defaultPrices.entries) {
          result.putIfAbsent(
            entry.key,
            () => entry.value,
          );
        }

        return result;
      }
    } catch (_) {}

    return <int, double>{
      ...defaultPrices,
    };
  }

  Future<void> setPrices(
    Map<int, double> prices,
  ) async {
    final file = await _pricingFile();

    final data = <String, dynamic>{
      for (final entry in prices.entries) entry.key.toString(): entry.value,
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      encoding: utf8,
      flush: true,
    );
  }

  Future<void> savePricingCatalog(
    File target,
  ) async {
    final prices = await getPrices();

    final data = <String, dynamic>{
      'version': 1,
      'currency': 'تومان',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'prices': <String, dynamic>{
        for (final entry in prices.entries) entry.key.toString(): entry.value,
      },
    };

    await target.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      encoding: utf8,
      flush: true,
    );
  }
}
