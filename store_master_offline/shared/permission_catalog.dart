// کاتالوگ نقش‌ها و دسترسی‌های مشترک (نسخه محلی درون پروژه)
class RoleCatalog {
  static const String owner = 'OWNER';
  static const String admin = 'ADMIN';
  static const String manager = 'MANAGER';
  static const String seller = 'SELLER';
  static const String warehouse = 'WAREHOUSE';
  static const String accountant = 'ACCOUNTANT';
  static const String cashier = 'CASHIER';
  static const String custom = 'CUSTOM';
}

class PermissionCatalog {
  static const String allAccess = 'ALL';
  static const String dashboardView = 'dashboard_view';
  static const String salesCreate = 'sales_create';
  static const String invoicesEdit = 'invoices_edit';
  static const String invoicesDelete = 'invoices_delete';
  static const String invoicesReturn = 'invoices_return';
  static const String productsView = 'products_view';
  static const String inventoryView = 'inventory_view';
  static const String inventoryManage = 'inventory_manage';
  static const String customersView = 'customers_view';
  static const String accountingExpenses = 'accounting_expenses';
  static const String accountingManage = 'accounting_manage';
  static const String reportsView = 'reports_view';
  static const String reportsAdvanced = 'reports_advanced';
  static const String usersManage = 'users_manage';
  static const String rolesManage = 'roles_manage';
  static const String settingsManage = 'settings_manage';
  static const String warehousesManage = 'warehouses_manage';

  static const List<String> all = [
    dashboardView,
    salesCreate,
    invoicesEdit,
    invoicesDelete,
    invoicesReturn,
    productsView,
    inventoryView,
    inventoryManage,
    customersView,
    accountingExpenses,
    accountingManage,
    reportsView,
    reportsAdvanced,
    usersManage,
    rolesManage,
    settingsManage,
    warehousesManage,
  ];
}
