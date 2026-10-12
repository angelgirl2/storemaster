import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'online_admin_service.dart';
import '../catalog/business_catalog.dart';
import '../models/license_models.dart';
import '../services/license_repository.dart';
import '../services/license_signer.dart';

class LicenseManagerScreen extends StatefulWidget {
  const LicenseManagerScreen({super.key});

  @override
  State<LicenseManagerScreen> createState() => _LicenseManagerScreenState();
}

class _LicenseManagerScreenState extends State<LicenseManagerScreen> {
  final customer = TextEditingController();
  final phone = TextEditingController();
  final device = TextEditingController();
  final note = TextEditingController();

  final Set<String> selected = <String>{};
  int duration = 30;
  Map<int, double> _prices = <int, double>{...LicenseRepository.defaultPrices};
  final String _currency = 'تومان';
  String platform = 'ANDROID';
  bool _busy = false;
  bool _dark = false;
  int _seedIndex = 0;
  int _section = 0;
  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];
  String? _lastLicense;

  static const _navItems = <({IconData icon, String title})>[
    (icon: Icons.dashboard_rounded, title: 'داشبورد'),
    (icon: Icons.vpn_key_rounded, title: 'صدور لایسنس'),
    (icon: Icons.history_rounded, title: 'سوابق لایسنس'),
    (icon: Icons.settings_rounded, title: 'تنظیمات'),
  ];

  static const _palette = <Color>[
    Color(0xFF5B2EFF),
    Color(0xFF00796B),
    Color(0xFF1565C0),
    Color(0xFFD84315),
    Color(0xFF8E24AA),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    customer.dispose();
    phone.dispose();
    device.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final history = await LicenseRepository.instance.all();
      final prices = await LicenseRepository.instance.getPrices();
      if (!mounted) return;
      setState(() {
        _history = history;
        _prices = prices;
      });
    } catch (e) {
      _msg('خطا در بارگذاری سوابق لایسنس: $e', error: true);
    }
  }

  Future<void> _importDeviceCard() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final bytes = picked.bytes;
      final text = bytes != null
          ? utf8.decode(bytes)
          : (picked.path == null
              ? ''
              : await File(picked.path!).readAsString());

      if (text.trim().isEmpty) {
        throw const FormatException('فایل مشخصات دستگاه خالی است.');
      }

      String? importedDevice;
      String? importedPlatform;
      for (final rawLine in text.split(RegExp(r'\\r?\\n'))) {
        final line = rawLine.trim();
        final lower = line.toLowerCase();
        if (lower.startsWith('device id:')) {
          importedDevice = line.substring(line.indexOf(':') + 1).trim();
        } else if (lower.startsWith('platform:')) {
          importedPlatform =
              line.substring(line.indexOf(':') + 1).trim().toUpperCase();
        }
      }

      if (importedDevice == null || importedDevice.trim().isEmpty) {
        throw const FormatException('Device ID داخل فایل پیدا نشد.');
      }

      final normalizedDevice = importedDevice.trim().toUpperCase();
      if (!RegExp(r'^[0-9A-F]{64}$').hasMatch(normalizedDevice)) {
        throw const FormatException(
            'Device ID باید ۶۴ کاراکتر هگزادسیمال باشد.');
      }

      if (importedPlatform != 'ANDROID' && importedPlatform != 'WINDOWS') {
        throw const FormatException(
            'پلتفرم دستگاه باید ANDROID یا WINDOWS باشد.');
      }

      if (!mounted) return;
      setState(() {
        device.text = normalizedDevice;
        platform = importedPlatform!;
      });
      _msg('شناسه دستگاه و پلتفرم با موفقیت وارد شد.');
    } catch (e) {
      if (mounted) _msg('خطا در خواندن مشخصات دستگاه: $e', error: true);
    }
  }

  Future<void> _issue() async {
    if (customer.text.trim().isEmpty) {
      _msg('نام مشتری الزامی است', error: true);
      return;
    }
    final normalizedDevice = device.text.trim().toUpperCase();
    if (normalizedDevice.isEmpty) {
      _msg('شناسه دستگاه الزامی است', error: true);
      return;
    }
    if (!RegExp(r'^[0-9A-F]{64}$').hasMatch(normalizedDevice)) {
      _msg('شناسه دستگاه نامعتبر است؛ باید ۶۴ کاراکتر هگزادسیمال باشد.',
          error: true);
      return;
    }
    if (platform != 'ANDROID' && platform != 'WINDOWS') {
      _msg('پلتفرم لایسنس نامعتبر است.', error: true);
      return;
    }
    if (selected.isEmpty) {
      _msg('حداقل یک شغل انتخاب کنید', error: true);
      return;
    }

    if (!selected.contains('*') &&
        selected.any((code) => !BusinessCatalog.containsCode(code))) {
      _msg('یک یا چند کد شغل با کاتالوگ مشترک StoreMaster هماهنگ نیست.',
          error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final expires = now.add(Duration(days: duration));
      final price = _prices[duration] ?? 0;
      if (price <= 0) throw StateError('قیمت این مدت لایسنس تعیین نشده است.');
      final id = 'SM-${_randomReadable()}';
      final payload = LicensePayload(
        licenseId: id,
        customerName: customer.text.trim(),
        phone: phone.text.trim(),
        businessTypes: selected.toList(),
        deviceId: normalizedDevice,
        platform: platform,
        plan: switch (duration) {
          30 => '1M',
          90 => '3M',
          180 => '6M',
          365 => '12M',
          _ => 'CUSTOM',
        },
        durationDays: duration,
        issuedAt: now.millisecondsSinceEpoch,
        expiresAt: expires.millisecondsSinceEpoch,
        priceAtPurchase: price,
        currency: _currency,
        features: const <String>['FULL'],
      );

      final signature = await LicenseSigner.sign(payload);
      final document =
          LicenseDocument(payload: payload, signatureBase64: signature);
      await LicenseRepository.instance.add(payload);

      final text = document.toJson();
      final path = await _saveFile(text, id);
      if (!mounted) return;
      setState(() => _lastLicense = text);
      _msg('لایسنس با موفقیت صادر شد و در $path ذخیره شد.');
      await _load();
      setState(() => _section = 2);
    } catch (e) {
      if (mounted) _msg('خطا در صدور لایسنس: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _saveFile(String text, String id) async {
    // ----------------------------------------------------------------
    // در Android و iOS بسته‌ی file_picker برای ذخیره فایل الزاماً نیاز
    // به پارامتر bytes دارد (در غیر این صورت با خطای زیر متوقف می‌شود:
    // "Bytes are required on Android & iOS when saving a file.").
    // در Windows/Linux/macOS نوشتن مستقیم فایل همچنان پشتیبانی می‌شود.
    // ----------------------------------------------------------------
    final bytes = Uint8List.fromList(utf8.encode(text));

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'ذخیره لایسنس',
      fileName: '$id.json',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );

    if (result == null || result.trim().isEmpty) {
      throw StateError('محل ذخیره انتخاب نشد.');
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      try {
        final normalizedPath = result.toLowerCase().endsWith('.json')
            ? result
            : '$result.json';
        final file = File(normalizedPath);
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      } catch (_) {
        return result;
      }
    }
    return result;
  }

  String _randomReadable() {
    final value =
        DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase();
    final prefix = value.length > 4 ? value.substring(0, 4) : value;
    final suffix = (value.hashCode.abs() % 1000000).toString().padLeft(6, '0');
    return '$prefix-$suffix';
  }

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, textDirection: ui.TextDirection.rtl),
          backgroundColor: error ? Colors.red.shade700 : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _selectSection(int value) {
    if (!mounted) return;
    setState(() => _section = value);
  }

  ThemeData _themeData() {
    final seed = _palette[_seedIndex];
    return ThemeData(
      useMaterial3: true,
      brightness: _dark ? Brightness.dark : Brightness.light,
      colorSchemeSeed: seed,
      scaffoldBackgroundColor:
          _dark ? const Color(0xFF101119) : const Color(0xFFF5F7FB),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      cardTheme: const CardThemeData(margin: EdgeInsets.zero),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _themeData(),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final profiles = BusinessCatalog.profiles;
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            drawer: _buildDrawer(theme),
            body: SafeArea(
              child: Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  if (MediaQuery.sizeOf(context).width >= 980)
                    _buildSidebar(theme),
                  Expanded(
                    child: Column(
                      children: [
                        _buildTopBar(theme),
                        Expanded(
                            child: _buildContent(
                                theme, profiles.cast<BusinessProfile>())),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Drawer _buildDrawer(ThemeData theme) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _drawerHeader(theme),
            const Divider(height: 1),
            Expanded(child: _navList(theme)),
          ],
        ),
      ),
    );
  }

  Widget _drawerHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
      ),
      child: const Row(
        textDirection: ui.TextDirection.rtl,
        children: [
          CircleAvatar(radius: 24, child: Icon(Icons.key_rounded)),
          SizedBox(width: 10),
          Expanded(
              child: Text('StoreMaster\nLicense Manager',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.15))),
        ],
      ),
    );
  }

  Widget _navList(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _navItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 5),
      itemBuilder: (_, i) {
        final item = _navItems[i];
        return ListTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          selected: _section == i,
          selectedTileColor: theme.colorScheme.primary.withValues(alpha: .12),
          leading: Icon(item.icon),
          title: Text(item.title, textDirection: ui.TextDirection.rtl),
          onTap: () {
            Navigator.of(context).maybePop();
            _selectSection(i);
          },
        );
      },
    );
  }

  Widget _buildSidebar(ThemeData theme) {
    return Container(
      width: 255,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
            left: BorderSide(color: theme.dividerColor.withValues(alpha: .5))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              textDirection: ui.TextDirection.rtl,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary
                    ]),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                          color:
                              theme.colorScheme.primary.withValues(alpha: .25),
                          blurRadius: 16)
                    ],
                  ),
                  child: const Icon(Icons.key_rounded, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text('StoreMaster\nLicense Manager',
                        textDirection: ui.TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.w900, height: 1.15))),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _navList(theme)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  theme.colorScheme.primary.withValues(alpha: .10),
                  theme.colorScheme.secondary.withValues(alpha: .10)
                ]),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: .18)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  textDirection: ui.TextDirection.rtl,
                  children: [
                    Icon(Icons.verified_user_outlined, size: 19),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text('صدور امضاشده و آفلاین',
                            textDirection: ui.TextDirection.rtl,
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: .96),
        border: Border(
            bottom:
                BorderSide(color: theme.dividerColor.withValues(alpha: .45))),
      ),
      child: Row(
        textDirection: ui.TextDirection.rtl,
        children: [
          if (MediaQuery.sizeOf(context).width < 980)
            IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded)),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_navItems[_section].title,
                    textDirection: ui.TextDirection.rtl,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
                Text('مرکز صدور و کنترل مجوزهای StoreMaster',
                    textDirection: ui.TextDirection.rtl,
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
              tooltip: 'حالت روشن/تیره',
              onPressed: () => setState(() => _dark = !_dark),
              icon: Icon(
                  _dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded)),
          IconButton(
              tooltip: 'به‌روزرسانی',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, List<BusinessProfile> profiles) {
    final padding = MediaQuery.sizeOf(context).width < 700 ? 12.0 : 20.0;

    // صفحه سوابق اسکرول داخلی خودش را دارد.
    // قرار دادن آن داخل SingleChildScrollView باعث می‌شود Wheel/Drag
    // روی ویندوز و دسکتاپ به‌درستی به ListView داخلی نرسد.
    if (_section == 2) {
      return Padding(
        padding: EdgeInsets.all(padding),
        child: _historyPage(theme),
      );
    }

    return SingleChildScrollView(
      primary: true,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(padding),
      child: switch (_section) {
        0 => _dashboard(theme, profiles),
        1 => _issuePage(theme, profiles),
        _ => _settingsPage(theme),
      },
    );
  }

  Widget _dashboard(ThemeData theme, List<BusinessProfile> profiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHero(theme),
        const SizedBox(height: 16),
        _buildStats(theme),
        const SizedBox(height: 16),
        _buildQuickActions(theme),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 900) {
            return Column(children: [
              _buildIssueCard(theme, profiles),
              const SizedBox(height: 16),
              _buildHistoryCard(theme)
            ]);
          }
          return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: ui.TextDirection.rtl,
              children: [
                Expanded(flex: 6, child: _buildIssueCard(theme, profiles)),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: _buildHistoryCard(theme)),
              ]);
        }),
      ],
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Row(
      textDirection: ui.TextDirection.rtl,
      children: [
        Expanded(
            child: _actionCard(theme, Icons.vpn_key_rounded, 'صدور لایسنس',
                'ساخت لایسنس جدید', 1)),
        const SizedBox(width: 12),
        Expanded(
            child: _actionCard(theme, Icons.history_rounded, 'سوابق',
                'مشاهده و بررسی لایسنس‌ها', 2)),
        const SizedBox(width: 12),
        Expanded(
            child: _actionCard(theme, Icons.settings_rounded, 'تنظیمات',
                'ظاهر و تنظیمات مدیر', 3)),
      ],
    );
  }

  Widget _actionCard(ThemeData theme, IconData icon, String title,
      String subtitle, int section) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _selectSection(section),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            theme.colorScheme.surface,
            theme.colorScheme.primary.withValues(alpha: .05)
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: .15)),
        ),
        child: Row(textDirection: ui.TextDirection.rtl, children: [
          CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: .12),
              foregroundColor: theme.colorScheme.primary,
              child: Icon(icon)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    textDirection: ui.TextDirection.rtl,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(subtitle,
                    textDirection: ui.TextDirection.rtl,
                    style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant))
              ])),
        ]),
      ),
    );
  }

  Widget _issuePage(ThemeData theme, List<BusinessProfile> profiles) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHero(theme),
        const SizedBox(height: 16),
        _buildIssueCard(theme, profiles)
      ]);

  Widget _historyPage(ThemeData theme) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHero(theme),
        const SizedBox(height: 16),
        _buildHistoryCard(theme, tall: true)
      ]);

  Widget _settingsPage(ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildHero(theme),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('تنظیمات ظاهر',
                textDirection: ui.TextDirection.rtl,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
                value: _dark,
                onChanged: (v) => setState(() => _dark = v),
                title: const Text('حالت تاریک'),
                subtitle: const Text('ظاهر برنامه در حالت شب')),
            const SizedBox(height: 8),
            const Text('رنگ اصلی',
                textDirection: ui.TextDirection.rtl,
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
                spacing: 10,
                children: List.generate(_palette.length, (i) {
                  final active = i == _seedIndex;
                  return InkWell(
                      onTap: () => setState(() => _seedIndex = i),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                              color: _palette[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: active
                                      ? theme.colorScheme.onSurface
                                      : Colors.transparent,
                                  width: 3)),
                          child: active
                              ? const Icon(Icons.check, color: Colors.white)
                              : null));
                })),
            const SizedBox(height: 14),
            FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('بارگذاری مجدد سوابق')),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'قیمت‌گذاری لایسنس',
                textDirection: ui.TextDirection.rtl,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'قیمت‌ها خارج از کد برنامه مشتری ذخیره می‌شوند و از اینجا برای صدورهای جدید تغییر می‌کنند.',
                textDirection: ui.TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              for (final days in const [30, 90, 180, 365])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextFormField(
                    key: ValueKey('price-$days-${_prices[days]}'),
                    initialValue: (_prices[days] ?? 0).round().toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: switch (days) {
                        30 => '۱ ماهه',
                        90 => '۳ ماهه',
                        180 => '۶ ماهه',
                        365 => '۱۲ ماهه',
                        _ => 'پلن'
                      },
                      suffixText: _currency,
                    ),
                    onChanged: (value) {
                      _prices[days] = double.tryParse(
                            value.replaceAll(',', '').replaceAll('٬', ''),
                          ) ??
                          (_prices[days] ?? 0);
                    },
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      await LicenseRepository.instance.setPrices(_prices);

                      await _load();

                      if (mounted) {
                        _msg(
                          'قیمت‌های جدید ذخیره شدند و از این لحظه برای صدورهای جدید استفاده می‌شوند.',
                        );
                      }
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text(
                      'ذخیره قیمت‌ها',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.saveFile(
                        dialogTitle: 'ذخیره لیست قیمت لایسنس',
                        fileName: 'storemaster_pricing.json',
                        type: FileType.custom,
                        allowedExtensions: const ['json'],
                      );

                      if (result == null || result.trim().isEmpty) {
                        return;
                      }

                      final path = result.toLowerCase().endsWith('.json')
                          ? result
                          : '$result.json';

                      final file = File(path);

                      await LicenseRepository.instance.savePricingCatalog(file);

                      if (mounted) {
                        _msg(
                          'لیست قیمت برای انتقال به دستگاه مشتری ذخیره شد.',
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.download_rounded,
                    ),
                    label: const Text(
                      'خروجی لیست قیمت',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Row(textDirection: ui.TextDirection.rtl, children: [
            Icon(Icons.security_rounded),
            SizedBox(width: 10),
            Expanded(
                child: Text(
                    'لایسنس‌ها به‌صورت آفلاین و با امضای دیجیتال صادر می‌شوند. کلید خصوصی باید فقط در محیط امن مدیر لایسنس نگهداری شود.',
                    textDirection: ui.TextDirection.rtl))
          ]),
        ),
      ),
    ]);
  }

  Widget _buildHero(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: .22),
              blurRadius: 25,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(textDirection: ui.TextDirection.rtl, children: [
        Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 30)),
        const SizedBox(width: 14),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مرکز حرفه‌ای صدور لایسنس',
              textDirection: ui.TextDirection.rtl,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22)),
          SizedBox(height: 5),
          Text(
              'لایسنس امضاشده برای Android و Windows، بر اساس دستگاه، شغل و مدت اشتراک',
              textDirection: ui.TextDirection.rtl,
              style:
                  TextStyle(color: Colors.white70, fontSize: 12, height: 1.5))
        ])),
        const SizedBox(width: 12),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24)),
            child: const Text('کاملاً آفلاین',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _buildStats(ThemeData theme) {
    return Wrap(spacing: 12, runSpacing: 12, children: [
      _statCard(theme, Icons.receipt_long_rounded, 'کل لایسنس‌ها',
          '${_history.length}', theme.colorScheme.primary),
      _statCard(
          theme,
          Icons.android_rounded,
          'Android',
          '${_history.where((x) => x['platform'] == 'ANDROID').length}',
          Colors.green.shade700),
      _statCard(
          theme,
          Icons.desktop_windows_rounded,
          'Windows',
          '${_history.where((x) => x['platform'] == 'WINDOWS').length}',
          Colors.indigo.shade700),
      _statCard(
          theme,
          Icons.schedule_rounded,
          'آخرین صدور',
          _history.isEmpty ? '—' : (_history.first['plan']?.toString() ?? '—'),
          Colors.orange.shade800),
    ]);
  }

  Widget _statCard(
      ThemeData theme, IconData icon, String title, String value, Color color) {
    return Container(
        width: 205,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: .20))),
        child: Row(textDirection: ui.TextDirection.rtl, children: [
          Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    textDirection: ui.TextDirection.rtl,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16))
              ]))
        ]));
  }

  Widget _buildIssueCard(ThemeData theme, List<BusinessProfile> profiles) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: .55))),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(textDirection: ui.TextDirection.rtl, children: const [
            Icon(Icons.vpn_key_rounded),
            SizedBox(width: 8),
            Expanded(
                child: Text('صدور لایسنس جدید',
                    textDirection: ui.TextDirection.rtl,
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 17)))
          ]),
          const SizedBox(height: 16),
          _input(customer, 'نام مشتری / کسبه', Icons.person_outline_rounded),
          const SizedBox(height: 10),
          _input(phone, 'شماره تماس', Icons.phone_outlined,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 10),
          _input(device, 'Hardware / Device ID', Icons.devices_other_rounded,
              helper:
                  'شناسه را از فایل مشخصات دستگاه مشتری وارد کنید یا دقیقاً کپی کنید.'),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _importDeviceCard,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('وارد کردن مشخصات دستگاه مشتری'),
            ),
          ),
          const SizedBox(height: 10),
          _input(note, 'یادداشت', Icons.notes_rounded, maxLines: 2),
          const SizedBox(height: 16),
          const Text('مدت لایسنس',
              textDirection: ui.TextDirection.rtl,
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _durationChip(30, '۱ ماهه'),
            _durationChip(90, '۳ ماهه'),
            _durationChip(180, '۶ ماهه'),
            _durationChip(365, '۱۲ ماهه')
          ]),
          const SizedBox(height: 16),
          const Text('پلتفرم',
              textDirection: ui.TextDirection.rtl,
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<String>(segments: const [
            ButtonSegment(
                value: 'ANDROID',
                label: Text('Android'),
                icon: Icon(Icons.android)),
            ButtonSegment(
                value: 'WINDOWS',
                label: Text('Windows'),
                icon: Icon(Icons.desktop_windows))
          ], selected: {
            platform
          }, onSelectionChanged: (v) => setState(() => platform = v.first)),
          const SizedBox(height: 16),
          const Text('نوع شغل / فروشگاه',
              textDirection: ui.TextDirection.rtl,
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 210,
            decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: .55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: theme.dividerColor.withValues(alpha: .45))),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  FilterChip(
                      label: const Text('همه مشاغل'),
                      selected: selected.contains('*'),
                      onSelected: _selectAllJobs),
                  ...profiles.map(_jobChip)
                ]),
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
              onPressed: _busy ? null : _issue,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.verified_rounded),
              label: Text(_busy ? 'در حال صدور...' : 'صدور و ذخیره لایسنس')),
          if (_lastLicense != null) ...[
            const SizedBox(height: 14),
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12)),
                child: SelectableText(_lastLicense!,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 10))),
          ],
        ]),
      ),
    );
  }

  Widget _input(TextEditingController c, String label, IconData icon,
      {TextInputType? keyboardType, String? helper, int maxLines = 1}) {
    return TextField(
        controller: c,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textDirection: ui.TextDirection.rtl,
        decoration: InputDecoration(
            prefixIcon: Icon(icon), labelText: label, helperText: helper));
  }

  void _selectAllJobs(bool on) {
    setState(() {
      selected.clear();
      if (on) {
        selected.add('*');
      }
    });
  }

  Widget _jobChip(BusinessProfile profile) {
    final code = profile.code;
    final label = profile.label;
    return FilterChip(
        label: Text(label),
        selected: selected.contains(code),
        onSelected: (v) => setState(() {
              selected.remove('*');
              v ? selected.add(code) : selected.remove(code);
            }));
  }

  Widget _durationChip(int value, String label) => ChoiceChip(
      label: Text(
          '$label • ${NumberFormat('#,##0', 'en_US').format(_prices[value] ?? 0)} $_currency'),
      selected: duration == value,
      onSelected: _busy ? null : (_) => setState(() => duration = value));

  Widget _buildHistoryCard(ThemeData theme, {bool tall = false}) {
    final height = tall ? 640.0 : 520.0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: .55))),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(textDirection: ui.TextDirection.rtl, children: [
              const Icon(Icons.history_rounded),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('سوابق لایسنس',
                      textDirection: ui.TextDirection.rtl,
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 17))),
              IconButton(
                  onPressed: _history.isEmpty ? null : () => _load(),
                  tooltip: 'بازخوانی',
                  icon: const Icon(Icons.refresh_rounded))
            ]),
            const SizedBox(height: 10),
            Expanded(
                child: _history.isEmpty
                    ? const Center(child: Text('هنوز لایسنسی صادر نشده است.'))
                    : Scrollbar(
                        thumbVisibility: true,
                        interactive: true,
                        child: ScrollConfiguration(
                          behavior: const MaterialScrollBehavior().copyWith(
                            dragDevices: {
                              ui.PointerDeviceKind.mouse,
                              ui.PointerDeviceKind.touch,
                              ui.PointerDeviceKind.trackpad,
                            },
                          ),
                          child: ListView.separated(
                            primary: false,
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: _history.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) =>
                                _historyTile(theme, _history[i]),
                          ),
                        ),
                      )),
          ]),
        ),
      ),
    );
  }

  Widget _historyTile(ThemeData theme, Map<String, dynamic> item) {
    final name = item['customerName']?.toString() ?? 'بدون نام';
    final id = item['licenseId']?.toString() ?? '';
    final plan = item['plan']?.toString() ?? '';
    final price = (item['priceAtPurchase'] as num?)?.toDouble() ?? 0;
    final currency = item['currency']?.toString() ?? 'تومان';
    final plat = item['platform']?.toString() ?? '';
    final deviceId = item['deviceId']?.toString() ?? '';
    final business = (item['businessTypes'] is List)
        ? (item['businessTypes'] as List).join('، ')
        : '—';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: .60),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(textDirection: ui.TextDirection.rtl, children: [
          CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: .12),
              foregroundColor: theme.colorScheme.primary,
              child: Icon(
                  plat == 'ANDROID' ? Icons.android : Icons.desktop_windows,
                  size: 18)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(name,
                  textDirection: ui.TextDirection.rtl,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(plan,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary)),
            Text('${NumberFormat('#,##0', 'en_US').format(price)} $currency',
                style: TextStyle(
                    fontSize: 10, color: theme.colorScheme.onSurfaceVariant))
          ])
        ]),
        const SizedBox(height: 6),
        Text(id,
            textDirection: ui.TextDirection.ltr,
            style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
        const SizedBox(height: 4),
        SelectableText('دستگاه: $deviceId',
            textDirection: ui.TextDirection.rtl,
            maxLines: 2,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text('شغل: $business',
            textDirection: ui.TextDirection.rtl,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    );
  }
}
