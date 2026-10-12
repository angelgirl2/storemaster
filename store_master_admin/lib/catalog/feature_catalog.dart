// کاتالوگ قابلیت‌های برنامه
// این کاتالوگ باید با کلاینت کاربر و License Manager یکسان باشد.
class FeatureCatalog {
  static const String sales = 'sales';
  static const String products = 'products';
  static const String inventory = 'inventory';
  static const String customers = 'customers';
  static const String accounting = 'accounting';
  static const String reports = 'reports';
  static const String businessModules = 'business_modules';
  static const String attendance = 'attendance';
  static const String multiWarehouse = 'multi_warehouse';
  static const String sms = 'sms';
  static const String advancedReports = 'advanced_reports';

  static const List<String> allFeatures = [
    sales,
    products,
    inventory,
    customers,
    accounting,
    reports,
    businessModules,
    attendance,
    multiWarehouse,
    sms,
    advancedReports,
  ];

  // سازگاری با کدهای قدیمی
  static const List<String> all = allFeatures;
}
