// ============================================================================
// dashboard_screen.dart
// داشبورد مدیریت StoreMaster Pro - نسخه RTL اصلاح‌شده
// ============================================================================
// ignore_for_file: unused_import

import 'dart:ui' as ui;
import 'dart:async';
import '../services/online_api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../shared_src/feature_catalog.dart';
import '../shared_src/permission_catalog.dart';
import '../utils/shamsi_date_utils.dart';

import '../viewmodels/main_viewmodel.dart';
import '../services/license/license_service.dart';
import 'contacts_screen.dart';
import 'commercial_features_screen.dart';
import 'accounting_screen.dart';
import 'invoices_screen.dart';
import 'expenses_screen.dart';
import 'enterprise_control_screen.dart';
import 'logs_screen.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'support_chat_screen.dart';
import 'stock_screen.dart';
import 'users_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _liveTimer;
  Map<String, dynamic> _livePricing = <String, dynamic>{
    'currency': 'تومان',
    'prices': <String, num>{'30': 990000, '90': 2490000, '180': 4490000, '365': 7990000},
  };
  final List<Map<String, dynamic>> _serverNotifications = <Map<String, dynamic>>[];
  final Set<int> _seenNotificationIds = <int>{};
  int _lastNotificationId = 0;
  int _serverUnreadCount = 0;
  bool _pricingLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshLiveData(initial: true);
    _liveTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshLiveData());
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshLiveData({bool initial = false}) async {
    if (_pricingLoading) return;
    _pricingLoading = true;
    try {
      final data = await OnlineApiService.instance.fetchPublicPricing();
      if (mounted && data.isNotEmpty) {
        setState(() => _livePricing = Map<String, dynamic>.from(data));
      }

      final api = OnlineApiService.instance;
      if (OnlineApiService.onlineEnabled && api.isAuthenticated) {
        final newItems = await api.fetchNotifications(afterId: initial ? 0 : _lastNotificationId);
        if (mounted && newItems.isNotEmpty) {
          for (final item in newItems) {
            final id = (item['id'] as num?)?.toInt() ?? 0;
            if (id <= 0 || !_seenNotificationIds.add(id)) continue;
            _serverNotifications.add(item);
            if (_serverNotifications.length > 100) _serverNotifications.removeAt(0);
            if (id > _lastNotificationId) _lastNotificationId = id;
          }
          if (_lastNotificationId > 0 && _serverNotifications.isNotEmpty) {
            final maxId = _serverNotifications.fold<int>(0, (value, item) => value > ((item['id'] as num?)?.toInt() ?? 0) ? value : ((item['id'] as num?)?.toInt() ?? 0));
            if (maxId > _lastNotificationId) _lastNotificationId = maxId;
          }
        }
        final unread = await api.unreadNotificationCount();
        if (mounted) setState(() => _serverUnreadCount = unread);
      }
    } catch (_) {
      // The dashboard must remain usable in offline mode.
    } finally {
      _pricingLoading = false;
    }
  }

  void _showNotifications() {
    final serverItems = List<Map<String, dynamic>>.from(_serverNotifications)
      ..sort((a, b) => ((b['id'] as num?)?.toInt() ?? 0).compareTo((a['id'] as num?)?.toInt() ?? 0));
    final allMessages = <String>[
      ...serverItems.map((item) {
        final title = '${item['title'] ?? 'اعلان Store Master'}';
        final message = '${item['message'] ?? ''}';
        final when = (item['createdAt'] as num?)?.toInt();
        final date = when == null ? '' : '\n${ShamsiDateUtils.date(DateTime.fromMillisecondsSinceEpoch(when))}';
        return '$title\n$message$date';
      }),
    ];
    // Opening the inbox marks all visible server notifications as read.
    for (final item in serverItems) {
      final id = (item['id'] as num?)?.toInt() ?? 0;
      if (id > 0 && item['isRead'] != true) {
        unawaited(OnlineApiService.instance.markNotificationRead(id));
        item['isRead'] = true;
      }
    }
    _serverUnreadCount = 0;
    if (mounted) setState(() {});
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(children: [const Icon(Icons.notifications_active_outlined), const SizedBox(width: 8), const Text('اعلان‌ها')]),
        content: SizedBox(
          width: 420,
          child: allMessages.isEmpty
              ? const Text('اعلان جدیدی دریافت نشده است. اعلان‌های لایسنس، همگام‌سازی، چاپ و تیکت‌ها هنگام اتصال به سرور نمایش داده می‌شوند.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: allMessages.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (_, index) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.notifications_none),
                    title: Text(allMessages[index]),
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () {
            setState(() {
              _serverNotifications.clear();
              _seenNotificationIds.clear();
            });
            Navigator.pop(dialogContext);
          }, child: const Text('پاک کردن اعلان‌ها')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('بستن')),
        ],
      ),
    );
  }

  Widget _liveLicensePricingCard() {
    final prices = _livePricing['prices'];
    if (prices is! Map || prices.isEmpty) return const SizedBox.shrink();
    final entries = prices.entries.toList()
      ..sort((a, b) => (int.tryParse('${a.key}') ?? 0).compareTo(int.tryParse('${b.key}') ?? 0));
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.sell_outlined),
            const SizedBox(width: 8),
            const Expanded(child: Text('قیمت لایسنس‌ها', style: TextStyle(fontWeight: FontWeight.bold))),
            IconButton(onPressed: _refreshLiveData, tooltip: 'به‌روزرسانی قیمت', icon: const Icon(Icons.refresh)),
          ]),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entries.map((entry) {
              final days = int.tryParse('${entry.key}') ?? 0;
              final value = (entry.value as num?)?.toDouble() ?? double.tryParse('${entry.value}') ?? 0;
              return Chip(label: Text('$days روز: ${NumberFormat('#,##0', 'fa_IR').format(value)} ${_livePricing['currency'] ?? 'تومان'}'));
            }).toList(),
          ),
        ]),
      ),
    );
  }

  void _openSupport() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SupportChatScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainViewModel>();
    final user = vm.currentUser;
    final config = vm.config;
    final currency = config?.currency ?? 'تومان';

    final now = DateTime.now();
    final todayStartDate = DateTime(now.year, now.month, now.day);

    final todayStart = todayStartDate.millisecondsSinceEpoch;
    final tomorrowStart =
        todayStartDate.add(const Duration(days: 1)).millisecondsSinceEpoch;

    final todaySaleTransactions = vm.transactions.where(
      (t) =>
          t.type == 'SALE' &&
          t.dateMillis >= todayStart &&
          t.dateMillis < tomorrowStart,
    );

    final double todaySales = todaySaleTransactions.fold<double>(
      0,
      (sum, t) => sum + t.finalAmount,
    );

    final double totalDebts = vm.debtors.fold<double>(
      0,
      (sum, c) => sum + c.totalDebt,
    );

    final double totalPayables = vm.creditors.fold<double>(
      0,
      (sum, c) => sum + c.totalPayable,
    );

    final double totalExpenses = vm.expenses.fold<double>(
      0,
      (sum, e) => sum + e.amount,
    );

    // ------------------------------------------------------------------------
    // ساعات شیفت
    // ------------------------------------------------------------------------

    final int morningStart = _normalizeStartHour(config?.morningStartHour ?? 6);

    final int morningEnd = _normalizeEndHour(config?.morningEndHour ?? 15);

    final int eveningStart =
        _normalizeStartHour(config?.eveningStartHour ?? 15);

    final int eveningEnd = _normalizeEndHour(config?.eveningEndHour ?? 24);

    final bool hasActiveAttendance = user != null &&
        vm.attendance.any(
          (a) => a.userId == user.id && a.clockOutTime == null,
        );

    double morningSales = 0;
    double eveningSales = 0;

    for (final transaction in todaySaleTransactions) {
      final hour =
          DateTime.fromMillisecondsSinceEpoch(transaction.dateMillis).hour;

      if (_isHourInShift(hour, morningStart, morningEnd)) {
        morningSales += transaction.finalAmount;
      }

      if (_isHourInShift(hour, eveningStart, eveningEnd)) {
        eveningSales += transaction.finalAmount;
      }
    }

    final dailyData = _buildWeeklySalesData(vm, now);

    final recentSales = vm.transactions
        .where((transaction) => transaction.type == 'SALE')
        .toList()
      ..sort(
        (a, b) => b.dateMillis.compareTo(a.dateMillis),
      );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'داشبورد مدیریت - StoreMaster Pro',
          textDirection: ui.TextDirection.rtl,
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            tooltip: 'اعلان‌ها',
            onPressed: _showNotifications,
            icon: Badge(
              isLabelVisible: _serverUnreadCount > 0,
              label: Text(_serverUnreadCount > 99 ? '99+' : '$_serverUnreadCount'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          PopupMenuButton<String>(
            iconColor: Theme.of(context).colorScheme.onSurface,
            onSelected: (value) => _onMenu(context, vm, value),
            itemBuilder: (context) {
              final items = <PopupMenuEntry<String>>[];
              if (vm.hasPermission(PermissionCatalog.salesCreate)) {
                items.add(const PopupMenuItem(value: 'pos', child: Text('ثبت فروش / صندوق')));
              }
              if (vm.hasPermission(PermissionCatalog.invoicesEdit) ||
                  vm.hasPermission(PermissionCatalog.invoicesDelete)) {
                items.add(const PopupMenuItem(value: 'invoices', child: Text('فاکتورها | ویرایش و حذف')));
              }
              if (vm.hasPermission(PermissionCatalog.invoicesReturn)) {
                items.add(const PopupMenuItem(value: 'accounting_returns', child: Text('برگشت فروش و خرید')));
              }
              if (vm.hasPermission(PermissionCatalog.productsView)) {
                items.add(const PopupMenuItem(value: 'products', child: Text('کالاها')));
              }
              if (vm.hasPermission(PermissionCatalog.inventoryView) ||
                  vm.hasPermission(PermissionCatalog.inventoryManage)) {
                items.add(const PopupMenuItem(value: 'stock', child: Text('ورود و خروج کالا')));
              }
              if (vm.hasPermission(PermissionCatalog.customersView)) {
                items.add(const PopupMenuItem(value: 'contacts', child: Text('مشتریان و طرف حساب‌ها')));
              }
              if (vm.hasPermission(PermissionCatalog.accountingExpenses)) {
                items.add(const PopupMenuItem(value: 'expenses', child: Text('هزینه‌ها')));
              }
              if (vm.hasPermission(PermissionCatalog.reportsView)) {
                items.add(const PopupMenuItem(value: 'reports', child: Text('گزارشات')));
              }
              if (vm.hasPermission(PermissionCatalog.accountingManage) || vm.isAdmin) {
                items.add(const PopupMenuItem(value: 'accounting', child: Text('حسابداری تجاری')));
              }

              if (vm.isAdmin) {
                items.addAll(
                  const [
                    PopupMenuItem(
                      value: 'users',
                      child: Text('کاربران و پرسنل'),
                    ),
                    PopupMenuItem(
                      value: 'settings',
                      child: Text('تنظیمات'),
                    ),
                    PopupMenuItem(
                      value: 'logs',
                      child: Text('لاگ‌های سیستم'),
                    ),
                    PopupMenuItem(
                      value: 'attendance_admin',
                      child: Text('مدیریت حضور و غیاب'),
                    ),
                  ],
                );
              }

              items.addAll(
                const [
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: Text('خروج / تغییر کاربر'),
                  ),
                ],
              );

              return items;
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _liveLicensePricingCard(),
              // =================================================================
              // کارت کاربر
              // =================================================================

              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 700) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              textDirection: ui.TextDirection.rtl,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'خوش آمدید، ${user?.name ?? "کاربر"}',
                                        textDirection: ui.TextDirection.rtl,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'نقش: ${{'OWNER':'مالک','ADMIN':'مدیر کل','MANAGER':'مدیر','SELLER':'فروشنده','WAREHOUSE':'انباردار','ACCOUNTANT':'حسابدار','CASHIER':'صندوقدار','CUSTOM':'سفارشی'}[user?.role] ?? 'کاربر'}',
                                        textDirection: ui.TextDirection.rtl,
                                        textAlign: TextAlign.right,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              textDirection: ui.TextDirection.rtl,
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (user != null)
                                  _attendanceButton(
                                    context: context,
                                    vm: vm,
                                    config: config,
                                    hasActiveAttendance: hasActiveAttendance,
                                  ),
                                ElevatedButton.icon(
                                  onPressed: vm.logout,
                                  icon: const Icon(
                                    Icons.switch_account,
                                  ),
                                  label: const Text('تغییر کاربر'),
                                ),
                                OutlinedButton.icon(onPressed: _openSupport, icon: const Icon(Icons.support_agent), label: const Text('پشتیبانی زنده')),
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        textDirection: ui.TextDirection.rtl,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'خوش آمدید، ${user?.name ?? "کاربر"}',
                                  textDirection: ui.TextDirection.rtl,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'نقش: ${{'OWNER':'مالک','ADMIN':'مدیر کل','MANAGER':'مدیر','SELLER':'فروشنده','WAREHOUSE':'انباردار','ACCOUNTANT':'حسابدار','CASHIER':'صندوقدار','CUSTOM':'سفارشی'}[user?.role] ?? 'کاربر'}',
                                  textDirection: ui.TextDirection.rtl,
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                          ),
                          if (user != null)
                            _attendanceButton(
                              context: context,
                              vm: vm,
                              config: config,
                              hasActiveAttendance: hasActiveAttendance,
                            ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: vm.logout,
                            icon: const Icon(
                              Icons.switch_account,
                            ),
                            label: const Text('تغییر کاربر'),
                          ),
                          IconButton(onPressed: _openSupport, tooltip: 'پشتیبانی زنده', icon: const Icon(Icons.support_agent_rounded)),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // =================================================================
              // خلاصه مالی
              // =================================================================

              const Text(
                'خلاصه وضعیت مالی',
                textDirection: ui.TextDirection.rtl,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                height: 115,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _KpiCard(
                      title: 'فروش امروز',
                      value: _formatMoney(
                        todaySales,
                        currency,
                      ),
                      icon: Icons.point_of_sale,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    _KpiCard(
                      title: 'کل طلب‌های ما',
                      value: _formatMoney(
                        totalDebts,
                        currency,
                      ),
                      icon: Icons.account_balance_wallet,
                      color: const Color(0xFFD81B60),
                    ),
                    _KpiCard(
                      title: 'کل بدهی‌های ما',
                      value: _formatMoney(
                        totalPayables,
                        currency,
                      ),
                      icon: Icons.money_off,
                      color: const Color(0xFFE65100),
                    ),
                    _KpiCard(
                      title: 'کل هزینه‌ها',
                      value: _formatMoney(
                        totalExpenses,
                        currency,
                      ),
                      icon: Icons.receipt_long,
                      color: const Color(0xFF5E35B1),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // =================================================================
              // گزارش شیفت
              // =================================================================

              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        textDirection: ui.TextDirection.rtl,
                        children: [
                          const Icon(
                            Icons.wb_sunny,
                            color: Color(0xFFF57F17),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'گزارش فروش شیفت صبح و عصر',
                              textDirection: ui.TextDirection.rtl,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _navigate(context, 'reports'),
                            child: const Text('جزئیات'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 600) {
                            return Column(
                              children: [
                                _ShiftCard(
                                  title:
                                      'شیفت صبح ($morningStart تا $morningEnd)',
                                  sales: morningSales,
                                  currency: currency,
                                  icon: Icons.wb_sunny,
                                  iconColor: const Color(0xFFF57F17),
                                  isMorning: true,
                                ),
                                const SizedBox(height: 12),
                                _ShiftCard(
                                  title:
                                      'شیفت عصر ($eveningStart تا $eveningEnd)',
                                  sales: eveningSales,
                                  currency: currency,
                                  icon: Icons.nights_stay,
                                  iconColor: const Color(0xFF3949AB),
                                  isMorning: false,
                                ),
                              ],
                            );
                          }

                          return Row(
                            textDirection: ui.TextDirection.rtl,
                            children: [
                              Expanded(
                                child: _ShiftCard(
                                  title:
                                      'شیفت صبح ($morningStart تا $morningEnd)',
                                  sales: morningSales,
                                  currency: currency,
                                  icon: Icons.wb_sunny,
                                  iconColor: const Color(0xFFF57F17),
                                  isMorning: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ShiftCard(
                                  title:
                                      'شیفت عصر ($eveningStart تا $eveningEnd)',
                                  sales: eveningSales,
                                  currency: currency,
                                  icon: Icons.nights_stay,
                                  iconColor: const Color(0xFF3949AB),
                                  isMorning: false,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // =================================================================
              // نمودار
              // =================================================================

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'نمودار میله‌ای روند فروش ۷ روز اخیر',
                        textDirection: ui.TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'فروش روزانه به تفکیک تاریخ',
                        textDirection: ui.TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 190,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _BarPainter(dailyData),
                          size: Size.infinite,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // =================================================================
              // دسترسی سریع
              // =================================================================

              const Text(
                'دسترسی سریع',
                textDirection: ui.TextDirection.rtl,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 8),

              _buildPrimaryActions(context, vm),

              const SizedBox(height: 16),

              _NavButton(
                'امکانات تجاری پیشرفته',
                Icons.business_center_rounded,
                () => _navigate(context, 'commercial'),
              ),

              // =================================================================
              // هشدار موجودی
              // =================================================================

              if (vm.lowStockProducts.isNotEmpty)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          textDirection: ui.TextDirection.rtl,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'هشدار کمبود موجودی '
                                '(${vm.lowStockProducts.length} کالا)',
                                textDirection: ui.TextDirection.rtl,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...vm.lowStockProducts.take(3).map(
                              (product) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  '• ${product.name}: موجودی '
                                  '${product.stockQuantity} '
                                  '${product.unit} '
                                  '(حداقل: ${product.minStockAlert})',
                                  textDirection: ui.TextDirection.rtl,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // =================================================================
              // آخرین فاکتورها
              // =================================================================

              Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  Expanded(
                    child: Text(
                      'آخرین فاکتورهای فروش',
                      textDirection: ui.TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _navigate(context, 'reports'),
                    child: const Text('مشاهده همه'),
                  ),
                ],
              ),

              if (recentSales.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'هنوز فاکتور فروشی ثبت نشده است.',
                    textDirection: ui.TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                )
              else
                ...recentSales.take(5).map(
                  (transaction) {
                    final customer = transaction.contactName.trim().isEmpty
                        ? 'مشتری حضوری'
                        : transaction.contactName.trim();

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              textDirection: ui.TextDirection.rtl,
                          children: [
                            CircleAvatar(
                              radius: 21,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: const Icon(
                                Icons.receipt_long,
                                color: Color(0xFF6750A4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'فاکتور #${transaction.id} - $customer',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: ui.TextDirection.rtl,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${faDateTimeMillis(transaction.dateMillis)} | ثبت: ${transaction.userName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: ui.TextDirection.rtl,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatMoney(
                                    transaction.finalAmount,
                                    currency,
                                  ),
                                  textDirection: ui.TextDirection.rtl,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                if (transaction.debtAmount > 0)
                                  Text(
                                    'بدهی: ${_formatMoney(
                                      transaction.debtAmount,
                                      '',
                                    )}',
                                    textDirection: ui.TextDirection.rtl,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                              ],
                            ),
                            const Divider(height: 18),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 4,
                              children: [
                                if (vm.hasPermission(PermissionCatalog.invoicesEdit) && vm.canEditOrDeleteTransaction(transaction))
                                  TextButton.icon(
                                    onPressed: () => _navigate(context, 'invoices'),
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    label: const Text('ویرایش فاکتور'),
                                  ),
                                if (vm.hasPermission(PermissionCatalog.invoicesDelete) && vm.canEditOrDeleteTransaction(transaction))
                                  TextButton.icon(
                                    onPressed: () => _navigate(context, 'invoices'),
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    label: const Text('حذف فاکتور'),
                                  ),
                                if (vm.hasPermission(PermissionCatalog.invoicesReturn))
                                  TextButton.icon(
                                    onPressed: () => _navigate(context, 'accounting_returns'),
                                    icon: const Icon(Icons.assignment_return_outlined, size: 18),
                                    label: const Text('برگشت'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              if (vm.userMessage != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    vm.userMessage!,
                    textDirection: ui.TextDirection.rtl,
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attendanceButton({
    required BuildContext context,
    required MainViewModel vm,
    required dynamic config,
    required bool hasActiveAttendance,
  }) {
    return OutlinedButton.icon(
      onPressed: () async {
        try {
          if (hasActiveAttendance) {
            await vm.clockOut();
          } else {
            final currentHour = DateTime.now().hour;

            final eveningStart = _normalizeStartHour(
              config?.eveningStartHour ?? 15,
            );

            await vm.clockIn(
              shiftType: currentHour < eveningStart ? 'MORNING' : 'EVENING',
            );
          }

          if (!context.mounted) return;

          setState(() {});
        } catch (e) {
          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString(),
                textDirection: ui.TextDirection.rtl,
              ),
            ),
          );
        }
      },
      icon: Icon(
        hasActiveAttendance ? Icons.logout : Icons.login,
      ),
      label: Text(
        hasActiveAttendance ? 'اتمام شیفت' : 'آغاز شیفت',
      ),
    );
  }

  // ===========================================================================
  // تشخیص شیفت
  // ===========================================================================

  bool _isHourInShift(
    int hour,
    int start,
    int end,
  ) {
    start = _normalizeStartHour(start);
    end = _normalizeEndHour(end);

    // 24 = پایان روز
    if (end == 24) {
      return hour >= start && hour <= 23;
    }

    // شیفت عادی
    if (start < end) {
      return hour >= start && hour < end;
    }

    // شیفت عبوری از نیمه شب
    if (start > end) {
      return hour >= start || hour < end;
    }

    // شروع و پایان برابر = کل شبانه‌روز
    return true;
  }

  int _normalizeStartHour(int value) {
    if (value < 0) return 0;
    if (value > 23) return 23;
    return value;
  }

  int _normalizeEndHour(int value) {
    if (value < 0) return 0;
    if (value > 24) return 24;
    return value;
  }

  // ===========================================================================
  // داده نمودار
  // ===========================================================================

  List<Map<String, dynamic>> _buildWeeklySalesData(
    MainViewModel vm,
    DateTime now,
  ) {
    final List<Map<String, dynamic>> result = [];

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));

      final start = DateTime(
        date.year,
        date.month,
        date.day,
      );

      final end = start.add(const Duration(days: 1));

      final double total = vm.transactions
          .where(
            (transaction) =>
                transaction.type == 'SALE' &&
                transaction.dateMillis >= start.millisecondsSinceEpoch &&
                transaction.dateMillis < end.millisecondsSinceEpoch,
          )
          .fold<double>(
            0,
            (sum, transaction) => sum + transaction.finalAmount,
          );

      result.add(
        {
          'label': faShortDate(date),
          'value': total,
          'date': date,
        },
      );
    }

    return result;
  }

  // ===========================================================================
  // فرمت پول
  // ===========================================================================

  String _formatMoney(
    num value,
    String currency,
  ) {
    final formatted = NumberFormat('#,##0', 'fa_IR').format(value);

    return currency.trim().isEmpty ? formatted : '$formatted $currency';
  }

  // ===========================================================================
  // Navigation
  // ===========================================================================

  Widget _buildPrimaryActions(BuildContext context, MainViewModel vm) {
    final actions = <Widget>[];
    final addedRoutes = <String>{};

    void add(String title, IconData icon, String route) {
      // Each destination may appear only once in the dashboard.  Several
      // permissions can grant access to related features, so the route itself
      // is the canonical de-duplication key.
      if (!addedRoutes.add(route)) return;
      actions.add(_NavButton(title, icon, () => _navigate(context, route)));
    }

    if (vm.hasPermission(PermissionCatalog.salesCreate)) {
      add('ثبت فروش / فاکتور فروش', Icons.point_of_sale_rounded, 'pos');
    }
    if (vm.hasPermission(PermissionCatalog.invoicesEdit) ||
        vm.hasPermission(PermissionCatalog.invoicesDelete)) {
      add('فاکتورها و ویرایش / حذف', Icons.receipt_long_rounded, 'invoices');
    }
    if (vm.hasPermission(PermissionCatalog.invoicesReturn)) {
      add('برگشت فروش و خرید', Icons.assignment_return_rounded, 'accounting_returns');
    }
    if (vm.hasPermission(PermissionCatalog.productsView)) {
      add('کالاها و خدمات', Icons.inventory_2_rounded, 'products');
    }
    if (vm.hasPermission(PermissionCatalog.inventoryView) ||
        vm.hasPermission(PermissionCatalog.inventoryManage)) {
      add('ورود و خروج انبار', Icons.warehouse_rounded, 'stock');
    }
    if (vm.hasPermission(PermissionCatalog.customersView)) {
      add('مشتریان و طرف حساب‌ها', Icons.people_alt_rounded, 'contacts');
    }
    if (vm.hasPermission(PermissionCatalog.accountingExpenses)) {
      add('هزینه‌ها', Icons.payments_rounded, 'expenses');
    }
    if (vm.hasPermission(PermissionCatalog.reportsView)) {
      add('گزارش‌ها', Icons.analytics_rounded, 'reports');
    }
    if (vm.hasPermission(PermissionCatalog.accountingManage) || vm.isAdmin) {
      add('حسابداری تجاری', Icons.account_balance_rounded, 'accounting');
    }
    if (vm.isAdmin) {
      add('مدیریت کاربران', Icons.manage_accounts_rounded, 'users');
      add('حضور و غیاب', Icons.access_time_rounded, 'attendance_admin');
      add('لاگ سیستم', Icons.history_rounded, 'logs');
      add('تنظیمات فروشگاه', Icons.settings_rounded, 'settings');
    }

    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1200 ? 4 : constraints.maxWidth >= 700 ? 2 : 1;
      final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: actions
            .map((w) => SizedBox(width: width, child: w))
            .toList(),
      );
    });
  }

  Future<void> _navigate(
    BuildContext context,
    String route,
  ) async {
    final vm = context.read<MainViewModel>();

    const routeFeatures = <String, String>{
      'invoices': FeatureCatalog.sales,
      'pos': FeatureCatalog.sales,
      'products': FeatureCatalog.products,
      'stock': FeatureCatalog.inventory,
      'contacts': FeatureCatalog.customers,
      'expenses': FeatureCatalog.accounting,
      'reports': FeatureCatalog.reports,
      'accounting': FeatureCatalog.accounting,
      'commercial': FeatureCatalog.businessModules,
      'accounting_returns': FeatureCatalog.accounting,
    };

    final requiredFeature = routeFeatures[route];
    if (requiredFeature != null) {
      final status = await LicenseService.instance.validate(config: vm.config);
      if (!status.valid ||
          !LicenseService.instance.hasFeature(status.payload, requiredFeature)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'این قابلیت در لایسنس/دوره تست فعلی فعال نیست.',
                textDirection: ui.TextDirection.rtl,
              ),
            ),
          );
        }
        return;
      }
    }

    if (!vm.isAdmin &&
        const {
          'users',
          'settings',
          'logs',
          'attendance_admin',
        }.contains(route)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'این بخش فقط برای مدیر اصلی قابل دسترسی است.',
            textDirection: ui.TextDirection.rtl,
          ),
        ),
      );
      return;
    }

    switch (route) {
      case 'invoices':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoicesScreen()));
        break;

      case 'pos':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PosScreen(),
          ),
        );
        break;

      case 'products':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ProductsScreen(),
          ),
        );
        break;

      case 'stock':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const StockScreen(),
          ),
        );
        break;

      case 'contacts':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ContactsScreen(),
          ),
        );
        break;

      case 'expenses':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ExpensesScreen(),
          ),
        );
        break;

      case 'reports':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ReportsScreen(),
          ),
        );
        break;

      case 'accounting_returns':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountingScreen(initialTab: 8)));
        break;

      case 'accounting':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AccountingScreen(),
          ),
        );
        break;

      case 'users':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const UsersScreen(),
          ),
        );
        break;

      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SettingsScreen(),
          ),
        );
        break;

      case 'commercial':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CommercialFeaturesScreen(),
          ),
        );
        break;

      case 'attendance_admin':
        await _showAttendanceAdmin(context, vm);
        break;

      case 'logs':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LogsScreen(),
          ),
        );
        break;
    }
  }

  Future<void> _showAttendanceAdmin(BuildContext context, MainViewModel vm) async {
    if (!vm.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فقط مدیر اصلی به حضور و غیاب دسترسی دارد.')),
      );
      return;
    }
    final records = await vm.getAttendanceForAdmin();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مدیریت حضور و غیاب'),
        content: SizedBox(
          width: 720,
          child: records.isEmpty
              ? const Center(child: Text('هنوز رکورد حضوری ثبت نشده است.'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: records.length,
                  itemBuilder: (_, i) {
                    final a = records[i];
                    final out = a.clockOutTime == null
                        ? 'در حال شیفت'
                        : faDateTimeMillis(a.clockOutTime!);
                    final overtime = a.overtimeMinutes > 0
                        ? ' • اضافه‌کاری ${a.overtimeMinutes} دقیقه'
                        : '';
                    return ListTile(
                      dense: true,
                      title: Text(a.userName),
                      subtitle: Text(
                        '${a.shiftType} • ورود ${faDateTimeMillis(a.clockInTime)} • خروج $out$overtime',
                      ),
                      trailing: Text(a.status == 'LATE' ? 'با تأخیر' : 'حضور'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن')),
        ],
      ),
    );
  }

  void _onMenu(
    BuildContext context,
    MainViewModel vm,
    String value,
  ) {
    if (value == 'logout') {
      vm.logout();
      return;
    }

    _navigate(
      context,
      value,
    );
  }
}

// ============================================================================
// KPI CARD
// ============================================================================

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsetsDirectional.only(
        end: 10,
      ),
      child: Container(
        width: 175,
        height: 115,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              textDirection: ui.TextDirection.rtl,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withAlpha(38),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    textDirection: ui.TextDirection.rtl,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              value,
              textDirection: ui.TextDirection.rtl,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// NAV BUTTON
// ============================================================================

class _NavButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onClick;

  const _NavButton(
    this.title,
    this.icon,
    this.onClick,
  );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onClick,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          textDirection: ui.TextDirection.rtl,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: ui.TextDirection.rtl,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SHIFT CARD
// ============================================================================

class _ShiftCard extends StatelessWidget {
  final String title;
  final double sales;
  final String currency;
  final IconData icon;
  final Color iconColor;
  final bool isMorning;

  const _ShiftCard({
    required this.title,
    required this.sales,
    required this.currency,
    required this.icon,
    required this.iconColor,
    required this.isMorning,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        isMorning ? const Color(0xFFFFF8E1) : const Color(0xFFE8EAF6);

    final borderColor =
        isMorning ? const Color(0xFFFFB300) : const Color(0xFF3F51B5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(
          color: borderColor,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: ui.TextDirection.rtl,
            children: [
              Icon(
                icon,
                color: iconColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  textDirection: ui.TextDirection.rtl,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'فروش: ${_formatNumber(sales)} $currency',
            textDirection: ui.TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'سود تقریبی: ${_formatNumber(sales * 0.22)} $currency',
            textDirection: ui.TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    return NumberFormat(
      '#,##0',
      'fa_IR',
    ).format(value);
  }
}

// ============================================================================
// BAR PAINTER - RTL
// ============================================================================

class _BarPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  _BarPainter(this.data);

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (data.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    const double bottomLabelSpace = 24;
    const double topValueSpace = 18;
    const double horizontalGap = 8;

    final values = data
        .map(
          (item) => (item['value'] as num).toDouble(),
        )
        .toList();

    final maxValue = values.fold<double>(
      1,
      (max, value) => value > max ? value : max,
    );

    final availableHeight = size.height - bottomLabelSpace - topValueSpace;

    if (availableHeight <= 0) {
      return;
    }

    final count = data.length;

    final barWidth = (size.width - (horizontalGap * (count + 1))) / count;

    if (barWidth <= 0) {
      return;
    }

    final barPaint = Paint();

    const primary = Color(0xFF6750A4);
    const secondary = Color(0xFF8E7CC3);

    for (int i = 0; i < count; i++) {
      final value = values[i];

      final ratio = value <= 0 ? 0.02 : (value / maxValue).clamp(0.02, 1.0);

      final barHeight = availableHeight * ratio;

      // جدیدترین تاریخ در سمت راست
      final rtlIndex = count - 1 - i;

      final left = horizontalGap + rtlIndex * (barWidth + horizontalGap);

      final top = topValueSpace + (availableHeight - barHeight);

      final rect = Rect.fromLTWH(
        left,
        top,
        barWidth,
        barHeight,
      );

      barPaint.shader = const LinearGradient(
        colors: [
          primary,
          secondary,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(6),
        ),
        barPaint,
      );

      // ----------------------------------------------------------------------
      // مقدار
      // ----------------------------------------------------------------------

      final valueText = value >= 1000
          ? '${(value / 1000).toStringAsFixed(
              value >= 10000 ? 0 : 1,
            )}k'
          : value.toStringAsFixed(0);

      final valuePainter = TextPainter(
        text: TextSpan(
          text: valueText,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        textDirection: ui.TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout(
          maxWidth: barWidth + 20,
        );

      valuePainter.paint(
        canvas,
        Offset(
          left + (barWidth - valuePainter.width) / 2,
          top - 15,
        ),
      );

      // ----------------------------------------------------------------------
      // تاریخ
      // ----------------------------------------------------------------------

      final labelPainter = TextPainter(
        text: TextSpan(
          text: data[i]['label'] as String,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.grey,
          ),
        ),
        textDirection: ui.TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout(
          maxWidth: barWidth + 10,
        );

      labelPainter.paint(
        canvas,
        Offset(
          left + (barWidth - labelPainter.width) / 2,
          size.height - labelPainter.height,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _BarPainter oldDelegate,
  ) {
    if (oldDelegate.data.length != data.length) {
      return true;
    }

    for (int i = 0; i < data.length; i++) {
      if (oldDelegate.data[i]['value'] != data[i]['value'] ||
          oldDelegate.data[i]['label'] != data[i]['label']) {
        return true;
      }
    }

    return false;
  }
}
