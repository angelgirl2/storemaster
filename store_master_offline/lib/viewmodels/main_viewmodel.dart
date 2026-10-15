// ============================================================================
// main_viewmodel.dart
// MainViewModel کامل، ایمن و هماهنگ با تمام قابلیت‌ها و محدودیت‌های سطوح دسترسی
// ============================================================================

import 'dart:io';
import 'dart:async';
import '../utils/shamsi_date_utils.dart';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';
import '../models/audit_log.dart';
import '../models/cart_item.dart';
import '../models/contact.dart';
import '../models/expense.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../models/store_config.dart';
import '../models/store_transaction.dart';
import '../models/transaction_item.dart';
import '../models/user.dart';
import '../models/accounting_models.dart';
import '../models/business_profile.dart';
import '../services/backup_manager.dart';
import '../services/exporter.dart';
import '../services/store_repository.dart';
import '../services/online_api_service.dart';
import '../services/online_config.dart';
import '../services/online_session_store.dart';
import '../services/cloud_sync_service.dart';
import '../services/local_network_sync_service.dart';
import '../services/license/license_service.dart';
import '../services/permission_service.dart';
import '../shared_src/permission_catalog.dart';
import '../shared_src/business_catalog.dart';

// ===========================================================================
// صفحات اصلی برنامه
// ===========================================================================
enum AppScreen {
  setup,
  login,
  dashboard,
  pos,
  products,
  stock,
  expenses,
  contacts,
  users,
  reports,
  settings,
  logs,
  invoices,
  accounting,
}

// ============================================================================
// نتیجه گزارش شیفت
// ============================================================================

class ShiftReportResult {
  final double morningSales;
  final double eveningSales;
  final double morningProfit;
  final double eveningProfit;

  const ShiftReportResult({
    required this.morningSales,
    required this.eveningSales,
    required this.morningProfit,
    required this.eveningProfit,
  });
}

// ============================================================================
// MainViewModel
// ============================================================================

class MainViewModel extends ChangeNotifier {
  MainViewModel({
    StoreRepository? repository,
  }) : _repo = repository ?? StoreRepository() {
    LocalNetworkSyncService.instance.addListener(_onLocalNetworkSyncChanged);
    _cloudSyncSubscription =
        CloudSyncService.instance.changes.listen(_onCloudSyncChanged);
  }
  final StoreRepository _repo;

  // --------------------------------------------------------------------------
  // وضعیت کلی برنامه
  // --------------------------------------------------------------------------
  StoreConfig? _config;
  User? _currentUser;

  List<User> _users = <User>[];
  List<Product> _products = <Product>[];
  List<Product> _lowStock = <Product>[];
  List<Contact> _contacts = <Contact>[];
  List<Contact> _debtors = <Contact>[];
  List<Contact> _creditors = <Contact>[];
  List<Expense> _expenses = <Expense>[];
  List<StoreTransaction> _transactions = <StoreTransaction>[];
  List<StockMovement> _stockMovements = <StockMovement>[];
  List<AuditLog> _auditLogs = <AuditLog>[];
  List<AttendanceRecord> _attendance = <AttendanceRecord>[];
  List<CartItem> _cart = <CartItem>[];

  Contact? _selectedCustomer;

  double _discount = 0.0;
  String _paymentMethod = 'CASH';
  String _searchQuery = '';
  String? _userMessage;

  AppScreen _currentScreen = AppScreen.dashboard;

  bool _isLoading = false;
  bool _hasLoadError = false; // جلوگیری از صفحه خاکستری و مدیریت خطای لود
  String? _loadErrorMessage;
  bool _isCheckingOut = false;
  bool _disposed = false;
  Timer? _syncTimer;
  Timer? _localRefreshTimer;
  Timer? _cloudRefreshTimer;
  StreamSubscription<int>? _cloudSyncSubscription;
  int _lastLocalSyncChangeVersion = 0;

  // --------------------------------------------------------------------------
  // Getterها
  // --------------------------------------------------------------------------

  StoreConfig? get config => _config;

  User? get currentUser => _currentUser;

  List<User> get users => List<User>.unmodifiable(_users);

  List<Product> get products => List<Product>.unmodifiable(_products);

  List<Product> get lowStockProducts => List<Product>.unmodifiable(_lowStock);

  List<Contact> get allContacts => List<Contact>.unmodifiable(_contacts);

  List<Contact> get debtors => List<Contact>.unmodifiable(_debtors);

  List<Contact> get creditors => List<Contact>.unmodifiable(_creditors);

  List<Expense> get expenses => List<Expense>.unmodifiable(_expenses);

  // تفکیک دسترسی تراکنش‌ها: فروشنده فقط فاکتورهای خودش را می‌بیند، مدیر کل همه را می‌بیند
  List<StoreTransaction> get transactions {
    final user = _currentUser;
    if (user == null) {
      return const <StoreTransaction>[];
    }
    if (isAdmin) {
      return List<StoreTransaction>.unmodifiable(_transactions);
    }
    // هر فروشنده/صندوقدار فقط تراکنش‌های ثبت‌شده توسط خودش را می‌بیند.
    // userId تراکنش محلی است؛ در داده‌های قدیمی که نام کاربر معتبر است
    // fallback به نام هم اعمال می‌شود تا رکوردهای قبلی از دست نروند.
    final owned = _transactions.where((t) =>
        t.userId == user.id ||
        (t.userId <= 0 && t.userName.trim() == user.name.trim()));
    return List<StoreTransaction>.unmodifiable(owned);
  }

  bool canEditOrDeleteTransaction(StoreTransaction transaction) {
    final user = _currentUser;
    if (user == null) return false;
    if (isAdmin) return true;
    return transaction.userId == user.id ||
        (transaction.userId <= 0 && transaction.userName.trim() == user.name.trim());
  }

  bool canViewAttendanceManagement() => isAdmin;

  List<StockMovement> get stockMovements =>
      List<StockMovement>.unmodifiable(_stockMovements);

  // لاگ سیستم فقط برای مدیر اصلی/مالک قابل مشاهده است.
  List<AuditLog> get auditLogs => isAdmin
      ? List<AuditLog>.unmodifiable(_auditLogs)
      : const <AuditLog>[];

  // کاربر عادی فقط رکوردهای حضور خودش را می‌بیند؛ مدیر همه رکوردها را می‌بیند.
  List<AttendanceRecord> get attendance {
    if (isAdmin) return List<AttendanceRecord>.unmodifiable(_attendance);
    final user = _currentUser;
    if (user == null) return const <AttendanceRecord>[];
    return List<AttendanceRecord>.unmodifiable(
      _attendance.where((a) => a.userId == user.id),
    );
  }

  List<CartItem> get cart => List<CartItem>.unmodifiable(_cart);

  Contact? get selectedCustomer => _selectedCustomer;

  double get discountAmount => _discount;

  String get paymentMethod => _paymentMethod;

  String get searchQuery => _searchQuery;

  String? get userMessage => _userMessage;

  String? get lastStatusMessage => _userMessage;

  AppScreen get currentScreen => _currentScreen;

  bool get isLoading => _isLoading;

  bool get hasLoadError => _hasLoadError;

  String? get loadErrorMessage => _loadErrorMessage;

  bool get isCheckingOut => _isCheckingOut;

  bool get isAdmin =>
      _currentUser?.role == 'ADMIN' || _currentUser?.role == 'OWNER';

  bool hasPermission(String permission) {
    final u = _currentUser;
    return u != null &&
        PermissionService.can(
            role: u.role, permissions: u.permissions, permission: permission);
  }

  double get rawTotal {
    return _cart.fold<double>(
      0.0,
      (sum, item) => sum + item.totalPrice.toDouble(),
    );
  }

  double get finalTotal {
    return (rawTotal - _discount).clamp(0.0, double.infinity).toDouble();
  }

  int get cartItemsCount {
    return _cart.fold<int>(
      0,
      (sum, item) => sum + item.quantity.ceil(),
    );
  }

  // --------------------------------------------------------------------------
  // مدیریت ChangeNotifier
  // --------------------------------------------------------------------------

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _onLocalNetworkSyncChanged() {
    if (_disposed) return;
    // Connection/status notifications must NOT reload the entire UI.
    // Only a real database change received over LAN should trigger a reload.
    final version = LocalNetworkSyncService.instance.dataChangeVersion;
    if (version == _lastLocalSyncChangeVersion) return;
    _lastLocalSyncChangeVersion = version;

    _localRefreshTimer?.cancel();
    _localRefreshTimer = Timer(const Duration(milliseconds: 250), () async {
      if (_disposed) return;
      try { await loadAll(showLoading: false); } catch (_) {}
    });
  }


  void _onCloudSyncChanged(int _) {
    if (_disposed || _currentUser == null) return;
    _cloudRefreshTimer?.cancel();
    _cloudRefreshTimer = Timer(const Duration(milliseconds: 250), () async {
      if (_disposed) return;
      if (_isLoading) {
        _onCloudSyncChanged(0);
        return;
      }
      await loadAll(showLoading: false);
    });
  }

