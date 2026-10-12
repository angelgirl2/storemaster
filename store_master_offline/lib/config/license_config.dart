class LicenseConfig {
  /// کنترل فعال بودن اعتبارسنجی آنلاین لایسنس.
  ///
  /// پیش‌فرض false است تا برنامه‌ی آفلاین بدون سرور اجرا شود.
  /// برای نسخه‌ای که به API وصل می‌شود:
  /// --dart-define=STORE_MASTER_ONLINE_LICENSE_ENABLED=true
  static const bool onlineLicenseEnabled = bool.fromEnvironment(
    'STORE_MASTER_ONLINE_LICENSE_ENABLED',
    defaultValue: false,
  );
}
