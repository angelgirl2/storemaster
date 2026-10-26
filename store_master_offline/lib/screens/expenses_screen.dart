// expenses_screen_fixed.dart
// نسخه اصلاح‌شده ExpensesScreen — بدون خطا و قابل اجرا

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/shamsi_date_utils.dart';

import '../models/expense.dart';
import '../services/exporter.dart';
import '../viewmodels/main_viewmodel.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({Key? key}) : super(key: key);

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  int _selectedTab = 0;
  String _searchQuery = '';
  bool _isExporting = false;
  bool _isPrinting = false;

  static const List<String> _expenseCategories = [
    'مالیات',
    'اجاره',
    'قبوض',
    'تعمیر',
    'دستمزد',
    'خرید کالا',
    'حمل',
    'لوازم مصرفی',
    'تبلیغات',
    'مشاوره',
    'بیمه',
    'سایر',
  ];

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainViewModel>();
    final currency = vm.config?.currency ?? 'تومان';

    // ایجاد کپی برای جلوگیری از تغییر مستقیم لیست ViewModel
    final expenses = vm.expenses.toList()
      ..sort((a, b) => b.dateMillis.compareTo(a.dateMillis));

    final totalExpenses = expenses.fold<double>(
      0.0,
      (sum, expense) => sum + expense.amount.toDouble(),
    );

    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;

    final tomorrowStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1)).millisecondsSinceEpoch;

    final todayExpenses = expenses.fold<double>(
      0.0,
      (sum, expense) {
        if (expense.dateMillis >= todayStart &&
            expense.dateMillis < tomorrowStart) {
          return sum + expense.amount.toDouble();
        }

        return sum;
      },
    );

    final taxCount = expenses
        .where(
          (expense) => expense.category == 'مالیات',
        )
        .length;

    final normalizedQuery = _searchQuery.trim().toLowerCase();

    final filteredExpenses = expenses.where((expense) {
      if (_selectedTab == 1 && expense.category != 'مالیات') {
        return false;
      }

      if (normalizedQuery.isEmpty) {
        return true;
      }

      final searchableText = [
        expense.title,
        expense.category,
        expense.note,
        expense.userName,
        expense.amount.toString(),
      ].join(' ').toLowerCase();

      return searchableText.contains(normalizedQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ثبت هزینه‌ها'),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'ثبت هزینه جدید',
        onPressed: () => _openExpenseForm(
          vm: vm,
          currency: currency,
        ),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // در صورت وجود متد بارگذاری مجدد در ViewModel می‌توانید
                  // آن را در این قسمت فراخوانی کنید.
                  await Future<void>.delayed(
                    const Duration(milliseconds: 300),
                  );
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _buildHeader(
                      context: context,
                      vm: vm,
                      expenses: expenses,
                      total: totalExpenses,
                      currency: currency,
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryCards(
                      context: context,
                      todayExpenses: todayExpenses,
                      totalExpenses: totalExpenses,
                      expenseCount: expenses.length,
                      currency: currency,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'جستجو در هزینه‌ها',
                        hintText: 'عنوان، دسته، توضیحات یا نام ثبت‌کننده...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'پاک کردن جستجو',
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                icon: const Icon(Icons.clear),
                              ),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildFilters(
                      context: context,
                      vm: vm,
                      allCount: expenses.length,
                      taxCount: taxCount,
                    ),
                    const SizedBox(height: 12),
                    if (filteredExpenses.isEmpty)
                      _EmptyExpensesView(
                        hasSearch: normalizedQuery.isNotEmpty,
                        isTaxFilter: _selectedTab == 1,
                        onAddPressed: () => _openExpenseForm(
                          vm: vm,
                          currency: currency,
                        ),
                      )
                    else
                      ...filteredExpenses.map(
                        (expense) => _ExpenseCard(
                          expense: expense,
                          currency: currency,
                          onEdit: () => _openExpenseForm(
                            vm: vm,
                            currency: currency,
                            existingExpense: expense,
                          ),
                          onDelete: () => _confirmDeleteExpense(
                            vm: vm,
                            expense: expense,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({
    required BuildContext context,
    required MainViewModel vm,
    required List<Expense> expenses,
    required double total,
    required String currency,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;

        final title = const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هزینه‌های فروشگاه',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'ثبت کلیه هزینه‌های فروشگاه با دسته‌بندی استاندارد مالی',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        );

        final buttons = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: expenses.isEmpty || _isExporting
                  ? null
                  : () => _exportCsv(
                        vm: vm,
                        expenses: expenses,
                        currency: currency,
                      ),
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.table_chart,
                      size: 18,
                    ),
              label: const Text('خروجی اکسل'),
            ),
            ElevatedButton.icon(
              onPressed: expenses.isEmpty || _isPrinting
                  ? null
                  : () => _printExpenses(
                        vm: vm,
                        expenses: expenses,
                        total: total,
                        currency: currency,
                      ),
              icon: _isPrinting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.picture_as_pdf,
                      size: 18,
                    ),
              label: const Text('چاپ PDF'),
            ),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: buttons,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            buttons,
          ],
        );
      },
    );
  }

  Widget _buildSummaryCards({
    required BuildContext context,
    required double todayExpenses,
    required double totalExpenses,
    required int expenseCount,
    required String currency,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 480;

        final todayCard = _SummaryCard(
          title: 'هزینه‌های امروز',
          value: _formatMoney(todayExpenses, currency),
          icon: Icons.today,
          foregroundColor: const Color(0xFF3949AB),
          backgroundColor: const Color(0xFFE8EAF6),
        );

        final totalCard = _SummaryCard(
          title: 'کل هزینه‌ها ($expenseCount مورد)',
          value: _formatMoney(totalExpenses, currency),
          icon: Icons.payments_outlined,
          foregroundColor: Theme.of(context).colorScheme.primary,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
        );

        if (isNarrow) {
          return Column(
            children: [
              todayCard,
              const SizedBox(height: 8),
              totalCard,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: todayCard),
            const SizedBox(width: 8),
            Expanded(child: totalCard),
          ],
        );
      },
    );
  }

  Widget _buildFilters({
    required BuildContext context,
    required MainViewModel vm,
    required int allCount,
    required int taxCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: SizedBox(
              width: double.infinity,
              child: Text(
                'همه ($allCount)',
                textAlign: TextAlign.center,
              ),
            ),
            selected: _selectedTab == 0,
            onSelected: (_) {
              setState(() {
                _selectedTab = 0;
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ChoiceChip(
            label: SizedBox(
              width: double.infinity,
              child: Text(
                'مالیات ($taxCount)',
                textAlign: TextAlign.center,
              ),
            ),
            selected: _selectedTab == 1,
            onSelected: (_) {
              setState(() {
                _selectedTab = 1;
              });
            },
          ),
        ),
        if (allCount > 0) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'پاکسازی همه هزینه‌ها',
            onPressed: () => _confirmClearAll(vm),
            icon: const Icon(
              Icons.delete_sweep,
              color: Colors.red,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openExpenseForm({
    required MainViewModel vm,
    required String currency,
    Expense? existingExpense,
  }) async {
    final result = await showDialog<Expense>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ExpenseFormDialog(
          categories: _expenseCategories,
          existing: existingExpense,
          currency: currency,
          currentUserId: existingExpense?.userId ?? 0,
          currentUserName:
              existingExpense?.userName ?? vm.currentUser?.name ?? '',
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    try {
      vm.saveExpense(result);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingExpense == null
                ? 'هزینه با موفقیت ثبت شد.'
                : 'هزینه با موفقیت ویرایش شد.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در ذخیره هزینه: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteExpense({
    required MainViewModel vm,
    required Expense expense,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('حذف هزینه'),
              content: Text(
                'هزینه «${expense.title}» از گزارش‌ها و جمع کل حذف شود؟',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('انصراف'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('حذف'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    try {
      vm.deleteExpense(expense.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هزینه حذف شد.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در حذف هزینه: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmClearAll(MainViewModel vm) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              icon: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 42,
              ),
              title: const Text('پاکسازی همه هزینه‌ها'),
              content: const Text(
                'آیا از حذف همه هزینه‌های فروشگاه مطمئن هستید؟ '
                'این عملیات غیرقابل بازگشت است.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('انصراف'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('پاکسازی کلی'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    try {
      vm.clearAllExpenses();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedTab = 0;
        _searchQuery = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('همه هزینه‌ها پاکسازی شدند.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در پاکسازی هزینه‌ها: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportCsv({
    required MainViewModel vm,
    required List<Expense> expenses,
    required String currency,
  }) async {
    if (_isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final file = await Exporter.exportExcel(
        filenamePrefix: 'لیست_هزینه_های_فروشگاه',
        sheetName: 'هزینه‌ها',
        title: 'لیست هزینه‌های فروشگاه',
        storeName: vm.config?.storeName,
        headers: [
          'شناسه',
          'تاریخ',
          'دسته',
          'عنوان',
          'مبلغ ($currency)',
          'توضیحات',
          'ثبت توسط',
        ],
        rows: expenses
            .map((expense) => [
                  expense.id,
                  _formatDate(expense.dateMillis),
                  expense.category,
                  expense.title,
                  expense.amount,
                  expense.note,
                  expense.userName,
                ])
            .toList(),
      );

      if (!mounted) {
        return;
      }

      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خروجی Excel ایجاد نشد.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final normalizedPath = file.path.replaceAll('\\', '/');
      final fileName = normalizedPath.split('/').last;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خروجی Excel ایجاد شد: $fileName'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در ایجاد خروجی CSV: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _printExpenses({
    required MainViewModel vm,
    required List<Expense> expenses,
    required double total,
    required String currency,
  }) async {
    if (_isPrinting) {
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    try {
      final file = await Exporter.exportTableToPdf(
        filenamePrefix: 'گزارش_هزینه_های_فروشگاه',
        title: 'گزارش هزینه‌های فروشگاه',
        storeName: vm.config?.storeName ?? 'فروشگاه',
        headers: const [
          'تاریخ',
          'دسته',
          'عنوان',
          'مبلغ',
          'توضیحات',
          'ثبت توسط'
        ],
        rows: expenses
            .map((expense) => [
                  _formatDate(expense.dateMillis),
                  expense.category,
                  expense.title,
                  '${NumberFormat('#,##0', 'fa_IR').format(expense.amount)} $currency',
                  expense.note,
                  expense.userName,
                ])
            .toList(),
        subtitle:
            'مجموع هزینه: ${NumberFormat('#,##0', 'fa_IR').format(total)} $currency',
      );
      if (file == null) throw Exception('ساخت PDF انجام نشد.');

      final printed = await Exporter.printPdfFile(
        file,
        jobName: 'گزارش_هزینه_های_فروشگاه',
      );
      if (!printed) {
        await Exporter.openExportFile(file.path);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              printed
                  ? 'گزارش هزینه‌ها مستقیماً برای چاپ ارسال شد.'
                  : 'PDF گزارش ساخته شد، اما چاپگر در دسترس نبود.',
            ),
            backgroundColor: printed ? null : Colors.orange,
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در چاپ گزارش: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  String _formatMoney(num value, String currency) {
    final formatted = NumberFormat(
      '#,##0',
      'fa_IR',
    ).format(value);

    return '$formatted $currency';
  }

  String _formatDate(int milliseconds) {
    return faDateTime(
      DateTime.fromMillisecondsSinceEpoch(milliseconds),
    );
  }
}

// --------------------------------------------------
// کارت خلاصه
// --------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: foregroundColor.withAlpha(28),
              foregroundColor: foregroundColor,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: foregroundColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: foregroundColor,
                    ),
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

// --------------------------------------------------
// کارت نمایش هزینه
// --------------------------------------------------

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseCard({
    required this.expense,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final formattedAmount = NumberFormat(
      '#,##0',
      'fa_IR',
    ).format(expense.amount);

    final formattedDate = faDateTimeMillis(expense.dateMillis);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    _categoryIcon(expense.category),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          expense.category,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$formattedAmount $currency',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (expense.note.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                expense.note,
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
            ],
            const Divider(height: 22),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 15,
                  color: Colors.grey,
                ),
                const SizedBox(width: 5),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                if (expense.userName.trim().isNotEmpty) ...[
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.person_outline,
                    size: 15,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      expense.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                IconButton(
                  tooltip: 'ویرایش',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Colors.blue,
                    size: 21,
                  ),
                ),
                IconButton(
                  tooltip: 'حذف',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 21,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'مالیات':
        return Icons.account_balance;
      case 'اجاره':
        return Icons.home_work_outlined;
      case 'قبوض':
        return Icons.receipt_long;
      case 'تعمیر':
        return Icons.build_outlined;
      case 'دستمزد':
        return Icons.people_outline;
      case 'خرید کالا':
        return Icons.shopping_cart_outlined;
      case 'حمل':
        return Icons.local_shipping_outlined;
      case 'لوازم مصرفی':
        return Icons.inventory_2_outlined;
      case 'تبلیغات':
        return Icons.campaign_outlined;
      case 'مشاوره':
        return Icons.support_agent;
      case 'بیمه':
        return Icons.health_and_safety_outlined;
      default:
        return Icons.payments_outlined;
    }
  }
}

// --------------------------------------------------
// حالت خالی
// --------------------------------------------------

class _EmptyExpensesView extends StatelessWidget {
  final bool hasSearch;
  final bool isTaxFilter;
  final VoidCallback onAddPressed;

  const _EmptyExpensesView({
    required this.hasSearch,
    required this.isTaxFilter,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    String message;

    if (hasSearch) {
      message = 'هزینه‌ای مطابق عبارت جستجو پیدا نشد.';
    } else if (isTaxFilter) {
      message = 'هیچ هزینه‌ای در دسته مالیات ثبت نشده است.';
    } else {
      message = 'هنوز هیچ هزینه‌ای ثبت نشده است.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 55,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            hasSearch ? Icons.search_off : Icons.receipt_long_outlined,
            size: 58,
            color: Colors.grey,
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          if (!hasSearch && !isTaxFilter) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add),
              label: const Text('ثبت اولین هزینه'),
            ),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------
// دیالوگ افزودن و ویرایش هزینه
// --------------------------------------------------

class _ExpenseFormDialog extends StatefulWidget {
  final List<String> categories;
  final Expense? existing;
  final String currency;
  final int currentUserId;
  final String currentUserName;

  const _ExpenseFormDialog({
    required this.categories,
    required this.currency,
    required this.currentUserId,
    required this.currentUserName,
    this.existing,
    Key? key,
  }) : super(key: key);

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  late String _selectedCategory;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );

    _amountController = TextEditingController(
      text: widget.existing == null
          ? ''
          : widget.existing!.amount.toStringAsFixed(0),
    );

    _descriptionController = TextEditingController(
      text: widget.existing?.note ?? '',
    );

    final existingCategory = widget.existing?.category;

    if (existingCategory != null &&
        widget.categories.contains(existingCategory)) {
      _selectedCategory = existingCategory;
    } else {
      _selectedCategory = widget.categories.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.existing == null ? Icons.add_card : Icons.edit_note,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.existing == null ? 'ثبت هزینه جدید' : 'ویرایش هزینه',
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 430,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  autofocus: widget.existing == null,
                  textInputAction: TextInputAction.next,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'عنوان هزینه',
                    hintText: 'مثال: قبض برق فروشگاه',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'عنوان هزینه را وارد کنید.';
                    }

                    if (value.trim().length < 2) {
                      return 'عنوان هزینه بسیار کوتاه است.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  textInputAction: TextInputAction.next,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9۰-۹٠-٩.,]'),
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: 'مبلغ (${widget.currency})',
                    hintText: 'مثال: 1,500,000',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final amount = _parseAmount(value ?? '');

                    if (amount == null) {
                      return 'مبلغ معتبر وارد کنید.';
                    }

                    if (amount <= 0) {
                      return 'مبلغ باید بیشتر از صفر باشد.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'دسته‌بندی',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: widget.categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _selectedCategory = value;
                          });
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  textInputAction: TextInputAction.newline,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'توضیحات',
                    hintText: 'توضیحات تکمیلی هزینه، در صورت نیاز',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('انصراف'),
        ),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save),
          label: const Text('ذخیره'),
        ),
      ],
    );
  }

  void _submit() {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final amount = _parseAmount(_amountController.text);

    if (amount == null || amount <= 0) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final existing = widget.existing;

    final expense = Expense(
      id: existing?.id ?? 0,
      title: _titleController.text.trim(),
      amount: amount,
      category: _selectedCategory,
      note: _descriptionController.text.trim(),
      dateMillis: existing?.dateMillis ?? DateTime.now().millisecondsSinceEpoch,
      userId: existing?.userId ?? widget.currentUserId,
      userName: existing?.userName ?? widget.currentUserName,
    );

    Navigator.of(context).pop(expense);
  }

  double? _parseAmount(String input) {
    var normalized = input.trim();

    if (normalized.isEmpty) {
      return null;
    }

    normalized = _convertPersianAndArabicDigits(normalized);
    normalized = normalized.replaceAll(',', '');
    normalized = normalized.replaceAll('٬', '');
    normalized = normalized.replaceAll('٫', '.');
    normalized = normalized.replaceAll(' ', '');

    return double.tryParse(normalized);
  }

  String _convertPersianAndArabicDigits(String input) {
    const persianDigits = [
      '۰',
      '۱',
      '۲',
      '۳',
      '۴',
      '۵',
      '۶',
      '۷',
      '۸',
      '۹',
    ];

    const arabicDigits = [
      '٠',
      '١',
      '٢',
      '٣',
      '٤',
      '٥',
      '٦',
      '٧',
      '٨',
      '٩',
    ];

    var result = input;

    for (int index = 0; index < 10; index++) {
      result = result.replaceAll(
        persianDigits[index],
        index.toString(),
      );

      result = result.replaceAll(
        arabicDigits[index],
        index.toString(),
      );
    }

    return result;
  }
}
