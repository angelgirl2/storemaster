import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class OnlineConfig {
  static final instance = OnlineConfig._();
  OnlineConfig._();
  String baseUrl = const String.fromEnvironment('STORE_MASTER_API_URL',
      defaultValue: 'http://localhost:8080');
  String fallbackUrl = const String.fromEnvironment(
    'STORE_MASTER_API_FALLBACK_URL',
    defaultValue: '',
  );
  bool required = const bool.fromEnvironment('STORE_MASTER_ONLINE_REQUIRED',
      defaultValue: false);

  List<String> get apiBaseUrls {
    final values = <String>[baseUrl, fallbackUrl]
        .map((value) => value.trim().replaceFirst(RegExp(r'/$'), ''))
        .where((value) => value.isNotEmpty && !value.contains('YOUR-DOMAIN'))
        .toList();
    return values.toSet().toList();
  }
  Future<void> load() async {
    try {
      final d = await getApplicationSupportDirectory();
      final f = File(p.join(d.path, 'StoreMaster', 'online_config.json'));
      if (!await f.exists()) return;
      final x = jsonDecode(await f.readAsString());
      if (x is Map) {
        final u = '${x['baseUrl'] ?? ''}'.trim();
        if (u.isNotEmpty) baseUrl = u.replaceFirst(RegExp(r'/$'), '');
        final fallback = '${x['fallbackUrl'] ?? ''}'.trim();
        if (fallback.isNotEmpty) fallbackUrl = fallback.replaceFirst(RegExp(r'/$'), '');
        if (x['required'] is bool) required = x['required'];
      }
    } catch (_) {}
  }
}
