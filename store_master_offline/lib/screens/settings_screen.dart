// settings_screen_fixed.dart
// ============================================================================
// SettingsScreen - تنظیمات، تم، واحد پول، شیفت و پشتیبان‌گیری
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../viewmodels/main_viewmodel.dart';
import 'license/license_activation_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoBackupOnLaunch = true;
  bool _isBackingUp = false;
  bool _isRestoring = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainViewModel>();
    final config = vm.config;

    final currency = config?.currency ?? 'تومان';
    final morningStart = config?.morningStartHour ?? 6;
    final morningEnd = config?.morningEndHour ?? 15;
    final eveningStart = config?.eveningStartHour ?? 15;
    final eveningEnd = config?.eveningEndHour ?? 24;
    final profitCoefficient = (config?.profitCoefficient ?? 0.22).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات فروشگاه'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _SettingsHeader(
              storeName: config?.storeName ?? 'فروشگاه',
              storeType: config?.storeType ?? 'نامشخص',
            ),

            const SizedBox(height: 12),

            // اطلاعات فروشگاه
            _SettingsSection(
              title: 'اطلاعات فروشگاه',
              icon: Icons.storefront,
              children: [
                _SettingTile(
                  icon: Icons.storefront_outlined,
                  title: 'نام فروشگاه',
                  value: _displayValue(config?.storeName),
                  onEdit: () => _editStoreName(
                    vm,
                    config?.storeName ?? '',
                  ),
                ),
                _SettingTile(
                  icon: Icons.category_outlined,
                  title: 'نوع فروشگاه',
                  value: _displayValue(config?.storeType),
                ),
                _SettingTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'تم تیره / روشن سیستم',
                  value: (config?.isDarkMode ?? false)
                      ? 'حالت تیره فعال'
                      : 'حالت روشن فعال',
                  trailing: Switch(
                    value: config?.isDarkMode ?? false,
                    onChanged: (value) => vm.updateDarkMode(value),
                  ),
                ),
                _SettingTile(
                  icon: Icons.palette_outlined,
                  title: 'تم رنگی فعلی',
                  value: _colorThemeLabel(
                    config?.colorTheme ?? 'PROFESSIONAL',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // مدیریت لایسنس
            _SettingsSection(
              title: 'لایسنس و مجوز برنامه',
              icon: Icons.verified_user_outlined,
              children: [
                _SettingTile(
                  icon: Icons.swap_horiz_outlined,
                  title: 'تعویض / ابطال لایسنس',
                  value: 'حفظ کامل اطلاعات و دیتابیس فروشگاه',
                  description: 'ورود لایسنس جدید، غیرفعال‌سازی فعلی و اعمال بسته ابطال',
                  onEdit: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LicenseActivationScreen(
                          managementMode: true,
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // واحد پول و ظاهر
            _SettingsSection(
              title: 'واحد پول و ظاهر فروش',
              icon: Icons.dashboard_customize_outlined,
              children: [
                _SettingTile(
                  icon: Icons.payments_outlined,
                  title: 'واحد پول',
                  value: currency,
                  onEdit: () => _editCurrency(vm, currency),
                ),
                _SettingTile(
                  icon: Icons.dashboard_outlined,
                  title: 'سبک چیدمان صفحه فروش',
                  value: _layoutStyleLabel(
                    config?.layoutStyle ?? 'GRID',
                  ),
                  onEdit: () => _editLayoutStyle(
                    vm,
                    config?.layoutStyle ?? 'GRID',
                  ),
                ),
                _SettingTile(
                  icon: Icons.color_lens_outlined,
                  title: 'تم رنگی برنامه',
                  value: _colorThemeLabel(
                    config?.colorTheme ?? 'PROFESSIONAL',
                  ),
                  onEdit: () => _editColorTheme(
                    vm,
                    config?.colorTheme ?? 'PROFESSIONAL',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // تنظیمات چاپ حرفه‌ای
            _SettingsSection(
              title: 'تنظیمات چاپ و اندازه برگه',
              icon: Icons.print_outlined,
              children: [
                _SettingTile(
                  icon: Icons.description_outlined,
                  title: 'اندازه برگه فاکتور و گزارش',
                  value: _printPaperLabel(config?.printPaperSize ?? 'A4'),
                  description:
                      'A4، A5، Letter، Legal، B5، رول ۵۸، رول ۸۰ یا اندازه سفارشی',
                  onEdit: () => _editPrintSettings(vm, config),
                ),
                _SettingTile(
                  icon: Icons.screen_rotation_outlined,
                  title: 'جهت چاپ',
                  value: (config?.printOrientation ?? 'PORTRAIT') == 'LANDSCAPE'
                      ? 'افقی'
                      : 'عمودی',
                  onEdit: () => _editPrintSettings(vm, config),
                ),
                _SettingTile(
                  icon: Icons.space_bar_outlined,
                  title: 'حاشیه چاپ',
                  value:
                      '${(config?.printMarginMm ?? 8).toStringAsFixed(1)} میلی‌متر',
                  onEdit: () => _editPrintSettings(vm, config),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // شیفت و محاسبات مالی
            _SettingsSection(
              title: 'ساعات شیفت و محاسبات مالی',
              icon: Icons.schedule,
              children: [
                _SettingTile(
                  icon: Icons.wb_sunny_outlined,
                  iconColor: const Color(0xFFF57F17),
                  title: 'شیفت صبح',
                  value:
                      '${_formatHour(morningStart)} تا ${_formatHour(morningEnd)}',
                  onEdit: () => _editMorningShift(
                    vm,
                    morningStart,
                    morningEnd,
                  ),
                ),
                _SettingTile(
                  icon: Icons.nights_stay_outlined,
                  iconColor: const Color(0xFF3949AB),
                  title: 'شیفت عصر',
                  value:
                      '${_formatHour(eveningStart)} تا ${_formatHour(eveningEnd)}',
                  onEdit: () => _editEveningShift(
                    vm,
                    eveningStart,
                    eveningEnd,
                  ),
                ),
                _SettingTile(
                  icon: Icons.show_chart,
                  title: 'ضریب سود تخمینی',
                  value: '${(profitCoefficient * 100).toStringAsFixed(0)}٪',
                  description: 'برای محاسبه سود تخمینی در گزارش‌ها',
                  onEdit: () => _editProfitCoefficient(
                    vm,
                    profitCoefficient,
                  ),
                ),
                _SettingTile(
                  icon: Icons.alarm_on_outlined,
                  title: 'زمان هشدار پایان روز',
                  value: _normalizeDisplayedTime(
                    config?.endShiftAlertTime ?? '21:00',
                  ),
                  onEdit: () => _editEndShiftAlert(
                    vm,
                    config?.endShiftAlertTime ?? '21:00',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // پشتیبان‌گیری
            _SettingsSection(
              title: 'پشتیبان‌گیری و بازیابی',
              icon: Icons.cloud_sync_outlined,
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  secondary: Icon(
                    Icons.backup_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text(
                    'پشتیبان‌گیری خودکار در شروع برنامه',
                  ),
                  subtitle: const Text(
                    'این گزینه در وضعیت فعلی فقط برای نشست جاری نگهداری می‌شود.',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: _autoBackupOnLaunch,
                  onChanged: _isBackingUp || _isRestoring
                      ? null
                      : (value) {
                          setState(() {
                            _autoBackupOnLaunch = value;
                          });
                        },
                ),
                const SizedBox(height: 8),
                _BackupButtons(
                  isBackingUp: _isBackingUp,
                  isRestoring: _isRestoring,
                  onBackup: () => _runManualBackup(vm),
                  onRestore: () => _requestManualRestore(vm),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 19,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'بازیابی اطلاعات ممکن است داده‌های فعلی را تغییر دهد. '
                          'پیش از بازیابی، یک نسخه پشتیبان جدید تهیه کنید.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (vm.lastStatusMessage != null &&
                vm.lastStatusMessage!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vm.lastStatusMessage!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // نام فروشگاه
  // --------------------------------------------------------------------------

  Future<void> _editStoreName(
    MainViewModel vm,
    String currentValue,
  ) async {
    final value = await _showTextInputDialog(
      title: 'نام فروشگاه',
      initialValue: currentValue,
      label: 'نام فروشگاه',
      hint: 'مثال: فروشگاه نمونه',
      icon: Icons.storefront_outlined,
      maxLength: 100,
      validator: (input) {
        if (input.trim().isEmpty) {
          return 'نام فروشگاه را وارد کنید.';
        }

        if (input.trim().length < 2) {
          return 'نام فروشگاه بسیار کوتاه است.';
        }

        return null;
      },
    );

    if (value == null || !mounted) {
      return;
    }

    try {
      await vm.updateStoreName(value.trim());
      _showMessage('نام فروشگاه ذخیره شد.');
    } catch (error) {
      _showMessage(
        'خطا در ذخیره نام فروشگاه: $error',
        backgroundColor: Colors.red,
      );
    }
  }

  // --------------------------------------------------------------------------
  // واحد پول
  // --------------------------------------------------------------------------

  Future<void> _editCurrency(
    MainViewModel vm,
    String currentValue,
  ) async {
    final value = await _showChoiceDialog(
      title: 'انتخاب واحد پول',
      currentValue: currentValue,
      options: const {
        'تومان': 'تومان',
        'ریال': 'ریال',
        '\$': 'دلار (\$)',
      },
    );

    if (value == null || !mounted) {
      return;
    }

    try {
      await vm.updateCurrency(value);
      _showMessage('واحد پول تغییر کرد.');
    } catch (error) {
      _showMessage(
        'خطا در تغییر واحد پول: $error',
        backgroundColor: Colors.red,
      );
    }
  }

  // --------------------------------------------------------------------------
  // چیدمان فروش
  // --------------------------------------------------------------------------

  Future<void> _editLayoutStyle(
    MainViewModel vm,
    String currentValue,
  ) async {
    final value = await _showLayoutStyleDialog(currentValue);

    if (value == null || !mounted) {
      return;
    }

    try {
      await vm.updateLayoutStyle(value);
      _showMessage('چیدمان صفحه فروش تغییر کرد.');
    } catch (error) {
      _showMessage(
        'خطا در تغییر چیدمان: $error',
        backgroundColor: Colors.red,
      );
    }
  }

  // --------------------------------------------------------------------------
  // تم رنگی
  // --------------------------------------------------------------------------

  Future<String?> _showLayoutStyleDialog(String currentValue) {
    const options = <String, String>{
      'GRID': 'شبکه‌ای',
      'TOUCH_TILES': 'کاشی‌های لمسی بزرگ',
      'LIST': 'لیست فشرده',
    };
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('چیدمان صفحه فروش'),
          children: options.entries.map((entry) {
            final selected = entry.key == currentValue;
            return SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(entry.key),
              child: Row(
                children: [
                  Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: selected ? Theme.of(dialogContext).colorScheme.primary : Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(child: Text(entry.value)),
                  const SizedBox(width: 8),
                  _LayoutModeMiniPreview(mode: entry.key),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _editColorTheme(
    MainViewModel vm,
    String currentValue,
  ) async {
    final value = await _showChoiceDialog(
      title: 'تم رنگی برنامه',
      currentValue: currentValue,
      options: const {
        'PROFESSIONAL': 'حرفه‌ای',
        'EMERALD': 'زمردی',
        'OCEAN': 'اقیانوسی',
        'GOLDEN': 'طلایی',
        'PURPLE': 'ارغوانی',
        'RUBY': 'یاقوتی',
      },
    );

    if (value == null || !mounted) {
      return;
    }

    try {
      await vm.updateColorTheme(value);
      _showMessage('تم رنگی برنامه تغییر کرد.');
    } catch (error) {
      _showMessage(
        'خطا در تغییر تم رنگی: $error',
        backgroundColor: Colors.red,
      );
    }
  }

  // --------------------------------------------------------------------------
  // شیفت صبح
  // --------------------------------------------------------------------------

  Future<void> _editMorningShift(
    MainViewModel vm,
    int start,
    int end,
  ) async {
    final result = await _pickShiftHours(
      title: 'ساعات شیفت صبح',
      startHour: start,
      endHour: end,
    );

    if (result == null || !mounted) {
      return;
    }

    try {
      await vm.updateShiftHours(
        start: result.start,
        end: result.end,
      );

      _showMessage('ساعات شیفت صبح ذخیره شد.');
    } catch (error) {
      _showMessage(
        'خطا در ذخیره ساعات شیفت صبح: $error',
        backgroundColor: Colors.red,
      );
    }
  }

  // --------------------------------------------------------------------------
  // شیفت عصر
  // --------------------------------------------------------------------------

  Future<void> _editEveningShift(
    MainViewModel vm,
    int start,
    int end,
  ) async {
    final result = await _pickShiftHours(
      title: 'ساعات شیفت عصر',
      startHour: start,
      endHour: end,
    );

    if (result == null || !mounted) {
      return;
    }

    try {
      await vm.updateEveningShift(
        start: result.start,
        end: result.end,
      );

      _showMessage('ساعات شیفت عصر ذخیره شد.');
    } catch (error) {
      _showMessage(
        'خطا در ذخیره ساعات شیفت عصر: $error',
        backgroundColor: Colors.red,
      );
    }
  }

  // --------------------------------------------------------------------------
  // انتخاب ساعات شیفت
  // --------------------------------------------------------------------------

  Future<_ShiftHours?> _pickShiftHours({
    required String title,
    required int startHour,
    required int endHour,
  }) async {
    final startController = TextEditingController(
      text: startHour.toString(),
    );

    final endController = TextEditingController(
      text: endHour.toString(),
    );

    final formKey = GlobalKey<FormState>();

    try {
      return await showDialog<_ShiftHours>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.schedule),
                const SizedBox(width: 8),
                Expanded(child: Text(title)),
              ],
            ),
            content: SizedBox(
              width: 390,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'ساعت شروع و پایان را بین ۰ تا ۲۴ وارد کنید.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: startController,
                              autofocus: true,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9۰-۹٠-٩]'),
                                ),
                                LengthLimitingTextInputFormatter(2),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'شروع',
                                hintText: '6',
                                suffixText: ':00',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validateShiftHour,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 16,
                            ),
                            child: Text(
                              'تا',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: endController,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9۰-۹٠-٩]'),
                                ),
                                LengthLimitingTextInputFormatter(2),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'پایان',
                                hintText: '15',
                                suffixText: ':00',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validateShiftHour,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'برای شیفت شب می‌توانید بازه‌ای مانند ۱۸ تا ۶ وارد کنید.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('انصراف'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) {
                    return;
                  }

                  final start = int.parse(
                    _convertDigits(startController.text),
                  );

                  final end = int.parse(
                    _convertDigits(endController.text),
                  );

                  if (start == end) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'ساعت شروع و پایان نباید یکسان باشند.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.of(dialogContext).pop(
                    _ShiftHours(
                      start: start,
                      end: end,
                    ),
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text('ذخیره'),
              ),
            ],
          );
        },
      );
    } finally {
      startController.dispose();
      endController.dispose();
    }
  }

  String? _validateShiftHour(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'الزامی';
    }

    final normalized = _convertDigits(value.trim());
    final hour = int.tryParse(normalized);

    if (hour == null) {
      return 'نامعتبر';
    }

    if (hour < 0 || hour > 24) {
      return '۰ تا ۲۴';
    }

    return null;
  }

  // --------------------------------------------------------------------------
  // ضریب سود
  // --------------------------------------------------------------------------

  Future<void> _editProfitCoefficient(
    MainViewModel vm,
    double currentValue,
  ) async {
    final value = await _showTextInputDialog(
      title: 'ضریب سود تخمینی',
      initialValue: currentValue.toString(),
      label: 'ضریب سود',
      hint: 'مثال: 0.22',
      helperText: 'مقداری بیشتر از صفر و حداکثر ۱ وارد کنید.',
      icon: Icons.show_chart,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(r'[0-9۰-۹٠-٩.,٫]'),
        ),
      ],
      validator: (input) {
        final parsed = _parseDecimal(input);

        if (parsed == null) {
          return 'ضریب سود معتبر وارد کنید.';
        }

        if (parsed <= 0 || parsed > 1) {
          return 'ضریب باید بیشتر از صفر و حداکثر ۱ باشد.';
        }

        return null;
      },
    );

    if (value == null || !mounted) {
      return;
    }

    final parsed = _parseDecimal(value);

    if (parsed == null || parsed <= 0 || parsed > 1) {
      return;
    }

    try {
      await vm.updateProfitCoefficient(parsed);
      _showMessage('ضریب سود ذخیره شد.');
    } catch (error) {
      _showMessage(
        'خطا در ذخیره ضریب سود: $error',
        backgroundColor: Colors.red,
      );
    }
  }

  // --------------------------------------------------------------------------
  // هشدار پایان روز
  // --------------------------------------------------------------------------

  Future<void> _editEndShiftAlert(
    MainViewModel vm,
    String currentValue,
  ) async {
    final value = await _showTextInputDialog(
      title: 'زمان هشدار پایان روز',
      initialValue: _normalizeDisplayedTime(currentValue),
      label: 'ساعت',
      hint: 'مثال: 21:00',
      helperText: 'زمان را با قالب HH:mm وارد کنید.',
      icon: Icons.alarm_on_outlined,
      keyboardType: TextInputType.datetime,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(r'[0-9۰-۹٠-٩:]'),
        ),
        LengthLimitingTextInputFormatter(5),
      ],
      validator: (input) {
        final normalized = _normalizeTime(input);

        if (normalized == null) {
          return 'زمان معتبر با قالب HH:mm وارد کنید.';
        }

        return null;
      },
    );

    if (value == null || !mounted) {
      return;
    }

    final normalized = _normalizeTime(value);

    if (normalized == null) {
      return;
    }

    try {
      await vm.updateEndShiftAlert(normalized);
      _showMessage('زمان هشدار پایان روز ذخیره شد.');
    } catch (error) {
      _showMessage(
        'خطا در ذخیره زمان هشدار: $error',
        backgroundColor: Colors.red,
      );
    }
  }

  // --------------------------------------------------------------------------
  // پشتیبان‌گیری دستی
  // --------------------------------------------------------------------------

  Future<void> _runManualBackup(MainViewModel vm) async {
    if (_isBackingUp || _isRestoring) {
      return;
    }

    setState(() {
      _isBackingUp = true;
    });

    try {
      final file = await vm.runManualBackup();

      if (!mounted) {
        return;
      }

      if (file == null) {
        _showMessage(
          'فایل پشتیبان ایجاد نشد.',
          backgroundColor: Colors.orange,
        );
        return;
      }

      final normalizedPath = file.path.replaceAll('\\', '/');
      final fileName = normalizedPath.split('/').last;

      _showMessage(
        'نسخه پشتیبان ایجاد شد: $fileName',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'خطا در پشتیبان‌گیری: $error',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  // --------------------------------------------------------------------------
  // بازیابی دستی
  // --------------------------------------------------------------------------

  Future<void> _requestManualRestore(MainViewModel vm) async {
    if (_isBackingUp || _isRestoring) {
      return;
    }

    final json = await _showTextInputDialog(
      title: 'بازیابی نسخه پشتیبان',
      initialValue: '',
      label: 'محتوای JSON پشتیبان',
      hint: 'متن فایل پشتیبان را در این قسمت قرار دهید.',
      icon: Icons.data_object,
      minLines: 8,
      maxLines: 14,
      validator: (input) {
        final trimmed = input.trim();

        if (trimmed.isEmpty) {
          return 'محتوای نسخه پشتیبان را وارد کنید.';
        }

        if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
          return 'ساختار JSON معتبر به نظر نمی‌رسد.';
        }

        return null;
      },
    );

    if (json == null || !mounted) {
      return;
    }

    final confirmed = await _confirmRestore();

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isRestoring = true;
    });

    try {
      final success = await vm.runManualRestore(json.trim());

      if (!mounted) {
        return;
      }

      if (success) {
        _showMessage(
          'بازیابی اطلاعات با موفقیت انجام شد.',
          backgroundColor: Colors.green,
        );
      } else {
        _showMessage(
          'بازیابی اطلاعات ناموفق بود.',
          backgroundColor: Colors.red,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'خطا در بازیابی اطلاعات: $error',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  Future<bool> _confirmRestore() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              icon: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 44,
              ),
              title: const Text('تأیید بازیابی اطلاعات'),
              content: const Text(
                'بازیابی نسخه پشتیبان ممکن است اطلاعات فعلی برنامه را '
                'تغییر دهد یا جایگزین کند. آیا ادامه می‌دهید؟',
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
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('بازیابی'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // --------------------------------------------------------------------------
  // دیالوگ ورود متن
  // --------------------------------------------------------------------------

  Future<String?> _showTextInputDialog({
    required String title,
    required String initialValue,
    required String label,
    IconData? icon,
    String? hint,
    String? helperText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String value)? validator,
    int? maxLength,
    int minLines = 1,
    int maxLines = 1,
  }) async {
    final controller = TextEditingController(
      text: initialValue,
    );

    final formKey = GlobalKey<FormState>();

    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Text(title)),
              ],
            ),
            content: SizedBox(
              width: 450,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: TextFormField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: keyboardType ??
                        (maxLines > 1
                            ? TextInputType.multiline
                            : TextInputType.text),
                    inputFormatters: inputFormatters,
                    maxLength: maxLength,
                    minLines: minLines,
                    maxLines: maxLines,
                    textInputAction: maxLines > 1
                        ? TextInputAction.newline
                        : TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: label,
                      hintText: hint,
                      helperText: helperText,
                      alignLabelWithHint: maxLines > 1,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (validator == null) {
                        return null;
                      }

                      return validator(value ?? '');
                    },
                    onFieldSubmitted: maxLines > 1
                        ? null
                        : (_) {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }

                            Navigator.of(dialogContext).pop(
                              controller.text,
                            );
                          },
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('انصراف'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  FocusScope.of(dialogContext).unfocus();

                  if (!(formKey.currentState?.validate() ?? false)) {
                    return;
                  }

                  Navigator.of(dialogContext).pop(
                    controller.text,
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text('ذخیره'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  // --------------------------------------------------------------------------
  // دیالوگ انتخاب گزینه
  // --------------------------------------------------------------------------

  Future<String?> _showChoiceDialog({
    required String title,
    required String currentValue,
    required Map<String, String> options,
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text(title),
          children: options.entries.map((entry) {
            final selected = entry.key == currentValue;

            return SimpleDialogOption(
              onPressed: () {
                Navigator.of(dialogContext).pop(entry.key);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected
                          ? Theme.of(dialogContext).colorScheme.primary
                          : Colors.grey,
                      size: 21,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // توابع کمکی
  // --------------------------------------------------------------------------

  String _displayValue(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'تعیین نشده';
    }

    return value.trim();
  }

  String _formatHour(int hour) {
    if (hour == 24) {
      return '24:00';
    }

    final normalized = hour.clamp(0, 23);
    return '${normalized.toString().padLeft(2, '0')}:00';
  }

  String _layoutStyleLabel(String value) {
    switch (value) {
      case 'TOUCH_TILES':
        return 'کاشی‌های لمسی بزرگ';
      case 'LIST':
        return 'لیست فشرده';
      case 'GRID':
      default:
        return 'شبکه‌ای';
    }
  }

  String _colorThemeLabel(String value) {
    switch (value) {
      case 'EMERALD':
        return 'زمردی';
      case 'OCEAN':
        return 'اقیانوسی';
      case 'GOLDEN':
        return 'طلایی';
      case 'PURPLE':
        return 'ارغوانی';
      case 'RUBY':
        return 'یاقوتی';
      case 'PROFESSIONAL':
      default:
        return 'حرفه‌ای';
    }
  }

  double? _parseDecimal(String input) {
    final normalized = _convertDigits(input.trim())
        .replaceAll('٫', '.')
        .replaceAll(',', '.')
        .replaceAll(' ', '');

    return double.tryParse(normalized);
  }

  String? _normalizeTime(String input) {
    final normalized =
        _convertDigits(input.trim()).replaceAll('：', ':').replaceAll(' ', '');

    final match = RegExp(
      r'^(\d{1,2}):(\d{1,2})$',
    ).firstMatch(normalized);

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

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  String _normalizeDisplayedTime(String input) {
    return _normalizeTime(input) ?? input;
  }

  String _convertDigits(String input) {
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

  String _printPaperLabel(String value) {
    switch (value) {
      case 'A5':
        return 'A5';
      case 'LETTER':
        return 'Letter';
      case 'LEGAL':
        return 'Legal';
      case 'B5':
        return 'B5';
      case 'R58':
        return 'رول ۵۸ میلی‌متر';
      case 'R80':
        return 'رول ۸۰ میلی‌متر';
      case 'CUSTOM':
        return 'سفارشی';
      case 'A4':
      default:
        return 'A4';
    }
  }

  Future<void> _editPrintSettings(
    MainViewModel vm,
    dynamic config,
  ) async {
    String paperSize = config?.printPaperSize ?? 'A4';
    String orientation = config?.printOrientation ?? 'PORTRAIT';
    double margin = (config?.printMarginMm ?? 8).toDouble();
    double width = (config?.customPaperWidthMm ?? 210).toDouble();
    double height = (config?.customPaperHeightMm ?? 297).toDouble();

    final marginController = TextEditingController(
      text: margin.toStringAsFixed(1),
    );
    final widthController = TextEditingController(
      text: width.toStringAsFixed(1),
    );
    final heightController = TextEditingController(
      text: height.toStringAsFixed(1),
    );

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final isCustom = paperSize == 'CUSTOM';
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.print_outlined),
                    SizedBox(width: 8),
                    Expanded(child: Text('تنظیمات چاپ حرفه‌ای')),
                  ],
                ),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'این تنظیمات به‌صورت آفلاین در دیتابیس ذخیره می‌شود و برای PDF، فاکتور و چاپ مستقیم استفاده خواهد شد.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: paperSize,
                          decoration: const InputDecoration(
                            labelText: 'اندازه برگه',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'A4', child: Text('A4 - استاندارد')),
                            DropdownMenuItem(value: 'A5', child: Text('A5')),
                            DropdownMenuItem(
                                value: 'LETTER', child: Text('Letter')),
                            DropdownMenuItem(
                                value: 'LEGAL', child: Text('Legal')),
                            DropdownMenuItem(value: 'B5', child: Text('B5')),
                            DropdownMenuItem(
                                value: 'R58',
                                child: Text('رول حرارتی ۵۸ میلی‌متر')),
                            DropdownMenuItem(
                                value: 'R80',
                                child: Text('رول حرارتی ۸۰ میلی‌متر')),
                            DropdownMenuItem(
                                value: 'CUSTOM', child: Text('اندازه سفارشی')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => paperSize = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'PORTRAIT',
                              icon: Icon(Icons.stay_current_portrait_outlined),
                              label: Text('عمودی'),
                            ),
                            ButtonSegment(
                              value: 'LANDSCAPE',
                              icon: Icon(Icons.stay_current_landscape_outlined),
                              label: Text('افقی'),
                            ),
                          ],
                          selected: {orientation},
                          onSelectionChanged: (value) {
                            setDialogState(() => orientation = value.first);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: marginController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'حاشیه (میلی‌متر)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (isCustom) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: widthController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'عرض (میلی‌متر)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: heightController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'ارتفاع (میلی‌متر)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('انصراف'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext, {
                        'paperSize': paperSize,
                        'orientation': orientation,
                        'margin':
                            _parseDecimal(marginController.text) ?? margin,
                        'width': _parseDecimal(widthController.text) ?? width,
                        'height':
                            _parseDecimal(heightController.text) ?? height,
                      });
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('ذخیره تنظیمات'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == null || !mounted) return;

      try {
        await vm.updatePrintSettings(
          paperSize: result['paperSize'] as String,
          orientation: result['orientation'] as String,
          marginMm: (result['margin'] as num).toDouble(),
          customWidthMm: (result['width'] as num).toDouble(),
          customHeightMm: (result['height'] as num).toDouble(),
        );
        _showMessage('تنظیمات چاپ ذخیره شد.');
      } catch (error) {
        _showMessage(
          'خطا در ذخیره تنظیمات چاپ: $error',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      marginController.dispose();
      widthController.dispose();
      heightController.dispose();
    }
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
// مدل ساعات شیفت
// ============================================================================

class _ShiftHours {
  final int start;
  final int end;

  const _ShiftHours({
    required this.start,
    required this.end,
  });
}

// ============================================================================
// سربرگ تنظیمات
// ============================================================================

class _SettingsHeader extends StatelessWidget {
  final String storeName;
  final String storeType;

  const _SettingsHeader({
    required this.storeName,
    required this.storeType,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.settings),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    storeName.trim().isEmpty ? 'فروشگاه' : storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'نوع فروشگاه: $storeType',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
// بخش تنظیمات
// ============================================================================

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            ..._withDividers(children),
          ],
        ),
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> widgets) {
    final result = <Widget>[];

    for (int index = 0; index < widgets.length; index++) {
      result.add(widgets[index]);

      if (index < widgets.length - 1) {
        result.add(const Divider(height: 1));
      }
    }

    return result;
  }
}

// ============================================================================
// آیتم تنظیمات
// ============================================================================

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? description;
  final VoidCallback? onEdit;
  final Widget? trailing;
  final Color? iconColor;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.value,
    this.description,
    this.onEdit,
    this.trailing,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 3,
      ),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor:
            (iconColor ?? Theme.of(context).colorScheme.primary).withAlpha(22),
        foregroundColor: iconColor ?? Theme.of(context).colorScheme.primary,
        child: Icon(icon, size: 21),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (description != null && description!.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              description!,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
      trailing: trailing ??
          (onEdit == null
              ? null
              : IconButton(
                  tooltip: 'ویرایش',
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Colors.blue,
                  ),
                )),
      onTap: trailing == null ? onEdit : null,
    );
  }
}

// ============================================================================
// دکمه‌های پشتیبان
// ============================================================================

class _BackupButtons extends StatelessWidget {
  final bool isBackingUp;
  final bool isRestoring;
  final VoidCallback onBackup;
  final VoidCallback onRestore;

  const _BackupButtons({
    required this.isBackingUp,
    required this.isRestoring,
    required this.onBackup,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final backupButton = ElevatedButton.icon(
      onPressed: isBackingUp || isRestoring ? null : onBackup,
      icon: isBackingUp
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.upload_outlined),
      label: Text(
        isBackingUp ? 'در حال پشتیبان‌گیری...' : 'پشتیبان‌گیری دستی',
      ),
    );

    final restoreButton = OutlinedButton.icon(
      onPressed: isBackingUp || isRestoring ? null : onRestore,
      icon: isRestoring
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.restore),
      label: Text(
        isRestoring ? 'در حال بازیابی...' : 'بازیابی پشتیبان',
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 48, child: backupButton),
              const SizedBox(height: 8),
              SizedBox(height: 48, child: restoreButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: backupButton,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 48,
                child: restoreButton,
              ),
            ),
          ],
        );
      },
    );
  }
}


class _LayoutModeMiniPreview extends StatelessWidget {
  final String mode;
  const _LayoutModeMiniPreview({required this.mode});

  @override
  Widget build(BuildContext context) {
    if (mode == 'LIST') {
      return SizedBox(
        width: 78,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (index) => Container(
              height: 8,
              margin: const EdgeInsets.only(bottom: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      );
    }

    final count = mode == 'TOUCH_TILES' ? 2 : 3;
    return SizedBox(
      width: 78,
      height: 38,
      child: GridView.count(
        crossAxisCount: count,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(
          count == 2 ? 4 : 6,
          (index) => DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}
