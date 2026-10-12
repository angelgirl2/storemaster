import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoreRepository {
  StoreRepository._();
  static final StoreRepository instance = StoreRepository._();

  Future<Directory> _root() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(dir.path, 'StoreMasterLicenseManager'));
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  Future<File> _file() async => File(p.join((await _root()).path, 'stores.json'));

  Future<List<Map<String, dynamic>>> all() async {
    final f = await _file();
    if (!await f.exists()) return [];
    try {
      final raw = jsonDecode(await f.readAsString());
      if (raw is! List) return [];
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { return []; }
  }

  Future<void> add(Map<String, dynamic> store) async {
    final items = await all();
    items.insert(0, store);
    final f = await _file();
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(items), flush: true);
  }

  Future<bool> updateByStoreCode(
    String storeCode,
    Map<String, dynamic> patch,
  ) async {
    final code = storeCode.trim();
    if (code.isEmpty) return false;
    final items = await all();
    final index = items.indexWhere(
      (item) => '${item['storeCode'] ?? ''}'.trim() == code,
    );
    if (index < 0) return false;
    items[index] = <String, dynamic>{
      ...items[index],
      ...patch,
      'storeCode': code,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    final f = await _file();
    await f.writeAsString(
      const JsonEncoder.withIndent('  ').convert(items),
      flush: true,
    );
    return true;
  }

  Future<bool> deleteByStoreCode(String storeCode) async {
    final code = storeCode.trim();
    if (code.isEmpty) return false;
    final items = await all();
    final before = items.length;
    items.removeWhere(
      (item) => '${item['storeCode'] ?? ''}'.trim() == code,
    );
    if (items.length == before) return false;
    final f = await _file();
    await f.writeAsString(
      const JsonEncoder.withIndent('  ').convert(items),
      flush: true,
    );
    return true;
  }
}
