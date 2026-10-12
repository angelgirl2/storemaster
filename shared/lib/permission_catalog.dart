// ============================================================================
// permission_catalog.dart
// مرجع واحد نقش‌ها و مجوزهای سیستم
// ============================================================================

class RoleCatalog {
  static const String owner = 'OWNER';
  static const String admin = 'ADMIN';
  static const String manager = 'MANAGER';
  static const String seller = 'SELLER';
  static const String warehouse = 'WAREHOUSE';
  static const String accountant = 'ACCOUNTANT';
  static const String cashier = 'CASHIER';
  static const String custom = 'CUSTOM';

  static const List<String> all = <String>[
    owner,
    admin,
    manager,
    seller,
    warehouse,
    accountant,
    cashier,
    custom,
  ];
}

class PermissionCatalog {
  // --------------------------------------------------------------------------
  // دسترسی کامل
  // --------------------------------------------------------------------------

  static const String allAccess = 'ALL';

  // --------------------------------------------------------------------------
  // داشبورد و فروش
  // --------------------------------------------------------------------------

  static const String dashboardView = 'dashboard_view';
  static const String salesCreate = 'sales_create';

  // --------------------------------------------------------------------------
  // فاکتورها
  // --------------------------------------------------------------------------

  static const String invoicesEdit = 'invoices_edit';
  static const String invoicesDelete = 'invoices_delete';

  // --------------------------------------------------------------------------
  // کالا
  // --------------------------------------------------------------------------

  static const String productsView = 'products_view';

  // --------------------------------------------------------------------------
  // انبار
  // --------------------------------------------------------------------------

  static const String inventoryView = 'inventory_view';
  static const String inventoryManage = 'inventory_manage';
  static const String warehousesManage = 'warehouses_manage';

  // --------------------------------------------------------------------------
  // مشتری / طرف حساب
  // --------------------------------------------------------------------------

  static const String customersView = 'customers_view';

  // --------------------------------------------------------------------------
  // حسابداری
  // --------------------------------------------------------------------------

  static const String accountingExpenses = 'accounting_expenses';
  static const String accountingManage = 'accounting_manage';

  // --------------------------------------------------------------------------
  // گزارش‌ها
  // --------------------------------------------------------------------------

  static const String reportsView = 'reports_view';
  static const String reportsAdvanced = 'reports_advanced';

  // --------------------------------------------------------------------------
  // کاربران و تنظیمات
  // --------------------------------------------------------------------------

  static const String usersManage = 'users_manage';
  static const String rolesManage = 'roles_manage';
  static const String settingsManage = 'settings_manage';

  // --------------------------------------------------------------------------
  // فقط permissionهای واقعی
  //
  // ALL عمداً داخل این لیست نیست.
  // --------------------------------------------------------------------------

  static const List<String> all = <String>[
    dashboardView,
    salesCreate,
    invoicesEdit,
    invoicesDelete,
    productsView,
    inventoryView,
    inventoryManage,
    warehousesManage,
    customersView,
    accountingExpenses,
    accountingManage,
    reportsView,
    reportsAdvanced,
    usersManage,
    rolesManage,
    settingsManage,
  ];

  // --------------------------------------------------------------------------
  // همه permissionها + ALL
  // --------------------------------------------------------------------------

  static const List<String> allWithAccess = <String>[allAccess, ...all];
}
