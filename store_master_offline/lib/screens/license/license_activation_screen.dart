import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../services/license/license_service.dart';
import '../../services/local_network_sync_service.dart';
import '../../viewmodels/main_viewmodel.dart';
import '../app_shell.dart';

class LicenseActivationScreen extends StatefulWidget {
  final bool managementMode;

  const LicenseActivationScreen({
    super.key,
    this.managementMode = false,
  });

  @override
  State<LicenseActivationScreen> createState() =>
      _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends State<LicenseActivationScreen> {
  final _codeController = TextEditingController();

  bool _busy = false;
  bool _checkingExisting = true;
  bool _redirecting = false;

  String _deviceId = '';
  String? _error;
  List<DiscoveredStore> _wifiStores = const <DiscoveredStore>[];
  bool _wifiBusy = false;

  Map<int, double> _prices = const <int, double>{
    30: 990000,
    90: 2490000,
    180: 4490000,
    365: 7990000,
  };

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await Future.wait<void>([
      _loadDeviceId(),
      _loadPricing(),
    ]);

    if (!mounted) return;
    await _checkExistingLicense();
    await _discoverWifiStores();
  }

  Future<void> _discoverWifiStores() async {
    if (!mounted) return;
    setState(() => _wifiBusy = true);
    try {
      final stores = await LocalNetworkSyncService.instance.discoverStores(
        wait: const Duration(seconds: 2),
      );
      if (!mounted) return;
      setState(() => _wifiStores = stores);
    } catch (_) {}
    if (mounted) setState(() => _wifiBusy = false);
  }

  Future<void> _joinWifiStore(DiscoveredStore store) async {
    if (_wifiBusy) return;
    setState(() {
      _wifiBusy = true;
      _error = null;
    });
    try {
      await LocalNetworkSyncService.instance.connectToDiscoveredStore(
        store,
        waitForInitialSync: true,
      );
      final vm = context.read<MainViewModel>();
      await vm.loadAll(showLoading: false);
      vm.resetSessionAfterLocalStoreJoin();
      final status = await LicenseService.instance.validate(config: vm.config);
      if (!status.valid) throw StateError(status.message);
      if (!mounted) return;
      _show('فروشگاه «${store.storeName}» انتخاب شد و لایسنس، تنظیمات و اطلاعات فروشگاه از طریق Wi-Fi همگام شد.');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) await _leaveActivationScreen();
    } catch (e) {
      if (mounted) setState(() => _error = 'اتصال به فروشگاه از طریق Wi-Fi ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => _wifiBusy = false);
    }
  }

  Future<void> _loadDeviceId() async {
    try {
      final id = await LicenseService.instance.getDeviceId();

      if (!mounted) return;

      setState(() {
        _deviceId = id;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'خطا در دریافت شناسه دستگاه: $e';
      });
    }
  }

