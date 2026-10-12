// مدل‌های Session آنلاین مشترک (نسخه محلی درون پروژه)
class OnlineSession {
  final String accessToken;
  final String refreshToken;
  final String storeCode;
  final int storeId;
  final int userId;
  final String name;
  final String role;
  final List<String> permissions;
  final List<String> features;
  final List<String> businessTypes;
  final int licenseExpiresAt;
  final String licenseStatus;
  final String licenseId;
  final String licensePlan;
  final String storeName;
  final String storeType;
  final String businessTitle;
  final String currency;

  const OnlineSession({
    this.accessToken = '',
    this.refreshToken = '',
    this.storeCode = '',
    this.storeId = 0,
    this.userId = 0,
    this.name = '',
    this.role = 'SELLER',
    this.permissions = const [],
    this.features = const [],
    this.businessTypes = const [],
    this.licenseExpiresAt = 0,
    this.licenseStatus = '',
    this.licenseId = '',
    this.licensePlan = 'TRIAL',
    this.storeName = '',
    this.storeType = 'GENERAL',
    this.businessTitle = 'فروشگاه',
    this.currency = 'تومان',
  });

  factory OnlineSession.fromMap(Map<String, dynamic> m) {
    List<String> list(dynamic v) =>
        v is List ? v.map((e) => '$e').toList() : const <String>[];

    return OnlineSession(
      accessToken: '${m['accessToken'] ?? m['access_token'] ?? ''}',
      refreshToken: '${m['refreshToken'] ?? m['refresh_token'] ?? ''}',
      storeCode: '${m['storeCode'] ?? m['store_code'] ?? ''}',
      storeId: (m['storeId'] as num?)?.toInt() ??
          (m['store_id'] as num?)?.toInt() ??
          0,
      userId: (m['userId'] as num?)?.toInt() ??
          (m['user_id'] as num?)?.toInt() ??
          0,
      name: '${m['name'] ?? ''}',
      role: '${m['role'] ?? 'SELLER'}',
      permissions: list(m['permissions']),
      features: list(m['features']),
      businessTypes: list(m['businessTypes'] ?? m['business_types']),
      licenseExpiresAt: (m['licenseExpiresAt'] as num?)?.toInt() ??
          (m['license_expires_at'] as num?)?.toInt() ??
          0,
      licenseStatus: '${m['licenseStatus'] ?? m['license_status'] ?? ''}',
      licenseId: '${m['licenseId'] ?? m['license_id'] ?? ''}',
      licensePlan: '${m['licensePlan'] ?? m['license_plan'] ?? 'TRIAL'}',
      storeName: '${m['storeName'] ?? m['store_name'] ?? ''}',
      storeType: '${m['storeType'] ?? m['store_type'] ?? 'GENERAL'}',
      businessTitle: '${m['businessTitle'] ?? m['business_title'] ?? 'فروشگاه'}',
      currency: '${m['currency'] ?? 'تومان'}',
    );
  }
}
