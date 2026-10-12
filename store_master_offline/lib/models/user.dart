import '../shared_src/permission_catalog.dart';


List<String> _permissionsFromMap(Map<String, dynamic> m) {
  final raw = '${m['permissions'] ?? ''}'.trim();
  final parsed = raw
      .split('|')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();
  if (parsed.isNotEmpty) return parsed;
  return User.defaultPermissionsForRole('${m['role'] ?? RoleCatalog.seller}');
}

// مدل User - کاربران سیستم
class User {
  static List<String> defaultPermissionsForRole(String role) {
    switch (role.trim().toUpperCase()) {
      case RoleCatalog.owner:
      case RoleCatalog.admin:
        return <String>[...PermissionCatalog.all, PermissionCatalog.allAccess];
      case RoleCatalog.manager:
        return PermissionCatalog.all
            .where((p) =>
                p != PermissionCatalog.rolesManage &&
                p != PermissionCatalog.settingsManage)
            .toList();
      case RoleCatalog.seller:
      case RoleCatalog.cashier:
        return <String>[
          PermissionCatalog.dashboardView,
          PermissionCatalog.salesCreate,
          PermissionCatalog.customersView,
          PermissionCatalog.productsView,
          PermissionCatalog.invoicesEdit,
          PermissionCatalog.invoicesDelete,
          PermissionCatalog.invoicesReturn,
        ];
      case RoleCatalog.warehouse:
        return <String>[
          PermissionCatalog.dashboardView,
          PermissionCatalog.productsView,
          PermissionCatalog.inventoryView,
          PermissionCatalog.inventoryManage,
          PermissionCatalog.warehousesManage,
        ];
      case RoleCatalog.accountant:
        return <String>[
          PermissionCatalog.dashboardView,
          PermissionCatalog.reportsView,
          PermissionCatalog.reportsAdvanced,
          PermissionCatalog.accountingExpenses,
          PermissionCatalog.accountingManage,
        ];
      default:
        return <String>[];
    }
  }

  final int id;
  final String name;
  final String pin;
  final String role; // "ADMIN" or "SELLER"
  final String phone;
  final bool isActive;
  final double baseSalary;
  final double commissionPercent;
  final double totalSalesAmount;
  final double totalCommission;
  final int createdAt;
  final int storeId;
  final int serverUserId;
  final List<String> permissions;

  User({
    this.id = 0,
    required this.name,
    required this.pin,
    required this.role,
    this.phone = '',
    this.isActive = true,
    this.baseSalary = 0.0,
    this.commissionPercent = 0.0,
    this.totalSalesAmount = 0.0,
    this.totalCommission = 0.0,
    int? createdAt,
    required String pinCode,
    this.storeId = 0,
    this.serverUserId = 0,
    this.permissions = const <String>[],
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'name': name,
        'pin': pin,
        'role': role,
        'phone': phone,
        'isActive': isActive ? 1 : 0,
        'baseSalary': baseSalary,
        'commissionPercent': commissionPercent,
        'totalSalesAmount': totalSalesAmount,
        'totalCommission': totalCommission,
        'createdAt': createdAt,
        'storeId': storeId,
        'serverUserId': serverUserId,
        'permissions': permissions.join('|'),
      };

  factory User.fromMap(Map<String, dynamic> m) => User(
        id: (m['id'] as num?)?.toInt() ?? 0,
        name: (m['name'] as String?) ?? '',
        pin: (m['pin'] as String?) ?? '',
        role: (m['role'] as String?) ?? 'SELLER',
        phone: (m['phone'] as String?) ?? '',
        isActive: (m['isActive'] as num? ?? 1) == 1,
        baseSalary: (m['baseSalary'] as num?)?.toDouble() ?? 0.0,
        commissionPercent: (m['commissionPercent'] as num?)?.toDouble() ?? 0.0,
        totalSalesAmount: (m['totalSalesAmount'] as num?)?.toDouble() ?? 0.0,
        totalCommission: (m['totalCommission'] as num?)?.toDouble() ?? 0.0,
        createdAt: (m['createdAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        pinCode: '',
        storeId: (m['storeId'] as num?)?.toInt() ?? 0,
        serverUserId: (m['serverUserId'] as num?)?.toInt() ?? 0,
        permissions: _permissionsFromMap(m),
      );

  User copyWith(
          {int? id,
          String? name,
          String? pin,
          String? role,
          String? phone,
          bool? isActive,
          double? baseSalary,
          double? commissionPercent,
          double? totalSalesAmount,
          double? totalCommission,
          int? storeId,
          int? serverUserId,
          List<String>? permissions}) =>
      User(
        id: id ?? this.id,
        name: name ?? this.name,
        pin: pin ?? this.pin,
        role: role ?? this.role,
        phone: phone ?? this.phone,
        isActive: isActive ?? this.isActive,
        baseSalary: baseSalary ?? this.baseSalary,
        commissionPercent: commissionPercent ?? this.commissionPercent,
        totalSalesAmount: totalSalesAmount ?? this.totalSalesAmount,
        totalCommission: totalCommission ?? this.totalCommission,
        createdAt: createdAt,
        pinCode: '',
        storeId: storeId ?? this.storeId,
        serverUserId: serverUserId ?? this.serverUserId,
        permissions: permissions ?? this.permissions,
      );
}