  Future<void> _loadPricing() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}'
        'StoreMasterLicenseManager${Platform.pathSeparator}pricing.json',
      );

      if (!await file.exists()) return;

      final raw = jsonDecode(await file.readAsString());

      if (raw is! Map || raw['prices'] is! Map) return;

      final loaded = <int, double>{};

      for (final entry in (raw['prices'] as Map).entries) {
        final key = int.tryParse(entry.key.toString());

        final value = entry.value is num
            ? (entry.value as num).toDouble()
            : double.tryParse(entry.value.toString());

        if (key != null && value != null && value >= 0) {
          loaded[key] = value;
        }
      }

      if (!mounted || loaded.isEmpty) return;

      setState(() {
        _prices = loaded;
      });
    } catch (_) {
      // لیست قیمت پیش‌فرض حفظ می‌شود.
    }
  }

  Future<void> _checkExistingLicense() async {
    try {
      final vm = context.read<MainViewModel>();

      final status = await LicenseService.instance.validate(
        config: vm.config,
      );

      if (!mounted) return;

      if (status.valid && !widget.managementMode) {
        await _leaveActivationScreen();
        return;
      }
    } catch (_) {
      // در صورت هر خطا، صفحه فعال‌سازی نمایش داده می‌شود.
    } finally {
      if (mounted) {
        setState(() {
          _checkingExisting = false;
        });
      }
    }
  }

  Future<void> _leaveActivationScreen() async {
    if (!mounted || _redirecting) return;

    _redirecting = true;

    final navigator = Navigator.of(context);

    // اگر این صفحه روی یک Route آمده باشد، همان Route را می‌بندیم.
    if (navigator.canPop()) {
      navigator.pop(true);
      return;
    }

    // اگر صفحه فعال‌سازی Route ریشه باشد، AppShell را جایگزین می‌کنیم.
    await navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => const AppShell(),
      ),
    );
  }

  Future<void> _importOfflineRevocations() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      final bytes = picked.bytes;
      final text = bytes != null
          ? utf8.decode(bytes)
          : picked.path == null
              ? ''
              : await File(picked.path!).readAsString();
      if (text.trim().isEmpty) throw const FormatException('فایل ابطال خالی است.');
      final added = await LicenseService.instance.importOfflineRevocationPackage(text);
      if (!mounted) return;
      setState(() {
        _error = added == 0
            ? 'بسته ابطال اعمال شد؛ لایسنس فعلی فقط در صورت وجود در بسته غیرفعال می‌شود.'
            : 'بسته ابطال اعمال شد. $added شناسه لایسنس جدید ثبت شد.';
      });
      await _checkExistingLicense();
    } catch (e) {
      if (mounted) setState(() => _error = 'اعمال بسته ابطال آفلاین ناموفق بود: $e');
    }
  }

  Future<void> _importPricing() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;

      final bytes = picked.bytes;
      final text = bytes != null
          ? utf8.decode(bytes)
          : picked.path == null
              ? ''
              : await File(picked.path!).readAsString();

      if (text.trim().isEmpty) {
        throw const FormatException('فایل لیست قیمت خالی است.');
      }

      final raw = jsonDecode(text);

      if (raw is! Map || raw['prices'] is! Map) {
        throw const FormatException(
          'فایل لیست قیمت معتبر نیست.',
        );
      }

      final loaded = <int, double>{};

      for (final entry in (raw['prices'] as Map).entries) {
        final key = int.tryParse(entry.key.toString());

        final value = entry.value is num
            ? (entry.value as num).toDouble()
            : double.tryParse(entry.value.toString());

        if (key != null && value != null && value >= 0) {
          loaded[key] = value;
        }
      }

      if (loaded.isEmpty) {
        throw const FormatException(
          'هیچ قیمت معتبری داخل فایل پیدا نشد.',
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}'
        'StoreMasterLicenseManager${Platform.pathSeparator}pricing.json',
      );

      await file.parent.create(recursive: true);

      final pricingJson = const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'prices': {
          for (final entry in loaded.entries)
            entry.key.toString(): entry.value,
        },
      });

      await file.writeAsString(pricingJson, encoding: utf8);

      if (!mounted) return;

      setState(() {
        _prices = loaded;
        _error = null;
      });

      _show('لیست قیمت جدید بارگذاری شد.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '').replaceFirst(RegExp(r'^Invalid argument\(s\):\s*'), '');
      });
    }
  }

  void _show(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text)),
      );
  }

  Future<void> _pickLicense() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'json',
          'license',
          'txt',
        ],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;

      final bytes = picked.bytes;

      if (bytes != null) {
        _codeController.text = utf8.decode(bytes);
      } else if (picked.path != null) {
        _codeController.text = await File(
          picked.path!,
        ).readAsString();
      }

      if (mounted) {
        setState(() {
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'خطا در خواندن فایل لایسنس: $e';
      });
    }
  }

  Future<void> _deactivateFromSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ابطال / غیرفعال‌سازی لایسنس'),
        content: const Text(
          'فقط لایسنس فعلی غیرفعال می‌شود. دیتابیس، کالاها، فاکتورها، مشتریان و تنظیمات فروشگاه حذف نخواهند شد. ادامه می‌دهید؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('غیرفعال کن')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() { _busy = true; _error = null; });
    try {
      await LicenseService.instance.deactivateActiveLicense();
      if (!mounted) return;
      _show('لایسنس غیرفعال شد؛ اطلاعات فروشگاه و دیتابیس حفظ شدند. اکنون می‌توانید لایسنس جدید را وارد کنید.');
    } catch (e) {
      if (mounted) setState(() => _error = 'غیرفعال‌سازی لایسنس ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activate() async {
    final licenseText = _codeController.text.trim();

    if (licenseText.isEmpty) {
      setState(() {
        _error = 'فایل یا متن لایسنس را وارد کنید.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final vm = context.read<MainViewModel>();

      await LicenseService.instance.activate(
        licenseText,
        config: vm.config,
      );

      // بعد از ذخیره، همان لایسنس را دوباره validate می‌کنیم.
      final status = await LicenseService.instance.validate(
        config: vm.config,
      );

      if (!status.valid) {
        throw StateError(
          status.message,
        );
      }

      await vm.loadAll();

      if (!mounted) return;

      _show('لایسنس با موفقیت فعال شد.');

      await Future<void>.delayed(
        const Duration(milliseconds: 250),
      );

      if (!mounted) return;

      if (!widget.managementMode) {
        await _leaveActivationScreen();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<MainViewModel>().config;

    if (_checkingExisting) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.managementMode ? 'مدیریت و تعویض لایسنس StoreMaster Pro' : 'فعال‌سازی لایسنس StoreMaster Pro',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 780,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 58,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'برای استفاده از برنامه، لایسنس معتبر این دستگاه را فعال کنید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (widget.managementMode) ...[
                      const SizedBox(height: 8),
                      Card(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'مدیریت لایسنس',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'تعویض یا ابطال لایسنس فقط مجوز برنامه را تغییر می‌دهد و اطلاعات فروشگاه و دیتابیس حذف نمی‌شود.',
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _deactivateFromSettings,
                                icon: const Icon(Icons.block_outlined),
                                label: const Text('ابطال / غیرفعال‌سازی لایسنس فعلی'),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _importOfflineRevocations,
                                icon: const Icon(Icons.gpp_bad_outlined),
                                label: const Text('اعمال فایل ابطال صادرشده توسط مدیر'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      'فروشگاه: ${config?.storeName ?? '—'}',
                    ),
                    Text(
                      'نوع فعالیت: ${config?.businessTitle ?? config?.storeType ?? '—'}',
                    ),
                    const SizedBox(height: 12),
                    const Text('شناسه دستگاه:'),
                    SelectableText(
                      _deviceId.isEmpty
                          ? 'در حال دریافت...'
                          : _deviceId,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed:
                          _deviceId.isEmpty || _busy
                              ? null
                              : () async {
                                  try {
                                    final path =
                                        await LicenseService.instance
                                            .exportDeviceCard(
                                      config: config,
                                    );

                                    if (!mounted) return;

                                    _show(
                                      'مشخصات دستگاه ذخیره شد: $path',
                                    );
                                  } catch (e) {
                                    if (!mounted) return;

                                    setState(() {
                                      _error =
                                          'خطا در ذخیره مشخصات دستگاه: $e';
                                    });
                                  }
                                },
                      icon: const Icon(
                        Icons.save_alt,
                      ),
                      label: const Text(
                        'ذخیره مشخصات دستگاه برای ارسال به فروشنده',
                      ),
                    ),
                    if (Platform.isAndroid) ...[
                      const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.wifi_rounded),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'انتخاب فروشگاه از همین Wi-Fi',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _wifiBusy ? null : _discoverWifiStores,
                                  tooltip: 'جستجوی دوباره',
                                  icon: _wifiBusy
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.refresh_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_wifiStores.isEmpty)
                              const Text(
                                'فروشگاه مشترکی پیدا نشد. ویندوز و Android باید روی یک Wi-Fi باشند و لایسنس Shared فعال باشد.',
                              ),
                            for (final store in _wifiStores)
                              ListTile(
                                dense: true,
                                leading: const CircleAvatar(child: Icon(Icons.store_rounded)),
                                title: Text(store.storeName),
                                subtitle: Text(
                                  [
                                    if (store.storeCode.trim().isNotEmpty) 'کد: ${store.storeCode}',
                                    'حداکثر دستگاه: ${store.maxDevices}',
                                    if (store.expiresAt > 0) 'تا ${DateFormat('yyyy/MM/dd').format(DateTime.fromMillisecondsSinceEpoch(store.expiresAt))}',
                                  ].join(' • '),
                                ),
                                trailing: const Icon(Icons.chevron_left_rounded),
                                onTap: _wifiBusy ? null : () => _joinWifiStore(store),
                              ),
                          ],
                        ),
                      ),
                    ),
                    ],
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'قیمت فعلی لایسنس‌ها',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final days in const [
                              30,
                              90,
                              180,
                              365,
                            ])
                              Text(
                                '${switch (days) {
                                  30 => '۱ ماهه',
                                  90 => '۳ ماهه',
                                  180 => '۶ ماهه',
                                  365 => '۱۲ ماهه',
                                  _ => 'پلن',
                                }}: ${NumberFormat(
                                  '#,##0',
                                  'en_US',
                                ).format(_prices[days] ?? 0)} تومان',
                              ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed:
                                  _busy ? null : _importPricing,
                              icon: const Icon(
                                Icons.price_change_outlined,
                              ),
                              label: const Text(
                                'بارگذاری آخرین لیست قیمت فروشنده',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _codeController,
                      maxLines: 10,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'محتوای فایل لایسنس',
                        hintText:
                            'JSON لایسنس را اینجا قرار دهید',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed:
                          _busy ? null : _pickLicense,
                      icon: const Icon(
                        Icons.folder_open,
                      ),
                      label: const Text(
                        'انتخاب فایل لایسنس',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _importOfflineRevocations,
                      icon: const Icon(Icons.gpp_bad_outlined),
                      label: const Text('اعمال بسته ابطال آفلاین'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed:
                          _busy ? null : _activate,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.key),
                      label: Text(
                        _busy
                            ? 'در حال بررسی...'
                            : 'فعال‌سازی لایسنس',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
