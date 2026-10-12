// logs_screen_fixed.dart
// ============================================================================
// LogsScreen - نسخه اصلاح‌شده و پایدار
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/shamsi_date_utils.dart';

import '../viewmodels/main_viewmodel.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({Key? key}) : super(key: key);

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isExporting = false;
  bool _isClearing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainViewModel>();

    // ایجاد کپی برای جلوگیری از تغییر مستقیم لیست ViewModel
    final logs = vm.auditLogs.toList()
      ..sort(
        (first, second) => second.timestamp.compareTo(first.timestamp),
      );

    final normalizedQuery = _searchQuery.trim().toLowerCase();

    final filteredLogs = logs.where((log) {
      if (normalizedQuery.isEmpty) {
        return true;
      }

      final searchableText = [
        log.action,
        log.details,
        log.userName,
        _formatDate(log.timestamp),
      ].join(' ').toLowerCase();

      return searchableText.contains(normalizedQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('لاگ سیستم و فعالیت‌ها'),
        actions: [
          IconButton(
            tooltip: 'خروجی CSV',
            onPressed:
                logs.isEmpty || _isExporting ? null : () => _exportLogs(vm),
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.download_outlined),
          ),
          if (logs.isNotEmpty)
            IconButton(
              tooltip: 'حذف همه لاگ‌ها',
              onPressed: _isClearing ? null : () => _confirmClearAll(vm),
              icon: _isClearing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: _LogsSummary(
                totalCount: logs.length,
                filteredCount: filteredLogs.length,
                hasSearch: normalizedQuery.isNotEmpty,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 500;

                  final searchField = TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'جست‌وجو در رخدادها',
                      hintText: 'عملیات، توضیحات، نام کاربر یا تاریخ...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'پاک کردن جست‌وجو',
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.clear),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  );

                  final exportButton = OutlinedButton.icon(
                    onPressed: logs.isEmpty || _isExporting
                        ? null
                        : () => _exportLogs(vm),
                    icon: _isExporting
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.upload_file,
                            size: 19,
                          ),
                    label: Text(
                      _isExporting ? 'در حال خروجی...' : 'خروجی CSV',
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 8),
                        exportButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 8),
                      exportButton,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filteredLogs.isEmpty
                  ? _EmptyLogsView(
                      hasSearch: normalizedQuery.isNotEmpty,
                      onClearSearch: _clearSearch,
                    )
                  : Scrollbar(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          12,
                          4,
                          12,
                          24,
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];

                          return _LogCard(
                            action: log.action,
                            details: log.details,
                            userName: log.userName,
                            timestamp: log.timestamp,
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // خروجی CSV
  // --------------------------------------------------------------------------

  Future<void> _exportLogs(MainViewModel vm) async {
    if (_isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      await vm.exportLogsCsv();

      if (!mounted) {
        return;
      }

      _showMessage(
        'خروجی CSV لاگ‌ها با موفقیت تهیه شد.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'خطا در تهیه خروجی لاگ‌ها: $error',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  // --------------------------------------------------------------------------
  // حذف همه لاگ‌ها
  // --------------------------------------------------------------------------

  Future<void> _confirmClearAll(MainViewModel vm) async {
    if (_isClearing || vm.auditLogs.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              icon: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 44,
              ),
              title: const Text(
                'حذف همه رخدادها و لاگ‌ها',
              ),
              content: const Text(
                'آیا از حذف کامل همه رخدادها و لاگ‌های سیستم '
                'مطمئن هستید؟ این عملیات غیرقابل بازگشت است.',
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
                  label: const Text('حذف کلی'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isClearing = true;
    });

    try {
      // این متد مطابق کد اصلی به‌صورت هم‌زمان فراخوانی می‌شود.
      vm.clearAllLogs();

      if (!mounted) {
        return;
      }

      _clearSearch();

      _showMessage(
        'همه رخدادها و لاگ‌ها حذف شدند.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'خطا در حذف لاگ‌ها: $error',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();

    if (mounted) {
      setState(() {
        _searchQuery = '';
      });
    }
  }

  void _showMessage(
    String message, {
    Color? backgroundColor,
  }) {
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

  static String _formatDate(int timestamp) {
    return faDateTimeSeconds(
      DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }
}

// ============================================================================
// کارت خلاصه لاگ‌ها
// ============================================================================

class _LogsSummary extends StatelessWidget {
  final int totalCount;
  final int filteredCount;
  final bool hasSearch;

  const _LogsSummary({
    required this.totalCount,
    required this.filteredCount,
    required this.hasSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.history),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'رخدادهای ثبت‌شده سیستم',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasSearch
                        ? '$filteredCount مورد از $totalCount رخداد'
                        : 'تعداد کل رخدادها: $totalCount',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (hasSearch)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'فیلتر فعال',
                  style: TextStyle(fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// کارت هر لاگ
// ============================================================================

class _LogCard extends StatelessWidget {
  final String action;
  final String details;
  final String userName;
  final int timestamp;

  const _LogCard({
    required this.action,
    required this.details,
    required this.userName,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final actionColor = _getActionColor(action);
    final displayAction = action.trim().isEmpty ? 'رخداد سیستم' : action.trim();
    final displayDetails = details.trim().isEmpty
        ? 'توضیحی برای این رخداد ثبت نشده است.'
        : details.trim();
    final displayUser = userName.trim().isEmpty ? 'سیستم' : userName.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showLogDetails(
          context,
          displayAction: displayAction,
          displayDetails: displayDetails,
          displayUser: displayUser,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: actionColor.withAlpha(28),
                foregroundColor: actionColor,
                child: Icon(
                  _getActionIcon(action),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayAction,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(timestamp),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      displayDetails,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _LogInfo(
                          icon: Icons.calendar_today_outlined,
                          text: _formatDate(timestamp),
                        ),
                        _LogInfo(
                          icon: Icons.person_outline,
                          text: displayUser,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_left,
                color: Colors.grey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogDetails(
    BuildContext context, {
    required String displayAction,
    required String displayDetails,
    required String displayUser,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _getActionIcon(action),
                color: _getActionColor(action),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(displayAction),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'جزئیات رخداد',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    displayDetails,
                    style: const TextStyle(height: 1.6),
                  ),
                  const Divider(height: 28),
                  _DetailRow(
                    icon: Icons.person_outline,
                    title: 'کاربر',
                    value: displayUser,
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.access_time,
                    title: 'زمان',
                    value: _formatFullDate(timestamp),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('بستن'),
            ),
          ],
        );
      },
    );
  }

  static IconData _getActionIcon(String action) {
    final normalized = action.toUpperCase();

    if (normalized.contains('DELETE') || normalized.contains('حذف')) {
      return Icons.delete_outline;
    }

    if (normalized.contains('CREATE') ||
        normalized.contains('ADD') ||
        normalized.contains('ثبت') ||
        normalized.contains('ایجاد')) {
      return Icons.add_circle_outline;
    }

    if (normalized.contains('UPDATE') ||
        normalized.contains('EDIT') ||
        normalized.contains('ویرایش')) {
      return Icons.edit_outlined;
    }

    if (normalized.contains('LOGIN') || normalized.contains('ورود')) {
      return Icons.login;
    }

    if (normalized.contains('LOGOUT') || normalized.contains('خروج')) {
      return Icons.logout;
    }

    if (normalized.contains('SALE') || normalized.contains('فروش')) {
      return Icons.point_of_sale;
    }

    if (normalized.contains('PURCHASE') || normalized.contains('خرید')) {
      return Icons.shopping_cart_outlined;
    }

    if (normalized.contains('EXPORT') || normalized.contains('خروجی')) {
      return Icons.file_download_outlined;
    }

    if (normalized.contains('ERROR') || normalized.contains('خطا')) {
      return Icons.error_outline;
    }

    return Icons.history;
  }

  static Color _getActionColor(String action) {
    final normalized = action.toUpperCase();

    if (normalized.contains('DELETE') ||
        normalized.contains('حذف') ||
        normalized.contains('ERROR') ||
        normalized.contains('خطا')) {
      return const Color(0xFFC62828);
    }

    if (normalized.contains('CREATE') ||
        normalized.contains('ADD') ||
        normalized.contains('ثبت') ||
        normalized.contains('ایجاد')) {
      return const Color(0xFF2E7D32);
    }

    if (normalized.contains('UPDATE') ||
        normalized.contains('EDIT') ||
        normalized.contains('ویرایش')) {
      return const Color(0xFF1565C0);
    }

    if (normalized.contains('LOGIN') ||
        normalized.contains('LOGOUT') ||
        normalized.contains('ورود') ||
        normalized.contains('خروج')) {
      return const Color(0xFF6A1B9A);
    }

    if (normalized.contains('SALE') || normalized.contains('فروش')) {
      return const Color(0xFF00897B);
    }

    if (normalized.contains('PURCHASE') || normalized.contains('خرید')) {
      return const Color(0xFFE65100);
    }

    return const Color(0xFF6750A4);
  }

  static String _formatTime(int timestamp) {
    return faTime(
      DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }

  static String _formatDate(int timestamp) {
    return faDate(
      DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }

  static String _formatFullDate(int timestamp) {
    return faDateTimeSecondsMillis(timestamp);
  }
}

// ============================================================================
// اطلاعات کوتاه هر رخداد
// ============================================================================

class _LogInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _LogInfo({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Colors.grey,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ردیف جزئیات
// ============================================================================

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          '$title: ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: SelectableText(value),
        ),
      ],
    );
  }
}

// ============================================================================
// حالت خالی
// ============================================================================

class _EmptyLogsView extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onClearSearch;

  const _EmptyLogsView({
    required this.hasSearch,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch ? Icons.search_off : Icons.history_toggle_off,
              size: 72,
              color: Theme.of(context).colorScheme.primary.withAlpha(120),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'رخدادی مطابق جست‌وجوی شما پیدا نشد.'
                  : 'رخدادی برای نمایش وجود ندارد.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'عبارت جست‌وجو را تغییر دهید یا فیلتر را پاک کنید.'
                  : 'فعالیت‌های کاربران و رخدادهای سیستم در این قسمت نمایش داده می‌شوند.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
            if (hasSearch) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.clear),
                label: const Text('پاک کردن جست‌وجو'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
