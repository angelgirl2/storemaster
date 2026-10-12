class LicenseConfig {
  // Online activation is kept in code but disabled until server deployment.
  static const bool onlineLicenseEnabled = bool.fromEnvironment('STORE_MASTER_ADMIN_ONLINE_ENABLED', defaultValue: false);
}
