import '../shared_src/permission_catalog.dart';

class PermissionService {
  static Set<String> defaultPermissionsForRole(String role) {
    switch (role.trim().toUpperCase()) {
      case RoleCatalog.owner:
      case RoleCatalog.admin:
        return {PermissionCatalog.allAccess};
      case RoleCatalog.manager:
        return PermissionCatalog.all
            .where((p) => p != PermissionCatalog.rolesManage && p != PermissionCatalog.settingsManage)
            .toSet();
      case RoleCatalog.seller:
      case RoleCatalog.cashier:
        return {PermissionCatalog.dashboardView, PermissionCatalog.salesCreate, PermissionCatalog.customersView, PermissionCatalog.productsView, PermissionCatalog.invoicesEdit, PermissionCatalog.invoicesDelete, PermissionCatalog.invoicesReturn};
      case RoleCatalog.warehouse:
        return {PermissionCatalog.dashboardView, PermissionCatalog.productsView, PermissionCatalog.inventoryView, PermissionCatalog.inventoryManage, PermissionCatalog.warehousesManage};
      case RoleCatalog.accountant:
        return {PermissionCatalog.dashboardView, PermissionCatalog.reportsView, PermissionCatalog.reportsAdvanced, PermissionCatalog.accountingExpenses, PermissionCatalog.accountingManage};
      default:
        return <String>{};
    }
  }

  static bool can({required String role, required Iterable<String> permissions, required String permission}) {
    final normalizedRole = role.trim().toUpperCase();
    if (normalizedRole == RoleCatalog.owner || normalizedRole == RoleCatalog.admin) return true;
    final set = permissions.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final effective = set.isEmpty ? defaultPermissionsForRole(normalizedRole) : set;
    return effective.contains(PermissionCatalog.allAccess) || effective.contains(permission);
  }
}