  @override
  void dispose() {
    LocalNetworkSyncService.instance.removeListener(_onLocalNetworkSyncChanged);
    _cloudSyncSubscription?.cancel();
    _disposed = true;
    _syncTimer?.cancel();
    _localRefreshTimer?.cancel();
    _cloudRefreshTimer?.cancel();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // پیام‌ها
  // --------------------------------------------------------------------------

  void showMessage(String message) {
    _userMessage = message;
    _notify();
  }

  void clearMessage() {
    if (_userMessage == null) {
      return;
    }

    _userMessage = null;
    _notify();
  }

  void setScreen(AppScreen screen) {
    if (_currentScreen == screen) {
      return;
    }

    _currentScreen = screen;
    _notify();
  }

  // --------------------------------------------------------------------------
  // بارگذاری اطلاعات (ایمن شده در برابر صفحه خاکستری و کرش)
  // --------------------------------------------------------------------------

  Future<void> loadAll({bool showLoading = true}) async {
    // A data reload must never replace the current page with a global
    // loading screen. The initial bootstrap already gates AppShell on its
    // own ready flag, so notifying here before SQLite finishes only causes
    // a visible app-wide rebuild/flicker.
    if (_isLoading) {
      return;
    }

    if (showLoading) {
      _isLoading = true;
    }
    _hasLoadError = false;
    _loadErrorMessage = null;

    try {
      _config = await _repo.getConfig();

      final results = await Future.wait<dynamic>([
        _repo.getAllUsers(),
        _repo.getAllProducts(),
        _repo.getAllContacts(),
        _repo.getAllExpenses(),
        _repo.getAllTransactions(),
        _repo.getAllMovements(),
        _repo.getRecentLogs(),
        _repo.getAllAttendance(),
        _repo.getLowStockProducts(),
        _repo.getDebtors(),
        _repo.getCreditors(),
      ]);

      _users = List<User>.from(results[0] as List);
      _products = List<Product>.from(results[1] as List);
      _contacts = List<Contact>.from(results[2] as List);
      _expenses = List<Expense>.from(results[3] as List);
      _transactions = List<StoreTransaction>.from(results[4] as List);
      _stockMovements = List<StockMovement>.from(results[5] as List);
      _auditLogs = List<AuditLog>.from(results[6] as List);
      _attendance = List<AttendanceRecord>.from(results[7] as List);
      _lowStock = List<Product>.from(results[8] as List);
      _debtors = List<Contact>.from(results[9] as List);
      _creditors = List<Contact>.from(results[10] as List);

      _sortLoadedData();
    } catch (error) {
      _hasLoadError = true;
      _loadErrorMessage = 'خطا در بارگذاری اطلاعات: $error';
      _userMessage = 'مشکلی در دریافت اطلاعات پایگاه داده رخ داد.';
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      _notify();
      // Most write operations finish by refreshing this ViewModel. Kick off
      // cloud sync here so non-sale updates also leave the device immediately.
      if (!_hasLoadError && _currentUser != null) {
        CloudSyncService.instance.requestSync();
      }
    }
  }

  Future<void> refreshAfterChange() async {
    await loadAll();
  }

  void _sortLoadedData() {
    _transactions.sort(
      (a, b) => b.dateMillis.compareTo(a.dateMillis),
    );

    _expenses.sort(
      (a, b) => b.dateMillis.compareTo(a.dateMillis),
    );

    _stockMovements.sort(
      (a, b) => b.dateMillis.compareTo(a.dateMillis),
    );

    _auditLogs.sort(
      (a, b) => b.timestamp.compareTo(a.timestamp),
    );

    _attendance.sort(
      (a, b) => b.clockInTime.compareTo(a.clockInTime),
    );
  }

  Future<void> _reloadAuditLogs() async {
    _auditLogs = await _repo.getRecentLogs();

    _auditLogs.sort(
      (a, b) => b.timestamp.compareTo(a.timestamp),
    );
  }

  // --------------------------------------------------------------------------
  // تنظیم اولیه فروشگاه
  // --------------------------------------------------------------------------

  Future<void> saveInitialSetup({
    required String storeName,
    required String storeType,
    String? businessTitle,
    String logoBase64 = '',
    required String colorTheme,
    required String currency,
    required String layoutStyle,
    required String adminName,
    required String adminPin,
  }) async {
    final normalizedStoreName = storeName.trim();
    final normalizedAdminName = adminName.trim();
    final normalizedPin = _normalizeDigits(adminPin.trim());

    if (normalizedStoreName.isEmpty) {
      throw ArgumentError('نام فروشگاه الزامی است.');
    }

    if (normalizedAdminName.isEmpty) {
      throw ArgumentError('نام مدیر الزامی است.');
    }

    if (normalizedPin.length < 4) {
      throw ArgumentError(
        'پین مدیر باید حداقل چهار رقم باشد.',
      );
    }

    if (await _repo.pinExists(normalizedPin)) {
      throw ArgumentError(
          'این پین قبلاً برای یک کاربر ثبت شده است. پین دیگری انتخاب کنید.');
    }

    final normalizedStoreType = storeType
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .join(',');
    const validLayoutStyles = <String>{'GRID', 'LIST', 'TOUCH_TILES'};
    final normalizedLayoutStyle = layoutStyle.trim().toUpperCase();
    if (!validLayoutStyles.contains(normalizedLayoutStyle)) {
      throw ArgumentError('نوع چیدمان معتبر نیست.');
    }

    final newConfig = StoreConfig(
      id: 1,
      storeName: normalizedStoreName,
      storeType: normalizedStoreType,
      businessTitle: businessTitle?.trim().isNotEmpty == true
          ? businessTitle!.trim()
          : BusinessCatalog.titleFor(storeType),
      logoBase64: logoBase64,
      colorTheme: colorTheme,
      currency: currency,
      layoutStyle: normalizedLayoutStyle,
      isConfigured: true,
      morningStartHour: _config?.morningStartHour ?? 6,
      morningEndHour: _config?.morningEndHour ?? 15,
      eveningStartHour: _config?.eveningStartHour ?? 15,
      eveningEndHour: _config?.eveningEndHour ?? 24,
      isDarkMode: _config?.isDarkMode ?? false,
    );

    await _repo.updateStoreConfig(newConfig);

    final admin = User(
      id: 0,
      name: normalizedAdminName,
      pin: normalizedPin,
      role: 'ADMIN',
      pinCode: '',
    );

    await _repo.insertUser(admin);

    final savedAdmin = await _repo.getUserByPin(normalizedPin) ?? admin;

    _config = newConfig;
    _currentUser = savedAdmin;

    try {
      final deviceId = await LicenseService.instance.getDeviceId();
      final result = await OnlineApiService.instance.bootstrapStore({
        'storeName': newConfig.storeName,
        'storeType': newConfig.storeType,
        'businessTitle': newConfig.businessTitle,
        'adminName': normalizedAdminName,
        'adminPin': normalizedPin,
        'phone': '',
        'deviceId': deviceId,
        'currency': newConfig.currency,
        'platform': Platform.isAndroid
            ? 'ANDROID'
            : Platform.isWindows
                ? 'WINDOWS'
                : Platform.operatingSystem.toUpperCase(),
        'deviceName': Platform.localHostname,
      });
      final sid = (result['storeId'] as num?)?.toInt() ?? 0;
      final uid = (result['userId'] as num?)?.toInt() ?? 0;
      _currentUser = savedAdmin.copyWith(
          role: 'OWNER',
          storeId: sid,
          serverUserId: uid,
          permissions: (List<String>.from(result['permissions'] ?? const [])).isEmpty
              ? User.defaultPermissionsForRole('OWNER')
              : List<String>.from(result['permissions']));
      try {
        final session = await OnlineApiService.instance.login(
            storeCode: '${result['storeCode'] ?? ''}',
            userId: uid,
            pin: normalizedPin,
            deviceId: deviceId);
        _currentUser = savedAdmin.copyWith(
            role: 'OWNER',
            storeId: session.storeId,
            serverUserId: session.userId,
            permissions: session.permissions.isEmpty
                ? savedAdmin.permissions
                : session.permissions);
      } catch (_) {
        await OnlineSessionStore.instance.save({
          'storeCode': '${result['storeCode'] ?? ''}',
          'storeId': sid,
          'userId': uid,
          'permissions': List<String>.from(result['permissions'] ?? const []),
          'licenseStatus': '${result['licenseStatus'] ?? 'ACTIVE'}',
          'licenseExpiresAt': (result['licenseExpiresAt'] as num?)?.toInt() ??
              DateTime.now()
                  .add(const Duration(days: 15))
                  .millisecondsSinceEpoch,
          'features': List<String>.from(result['trialFeatures'] ?? const []),
          'businessTypes': List<String>.from(
              result['businessTypes'] ?? [newConfig.storeType]),
          'licenseId': '${result['licenseId'] ?? ''}',
          'licensePlan': '${result['licensePlan'] ?? 'TRIAL'}'
        });
      }
      await LicenseService.instance.activateLocalTrial(
        licenseId: '${result['licenseId'] ?? ''}',
        features: List<String>.from(result['trialFeatures'] ?? const []),
        businessTypes:
            List<String>.from(result['businessTypes'] ?? [newConfig.storeType]),
        expiresAt: (result['licenseExpiresAt'] as num?)?.toInt() ??
            DateTime.now().add(const Duration(days: 15)).millisecondsSinceEpoch,
      );
      try {
        await CloudSyncService.instance.syncAll();
      } catch (_) {}
    } catch (e) {
      if (OnlineConfig.instance.required) rethrow;
    }

    await _insertAudit(
      action: 'تنظیم اولیه فروشگاه',
      details: 'فروشگاه $normalizedStoreName با موفقیت راه‌اندازی شد',
      user: savedAdmin,
    );

    _userMessage = 'تنظیمات فروشگاه با موفقیت ذخیره شد';

    await loadAll();
  }

  // --------------------------------------------------------------------------
  // تنظیمات فروشگاه
  // --------------------------------------------------------------------------

  Future<void> updateStoreDetails(
    String storeName,
    String storeType,
    String currency,
  ) async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی می‌تواند اطلاعات فروشگاه را تغییر دهد.');
    }

