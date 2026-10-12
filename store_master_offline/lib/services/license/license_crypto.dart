import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class LicenseCrypto {
  static const String publicKeyBase64 =
      'oTq2ZeINbTmkIUIzS+IzGCpo16CujKEPYSSt6QEHHdA=';
  static final Ed25519 _algorithm = Ed25519();

  static Future<bool> verify(
    String canonicalPayload,
    String signatureBase64,
  ) async {
    try {
      final sig = Signature(
        base64Decode(signatureBase64.trim()),
        publicKey: SimplePublicKey(
          base64Decode(publicKeyBase64),
          type: KeyPairType.ed25519,
        ),
      );
      return await _algorithm.verify(
        utf8.encode(canonicalPayload),
        signature: sig,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<String?> verifyPayload(
    String currentCanonical,
    String legacyCanonical,
    String signatureBase64,
  ) async {
    if (await verify(currentCanonical, signatureBase64)) return 'v2';
    if (legacyCanonical != currentCanonical &&
        await verify(legacyCanonical, signatureBase64)) {
      return 'v1';
    }
    return null;
  }
}
