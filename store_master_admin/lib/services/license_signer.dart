import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'license_key_config.dart';
import '../models/license_models.dart';

class LicenseSigner {
  static final Ed25519 _algorithm = Ed25519();

  static Future<String> sign(LicensePayload payload) async {
    final seed = base64Decode(LicenseKeyConfig.privateSeedBase64);
    if (seed.length != 32) {
      throw StateError('کلید خصوصی لایسنس باید دقیقاً ۳۲ بایت باشد.');
    }
    final keyPair = await _algorithm.newKeyPairFromSeed(seed);
    final signature = await _algorithm.sign(
      utf8.encode(payload.canonicalJson()),
      keyPair: keyPair,
    );
    return base64Encode(signature.bytes);
  }

  static Future<bool> selfTest(LicensePayload payload, String signature) async {
    try {
      final seed = base64Decode(LicenseKeyConfig.privateSeedBase64);
      final keyPair = await _algorithm.newKeyPairFromSeed(seed);
      final publicKey = await keyPair.extractPublicKey();
      final sig = Signature(
        base64Decode(signature),
        publicKey: publicKey,
      );
      return await _algorithm.verify(
        utf8.encode(payload.canonicalJson()),
        signature: sig,
      );
    } catch (_) {
      return false;
    }
  }
}