    final current = _requireConfig();
    final normalizedName = storeName.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError('نام فروشگاه نمی‌تواند خالی باشد.');
    }

    final updated = current.copyWith(
      storeName: normalizedName,
      storeType: storeType.trim(),
      currency: currency,
    );

    await _saveConfig(
      updated,
      'اطلاعات فروشگاه به‌روزرسانی شد',
    );
  }

  Future<void> updateFullStoreConfig({
    required String storeName,
    required String storeType,
    required String colorTheme,
    required String currency,
    required String layoutStyle,
    double taxPercentage = 0.0,
    int morningStartHour = 6,
    int morningEndHour = 15,
    int eveningStartHour = 15,
    int eveningEndHour = 24,
  }) async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی می‌تواند تنظیمات فروشگاه را تغییر دهد.');
    }

    _validateShiftHours(morningStartHour, morningEndHour);
    _validateShiftHours(eveningStartHour, eveningEndHour);

    final current = _requireConfig();

    final updated = current.copyWith(
      storeName: storeName.trim(),
      storeType: storeType.trim(),
      colorTheme: colorTheme,
      currency: currency,
      layoutStyle: layoutStyle,
      taxPercentage: taxPercentage.clamp(0.0, 100.0).toDouble(),
      morningStartHour: morningStartHour,
      morningEndHour: morningEndHour,
      eveningStartHour: eveningStartHour,
      eveningEndHour: eveningEndHour,
    );

    await _saveConfig(
      updated,
      'تنظیمات فروشگاه به‌روزرسانی شد',
    );
  }

  Future<void> updateStoreName(String value) async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی می‌تواند نام فروشگاه را تغییر دهد.');
    }

    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      throw ArgumentError('نام فروشگاه نمی‌تواند خالی باشد.');
    }

    final current = _requireConfig();
    await _saveConfig(
      current.copyWith(storeName: normalizedValue),
      'نام فروشگاه به‌روزرسانی شد',
    );
  }

  Future<void> updateCurrency(String value) async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی می‌تواند واحد پول را تغییر دهد.');
    }

    const validCurrencies = <String>['تومان', 'ریال', r'$'];
    if (!validCurrencies.contains(value)) {
      throw ArgumentError('واحد پول معتبر نیست.');
    }

    final current = _requireConfig();
    await _saveConfig(
      current.copyWith(currency: value),
      'واحد پول تغییر کرد',
    );
  }

  Future<void> updateLayoutStyle(String value) async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی می‌تواند چیدمان فروش را تغییر دهد.');
    }

    const validStyles = <String>['GRID', 'TOUCH_TILES', 'LIST'];
    final normalized = value.trim().toUpperCase();
    if (!validStyles.contains(normalized)) {
      throw ArgumentError('نوع چیدمان معتبر نیست.');
    }

    final current = _requireConfig();
    await _saveConfig(
      current.copyWith(layoutStyle: normalized),
      'چیدمان صفحه فروش تغییر کرد',
    );
  }

  Future<void> updateColorTheme(String value) async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی می‌تواند تم برنامه را تغییر دهد.');
    }

    const validThemes = <String>[
      'PROFESSIONAL',
      'EMERALD',
      'OCEAN',
      'GOLDEN',
      'PURPLE',
      'RUBY',
    ];

    if (!validThemes.contains(value)) {
      throw ArgumentError('تم رنگی معتبر نیست.');
    }

    final current = _requireConfig();
    await _saveConfig(
      current.copyWith(colorTheme: value),
      'تم رنگی برنامه تغییر کرد',
    );
  }

  Future<void> updateDarkMode(bool value) async {
    final current = _requireConfig();
    await _saveConfig(
      current.copyWith(isDarkMode: value),
      value ? 'حالت تیره فعال شد' : 'حالت روشن فعال شد',
    );
  }

  Future<void> toggleDarkMode() async {
    await updateDarkMode(!(_config?.isDarkMode ?? false));
  }

  Future<void> updatePrintSettings({
    required String paperSize,
    required String orientation,
    required double marginMm,
    required double customWidthMm,
    required double customHeightMm,
  }) async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی می‌تواند تنظیمات چاپ را تغییر دهد.');
    }

    const allowedSizes = {
      'A4',
      'A5',
      'LETTER',
      'LEGAL',
      'B5',
      'R58',
      'R80',
      'CUSTOM'
    };
    if (!allowedSizes.contains(paperSize)) {
      throw ArgumentError('اندازه کاغذ نامعتبر است.');
    }
    if (orientation != 'PORTRAIT' && orientation != 'LANDSCAPE') {
      throw ArgumentError('جهت چاپ نامعتبر است.');
    }
    if (marginMm < 0 || marginMm > 30) {
      throw ArgumentError('حاشیه چاپ باید بین ۰ تا ۳۰ میلی‌متر باشد.');
    }

    final current = _requireConfig();
    await _saveConfig(
      current.copyWith(
        printPaperSize: paperSize,
        printOrientation: orientation,
        printMarginMm: marginMm,
        customPaperWidthMm: customWidthMm,
        customPaperHeightMm: customHeightMm,
      ),
      'تنظیمات چاپ ذخیره شد',
    );
  }

  Future<void> updateShiftHours({
    required int start,
    required int end,
  }) async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی می‌تواند ساعات شیفت را تغییر دهد.');
    }

    _validateShiftHours(start, end);
    final current = _requireConfig();
    await _saveConfig(
      current.copyWith(morningStartHour: start, morningEndHour: end),
      'ساعات شیفت صبح به‌روزرسانی شد',
    );
  }

  Future<void> updateEveningShift({
    required int start,
    required int end,
  }) async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی می‌تواند ساعات شیفت را تغییر دهد.');
    }

    _validateShiftHours(start, end);
    final current = _requireConfig();
    await _saveConfig(
      current.copyWith(eveningStartHour: start, eveningEndHour: end),
      'ساعات شیفت عصر به‌روزرسانی شد',
    );
  }

  Future<void> updateAllShiftHours({
    required int morningStart,
    required int morningEnd,
    required int eveningStart,
    required int eveningEnd,
  }) async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی می‌تواند ساعات شیفت را تغییر دهد.');
    }

    _validateShiftHours(morningStart, morningEnd);
    _validateShiftHours(eveningStart, eveningEnd);

    final current = _requireConfig();
    await _saveConfig(
      current.copyWith(
        morningStartHour: morningStart,
        morningEndHour: morningEnd,
        eveningStartHour: eveningStart,
        eveningEndHour: eveningEnd,
      ),
      'ساعات شیفت‌ها به‌روزرسانی شد',
    );
  }

  Future<void> updateProfitCoefficient(double value) async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی می‌تواند ضریب سود را تغییر دهد.');
    }

    if (!value.isFinite || value <= 0 || value > 1) {
      throw ArgumentError('ضریب سود باید بیشتر از صفر و حداکثر یک باشد.');
    }

    final current = _requireConfig();
    await _saveConfig(
      current.copyWith(profitCoefficient: value),
      'ضریب سود به‌روزرسانی شد',
    );
  }

  Future<void> updateEndShiftAlert(String value) async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی می‌تواند هشدار پایان شیفت را تغییر دهد.');
    }

    final normalizedTime = _normalizeTime(value);
    if (normalizedTime == null) {
      throw ArgumentError('زمان هشدار معتبر نیست.');
    }

    final current = _requireConfig();
    await _saveConfig(
      current.copyWith(endShiftAlertTime: normalizedTime),
      'زمان هشدار پایان روز به‌روزرسانی شد',
    );
  }

  Future<void> _saveConfig(StoreConfig newConfig, String message) async {
    await _repo.updateStoreConfig(newConfig);
    _config = newConfig;
    _userMessage = message;
    _notify();
  }

  StoreConfig _requireConfig() {
    final current = _config;
    if (current == null) {
      throw StateError('تنظیمات فروشگاه بارگذاری نشده است.');
    }
    return current;
  }

  void _validateShiftHours(int start, int end) {
    if (start < 0 || start > 24 || end < 0 || end > 24) {
      throw ArgumentError('ساعت شیفت باید بین صفر و ۲۴ باشد.');
    }
    if (start == end) {
      throw ArgumentError('ساعت شروع و پایان نباید یکسان باشند.');
    }
  }

  // --------------------------------------------------------------------------
  // ورود، خروج و تغییر کاربر
  // --------------------------------------------------------------------------

  Future<({bool ok, String? msg})> loginOnlineToStore({
    required String storeCode,
    required int userId,
    required String pin,
  }) async {
    try {
      final deviceId = await LicenseService.instance.getDeviceId();
      final session = await OnlineApiService.instance.login(
          storeCode: storeCode.trim(),
          userId: userId,
          pin: _normalizeDigits(pin.trim()),
          deviceId: deviceId);
      final cfg = StoreConfig(
          id: 1,
          storeName:
              session.storeName.isEmpty ? 'فروشگاه آنلاین' : session.storeName,
          storeType: session.storeType.isEmpty ? 'GENERAL' : session.storeType,
          businessTitle:
              session.businessTitle.isEmpty ? 'فروشگاه' : session.businessTitle,
          colorTheme: 'EMERALD',
          currency: session.currency.isEmpty ? 'تومان' : session.currency,
          isConfigured: true);
      await _repo.updateStoreConfig(cfg);
      var local = await _repo.getUserById(session.userId);
      if (local == null) {
        final inserted = User(
            id: 0,
            name: session.name,
            pin: _normalizeDigits(pin.trim()),
            role: session.role,
            phone: '',
            storeId: session.storeId,
            serverUserId: session.userId,
            permissions: session.permissions.isEmpty
                ? User.defaultPermissionsForRole(session.role)
                : session.permissions,
            pinCode: '');
        final id = await _repo.insertUser(inserted);
        local = await _repo.getUserById(id) ?? inserted.copyWith(id: id);
      } else {
        local = local.copyWith(
            name: session.name,
            pin: _normalizeDigits(pin.trim()),
            role: session.role,
            storeId: session.storeId,
            serverUserId: session.userId,
            permissions: session.permissions.isEmpty
                ? local.permissions
                : session.permissions);
        await _repo.updateUser(local);
      }
      _config = cfg;
      _currentUser = local.copyWith(
          role: session.role,
          storeId: session.storeId,
          serverUserId: session.userId,
          permissions: session.permissions.isEmpty
                ? local.permissions
                : session.permissions);
      await OnlineSessionStore.instance.save({
        'accessToken': session.accessToken,
        'refreshToken': session.refreshToken,
        'storeCode': session.storeCode,
        'storeId': session.storeId,
        'userId': session.userId,
        'permissions': session.permissions.isEmpty ? local.permissions : session.permissions,
        'features': session.features,
        'businessTypes': session.businessTypes,
        'licenseExpiresAt': session.licenseExpiresAt,
        'licenseStatus': session.licenseStatus,
        'licenseId': session.licenseId,
        'licensePlan': session.licensePlan,
        'storeName': session.storeName,
        'storeType': session.storeType,
        'businessTitle': session.businessTitle,
        'currency': session.currency
      });
      try {
        await CloudSyncService.instance.syncAll();
      } catch (_) {}
      await loadAll();
      _notify();
      return (ok: true, msg: 'ورود آنلاین و همگام‌سازی با موفقیت انجام شد');
    } catch (e) {
      return (ok: false, msg: 'ورود آنلاین ناموفق بود: $e');
    }
  }

  Future<({bool ok, String? msg})> loginWithPin(
    String pin, {
    int? userId,
  }) async {
    final normalizedPin = _normalizeDigits(pin.trim());

    if (normalizedPin.isEmpty) {
      return (ok: false, msg: 'پین‌کد را وارد کنید');
    }

    try {
      final cfg = OnlineConfig.instance;
      if (OnlineApiService.onlineEnabled && (cfg.required || !cfg.baseUrl.contains('YOUR-DOMAIN'))) {
        final deviceId = await LicenseService.instance.getDeviceId();
        final savedSession = await OnlineSessionStore.instance.read();
        final storeCode = '${savedSession['storeCode'] ?? (_config?.id ?? 0)}';
        final session = await OnlineApiService.instance.login(
            storeCode: storeCode,
            userId: userId ?? 0,
            pin: normalizedPin,
            deviceId: deviceId);
        final local = userId == null
            ? await _repo.getUserByPin(normalizedPin)
            : await _repo.getUserByPinAndId(normalizedPin, userId);
        if (local == null) {
          return (ok: false, msg: 'کاربر در این دستگاه همگام نشده است.');
        }
        _currentUser = local.copyWith(
            role: session.role,
            storeId: session.storeId,
            serverUserId: session.userId,
            permissions: session.permissions.isEmpty
                ? local.permissions
                : session.permissions);
        await OnlineSessionStore.instance.save({
          'accessToken': session.accessToken,
          'refreshToken': session.refreshToken,
          'userId': session.userId,
          'storeId': session.storeId,
          'permissions': session.permissions.isEmpty ? local.permissions : session.permissions,
          'features': session.features,
          'licenseExpiresAt': session.licenseExpiresAt,
          'licenseStatus': session.licenseStatus
        });
        try {
          await CloudSyncService.instance.syncAll();
        } catch (_) {}
        await _insertAudit(
            action: 'ورود آنلاین',
            details: 'ورود موفق ${_currentUser!.name}',
            user: _currentUser!);
        await _reloadAuditLogs();
        _notify();
        return (ok: true, msg: 'ورود با موفقیت انجام شد');
      }
    } catch (e) {
      if (OnlineConfig.instance.required) {
        return (ok: false, msg: 'اتصال به سرور برقرار نشد: $e');
      }
    }

    final user = userId == null
        ? await _repo.getUserByPin(normalizedPin)
        : await _repo.getUserByPinAndId(normalizedPin, userId);

    if (user == null) {
      return (ok: false, msg: 'رمز عبور یا پین‌کد اشتباه است');
    }

    final normalizedUser = user;

    _currentUser = normalizedUser;

    await _insertAudit(
      action: 'ورود به حساب کاربری',
      details: 'ورود موفق کاربر ${normalizedUser.name}',
      user: normalizedUser,
    );

    await _reloadAuditLogs();
    _notify();

    return (ok: true, msg: 'ورود با موفقیت انجام شد');
  }

  /// بعد از انتخاب یک فروشگاه Shared از طریق Wi-Fi، هویت کاربر محلی
  /// دستگاه دیگر قابل اعتماد نیست؛ کاربر باید از کاربران همگام‌شده وارد شود.
  void resetSessionAfterLocalStoreJoin() {
    _currentUser = null;
    clearCart(notify: false);
    _notify();
  }

  Future<void> logout() async {
    final user = _currentUser;
    if (user != null) {
      await _insertAudit(
        action: 'خروج از حساب کاربری',
        details: 'خروج کاربر ${user.name}',
        user: user,
      );
    }

    _currentUser = null;
    clearCart(notify: false);

    await _reloadAuditLogs();
    _notify();
  }

  Future<void> switchUser(User target) async {
    _currentUser = target;
    clearCart(notify: false);

    await _insertAudit(
      action: 'سوئیچ سریع کاربر',
      details: 'ورود مستقیم به حساب ${target.name}',
      user: target,
    );

    _userMessage = 'کاربر فعال به ${target.name} تغییر یافت';
    await _reloadAuditLogs();
    _notify();
  }

  // --------------------------------------------------------------------------
  // حضور و غیاب (با احتساب ساعت تاخیر و شیفت)
  // --------------------------------------------------------------------------

  Future<void> clockIn({
    String shiftType = 'MORNING',
    String note = '',
  }) async {
    final user = _requireCurrentUser();
    final active = await _repo.getActiveAttendance(user.id);

    if (active != null) {
      _userMessage = 'شیفت فعلی شما از ${faDateTimeMillis(active.clockInTime)} فعال است.';
      await _reloadAuditLogs();
      _notify();
      return;
    }

    final now = DateTime.now();
    final cfg = _config;
    final startHour = shiftType == 'EVENING'
        ? (cfg?.eveningStartHour ?? 15)
        : (cfg?.morningStartHour ?? 6);
    final lateMinutes = _lateMinutesForShift(now, startHour);

    final record = AttendanceRecord(
      userId: user.id,
      userName: user.name,
      clockInTime: now.millisecondsSinceEpoch,
      shiftType: shiftType,
      status: lateMinutes > 0 ? 'LATE' : 'PRESENT',
      note: note.trim(),
      overtimeMinutes: 0,
    );

    await _repo.insertAttendance(record);
    await _insertAudit(
      action: 'ثبت حضور پرسنل',
      details: lateMinutes > 0
          ? 'آغاز شیفت $shiftType با $lateMinutes دقیقه تأخیر'
          : 'آغاز شیفت $shiftType',
      user: user,
    );

    _userMessage = lateMinutes > 0
        ? 'آغاز شیفت ثبت شد؛ میزان تأخیر: $lateMinutes دقیقه'
        : 'آغاز شیفت ثبت شد';
    await loadAll();
  }

  Future<void> clockOut({
    String note = '',
  }) async {
    final user = _requireCurrentUser();
    final active = await _repo.getActiveAttendance(user.id);

    if (active == null) {
      _userMessage = 'شیفت فعالی برای شما وجود ندارد؛ وضعیت آغاز/اتمام با اطلاعات ذخیره‌شده هماهنگ است.';
      _notify();
      return;
    }

    final now = DateTime.now();
    final expectedEnd = _shiftEndForDate(active, now);
    final overtimeMinutes = now.isAfter(expectedEnd)
        ? now.difference(expectedEnd).inMinutes
        : 0;

    final normalizedNote = note.trim();
    final overtimeText = overtimeMinutes > 0
        ? ' اضافه‌کاری: $overtimeMinutes دقیقه'
        : '';
    final updated = AttendanceRecord(
      id: active.id,
      userId: active.userId,
      userName: active.userName,
      dateMillis: active.dateMillis,
      clockInTime: active.clockInTime,
      clockOutTime: now.millisecondsSinceEpoch,
      shiftType: active.shiftType,
      status: active.status,
      overtimeMinutes: overtimeMinutes,
      note: [
        if (active.note.trim().isNotEmpty) active.note.trim(),
        if (normalizedNote.isNotEmpty) normalizedNote,
        if (overtimeMinutes > 0) 'اضافه‌کاری ثبت‌شده: $overtimeMinutes دقیقه',
      ].join(' | '),
    );

    await _repo.updateAttendance(updated);
    await _insertAudit(
      action: 'ثبت خروج پرسنل',
      details: 'ثبت خروج از شیفت ${active.shiftType}.$overtimeText',
      user: user,
    );

    _userMessage = overtimeMinutes > 0
        ? 'اتمام شیفت ثبت شد؛ $overtimeMinutes دقیقه اضافه‌کاری ثبت شد.'
        : 'اتمام شیفت ثبت شد.';
    await loadAll();
  }

  int _lateMinutesForShift(DateTime now, int startHour) {
    final start = DateTime(now.year, now.month, now.day, startHour.clamp(0, 23).toInt());
    if (now.isBefore(start)) return 0;
    return now.difference(start).inMinutes;
  }

  DateTime _shiftEndForDate(AttendanceRecord attendance, DateTime now) {
    final cfg = _config;
    final start = DateTime.fromMillisecondsSinceEpoch(attendance.clockInTime);
    final startHour = attendance.shiftType == 'EVENING'
        ? (cfg?.eveningStartHour ?? 15)
        : (cfg?.morningStartHour ?? 6);
    final endHour = attendance.shiftType == 'EVENING'
        ? (cfg?.eveningEndHour ?? 24)
        : (cfg?.morningEndHour ?? 15);
    final safeStart = startHour.clamp(0, 23).toInt();
    final safeEnd = endHour.clamp(0, 24).toInt();
    var end = safeEnd == 24
        ? DateTime(start.year, start.month, start.day).add(const Duration(days: 1))
        : DateTime(start.year, start.month, start.day, safeEnd);
    if (safeEnd < safeStart) {
      end = end.add(const Duration(days: 1));
    }
    return end;
  }

  Future<List<AttendanceRecord>> getAttendanceForAdmin() async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی فروشگاه به حضور و غیاب دسترسی دارد.');
    }
    return List<AttendanceRecord>.unmodifiable(_attendance);
  }

  // --------------------------------------------------------------------------
  // جست‌وجوی کالا
  // --------------------------------------------------------------------------

  void setSearchQuery(String query) {
    if (_searchQuery == query) {
      return;
    }
    _searchQuery = query;
    _notify();
  }

  bool isUnlimitedService(Product product) => product.isService;

  // --------------------------------------------------------------------------
  // سبد خرید
  // --------------------------------------------------------------------------

  void addToCart(Product product) {
    final unlimited = product.isService;
    if (!unlimited && product.stockQuantity <= 0) {
      showMessage('موجودی کالای «${product.name}» تمام شده است.');
      return;
    }

    final index = _cart.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (index >= 0) {
      final newQuantity = _cart[index].quantity + 1.0;
      if (!unlimited && newQuantity > product.stockQuantity) {
        showMessage('موجودی کافی برای کالای «${product.name}» وجود ندارد.');
        return;
      }
      _cart[index].quantity = newQuantity;
    } else {
      _cart.add(
        CartItem(
          product: product,
          quantity: 1.0,
        ),
      );
    }

    _notify();
  }

  void setCartItemQuantity(int productId, double quantity) {
    if (!quantity.isFinite || quantity <= 0) {
      final index = _cart.indexWhere((item) => item.product.id == productId);
      if (index >= 0) {
        _cart.removeAt(index);
        _notify();
      }
      return;
    }
    final index = _cart.indexWhere((item) => item.product.id == productId);
    if (index < 0) return;
    final item = _cart[index];
    if (!item.product.isService && quantity > item.product.stockQuantity) {
      showMessage(
        'حداکثر موجودی ${item.product.name}: ${item.product.stockQuantity} ${item.product.unit}',
      );
      return;
    }
    item.quantity = quantity;
    _notify();
  }

  void setCartItemPrice(int productId, double price) {
    if (!price.isFinite || price < 0) return;
    final index = _cart.indexWhere((item) => item.product.id == productId);
    if (index < 0) return;
    final item = _cart[index];
    item.customPrice = price;
    _notify();
  }

  void updateCartQuantity(
    int productId,
    double delta,
  ) {
    if (!delta.isFinite || delta == 0) {
      return;
    }

    final index = _cart.indexWhere(
      (item) => item.product.id == productId,
    );

    if (index < 0) {
      return;
    }

    final cartItem = _cart[index];
    final newQuantity = cartItem.quantity + delta;

    if (newQuantity <= 0) {
      _cart.removeAt(index);
      _notify();
      return;
    }

    if (!cartItem.product.isService && newQuantity > cartItem.product.stockQuantity) {
      showMessage(
        'حداکثر موجودی ${cartItem.product.name}: '
        '${cartItem.product.stockQuantity} '
        '${cartItem.product.unit}',
      );
      return;
    }

    cartItem.quantity = newQuantity;
    _notify();
  }

  void setDiscount(double value) {
    if (!value.isFinite) {
      return;
    }
    _discount = value.clamp(0.0, rawTotal).toDouble();
    _notify();
  }

  void setPaymentMethod(String method) {
    const validMethods = <String>['CASH', 'CARD', 'TRANSFER', 'CREDIT', 'MIXED'];
    if (!validMethods.contains(method)) {
      return;
    }
    _paymentMethod = method;
    _notify();
  }

  void setSelectedCustomer(Contact? contact) {
    _selectedCustomer = contact;
    _notify();
  }

  void clearCart({
    bool notify = true,
  }) {
    _cart = <CartItem>[];
    _discount = 0.0;
    _selectedCustomer = null;
    _paymentMethod = 'CASH';

    if (notify) {
      _notify();
    }
  }

  // --------------------------------------------------------------------------
  // ثبت فروش عادی و ثبت فروش سفارشی (تاریخ، ساعت و شماره فاکتور دلخواه)
  // --------------------------------------------------------------------------

  Future<int> checkout(double paidAmount) async {
    if (!hasPermission(PermissionCatalog.salesCreate)) {
      throw StateError('شما دسترسی ثبت فروش ندارید.');
    }
    if (_isCheckingOut) {
      throw StateError('فرایند ثبت فاکتور در حال انجام است.');
    }

    final user = _requireCurrentUser();

    if (_cart.isEmpty) {
      throw StateError('سبد خرید خالی است.');
    }

    if (!paidAmount.isFinite || paidAmount < 0) {
      throw ArgumentError('مبلغ پرداختی معتبر نیست.');
    }
    if (_paymentMethod == 'CREDIT' && _selectedCustomer == null) {
      throw StateError('برای ثبت نسیه باید مشتری یا طرف حساب انتخاب شود.');
    }
    if (_paymentMethod == 'CREDIT' && paidAmount > 0) {
      throw StateError('برای ثبت نسیه، مبلغ دریافتی باید صفر باشد.');
    }

    _isCheckingOut = true;
    _notify();

    try {
      final subtotal = rawTotal;
      final discount = _discount.clamp(0.0, subtotal).toDouble();
      final finalAmount =
          (subtotal - discount).clamp(0.0, double.infinity).toDouble();
      final actualPaid = paidAmount.clamp(0.0, finalAmount).toDouble();
      final debt =
          (finalAmount - actualPaid).clamp(0.0, double.infinity).toDouble();

      final customer = _selectedCustomer;

      final transaction = StoreTransaction(
        type: 'SALE',
        totalAmount: subtotal,
        discount: discount,
        finalAmount: finalAmount,
        paidAmount: actualPaid,
        debtAmount: debt,
        paymentMethod: _paymentMethod,
        contactId: customer?.id,
        contactName: customer?.name ?? 'مشتری حضوری',
        userId: user.id,
        userName: user.name,
      );

      final transactionItems = _cart.map((cartItem) {
        return TransactionItem(
          transactionId: 0,
          productId: cartItem.product.id,
          productName: cartItem.product.name,
          quantity: cartItem.quantity,
          unitPrice: cartItem.unitPrice,
          costPrice: cartItem.product.buyPrice,
          totalPrice: cartItem.totalPrice,
        );
      }).toList();

      final transactionId = await _repo.recordSale(
        transaction,
        transactionItems,
      );

      final commission =
          finalAmount * (user.commissionPercent.clamp(0.0, 100.0) / 100.0);
      final updatedSeller = user.copyWith(
        totalSalesAmount: user.totalSalesAmount + finalAmount,
        totalCommission: user.totalCommission + commission,
      );
      await _repo.updateUser(updatedSeller);
      _currentUser = updatedSeller;

      clearCart(notify: false);
      _userMessage = 'فاکتور #$transactionId با موفقیت ثبت شد';
      await loadAll();
      // Keep a categorized PDF receipt for the new sale even if the user does
      // not immediately open the print dialog. Receipt creation is best-effort
      // and must never undo a committed sale.
      await _saveReceiptPdfForTransaction(transactionId);
      // loadAll kicks off cloud sync only after the local transaction is committed.
      return transactionId;
    } finally {
      _isCheckingOut = false;
      _notify();
    }
  }

  /// متد جدید برای ثبت فاکتور دلخواه با تاریخ، ساعت، شماره فاکتور و اقلام سفارشی
  Future<int> createCustomInvoice({
    required List<TransactionItem> items,
    required double paidAmount,
    required double discount,
    required String paymentMethod,
    required Contact? customer,
    required int customDateMillis,
    String customInvoiceNumber = '',
    int? customInvoiceId,
  }) async {
    if (!hasPermission(PermissionCatalog.salesCreate)) {
      throw StateError('شما دسترسی ثبت فروش ندارید.');
    }
    final user = _requireCurrentUser();

    if (items.isEmpty) {
      throw ArgumentError('اقلام فاکتور خرید/فروش دلخواه خالی است.');
    }
    if (paymentMethod == 'CREDIT' && customer == null) {
      throw StateError('برای ثبت فاکتور نسیه باید مشتری یا طرف حساب انتخاب شود.');
    }
    if (paymentMethod == 'CREDIT' && paidAmount > 0) {
      throw StateError('برای ثبت فاکتور نسیه، مبلغ دریافتی باید صفر باشد.');
    }

    double subtotal = 0.0;
    for (final item in items) {
      subtotal += item.totalPrice.toDouble();
    }

    final finalAmount =
        (subtotal - discount).clamp(0.0, double.infinity).toDouble();
    final actualPaid = paidAmount.clamp(0.0, finalAmount).toDouble();
    final debt =
        (finalAmount - actualPaid).clamp(0.0, double.infinity).toDouble();

    final invoiceNumber = await _repo.getAvailableInvoiceNumber(
      preferred: customInvoiceNumber,
    );

    final transaction = StoreTransaction(
      id: customInvoiceId ?? 0,
      invoiceNumber: invoiceNumber,
      type: 'SALE',
      totalAmount: subtotal,
      discount: discount,
      finalAmount: finalAmount,
      paidAmount: actualPaid,
      debtAmount: debt,
      paymentMethod: paymentMethod,
      contactId: customer?.id,
      contactName: customer?.name ?? 'مشتری آزاد',
      userId: user.id,
      userName: user.name,
      dateMillis: customDateMillis,
    );

    final transactionId = await _repo.recordSale(transaction, items);
    _userMessage = 'فاکتور دلخواه #$transactionId با موفقیت ثبت شد';
    await loadAll();
    await _saveReceiptPdfForTransaction(transactionId);
    return transactionId;
  }

  Future<List<TransactionItem>> getTransactionItems(
    int transactionId,
  ) {
    return _repo.getTransactionItems(transactionId);
  }

  /// Saves the receipt immediately after an invoice is committed locally.
  /// The method intentionally swallows errors: a receipt export issue must not
  /// make the cashier think that a successful sale or purchase was rolled back.
  Future<void> _saveReceiptPdfForTransaction(int transactionId) async {
    try {
      StoreTransaction? transaction;
      for (final candidate in _transactions) {
        if (candidate.id == transactionId) {
          transaction = candidate;
          break;
        }
      }
      if (transaction == null) return;

      final config = _config;
      final items = await _repo.getTransactionItems(transactionId);
      final paper = config?.printPaperSize;
      await Exporter.exportThermalReceiptPdf(
        storeName: config?.storeName ?? 'فروشگاه',
        storePhone: config?.storePhone ?? '',
        businessTitle: config?.businessTitle ?? 'فروشگاه',
        logoBase64: config?.logoBase64 ?? '',
        transactionId: transaction.id,
        invoiceNumber: transaction.invoiceNumber,
        dateStr: faDateTime(
          DateTime.fromMillisecondsSinceEpoch(transaction.dateMillis),
        ),
        customerName: transaction.contactName.trim().isEmpty
            ? (transaction.type.toUpperCase() == 'PURCHASE'
                ? 'تأمین‌کننده عمومی'
                : 'مشتری حضوری')
            : transaction.contactName,
        userName: transaction.userName.trim().isEmpty
            ? (_currentUser?.name ?? 'فروشنده')
            : transaction.userName,
        items: items
            .map((item) => [item.productName, item.quantity, item.unitPrice])
            .toList(),
        totalAmount: transaction.totalAmount,
        discount: transaction.discount,
        finalAmount: transaction.finalAmount,
        paidAmount: transaction.paidAmount,
        debtAmount: transaction.debtAmount,
        currency: config?.currency ?? 'تومان',
        paymentMethod: transaction.paymentMethod,
        invoiceType: transaction.type,
        paperSize: paper == 'R58' || paper == 'R80' ? paper! : 'R80',
        orientation: 'PORTRAIT',
        marginMm: 3.0,
        customWidthMm: config?.customPaperWidthMm ?? 80.0,
        customHeightMm: config?.customPaperHeightMm ?? 220.0,
      );
    } catch (_) {
      // Saving a receipt is best-effort; the transaction is already stored.
    }
  }

  // --------------------------------------------------------------------------
  // ثبت فاکتور خرید
  // --------------------------------------------------------------------------

  Future<int> createPurchaseInvoice({
    required List<TransactionItem> items,
    required double paidAmount,
    required int? contactId,
    required String contactName,
  }) async {
    if (!isAdmin && !hasPermission(PermissionCatalog.accountingManage)) {
      throw StateError('شما دسترسی ثبت فاکتور خرید ندارید.');
    }
    final user = _requireCurrentUser();

    if (items.isEmpty) {
      throw ArgumentError('فاکتور خرید باید حداقل یک قلم داشته باشد.');
    }

    if (!paidAmount.isFinite || paidAmount < 0) {
      throw ArgumentError('مبلغ پرداختی معتبر نیست.');
    }

    double totalAmount = 0.0;
    for (final item in items) {
      if (item.quantity <= 0 || item.unitPrice <= 0) {
        throw ArgumentError('تعداد و قیمت خرید باید بیشتر از صفر باشند.');
      }
      totalAmount += item.quantity.toDouble() * item.unitPrice.toDouble();
    }

    final actualPaid = paidAmount.clamp(0.0, totalAmount).toDouble();
    final payable =
        (totalAmount - actualPaid).clamp(0.0, double.infinity).toDouble();

    final supplierName =
        contactName.trim().isEmpty ? 'تأمین‌کننده عمومی' : contactName.trim();

    final transaction = StoreTransaction(
      type: 'PURCHASE',
      totalAmount: totalAmount,
      discount: 0.0,
      finalAmount: totalAmount,
      paidAmount: actualPaid,
      debtAmount: payable,
      paymentMethod: payable > 0 ? 'CREDIT' : 'CASH',
      contactId: contactId,
      contactName: supplierName,
      userId: user.id,
      userName: user.name,
    );

    final transactionId = await _repo.recordPurchase(transaction, items);

    await _insertAudit(
      action: 'ثبت فاکتور خرید',
      details: 'فاکتور خرید #$transactionId از $supplierName ثبت شد',
      user: user,
    );

    _userMessage = 'فاکتور خرید #$transactionId ثبت شد';
    await loadAll();
    await _saveReceiptPdfForTransaction(transactionId);

    return transactionId;
  }

  // --------------------------------------------------------------------------
  // ثبت ارسال فاکتور
  // --------------------------------------------------------------------------

  Future<void> recordInvoiceDelivery({
    required int invoiceId,
    required String channel,
    required String destination,
  }) async {
    final user = _requireCurrentUser();

    const validChannels = <String>{'WHATSAPP', 'SMS', 'EMAIL', 'FILE'};
    if (!validChannels.contains(channel)) {
      throw ArgumentError('روش ارسال فاکتور معتبر نیست.');
    }

    final exists = _transactions.any(
      (transaction) => transaction.id == invoiceId,
    );

    if (!exists) {
      throw StateError('فاکتور مورد نظر یافت نشد.');
    }

    await _insertAudit(
      action: 'ارسال فاکتور',
      details:
          'فاکتور #$invoiceId از طریق $channel به ${destination.trim()} ارسال شد',
      user: user,
    );

    _userMessage = 'ارسال فاکتور با موفقیت ثبت شد';
    await _reloadAuditLogs();
    _notify();
  }

  Future<bool> getInvoiceNumberAvailability(String invoiceNumber) async {
    try {
      await _repo.getAvailableInvoiceNumber(preferred: invoiceNumber);
      return true;
    } catch (_) {
      return false;
    }
  }

  // --------------------------------------------------------------------------
  // محصولات
  // --------------------------------------------------------------------------

  Future<void> saveProduct(Product product) async {
    if (product.name.trim().isEmpty) {
      throw ArgumentError('نام کالا الزامی است.');
    }

    if (product.buyPrice < 0 ||
        product.sellPrice < 0 ||
        product.stockQuantity < 0) {
      throw ArgumentError('قیمت و موجودی کالا نمی‌توانند منفی باشند.');
    }

    if (product.id == 0) {
      await _repo.insertProduct(product);
      _userMessage = 'کالای جدید اضافه شد';
    } else {
      await _repo.updateProduct(product);
      _userMessage = 'اطلاعات کالا به‌روزرسانی شد';
    }

    await loadAll();
  }

  Future<void> deleteProduct(Product product) async {
    await _repo.deleteProduct(product);
    _userMessage = 'کالا حذف شد';
    await loadAll();
  }

  Future<void> clearAllProducts() async {
    await _repo.deleteAllProducts();
    clearCart(notify: false);
    _userMessage = 'تمام کالاهای انبار پاک‌سازی شدند';
    await loadAll();
  }

  // --------------------------------------------------------------------------
  // طرف حساب‌ها
  // --------------------------------------------------------------------------

  Future<void> saveContact(Contact contact) async {
    if (contact.name.trim().isEmpty) {
      throw ArgumentError('نام طرف حساب الزامی است.');
    }

    if (contact.id == 0) {
      await _repo.insertContact(contact);
      _userMessage = 'طرف حساب جدید ثبت شد';
    } else {
      await _repo.updateContact(contact);
      _userMessage = 'اطلاعات طرف حساب به‌روزرسانی شد';
    }

    await loadAll();
  }

  Future<void> deleteContact(Contact contact) async {
    await _repo.deleteContact(contact);
    if (_selectedCustomer?.id == contact.id) {
      _selectedCustomer = null;
    }
    _userMessage = 'طرف حساب حذف شد';
    await loadAll();
  }

  Future<void> recordDebtPayment(
    int contactId,
    double amount,
    bool isCustomerDebt,
  ) async {
    final user = _requireCurrentUser();

    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('مبلغ باید بیشتر از صفر باشد.');
    }

    if (isCustomerDebt) {
      await _repo.payDebt(contactId, amount);
      await _insertAudit(
        action: 'دریافت طلب',
        details: 'دریافت مبلغ $amount از طرف حساب $contactId',
        user: user,
      );
    } else {
      await _repo.payPayable(contactId, amount);
      await _insertAudit(
        action: 'پرداخت بدهی',
        details: 'پرداخت مبلغ $amount به تأمین‌کننده $contactId',
        user: user,
      );
    }

    _userMessage = 'تراکنش طرف حساب ثبت شد';
    await loadAll();
  }

  // --------------------------------------------------------------------------
  // هزینه‌ها
  // --------------------------------------------------------------------------

  Future<void> saveExpense(Expense expense) async {
    final user = _requireCurrentUser();

    if (expense.title.trim().isEmpty) {
      throw ArgumentError('عنوان هزینه الزامی است.');
    }

    if (!expense.amount.isFinite || expense.amount <= 0) {
      throw ArgumentError('مبلغ هزینه باید بیشتر از صفر باشد.');
    }

    final normalizedExpense = Expense(
      id: expense.id,
      title: expense.title.trim(),
      amount: expense.amount,
      category:
          expense.category.trim().isEmpty ? 'سایر' : expense.category.trim(),
      note: expense.note.trim(),
      dateMillis: expense.dateMillis > 0
          ? expense.dateMillis
          : DateTime.now().millisecondsSinceEpoch,
      userId: expense.id == 0 || expense.userId == 0 ? user.id : expense.userId,
      userName: expense.id == 0 || expense.userName.trim().isEmpty
          ? user.name
          : expense.userName,
    );

    if (normalizedExpense.id == 0) {
      await _repo.insertExpense(normalizedExpense);
    } else {
      await _repo.updateExpense(normalizedExpense);
    }

    await _insertAudit(
      action: normalizedExpense.id == 0 ? 'ثبت هزینه' : 'ویرایش هزینه',
      details: '${normalizedExpense.title} به مبلغ '
          '${normalizedExpense.amount.toStringAsFixed(0)}',
      user: user,
    );

    _userMessage =
        normalizedExpense.id == 0 ? 'هزینه ثبت شد' : 'هزینه به‌روزرسانی شد';
    await loadAll();
  }

  Future<void> deleteExpense(int expenseId) async {
    final user = _requireCurrentUser();
    Expense? expense;

    for (final item in _expenses) {
      if (item.id == expenseId) {
        expense = item;
        break;
      }
    }

    if (expense == null) {
      throw StateError('هزینه مورد نظر یافت نشد.');
    }

    await _repo.deleteExpense(expense);
    await _insertAudit(
      action: 'حذف هزینه',
      details: 'هزینه «${expense.title}» حذف شد',
      user: user,
    );

    _userMessage = 'هزینه حذف شد';
    await loadAll();
  }

  Future<void> clearAllExpenses() async {
    final user = _requireCurrentUser();
    if (!isAdmin) {
      throw StateError('فقط مدیر می‌تواند همه هزینه‌ها را حذف کند.');
    }

    await _repo.deleteAllExpenses();
    await _insertAudit(
      action: 'پاک‌سازی هزینه‌ها',
      details: 'همه هزینه‌های فروشگاه حذف شدند',
      user: user,
    );

    _userMessage = 'همه هزینه‌ها پاک‌سازی شدند';
    await loadAll();
  }

  // --------------------------------------------------------------------------
  // گردش انبار
  // --------------------------------------------------------------------------

  Future<void> saveStockMovement({
    int id = 0,
    StockMovement? old,
    required int productId,
    required String productName,
    required String type,
    required double quantity,
    required String unit,
    required double pricePerUnit,
    required String partyName,
    required String refNumber,
    required String note,
  }) async {
    final user = _requireCurrentUser();

    if (type != 'IN' && type != 'OUT') {
      throw ArgumentError('نوع گردش انبار معتبر نیست.');
    }

    if (!quantity.isFinite || quantity <= 0) {
      throw ArgumentError('تعداد باید بیشتر از صفر باشد.');
    }

    if (!pricePerUnit.isFinite || pricePerUnit < 0) {
      throw ArgumentError('قیمت واحد نمی‌تواند منفی باشد.');
    }

    final movement = StockMovement(
      id: id,
      productId: productId,
      productName: productName.trim(),
      type: type,
      quantity: quantity,
      unit: unit.trim(),
      pricePerUnit: pricePerUnit,
      totalPrice: quantity * pricePerUnit,
      partyName: partyName.trim(),
      refNumber: refNumber.trim(),
      dateMillis: old?.dateMillis ?? DateTime.now().millisecondsSinceEpoch,
      userId: user.id,
      userName: user.name,
      note: note.trim(),
    );

    if (id == 0 || old == null) {
      await _repo.recordStockMovement(movement);
      _userMessage = 'رسید ${type == 'IN' ? 'ورود' : 'خروج'} کالا ثبت شد';
    } else {
      await _repo.updateStockMovement(old, movement);
      _userMessage = 'رسید انبار به‌روزرسانی شد';
    }

    await loadAll();
  }

  Future<void> deleteStockMovement(StockMovement movement) async {
    await _repo.deleteStockMovement(movement);
    _userMessage = 'رسید ${movement.type == 'IN' ? 'ورود' : 'خروج'} حذف شد';
    await loadAll();
  }

  // --------------------------------------------------------------------------
  // تراکنش‌ها (مشاهده، ویرایش، حذف فاکتور)
  // --------------------------------------------------------------------------

  Future<void> updateTransaction(
    StoreTransaction transaction, {
    List<TransactionItem>? items,
  }) async {
    if (!hasPermission(PermissionCatalog.invoicesEdit)) {
      throw StateError('شما دسترسی ویرایش فاکتور را ندارید.');
    }
    if (!canEditOrDeleteTransaction(transaction)) {
      throw StateError('شما فقط مجاز به ویرایش فاکتورهای ثبت‌شده توسط خودتان هستید.');
    }
    final current = await _repo.getTransactionById(transaction.id);
    if (current == null) throw StateError('فاکتور مورد نظر یافت نشد.');
    final finalItems = items ?? await _repo.getTransactionItems(transaction.id);
    await _repo.replaceInvoice(
      oldTransaction: current,
      updatedTransaction: transaction,
      items: finalItems,
    );
    _userMessage = 'فاکتور ${transaction.invoiceNumber.isEmpty ? '#${transaction.id}' : 'شماره ${transaction.invoiceNumber}'} ویرایش شد';
    await loadAll();
  }

  Future<void> deleteTransaction(StoreTransaction transaction) async {
    if (!hasPermission(PermissionCatalog.invoicesDelete)) {
      throw StateError('شما دسترسی حذف فاکتور را ندارید.');
    }
    if (!canEditOrDeleteTransaction(transaction)) {
      throw StateError('شما فقط مجاز به حذف فاکتورهای ثبت‌شده توسط خودتان هستید.');
    }
    final current = await _repo.getTransactionById(transaction.id);
    if (current == null) {
      throw StateError('فاکتور مورد نظر یافت نشد.');
    }
    await _repo.deleteInvoice(transaction);
    _userMessage = 'فاکتور ${transaction.invoiceNumber.isEmpty ? '#${transaction.id}' : 'شماره ${transaction.invoiceNumber}'} حذف شد و آثار مالی/موجودی اصلاح گردید';
    await loadAll();
  }

  // --------------------------------------------------------------------------
  // کاربران
  // --------------------------------------------------------------------------

  Future<void> saveUser(User user) async {
    if (!hasPermission(PermissionCatalog.usersManage)) {
      throw StateError('شما دسترسی مدیریت کاربران را ندارید.');
    }

    final normalizedName = user.name.trim();
    final normalizedPin = _normalizeDigits(user.pin.trim());

    if (normalizedName.isEmpty) {
      throw ArgumentError('نام کاربر الزامی است.');
    }

    if (!RegExp(r'^\d{4,6}$').hasMatch(normalizedPin)) {
      throw ArgumentError('پین باید فقط ۴ تا ۶ رقم باشد.');
    }

    if (await _repo.pinExists(normalizedPin,
        excludingUserId: user.id == 0 ? null : user.id)) {
      throw StateError('این پین‌کد قبلاً برای کاربر دیگری ثبت شده است.');
    }

    var role = user.role.toUpperCase().trim();
    if (![
      'OWNER',
      'ADMIN',
      'MANAGER',
      'SELLER',
      'WAREHOUSE',
      'ACCOUNTANT',
      'CASHIER',
      'CUSTOM'
    ].contains(role)) {
      role = 'SELLER';
    }

    if (user.id != 0 && _currentUser?.id == user.id && role != 'ADMIN') {
      final adminCount = _users.where((item) => item.role == 'ADMIN').length;
      if (adminCount <= 1) {
        throw StateError('آخرین مدیر سیستم نمی‌تواند به فروشنده تبدیل شود.');
      }
    }

    final normalizedUser = user.copyWith(
      name: normalizedName,
      pin: normalizedPin,
      role: role,
      permissions: user.permissions.isEmpty
          ? PermissionService.defaultPermissionsForRole(role).toList()
          : user.permissions,
    );

    if (user.id == 0) {
      final localId = await _repo.insertUser(normalizedUser);

      if (OnlineApiService.onlineEnabled) {
        try {
          final created = await OnlineApiService.instance.createUser({
            'name': normalizedName,
            'phone': normalizedUser.phone,
            'role': role,
            'pin': normalizedPin,
            'active': normalizedUser.isActive,
            'permissions': normalizedUser.permissions,
          });
          final remoteId = (created['id'] as num?)?.toInt() ?? 0;
          if (remoteId > 0) {
            await _repo.updateUser(
              normalizedUser.copyWith(id: localId, serverUserId: remoteId),
            );
          }
        } catch (_) {
          // ذخیره محلی قطعی است؛ Cloud API در نسخه فعلی خاموش است.
        }
      }

      await loadAll();
      _userMessage = 'کاربر جدید ثبت شد';
    } else {
      await _repo.updateUser(normalizedUser);
      if (_currentUser?.id == user.id) {
        _currentUser = normalizedUser;
      }

      if (OnlineApiService.onlineEnabled) {
        try {
          final remoteId = normalizedUser.serverUserId == 0
              ? normalizedUser.id
              : normalizedUser.serverUserId;
          await OnlineApiService.instance.updateUser(remoteId, {
            'name': normalizedName,
            'phone': normalizedUser.phone,
            'role': role,
            'pin': normalizedPin,
            'active': normalizedUser.isActive,
            'permissions': normalizedUser.permissions,
          });
        } catch (_) {
          // تغییر محلی حفظ می‌شود؛ Cloud API در نسخه فعلی خاموش است.
        }
      }

      await loadAll();
      _userMessage = 'اطلاعات کاربر به‌روزرسانی شد';
    }

    await loadAll();
  }

  Future<({bool ok, String msg})> changeUserPassword(
    int userId,
    String oldPin,
    String newPin,
  ) async {
    final user = await _repo.getUserById(userId);
    if (user == null) {
      return (ok: false, msg: 'کاربر یافت نشد');
    }

    final normalizedOldPin = _normalizeDigits(oldPin.trim());
    final normalizedNewPin = _normalizeDigits(newPin.trim());

    if (normalizedOldPin.isNotEmpty && user.pin != normalizedOldPin) {
      return (ok: false, msg: 'پین‌کد فعلی اشتباه است');
    }

    if (normalizedNewPin.length < 4) {
      return (ok: false, msg: 'پین جدید باید حداقل چهار رقم باشد');
    }

    final updatedUser = user.copyWith(pin: normalizedNewPin);
    await _repo.updateUser(updatedUser);

    if (_currentUser?.id == userId) {
      _currentUser = updatedUser;
    }

    await _insertAudit(
      action: 'تغییر رمز عبور',
      details: 'رمز عبور کاربر ${user.name} تغییر یافت',
      user: user,
    );

    _userMessage = 'رمز عبور با موفقیت به‌روزرسانی شد';
    _notify();

    return (ok: true, msg: 'رمز عبور با موفقیت تغییر یافت');
  }

  Future<void> deleteUser(User user) async {
    if (!hasPermission(PermissionCatalog.usersManage)) {
      throw StateError('شما دسترسی حذف کاربر را ندارید.');
    }

    if (_currentUser?.id == user.id) {
      throw StateError('کاربر فعال نمی‌تواند حساب خود را حذف کند.');
    }

    final adminCount = _users.where((item) => item.role == 'ADMIN').length;
    if (user.role == 'ADMIN' && adminCount <= 1) {
      throw StateError('آخرین مدیر سیستم قابل حذف نیست.');
    }

    await _repo.deleteUser(user);
    if (OnlineApiService.onlineEnabled) {
      try {
        final remoteId = user.serverUserId == 0 ? user.id : user.serverUserId;
        await OnlineApiService.instance.deleteUser(remoteId);
      } catch (e) {
        if (OnlineConfig.instance.required) rethrow;
      }
    }

    _userMessage = 'کاربر حذف شد';
    await loadAll();
  }

  // --------------------------------------------------------------------------
  // گزارش شیفت
  // --------------------------------------------------------------------------

  ShiftReportResult shiftReport({
    required int startMillis,
    required int endMillis,
    required double profitCoeff,
  }) {
    final morningStart = _config?.morningStartHour ?? 6;
    final morningEnd = _config?.morningEndHour ?? 15;
    final eveningStart = _config?.eveningStartHour ?? 15;
    final eveningEnd = _config?.eveningEndHour ?? 24;
    double morningSales = 0.0;
    double eveningSales = 0.0;

    for (final transaction in _transactions) {
      if (transaction.type != 'SALE') {
        continue;
      }
      if (transaction.dateMillis < startMillis ||
          transaction.dateMillis > endMillis) {
        continue;
      }

      final date = DateTime.fromMillisecondsSinceEpoch(transaction.dateMillis);
      final hour = date.hour;

      if (_hourIsInsideShift(hour, morningStart, morningEnd)) {
        morningSales += transaction.finalAmount.toDouble();
      }

      if (_hourIsInsideShift(hour, eveningStart, eveningEnd)) {
        eveningSales += transaction.finalAmount.toDouble();
      }
    }

    final coefficient =
        profitCoeff.isFinite ? profitCoeff.clamp(0.0, 1.0).toDouble() : 0.0;

    return ShiftReportResult(
      morningSales: morningSales,
      eveningSales: eveningSales,
      morningProfit: morningSales * coefficient,
      eveningProfit: eveningSales * coefficient,
    );
  }

  bool _hourIsInsideShift(int hour, int start, int end) {
    if (start == end) {
      return false;
    }
    if (start < end) {
      return hour >= start && hour < end;
    }
    return hour >= start || hour < end;
  }

  // --------------------------------------------------------------------------
  // لاگ‌ها
  // --------------------------------------------------------------------------

  Future<File?> exportLogsCsv() async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی فروشگاه به لاگ سیستم دسترسی دارد.');
    }
    final logs = List<AuditLog>.from(_auditLogs)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final rows = logs.map((log) {
      return <String>[
        faDateTimeSeconds(DateTime.fromMillisecondsSinceEpoch(log.timestamp)),
        log.userName,
        log.userRole,
        log.action,
        log.details,
      ];
    }).toList();

    return Exporter.exportToCsv(
      filenamePrefix: 'گزارش_لاگ_سیستم',
      headers: const <String>[
        'تاریخ و زمان',
        'کاربر',
        'نقش',
        'عملیات',
        'جزئیات'
      ],
      rows: rows,
      storeName: _config?.storeName,
    );
  }

  Future<void> clearAllLogs() async {
    final user = _requireCurrentUser();
    if (!isAdmin) {
      throw StateError('فقط مدیر می‌تواند لاگ‌ها را حذف کند.');
    }

    await _repo.deleteAllLogs();
    await _insertAudit(
      action: 'پاک‌سازی لاگ‌ها',
      details: 'همه رخدادهای سیستم حذف شدند',
      user: user,
    );

    _userMessage = 'همه لاگ‌ها پاک‌سازی شدند';
    await loadAll();
  }

  Future<void> _insertAudit({
    required String action,
    required String details,
    User? user,
  }) async {
    final actor = user ?? _currentUser;
    await _repo.insertAuditLog(
      AuditLog(
        userId: actor?.id ?? 0,
        userName: actor?.name ?? 'سیستم',
        userRole: actor?.role ?? 'SYSTEM',
        action: action,
        details: details,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // پشتیبان‌گیری
  // --------------------------------------------------------------------------

  Future<File?> createBackup() {
    return BackupManager.createBackupJson();
  }

  Future<File?> createSqlBackup() {
    return BackupManager.createBackupSql();
  }

  Future<bool> restoreBackup(String json) {
    return BackupManager.restoreFromJson(json);
  }

  Future<File?> runManualBackup() async {
    final file = await BackupManager.createBackupJson();
    if (file == null) {
      _userMessage = 'فایل پشتیبان ایجاد نشد';
      _notify();
      return null;
    }

    await _insertAudit(
      action: 'پشتیبان‌گیری دستی',
      details: 'فایل پشتیبان ${file.path} ایجاد شد',
    );

    _userMessage = 'نسخه پشتیبان با موفقیت ایجاد شد';
    await _reloadAuditLogs();
    _notify();

    return file;
  }

  Future<bool> runManualRestore(String json) async {
    final normalizedJson = json.trim();
    if (normalizedJson.isEmpty) {
      throw ArgumentError('محتوای نسخه پشتیبان خالی است.');
    }

    final success = await BackupManager.restoreFromJson(normalizedJson);
    if (!success) {
      _userMessage = 'بازیابی اطلاعات ناموفق بود';
      _notify();
      return false;
    }

    await _insertAudit(
      action: 'بازیابی نسخه پشتیبان',
      details: 'اطلاعات از نسخه پشتیبان بازیابی شدند',
    );

    _userMessage = 'بازیابی اطلاعات با موفقیت انجام شد';
    await loadAll();

    return true;
  }

  // --------------------------------------------------------------------------
  // پاک‌سازی اطلاعات
  // --------------------------------------------------------------------------

  Future<void> clearAllBusinessData() async {
    if (!isAdmin) {
      throw StateError('فقط مدیر می‌تواند اطلاعات را پاک کند.');
    }

    await _repo.deleteAllProducts();
    await _repo.deleteAllContacts();
    await _repo.deleteAllExpenses();
    await _repo.deleteAllTransactions();
    await _repo.deleteAllMovements();

    clearCart(notify: false);
    _userMessage = 'تمام اطلاعات کسب‌وکار پاک‌سازی شدند';
    await loadAll();
  }

  // --------------------------------------------------------------------------
  // فهرست و قیمت خدمات
  // --------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getServicePriceCatalog({
    required String? businessCode,
  }) async {
    final code = businessCode?.trim();
    if (code == null || code.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final items = await _repo.getServiceItems(
      businessCode: code,
    );

    return items
        .map(
          (item) => <String, dynamic>{
            ...item,
            'businessCode': item['businessCode']?.toString() ?? code,
            'sellPrice': (item['sellPrice'] as num?)?.toDouble() ?? 0.0,
            'costPrice': (item['costPrice'] as num?)?.toDouble() ?? 0.0,
            'taxRate': (item['taxRate'] as num?)?.toDouble() ?? 0.0,
            'unit': item['unit']?.toString().trim().isNotEmpty == true
                ? item['unit'].toString()
                : 'خدمت',
            'note': item['note']?.toString() ?? '',
          },
        )
        .toList();
  }

  Future<int> saveServicePrice({
    int id = 0,
    required String businessCode,
    required String name,
    required double sellPrice,
    String unit = 'خدمت',
    String note = '',
  }) async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی می‌تواند قیمت خدمات را مدیریت کند.');
    }

    final code = businessCode.trim();
    final serviceName = name.trim();
    final serviceUnit = unit.trim().isEmpty ? 'خدمت' : unit.trim();
    final serviceNote = note.trim();

    if (code.isEmpty) {
      throw ArgumentError('نوع کسب‌وکار مشخص نشده است.');
    }
    if (serviceName.isEmpty) {
      throw ArgumentError('نام خدمت نمی‌تواند خالی باشد.');
    }
    if (!sellPrice.isFinite || sellPrice < 0) {
      throw ArgumentError('قیمت فروش معتبر نیست.');
    }

    final savedId = await _repo.saveServiceItem(
      <String, dynamic>{
        if (id > 0) 'id': id,
        'businessCode': code,
        'name': serviceName,
        'category': '',
        'sellPrice': sellPrice,
        'costPrice': 0.0,
        'unit': serviceUnit,
        'taxRate': 0.0,
        'isActive': 1,
        'note': serviceNote,
      },
    );

    _userMessage = id > 0
        ? 'قیمت خدمت «$serviceName» به‌روزرسانی شد'
        : 'خدمت «$serviceName» با موفقیت اضافه شد';

    await _reloadAuditLogs();
    _notify();

    return savedId;
  }

  // --------------------------------------------------------------------------
  // افزودن کالاهای پیش‌فرض
  // --------------------------------------------------------------------------

  Future<void> seedDefaultServicesAndProducts() async {
    final defaults = <Product>[
      Product(
        name: 'چاپ سیاه و سفید A4',
        category: 'چاپ سیاه و سفید',
        buyPrice: 500.0,
        sellPrice: 3000.0,
        stockQuantity: 9999.0,
        unit: 'صفحه',
      ),
      Product(
        name: 'چاپ رنگی A4',
        category: 'چاپ رنگی',
        buyPrice: 2000.0,
        sellPrice: 10000.0,
        stockQuantity: 9999.0,
        unit: 'صفحه',
      ),
    ];

    for (final product in defaults) {
      await _repo.insertProduct(product);
    }

    _userMessage = 'خدمات پیش‌فرض به انبار اضافه شدند';
    await loadAll();
  }

  // --------------------------------------------------------------------------
  // خروجی گزارش‌ها
  // --------------------------------------------------------------------------

  Future<File?> exportSalesCsv() async {
    final currency = _config?.currency ?? 'تومان';
    final rows = transactions
        .where((transaction) => transaction.type == 'SALE')
        .map((transaction) {
      return <String>[
        '#${transaction.id}',
        _formatDate(transaction.dateMillis),
        transaction.contactName,
        transaction.userName,
        transaction.paymentMethod,
        '${transaction.totalAmount} $currency',
        '${transaction.discount} $currency',
        '${transaction.finalAmount} $currency',
        '${transaction.paidAmount} $currency',
        '${transaction.debtAmount} $currency',
      ];
    }).toList();

    return Exporter.exportToCsv(
      filenamePrefix: 'گزارش_فروش',
      headers: const <String>[
        'شناسه فاکتور',
        'تاریخ',
        'خریدار',
        'فروشنده',
        'روش پرداخت',
        'جمع کل',
        'تخفیف',
        'مبلغ نهایی',
        'پرداختی',
        'بدهی',
      ],
      rows: rows,
      storeName: _config?.storeName,
    );
  }

  Future<File?> exportDebtorsCsv() async {
    final currency = _config?.currency ?? 'تومان';
    final rows = _debtors.map((contact) {
      return <String>[
        contact.id.toString(),
        contact.name,
        contact.phone,
        contact.address,
        '${contact.totalDebt} $currency',
        contact.note,
      ];
    }).toList();

    return Exporter.exportToCsv(
      filenamePrefix: 'لیست_بدهکاران',
      headers: const <String>[
        'شناسه',
        'نام مخاطب',
        'شماره تماس',
        'آدرس',
        'میزان طلب',
        'توضیحات'
      ],
      rows: rows,
      storeName: _config?.storeName,
    );
  }

  Future<File?> exportDebtorsPdf() async {
    final currency = _config?.currency ?? 'تومان';
    final storeName = _config?.storeName ?? 'فروشگاه';
    final totalDebt = _debtors.fold<double>(
      0.0,
      (sum, contact) => sum + contact.totalDebt.toDouble(),
    );

    final rows = _debtors.map((contact) {
      return <String>[
        contact.name,
        contact.phone.isEmpty ? '-' : contact.phone,
        contact.address.isEmpty ? '-' : contact.address,
        contact.note.isEmpty ? '-' : contact.note,
        '${NumberFormat('#,##0', 'en_US').format(contact.totalDebt)} $currency',
      ];
    }).toList();

    return Exporter.exportTableToPdf(
      filenamePrefix: 'لیست_بدهکاران',
      title: 'گزارش جامع بدهکاران',
      storeName: storeName,
      headers: const [
        'نام بدهکار',
        'شماره تماس',
        'آدرس',
        'توضیحات',
        'مبلغ بدهی'
      ],
      rows: rows,
      subtitle:
          'مجموع مطالبات: ${NumberFormat('#,##0', 'en_US').format(totalDebt)} $currency',
      paperSize: _config?.printPaperSize ?? 'A4',
      orientation: _config?.printOrientation ?? 'PORTRAIT',
      marginMm: _config?.printMarginMm ?? 8.0,
      customWidthMm: _config?.customPaperWidthMm ?? 210.0,
      customHeightMm: _config?.customPaperHeightMm ?? 297.0,
    );
  }

  Future<File?> exportExpensesCsv() async {
    final currency = _config?.currency ?? 'تومان';
    final rows = _expenses.map((expense) {
      return <String>[
        expense.id.toString(),
        _formatDate(expense.dateMillis),
        expense.title,
        expense.category,
        '${expense.amount} $currency',
        expense.userName,
        expense.note,
      ];
    }).toList();

    return Exporter.exportToCsv(
      filenamePrefix: 'گزارش_هزینه_ها',
      headers: const <String>[
        'شناسه',
        'تاریخ',
        'عنوان هزینه',
        'دسته‌بندی',
        'مبلغ',
        'ثبت‌کننده',
        'توضیحات'
      ],
      rows: rows,
      storeName: _config?.storeName,
    );
  }

  Future<File?> exportProductsCsv() async {
    final currency = _config?.currency ?? 'تومان';
    final rows = _products.map((product) {
      return <String>[
        product.id.toString(),
        product.name,
        product.barcode,
        product.category,
        product.stockQuantity.toString(),
        product.unit,
        product.minStockAlert.toString(),
        '${product.buyPrice} $currency',
        '${product.sellPrice} $currency',
      ];
    }).toList();

    return Exporter.exportToCsv(
      filenamePrefix: 'موجودی_کالاها',
      headers: const <String>[
        'شناسه',
        'نام کالا',
        'بارکد',
        'دسته‌بندی',
        'موجودی فعلی',
        'واحد',
        'آستانه هشدار',
        'قیمت خرید',
        'قیمت فروش'
      ],
      rows: rows,
      storeName: _config?.storeName,
    );
  }

  Future<File?> exportStockCsv() async {
    final currency = _config?.currency ?? 'تومان';
    final rows = _stockMovements.map((movement) {
      return <String>[
        movement.id.toString(),
        _formatDate(movement.dateMillis),
        movement.type == 'IN' ? 'ورودی' : 'خروجی',
        movement.productName,
        movement.quantity.toString(),
        movement.unit,
        '${movement.pricePerUnit} $currency',
        '${movement.totalPrice} $currency',
        movement.partyName,
        movement.refNumber,
        movement.userName,
        movement.note,
      ];
    }).toList();

    return Exporter.exportToCsv(
      filenamePrefix: 'گزارش_ورود_و_خروج_انبار',
      headers: const <String>[
        'شناسه',
        'تاریخ',
        'نوع تراکنش',
        'نام کالا',
        'تعداد',
        'واحد',
        'قیمت واحد',
        'مبلغ کل',
        'طرف حساب',
        'شماره مرجع',
        'کاربر',
        'توضیحات'
      ],
      rows: rows,
      storeName: _config?.storeName,
    );
  }

  // --------------------------------------------------------------------------
  // متدهای کمکی
  // --------------------------------------------------------------------------

  User _requireCurrentUser() {
    final user = _currentUser;
    if (user == null) {
      throw StateError('ابتدا وارد حساب کاربری شوید.');
    }
    return user;
  }

  String _formatDate(int milliseconds) {
    return faDateTimeMillis(milliseconds);
  }

  String _normalizeDigits(String input) {
    const persianDigits = <String>[
      '۰',
      '۱',
      '۲',
      '۳',
      '۴',
      '۵',
      '۶',
      '۷',
      '۸',
      '۹'
    ];
    const arabicDigits = <String>[
      '٠',
      '١',
      '٢',
      '٣',
      '٤',
      '٥',
      '٦',
      '٧',
      '٨',
      '٩'
    ];

    var result = input;
    for (int index = 0; index < 10; index++) {
      result = result.replaceAll(persianDigits[index], index.toString());
      result = result.replaceAll(arabicDigits[index], index.toString());
    }
    return result;
  }

  String? _normalizeTime(String input) {
    final normalized =
        _normalizeDigits(input.trim()).replaceAll('：', ':').replaceAll(' ', '');
    final match = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(normalized);

    if (match == null) {
      return null;
    }

    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  // --------------------------------------------------------------------------
  // حسابداری تجاری
  // --------------------------------------------------------------------------

  Future<void> ensureAccountingSeed() => _repo.ensureAccountingSeed();

  Future<List<ChartAccount>> getChartAccounts() => _repo.getChartAccounts();
  Future<void> deleteChartAccount(int id) async {
    if (!isAdmin) throw StateError('فقط مدیر اصلی می‌تواند سرفصل را حذف کند.');
    await _repo.deleteChartAccount(id);
    await loadAll();
  }


  Future<int> saveChartAccount(ChartAccount account) async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی می‌تواند سرفصل‌ها را مدیریت کند.');
    }
    final id = await _repo.saveChartAccount(account);
    await _insertAudit(
        action: 'مدیریت سرفصل حساب',
        details: '${account.code} - ${account.name}',
        user: _requireCurrentUser());
    return id;
  }

  Future<List<JournalEntry>> getJournalEntries(
          {int limit = 500, int? startMillis, int? endMillis}) =>
      _repo.getJournalEntries(
          limit: limit, startMillis: startMillis, endMillis: endMillis);

  Future<List<JournalLine>> getJournalLines(int journalId) =>
      _repo.getJournalLines(journalId);
  Future<void> deleteAllManualJournalEntries() async {
    if (!isAdmin) throw StateError('فقط مدیر اصلی می‌تواند سندهای دستی را حذف کند.');
    await _repo.deleteAllJournalEntries(manualOnly: true);
    await loadAll();
  }

  Future<void> updateJournalEntry({required int id, required String description, required List<JournalLine> lines, int? dateMillis}) async {
    if (!isAdmin) throw StateError('فقط مدیر اصلی می‌تواند سند را ویرایش کند.');
    await _repo.updateJournalEntry(id:id, description:description, lines:lines, dateMillis:dateMillis);
    await loadAll();
  }

  Future<void> deleteJournalEntry(int id) async {
    if (!isAdmin) throw StateError('فقط مدیر اصلی می‌تواند سند دستی را حذف کند.');
    await _repo.deleteJournalEntry(id);
    await loadAll();
  }


  Future<int> addBalancedJournal({
    required String description,
    required List<JournalLine> lines,
    String sourceType = 'MANUAL',
    int? sourceId,
  }) async {
    final user = _requireCurrentUser();
    final id = await _repo.createJournalEntry(
      description: description,
      lines: lines,
      sourceType: sourceType,
      sourceId: sourceId,
      userId: user.id,
      userName: user.name,
    );
    await _insertAudit(
        action: 'ثبت سند حسابداری', details: description, user: user);
    return id;
  }

  Future<List<Map<String, dynamic>>> getGeneralLedger(
          {int? accountId, int? startMillis, int? endMillis}) =>
      _repo.getGeneralLedger(
          accountId: accountId, startMillis: startMillis, endMillis: endMillis);

  Future<Map<String, double>> getProfitLossReport(
          int startMillis, int endMillis) =>
      _repo.getProfitLoss(startMillis, endMillis);

  Future<Map<String, double>> getBalanceSheetReport(int millis) =>
      _repo.getBalanceSheet(millis);

  Future<List<CashBankAccount>> getCashBankAccounts() =>
      _repo.getCashBankAccounts();
  Future<void> deleteCashBankAccount(int id) async {
    if (!isAdmin) throw StateError('فقط مدیر اصلی می‌تواند حساب صندوق/بانک را حذف کند.');
    await _repo.deleteCashBankAccount(id);
    await loadAll();
  }


  Future<int> saveCashBankAccount(CashBankAccount account) async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی می‌تواند صندوق و بانک را مدیریت کند.');
    }
    return _repo.saveCashBankAccount(account);
  }

  Future<double> getCashBankBalance(CashBankAccount account) =>
      _repo.getCashBankBalance(account);

  Future<int> settleContact({
    required int contactId,
    required String contactName,
    required String type,
    required double amount,
    required int cashBankId,
    required String cashBankName,
    String description = '',
  }) async {
    final user = _requireCurrentUser();
    final id = await _repo.createSettlement(SettlementRecord(
      contactId: contactId,
      contactName: contactName,
      type: type,
      amount: amount,
      cashBankId: cashBankId,
      cashBankName: cashBankName,
      dateMillis: DateTime.now().millisecondsSinceEpoch,
      description: description,
      userId: user.id,
      userName: user.name,
    ));
    await _insertAudit(
      action: type == 'RECEIPT' ? 'ثبت دریافت' : 'ثبت پرداخت',
      details: '$contactName - $amount',
      user: user,
    );
    await loadAll();
    return id;
  }

  Future<List<SettlementRecord>> getSettlements() => _repo.getSettlements();
  Future<void> updateSettlement(SettlementRecord record) async {
    if (!isAdmin) throw StateError('فقط مدیر اصلی می‌تواند تسویه را ویرایش کند.');
    await _repo.updateSettlement(record);
    await loadAll();
  }

  Future<void> deleteSettlement(int id) async {
    if (!isAdmin) throw StateError('فقط مدیر اصلی می‌تواند تسویه را حذف کند.');
    await _repo.deleteSettlement(id);
    await loadAll();
  }


  Future<int> transferCashBank({
    required CashBankAccount from,
    required CashBankAccount to,
    required double amount,
    String description = '',
  }) async {
    final user = _requireCurrentUser();
    final id = await _repo.transferCashBank(
      from: from,
      to: to,
      amount: amount,
      description: description,
      userId: user.id,
      userName: user.name,
    );
    await _insertAudit(
        action: 'انتقال بین صندوق و بانک',
        details: '${from.name} ← ${to.name} : $amount',
        user: user);
    await loadAll();
    return id;
  }

  Future<void> markPayrollPaid(PayrollRecord payroll,
      {int? cashBankId, String cashBankName = 'صندوق'}) async {
    final user = _requireCurrentUser();
    await _repo.markPayrollPaid(payroll,
        userId: user.id,
        userName: user.name,
        cashBankId: cashBankId,
        cashBankName: cashBankName);
    await _insertAudit(
        action: 'پرداخت حقوق',
        details: '${payroll.userName} - ${payroll.netSalary}',
        user: user);
    await loadAll();
  }

  Future<List<Map<String, dynamic>>> getTrialBalance(
          {int? startMillis, int? endMillis}) =>
      _repo.getTrialBalance(startMillis: startMillis, endMillis: endMillis);

  Future<List<Map<String, dynamic>>> getAgingDetails() =>
      _repo.getAgingDetails();

  Future<List<Map<String, dynamic>>> getTaxAnnualReport(
          int year, double rate) =>
      _repo.getTaxAnnualReport(year, rate);

  Future<int> savePayrollRecord(PayrollRecord record) async {
    if (!isAdmin) {
      throw StateError('فقط مدیر اصلی می‌تواند حقوق را مدیریت کند.');
    }
    return _repo.savePayroll(record);
  }

  Future<List<PayrollRecord>> getPayroll({int? year, int? month}) =>
      _repo.getPayroll(year: year, month: month);
  Future<void> deletePayroll(int id) async {
    if (!isAdmin) throw StateError('فقط مدیر اصلی می‌تواند رکورد حقوق را حذف کند.');
    await _repo.deletePayroll(id);
    await loadAll();
  }


  Future<Map<String, double>> getTaxReport(int year, int month, double rate) =>
      _repo.getTaxReport(year, month, rate);

  Future<Map<String, double>> getAgingSummary() => _repo.getAgingSummary();

  Future<int> recordReturn({
    required StoreTransaction original,
    required List<TransactionItem> items,
    required bool saleReturn,
  }) async {
    if (!hasPermission(PermissionCatalog.invoicesReturn)) {
      throw StateError('شما دسترسی ثبت برگشت را ندارید.');
    }
    if (!canEditOrDeleteTransaction(original)) {
      throw StateError('شما فقط مجاز به برگشت فاکتورهای ثبت‌شده توسط خودتان هستید.');
    }
    final user = _requireCurrentUser();
    final id =
        await _repo.recordReturn(original, items, saleReturn: saleReturn);
    await _insertAudit(
      action: saleReturn ? 'برگشت فروش' : 'برگشت خرید',
      details: 'برگشت از فاکتور #${original.id}',
      user: user,
    );
    await loadAll();
    return id;
  }
}

// Convenience delivery methods used by invoice UI.
extension InvoiceDeliveryConvenience on MainViewModel {
  Future<void> sendInvoiceViaWhatsApp(
          {required int invoiceId, String destination = ''}) =>
      recordInvoiceDelivery(
          invoiceId: invoiceId, channel: 'WHATSAPP', destination: destination);

  Future<void> sendInvoiceViaSms(
          {required int invoiceId, String destination = ''}) =>
      recordInvoiceDelivery(
          invoiceId: invoiceId, channel: 'SMS', destination: destination);

  Future<void> sendInvoiceViaEmail(
          {required int invoiceId, String destination = ''}) =>
      recordInvoiceDelivery(
          invoiceId: invoiceId, channel: 'EMAIL', destination: destination);
}
