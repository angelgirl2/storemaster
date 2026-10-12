import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'license_key_config.dart';

class LicenseRevocationService {
  static final LicenseRevocationService instance = LicenseRevocationService._();
  LicenseRevocationService._();

  static final Ed25519 _algorithm = Ed25519();

  Future<Directory> _root() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(dir.path, 'StoreMasterLicenseManager'));
    await root.create(recursive: true);
    return root;
  }

  Future<File> _stateFile() async => File(p.join((await _root()).path, 'revocations.json'));

  Future<List<Map<String, dynamic>>> all() async {
    final file = await _stateFile();
    if (!await file.exists()) return <Map<String, dynamic>>[];
    try {
      final raw = jsonDecode(await file.readAsString(encoding: utf8));
      if (raw is! List) return <Map<String, dynamic>>[];
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> revoke(String licenseId, {String reason = 'CANCELLED'}) async {
    final id = licenseId.trim();
    if (id.isEmpty) return;
    final items = await all();
    final exists = items.any((e) => '${e['licenseId'] ?? ''}'.trim() == id);
    if (exists) return;
    items.insert(0, <String, dynamic>{
      'licenseId': id,
      'reason': reason.trim().isEmpty ? 'CANCELLED' : reason.trim().toUpperCase(),
      'revokedAt': DateTime.now().millisecondsSinceEpoch,
    });
    final file = await _stateFile();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(items), encoding: utf8, flush: true);
  }

  Future<String> exportSignedPackage() async {
    final revocations = await all();
    final generatedAt = DateTime.now().millisecondsSinceEpoch;
    final payload = <String, dynamic>{
      'schema': 'StoreMaster.Revocations.v1',
      'generatedAt': generatedAt,
      'items': revocations,
    };
    final canonical = jsonEncode(payload);
    final seed = base64Decode(LicenseKeyConfig.privateSeedBase64);
    final keyPair = await _algorithm.newKeyPairFromSeed(seed);
    final signature = await _algorithm.sign(utf8.encode(canonical), keyPair: keyPair);
    final doc = <String, dynamic>{
      'version': 1,
      'payload': payload,
      'signature': base64Encode(signature.bytes),
    };
    final file = File(p.join((await _root()).path, 'StoreMaster_revocations_${generatedAt}.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(doc), encoding: utf8, flush: true);
    return file.path;
  }
}
