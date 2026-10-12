// reports_screen_fixed.dart
// نسخه اصلاح‌شده، واکنش‌گرا و پایدار ReportsScreen

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/shamsi_date_utils.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../models/store_transaction.dart';
import '../services/exporter.dart';
import '../viewmodels/main_viewmodel.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // 0 = امروز
  // 1 = هفت روز اخیر
  // 2 = سی روز اخیر
  // 3 = ماه جاری
  int _selectedRange = 0;

  bool _isPrinting = false;
  bool _isExportingExcel = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainViewModel>();
    final config = vm.config;
    final currency = config?.currency ?? 'تومان';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final range = _calculateRange(today);

    final startMillis = range.start.millisecondsSinceEpoch;
    final endExclusiveMillis = range.endExclusive.millisecondsSinceEpoch;

    // فقط فاکتورهای فروش داخل بازه انتخاب‌شده
    final salesTransactions = vm.transactions.where((transaction) {
      return transaction.type == 'SALE' &&
          transaction.dateMillis >= startMillis &&
          transaction.dateMillis < endExclusiveMillis;
    }).toList()
      ..sort(
        (first, second) => second.dateMillis.compareTo(first.dateMillis),
      );

    // هزینه‌های داخل همان بازه
    final expensesInRange = vm.expenses.where((expense) {
      return expense.dateMillis >= startMillis &&
          expense.dateMillis < endExclusiveMillis;
    }).toList();

    final totalSales = salesTransactions.fold<double>(
      0.0,
      (sum, transaction) => sum + transaction.finalAmount.toDouble(),
    );

    final totalDiscount = salesTransactions.fold<double>(
      0.0,
      (sum, transaction) => sum + transaction.discount.toDouble(),
    );

    final totalPaid = salesTransactions.fold<double>(
      0.0,
      (sum, transaction) => sum + transaction.paidAmount.toDouble(),
    );

    final totalSaleDebts = salesTransactions.fold<double>(
      0.0,
      (sum, transaction) => sum + transaction.debtAmount.toDouble(),
    );

    final cashSaleCount = salesTransactions.where((t) => t.paymentMethod.toUpperCase() == 'CASH').length;
    final cardSaleCount = salesTransactions.where((t) => t.paymentMethod.toUpperCase() == 'CARD').length;
    final transferSaleCount = salesTransactions.where((t) => t.paymentMethod.toUpperCase() == 'TRANSFER').length;
    final creditSaleCount = salesTransactions.where((t) => t.paymentMethod.toUpperCase() == 'CREDIT').length;

    final cashSaleAmount = salesTransactions.where((t) => t.paymentMethod.toUpperCase() == 'CASH').fold<double>(0, (s, t) => s + t.paidAmount);
    final cardSaleAmount = salesTransactions.where((t) => t.paymentMethod.toUpperCase() == 'CARD').fold<double>(0, (s, t) => s + t.paidAmount);
    final transferSaleAmount = salesTransactions.where((t) => t.paymentMethod.toUpperCase() == 'TRANSFER').fold<double>(0, (s, t) => s + t.paidAmount);
    final creditSaleAmount = salesTransactions.where((t) => t.paymentMethod.toUpperCase() == 'CREDIT').fold<double>(0, (s, t) => s + t.finalAmount);

    final totalExpenses = expensesInRange.fold<double>(
      0.0,
      (sum, expense) => sum + expense.amount.toDouble(),
    );

    final totalDebts = vm.debtors.fold<double>(
      0.0,
      (sum, contact) => sum + contact.totalDebt.toDouble(),
    );

    final totalPayables = vm.creditors.fold<double>(
      0.0,
      (sum, contact) => sum + contact.totalPayable.toDouble(),
    );

    final averageInvoice =
        salesTransactions.isEmpty ? 0.0 : totalSales / salesTransactions.length;

    final profitCoefficient = (config?.profitCoefficient ?? 0.22).toDouble();

    final estimatedGrossProfit = totalSales * profitCoefficient;
    final estimatedNetProfit = estimatedGrossProfit - totalExpenses;

    final shiftReport = vm.shiftReport(
      startMillis: startMillis,
      // اگر متد shiftReport انتهای بازه را به‌صورت <= بررسی کند،
      // یک میلی‌ثانیه از انتهای انحصاری کم می‌کنیم.
      endMillis: endExclusiveMillis - 1,
      profitCoeff: profitCoefficient,
    );

    final startLabel = faDate(range.start);

    final endLabel = faDate(
      range.endExclusive.subtract(const Duration(days: 1)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'گزارشات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'نمایش گزارش در پنجره',
            onPressed: () => _showDesktopReport(
              vm: vm,
              transactions: salesTransactions,
              currency: currency,
              startLabel: startLabel,
              endLabel: endLabel,
              totalSales: totalSales,
            ),
            icon: const Icon(Icons.desktop_windows_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _ReportHeader(
              currency: currency,
              startLabel: startLabel,
              endLabel: endLabel,
            ),

            const SizedBox(height: 12),

            _buildRangeSelector(),

            const SizedBox(height: 12),

            // گزارش کل فروش
            _ReportSectionCard(
              title: 'گزارش فروش',
              subtitle: '$startLabel تا $endLabel',
              icon: Icons.point_of_sale,
              color: const Color(0xFF2E7D32),
              backgroundColor: const Color(0xFFE8F5E9),
              child: _ResponsiveStats(
                children: [
                  _Stat(
                    label: 'تعداد فاکتور',
                    value: '${salesTransactions.length}',
                    icon: Icons.receipt_long,
                    color: const Color(0xFF2E7D32),
                  ),
                  _Stat(
                    label: 'جمع فروش',
                    value: _formatMoney(totalSales, currency),
                    icon: Icons.attach_money,
                    color: const Color(0xFF2E7D32),
                  ),
                  _Stat(
                    label: 'تخفیف',
                    value: _formatMoney(totalDiscount, currency),
                    icon: Icons.discount_outlined,
                    color: const Color(0xFF6750A4),
                  ),
                  _Stat(
                    label: 'میانگین فاکتور',
                    value: _formatMoney(averageInvoice, currency),
                    icon: Icons.calculate_outlined,
                    color: const Color(0xFF1565C0),
                  ),
                  _Stat(
                    label: 'مبلغ دریافت‌شده',
                    value: _formatMoney(totalPaid, currency),
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF00897B),
                  ),
                  _Stat(
                    label: 'فروش نسیه در بازه',
                    value: _formatMoney(totalSaleDebts, currency),
                    icon: Icons.menu_book_outlined,
                    color: const Color(0xFFC62828),
                  ),
                  _Stat(label: 'تعداد نقدی', value: '$cashSaleCount فاکتور', icon: Icons.payments_outlined, color: const Color(0xFF2E7D32)),
                  _Stat(label: 'تعداد کارتخوان', value: '$cardSaleCount فاکتور', icon: Icons.credit_card, color: const Color(0xFF1565C0)),
                  _Stat(label: 'تعداد کارت به کارت', value: '$transferSaleCount فاکتور', icon: Icons.swap_horiz_rounded, color: const Color(0xFF6A1B9A)),
                  _Stat(label: 'تعداد نسیه / دفتری', value: '$creditSaleCount فاکتور', icon: Icons.menu_book_outlined, color: const Color(0xFFC62828)),
                  _Stat(label: 'مبلغ نقدی', value: _formatMoney(cashSaleAmount, currency), icon: Icons.payments_outlined, color: const Color(0xFF2E7D32)),
                  _Stat(label: 'مبلغ کارتخوان', value: _formatMoney(cardSaleAmount, currency), icon: Icons.credit_card, color: const Color(0xFF1565C0)),
                  _Stat(label: 'مبلغ کارت به کارت', value: _formatMoney(transferSaleAmount, currency), icon: Icons.swap_horiz_rounded, color: const Color(0xFF6A1B9A)),
                  _Stat(label: 'مبلغ نسیه / دفتری', value: _formatMoney(creditSaleAmount, currency), icon: Icons.menu_book_outlined, color: const Color(0xFFC62828)),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // گزارش شیفت‌ها
            _ReportSectionCard(
              title: 'گزارش فروش و سود شیفت‌ها',
              subtitle:
                  'ضریب سود تخمینی: ${(profitCoefficient * 100).toStringAsFixed(0)}٪',
              icon: Icons.schedule,
              color: const Color(0xFF6750A4),
              child: _ResponsiveStats(
                children: [
                  _Stat(
                    label: 'فروش شیفت صبح',
                    value: _formatMoney(
                      shiftReport.morningSales,
                      currency,
                    ),
                    icon: Icons.wb_sunny_outlined,
                    color: const Color(0xFFF57F17),
                  ),
                  _Stat(
                    label: 'سود شیفت صبح',
                    value: _formatMoney(
                      shiftReport.morningProfit,
                      currency,
                    ),
                    icon: Icons.trending_up,
                    color: const Color(0xFFD81B60),
                  ),
                  _Stat(
                    label: 'فروش شیفت عصر',
                    value: _formatMoney(
                      shiftReport.eveningSales,
                      currency,
                    ),
                    icon: Icons.nights_stay_outlined,
                    color: const Color(0xFF3949AB),
                  ),
                  _Stat(
                    label: 'سود شیفت عصر',
                    value: _formatMoney(
                      shiftReport.eveningProfit,
                      currency,
                    ),
                    icon: Icons.trending_up,
                    color: const Color(0xFF7B1FA2),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // گزارش مالی
            _ReportSectionCard(
              title: 'گزارش مالی مفصل',
              subtitle: 'هزینه‌ها بر اساس بازه انتخاب‌شده محاسبه می‌شوند',
              icon: Icons.account_balance_outlined,
              color: const Color(0xFFE65100),
              backgroundColor: const Color(0xFFFFF3E0),
              child: _ResponsiveStats(
                children: [
                  _Stat(
                    label: 'هزینه‌های بازه',
                    value: _formatMoney(totalExpenses, currency),
                    icon: Icons.receipt_long,
                    color: const Color(0xFFE65100),
                  ),
                  _Stat(
                    label: 'کل طلب‌های فروشگاه',
                    value: _formatMoney(totalDebts, currency),
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFFC2185B),
                  ),
                  _Stat(
                    label: 'کل بدهی‌های فروشگاه',
                    value: _formatMoney(totalPayables, currency),
                    icon: Icons.money_off,
                    color: const Color(0xFFAD1457),
                  ),
                  _Stat(
                    label: 'کالاهای کم‌موجودی',
                    value: '${vm.lowStockProducts.length}',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.red,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // سود و زیان
            _ProfitLossCard(
              currency: currency,
              totalSales: totalSales,
              totalExpenses: totalExpenses,
              profitCoefficient: profitCoefficient,
              estimatedGrossProfit: estimatedGrossProfit,
              estimatedNetProfit: estimatedNetProfit,
            ),

            const SizedBox(height: 12),

            // فاکتورهای اخیر در بازه
            _TransactionsPreview(
              transactions: salesTransactions,
              currency: currency,
            ),

            const SizedBox(height: 16),

            _buildExportButtons(
              vm: vm,
              transactions: salesTransactions,
              currency: currency,
              startLabel: startLabel,
              endLabel: endLabel,
              totalSales: totalSales,
              totalExpenses: totalExpenses,
              totalDebts: totalDebts,
              totalPayables: totalPayables,
              profitCoefficient: profitCoefficient,
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: () => _showDesktopReport(
                vm: vm,
                transactions: salesTransactions,
                currency: currency,
                startLabel: startLabel,
                endLabel: endLabel,
                totalSales: totalSales,
              ),
              icon: const Icon(Icons.desktop_windows),
              label: const Text(
                'نمایش گزارش در پنجره بزرگ',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // انتخاب بازه زمانی
  // --------------------------------------------------------------------------

  Widget _buildRangeSelector() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.date_range_outlined),
                SizedBox(width: 8),
                Text(
                  'انتخاب بازه گزارش',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('امروز'),
                  selected: _selectedRange == 0,
                  onSelected: (_) {
                    setState(() {
                      _selectedRange = 0;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('۷ روز اخیر'),
                  selected: _selectedRange == 1,
                  onSelected: (_) {
                    setState(() {
                      _selectedRange = 1;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('۳۰ روز اخیر'),
                  selected: _selectedRange == 2,
                  onSelected: (_) {
                    setState(() {
                      _selectedRange = 2;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('ماه جاری'),
                  selected: _selectedRange == 3,
                  onSelected: (_) {
                    setState(() {
                      _selectedRange = 3;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // دکمه‌های خروجی
  // --------------------------------------------------------------------------

  Widget _buildExportButtons({
    required MainViewModel vm,
    required List<StoreTransaction> transactions,
    required String currency,
    required String startLabel,
    required String endLabel,
    required double totalSales,
    required double totalExpenses,
    required double totalDebts,
    required double totalPayables,
    required double profitCoefficient,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 550;

        final pdfButton = ElevatedButton.icon(
          onPressed: _isPrinting
              ? null
              : () => _printFullReport(
                    vm: vm,
                    transactions: transactions,
                    currency: currency,
                    startLabel: startLabel,
                    endLabel: endLabel,
                    totalSales: totalSales,
                    totalExpenses: totalExpenses,
                    totalDebts: totalDebts,
                    totalPayables: totalPayables,
                    profitCoefficient: profitCoefficient,
                  ),
          icon: _isPrinting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.picture_as_pdf),
          label: Text(
            _isPrinting ? 'در حال آماده‌سازی...' : 'چاپ / PDF گزارش',
          ),
        );

        final csvButton = OutlinedButton.icon(
          onPressed: transactions.isEmpty || _isExportingExcel
              ? null
              : () => _exportSalesExcel(
                    vm: vm,
                    transactions: transactions,
                    currency: currency,
                    startLabel: startLabel,
                    endLabel: endLabel,
                  ),
          icon: _isExportingExcel
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.table_chart),
          label: Text(
            _isExportingExcel ? 'در حال خروجی...' : 'خروجی Excel فروش',
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 48, child: pdfButton),
              const SizedBox(height: 8),
              SizedBox(height: 48, child: csvButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: pdfButton,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 48,
                child: csvButton,
              ),
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // چاپ گزارش کامل
  // --------------------------------------------------------------------------

  Future<void> _printFullReport({
    required MainViewModel vm,
    required List<StoreTransaction> transactions,
    required String currency,
    required String startLabel,
    required String endLabel,
    required double totalSales,
    required double totalExpenses,
    required double totalDebts,
    required double totalPayables,
    required double profitCoefficient,
  }) async {
    if (_isPrinting) {
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    try {
      final file = await Exporter.exportTableToPdf(
        filenamePrefix: 'گزارش_کل_${startLabel.replaceAll('/', '_')}',
        title: 'گزارش مدیریتی و مالی',
        storeName: vm.config?.storeName ?? 'فروشگاه',
        subtitle: '$startLabel تا $endLabel | فروش: ${_formatMoney(totalSales, currency)} | هزینه: ${_formatMoney(totalExpenses, currency)} | سود ضریب‌محور: ${(profitCoefficient * 100).toStringAsFixed(0)}٪',
        headers: const ['شناسه','تاریخ','مشتری','مبلغ نهایی','پرداختی','بدهی','ثبت توسط'],
        rows: transactions.map((transaction) => [
          transaction.id.toString(),
          _formatDateTime(transaction.dateMillis),
          transaction.contactName.trim().isEmpty ? 'مشتری حضوری' : transaction.contactName,
          _formatMoney(transaction.finalAmount, currency),
          _formatMoney(transaction.paidAmount, currency),
          _formatMoney(transaction.debtAmount, currency),
          transaction.userName,
        ]).toList(),
      );
      if (file == null) throw Exception('ساخت گزارش PDF انجام نشد.');

      final printed = await Exporter.printPdfFile(
        file,
        jobName: 'گزارش_مدیریتی_${startLabel.replaceAll('/', '_')}',
      );
      if (!printed) {
        await Exporter.openExportFile(file.path);
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        printed
            ? 'گزارش مستقیماً برای چاپ ارسال شد.'
            : 'PDF گزارش ساخته شد، اما چاپگر در دسترس نبود.',
        backgroundColor: printed ? null : Colors.orange,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'خطا در ایجاد گزارش: $error',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  // --------------------------------------------------------------------------
  // خروجی CSV
  // --------------------------------------------------------------------------

  Future<void> _exportSalesExcel({
    required MainViewModel vm,
    required List<StoreTransaction> transactions,
    required String currency,
    required String startLabel,
    required String endLabel,
  }) async {
    if (_isExportingExcel) return;
    setState(() => _isExportingExcel = true);
    try {
      final file = await Exporter.exportExcel(
        filenamePrefix: 'گزارش_فروش_${startLabel.replaceAll('/', '_')}_${endLabel.replaceAll('/', '_')}',
        sheetName: 'فروش',
        title: 'گزارش فروش',
        storeName: vm.config?.storeName,
        headers: [
          'شناسه','تاریخ','مشتری','مبلغ اولیه ($currency)','تخفیف ($currency)',
          'مبلغ نهایی ($currency)','پرداختی ($currency)','بدهی ($currency)','روش پرداخت','ثبت توسط',
        ],
        rows: transactions.map((transaction) => [
          transaction.id,
          _formatDateTime(transaction.dateMillis),
          transaction.contactName.trim().isEmpty ? 'مشتری حضوری' : transaction.contactName,
          transaction.totalAmount,
          transaction.discount,
          transaction.finalAmount,
          transaction.paidAmount,
          transaction.debtAmount,
          _paymentMethodLabel(transaction.paymentMethod),
          transaction.userName,
        ]).toList(),
      );
      if (!mounted) return;
      if (file == null) {
        _showMessage('فایل Excel ایجاد نشد.', backgroundColor: Colors.orange);
      } else {
        _showMessage('خروجی Excel ایجاد شد: ${file.path.replaceAll('\\', '/').split('/').last}');
      }
    } catch (error) {
      if (mounted) _showMessage('خطا در ایجاد Excel: $error', backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isExportingExcel = false);
    }
  }

  // --------------------------------------------------------------------------
  // نمایش پنجره گزارش
  // --------------------------------------------------------------------------

  Future<void> _showDesktopReport({
    required MainViewModel vm,
    required List<StoreTransaction> transactions,
    required String currency,
    required String startLabel,
    required String endLabel,
    required double totalSales,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screenSize = MediaQuery.sizeOf(dialogContext);

        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 900,
              maxHeight: screenSize.height * 0.9,
            ),
            child: _DesktopReportWindow(
              storeName: vm.config?.storeName ?? 'فروشگاه',
              transactions: transactions,
              currency: currency,
              startLabel: startLabel,
              endLabel: endLabel,
              totalSales: totalSales,
              onClose: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ),
        );
      },
    );
  }

  _DateRange _calculateRange(DateTime today) {
    late DateTime start;

    switch (_selectedRange) {
      case 1:
        start = today.subtract(const Duration(days: 6));
        break;

      case 2:
        start = today.subtract(const Duration(days: 29));
        break;

      case 3:
        final todayJalali = Jalali.fromDateTime(today);
        start = Jalali(todayJalali.year, todayJalali.month, 1).toDateTime();
        break;

      case 0:
      default:
        start = today;
        break;
    }

    return _DateRange(
      start: start,
      endExclusive: today.add(const Duration(days: 1)),
    );
  }

  void _showMessage(
    String message, {
    Color? backgroundColor,
  }) {
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
        ),
      );
  }
}

// ============================================================================
// مدل بازه تاریخ
// ============================================================================

class _DateRange {
  final DateTime start;
  final DateTime endExclusive;

  const _DateRange({
    required this.start,
    required this.endExclusive,
  });
}

// ============================================================================
// سربرگ گزارش
// ============================================================================

class _ReportHeader extends StatelessWidget {
  final String currency;
  final String startLabel;
  final String endLabel;

  const _ReportHeader({
    required this.currency,
    required this.startLabel,
    required this.endLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.analytics_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'گزارشات مدیریتی و مالی',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'بازه: $startLabel تا $endLabel | واحد پول: $currency',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// کارت هر بخش گزارش
// ============================================================================

class _ReportSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final Widget child;

  const _ReportSectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.subtitle,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withAlpha(25),
                  foregroundColor: color,
                  child: Icon(icon, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: color,
                        ),
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// شبکه واکنش‌گرای آمار
// ============================================================================

class _ResponsiveStats extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveStats({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columnCount;

        if (constraints.maxWidth >= 900) {
          columnCount = 4;
        } else if (constraints.maxWidth >= 550) {
          columnCount = 2;
        } else {
          columnCount = 1;
        }

        const spacing = 8.0;

        final itemWidth = columnCount == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing * (columnCount - 1)) /
                columnCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children.map((child) {
            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}

// ============================================================================
// آیتم آماری
// ============================================================================

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: effectiveColor.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: effectiveColor.withAlpha(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: effectiveColor,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: effectiveColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// کارت سود و زیان
// ============================================================================

class _ProfitLossCard extends StatelessWidget {
  final String currency;
  final double totalSales;
  final double totalExpenses;
  final double profitCoefficient;
  final double estimatedGrossProfit;
  final double estimatedNetProfit;

  const _ProfitLossCard({
    required this.currency,
    required this.totalSales,
    required this.totalExpenses,
    required this.profitCoefficient,
    required this.estimatedGrossProfit,
    required this.estimatedNetProfit,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = estimatedNetProfit >= 0;
    final resultColor = isProfit ? const Color(0xFF2E7D32) : Colors.red;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up),
                SizedBox(width: 8),
                Text(
                  'سود و زیان تخمینی',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ProfitLossLine(
              label: 'فروش کل',
              value: _formatMoney(totalSales, currency),
            ),
            _ProfitLossLine(
              label:
                  'سود تخمینی با ضریب ${(profitCoefficient * 100).toStringAsFixed(0)}٪',
              value: _formatMoney(
                estimatedGrossProfit,
                currency,
              ),
              color: const Color(0xFF2E7D32),
            ),
            _ProfitLossLine(
              label: 'هزینه‌های بازه',
              value: '-${_formatMoney(totalExpenses, currency)}',
              color: Colors.red,
            ),
            const Divider(height: 24),
            _ProfitLossLine(
              label: isProfit ? 'سود خالص برآوردی' : 'زیان خالص برآوردی',
              value: _formatMoney(
                estimatedNetProfit.abs(),
                currency,
              ),
              color: resultColor,
              bold: true,
            ),
            const SizedBox(height: 10),
            Text(
              'توجه: این مبلغ با ضریب سود تنظیم‌شده محاسبه شده است و '
              'در صورت ثبت قیمت خرید اقلام، سود واقعی می‌تواند متفاوت باشد.',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfitLossLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  const _ProfitLossLine({
    required this.label,
    required this.value,
    this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                fontSize: bold ? 14 : 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: bold ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// پیش‌نمایش فاکتورها
// ============================================================================

class _TransactionsPreview extends StatelessWidget {
  final List<StoreTransaction> transactions;
  final String currency;

  const _TransactionsPreview({
    required this.transactions,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'آخرین فاکتورهای بازه انتخاب‌شده',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  '${transactions.length} فاکتور',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 25),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 45,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'در این بازه فاکتور فروشی ثبت نشده است.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ...transactions.take(5).map((transaction) {
                final customer = transaction.contactName.trim().isEmpty
                    ? 'مشتری حضوری'
                    : transaction.contactName.trim();

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: const Icon(Icons.receipt_outlined),
                  ),
                  title: Text(
                    'فاکتور #${transaction.id} - $customer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    _formatDateTime(transaction.dateMillis),
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Text(
                    _formatMoney(
                      transaction.finalAmount,
                      currency,
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// پنجره بزرگ گزارش
// ============================================================================

class _DesktopReportWindow extends StatelessWidget {
  final String storeName;
  final List<StoreTransaction> transactions;
  final String currency;
  final String startLabel;
  final String endLabel;
  final double totalSales;
  final VoidCallback onClose;

  const _DesktopReportWindow({
    required this.storeName,
    required this.transactions,
    required this.currency,
    required this.startLabel,
    required this.endLabel,
    required this.totalSales,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نمایش کامل گزارش'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'بستن',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              storeName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'گزارش فروش از $startLabel تا $endLabel',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 30,
                runSpacing: 10,
                children: [
                  Text(
                    'تعداد فاکتورها: ${transactions.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'جمع فروش: ${_formatMoney(totalSales, currency)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            Expanded(
              child: transactions.isEmpty
                  ? const Center(
                      child: Text(
                        'فاکتوری در این بازه وجود ندارد.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: transactions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];

                        final customer = transaction.contactName.trim().isEmpty
                            ? 'مشتری حضوری'
                            : transaction.contactName.trim();

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          title: Text(
                            'فاکتور #${transaction.id} - $customer',
                          ),
                          subtitle: Text(
                            '${_formatDateTime(transaction.dateMillis)}'
                            ' | ${_paymentMethodLabel(transaction.paymentMethod)}',
                          ),
                          trailing: Text(
                            _formatMoney(
                              transaction.finalAmount,
                              currency,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// توابع کمکی
// ============================================================================

String _formatMoney(num value, String currency) {
  final formatted = NumberFormat('#,##0', 'en_US').format(value);

  return currency.trim().isEmpty ? formatted : '$formatted $currency';
}

String _formatDateTime(int dateMillis) {
  return faDateTime(
    DateTime.fromMillisecondsSinceEpoch(dateMillis),
  );
}

String _paymentMethodLabel(String method) {
  switch (method.toUpperCase()) {
    case 'CASH':
      return 'نقدی';

    case 'CARD':
      return 'کارتخوان';

    case 'CREDIT':
      return 'نسیه / دفتری';

    case 'TRANSFER':
      return 'کارت به کارت';

    case 'MIXED':
      return 'ترکیبی';

    default:
      return method.trim().isEmpty ? 'نامشخص' : method;
  }
}
