import 'dart:convert';

class LicensePayload {
  final String licenseId;
  final String customerName;
  final String phone;
  final List<String> businessTypes;
  final String deviceId;
  final String platform;
  final String deviceBinding;
  final int maxDevices;
  final String plan;
  final int durationDays;
  final int issuedAt;
  final int expiresAt;
  final double priceAtPurchase;
  final String currency;
  final List<String> features;
  final String storeCode;
  final String storeBinding;

  const LicensePayload({
    required this.licenseId,
    required this.customerName,
    required this.phone,
    required this.businessTypes,
    required this.deviceId,
    required this.platform,
    this.deviceBinding = 'DEVICE',
    this.maxDevices = 1,
    required this.plan,
    required this.durationDays,
    required this.issuedAt,
    required this.expiresAt,
    required this.priceAtPurchase,
    required this.currency,
    required this.features,
    this.storeCode = '',
    this.storeBinding = 'DEVICE',
  });

  List<String> _sorted(List<String> input) => input
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList()
    ..sort();

  Map<String, dynamic> toMap() => <String, dynamic>{
        'licenseId': licenseId,
        'customerName': customerName,
        'phone': phone,
        'businessTypes': _sorted(businessTypes),
        'deviceId': deviceId,
        'platform': platform,
        'deviceBinding': deviceBinding,
        'maxDevices': maxDevices,
        'plan': plan,
        'durationDays': durationDays,
        'issuedAt': issuedAt,
        'expiresAt': expiresAt,
        'priceAtPurchase': priceAtPurchase,
        'currency': currency,
        'features': _sorted(features),
        'storeCode': storeCode,
        'storeBinding': storeBinding,
      };

  String canonicalJson() => jsonEncode(toMap());

  /// Legacy signer compatibility for old licenses generated before v2.
  String legacyCanonicalJsonV1() => jsonEncode(<String, dynamic>{
        'licenseId': licenseId,
        'customerName': customerName,
        'phone': phone,
        'businessTypes': _sorted(businessTypes),
        'deviceId': deviceId,
        'platform': platform,
        'deviceBinding': deviceBinding,
        'maxDevices': maxDevices,
        'plan': plan,
        'durationDays': durationDays,
        'issuedAt': issuedAt,
        'expiresAt': expiresAt,
        'priceAtPurchase': priceAtPurchase,
        'currency': currency,
        'features': _sorted(features),
      });

  factory LicensePayload.fromMap(Map<String, dynamic> m) {
    List<String> list(dynamic value) => value is List
        ? value.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList()
        : const <String>[];

    return LicensePayload(
      licenseId: '${m['licenseId'] ?? ''}',
      customerName: '${m['customerName'] ?? ''}',
      phone: '${m['phone'] ?? ''}',
      businessTypes: list(m['businessTypes']),
      deviceId: '${m['deviceId'] ?? ''}',
      platform: '${m['platform'] ?? ''}',
      deviceBinding: '${m['deviceBinding'] ?? 'DEVICE'}',
      maxDevices: (m['maxDevices'] as num?)?.toInt() ?? 1,
      plan: '${m['plan'] ?? '1M'}',
      durationDays: (m['durationDays'] as num?)?.toInt() ?? 30,
      issuedAt: (m['issuedAt'] as num?)?.toInt() ?? 0,
      expiresAt: (m['expiresAt'] as num?)?.toInt() ?? 0,
      priceAtPurchase: (m['priceAtPurchase'] as num?)?.toDouble() ?? 0,
      currency: '${m['currency'] ?? 'تومان'}',
      features: list(m['features']),
      storeCode: '${m['storeCode'] ?? ''}',
      storeBinding: '${m['storeBinding'] ?? 'DEVICE'}',
    );
  }

  String get canonical => canonicalJson();
}

class LicenseDocument {
  final LicensePayload payload;
  final String signatureBase64;
  final int version;

  const LicenseDocument({
    required this.payload,
    required this.signatureBase64,
    this.version = 2,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'version': version,
        'payload': payload.toMap(),
        'signature': signatureBase64,
      };

  String toJson() => const JsonEncoder.withIndent('  ').convert(toMap());

  factory LicenseDocument.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('ساختار فایل لایسنس معتبر نیست.');
    }
    final map = Map<String, dynamic>.from(decoded);
    final payloadRaw = map['payload'];
    if (payloadRaw is! Map) {
      throw const FormatException('اطلاعات لایسنس ناقص است.');
    }
    final signature = '${map['signature'] ?? ''}'.trim();
    if (signature.isEmpty) {
      throw const FormatException('امضای لایسنس وجود ندارد.');
    }
    return LicenseDocument(
      payload: LicensePayload.fromMap(Map<String, dynamic>.from(payloadRaw)),
      signatureBase64: signature,
      version: (map['version'] as num?)?.toInt() ?? 1,
    );
  }
}
