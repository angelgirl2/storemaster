// ignore_for_file: unnecessary_non_null_assertion, unused_element, unused_import
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../catalog/business_catalog.dart';
import '../catalog/feature_catalog.dart';
import '../models/license_models.dart';
import '../services/license_repository.dart';
import '../services/license_revocation_service.dart';
import '../services/license_signer.dart';
import '../services/online_admin_service.dart';
import 'stores_screen.dart';
import 'support_inbox_screen.dart';
import 'dart:typed_data';

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
  final discountCode = TextEditingController();
  final TextEditingController _historySearch = TextEditingController();
  final ScrollController _jobsScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();
  final Set<String> selected = <String>{};
  final Set<String> selectedTrialFeatures = <String>{
    'sales',
    'customers',
    'products'
  };
  int duration = 30;
  Map<int, double> _prices = <int, double>{...LicenseRepository.defaultPrices};
  static const String _currency = 'تومان';
  String platform = 'ALL';
  bool _busy = false;
  double? _quotedOriginalPrice;
  double? _quotedFinalPrice;
  int _discountPercent = 0;
  String _appliedDiscountCode = '';
  bool _dark = false;
  int _seedIndex = 0;
  int _section = 0;
  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];
  String? _lastLicense;
  // این فیلد عمداً mutable است و در PopupMenuButton تغییر می‌کند.
  // ignore: prefer_final_fields
  String _historyStatusFilter = 'ALL';
  static const _navItems = <({IconData icon, String title})>[
    (
      icon: Icons.dashboard_rounded,
      title: 'داشبورد',
    ),
    (
      icon: Icons.vpn_key_rounded,
      title: 'صدور لایسنس',
    ),
    (
      icon: Icons.store_rounded,
      title: 'فروشگاه‌ها',
    ),
    (
      icon: Icons.history_rounded,
      title: 'سوابق لایسنس',
    ),
    (
      icon: Icons.support_agent_rounded,
      title: 'تیکت‌های پشتیبانی',
    ),
    (
      icon: Icons.settings_rounded,
      title: 'تنظیمات',
    ),
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
    discountCode.dispose();
    _historySearch.dispose();
    _jobsScrollController.dispose();
    _historyScrollController.dispose();
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
      _msg(
        'خطا در بارگذاری سوابق لایسنس: $e',
        error: true,
      );
    }
  }

  List<Map<String, dynamic>> get _filteredHistory {
    final q = _historySearch.text.trim().toLowerCase();
    return _history.where((item) {
      final status = (item['status']?.toString() ?? 'ACTIVE').toUpperCase();
      if (_historyStatusFilter != 'ALL' && status != _historyStatusFilter) {
        return false;
      }
      if (q.isEmpty) {
        return true;
      }
      final fields = <String>[
        item['licenseId']?.toString() ?? '',
        item['customerName']?.toString() ?? '',
        item['phone']?.toString() ?? '',
        item['deviceId']?.toString() ?? '',
        item['platform']?.toString() ?? '',
        item['businessTypes']?.toString() ?? '',
      ].join(' ').toLowerCase();
      return fields.contains(q);
    }).toList();
  }

  String _newOnlinePin() => List<String>.generate(
        8,
        (_) => Random.secure().nextInt(10).toString(),
      ).join();

  Future<Map<String, dynamic>?> _registerOnlineLicense(
    LicensePayload payload, {
    required double originalPrice,
    required double finalPrice,
    String discountCode = '',
  }) async {
    if (!OnlineAdminService.onlineEnabled) return null;

    final deviceId = payload.deviceId.trim().toUpperCase();
    if (payload.deviceBinding.toUpperCase() == 'STORE_SHARED' ||
        !RegExp(r'^[0-9A-F]{64}$').hasMatch(deviceId)) {
      throw StateError(
        'برای کنترل از راه دور، لایسنس باید به شناسه سخت‌افزاری ۶۴ کاراکتری یک دستگاه مشخص متصل باشد. '
        'در نسخه آنلاین، «همه دستگاه‌ها / SHARED» از کنترل متمرکز پشتیبانی نمی‌کند.',
      );
    }

    // The PIN is generated locally, sent over HTTPS to the server, and only
    // shown once to the License Manager operator after the whole flow succeeds.
    final onlinePin = _newOnlinePin();
    final response = await OnlineAdminService.instance.registerLicenseByDevice(
      deviceId: deviceId,
      licenseId: payload.licenseId,
      customerName: payload.customerName,
      phone: payload.phone,
      plan: payload.plan,
      expiresAt: payload.expiresAt,
      originalPrice: originalPrice,
      finalPrice: finalPrice,
      features: payload.features,
      businessTypes: payload.businessTypes,
      platform: payload.platform,
      password: onlinePin,
      discountCode: discountCode,
    );
    final userId = (response['userId'] as num?)?.toInt() ?? 0;
    final storeCode = '${response['storeCode'] ?? ''}'.trim();
    if (userId <= 0 || storeCode.isEmpty) {
      throw StateError('سرور لایسنس را ثبت کرد، اما شناسه ورود آنلاین برنگرداند. پاسخ سرور را بررسی کنید.');
    }
    return <String, dynamic>{
      'storeCode': storeCode,
      'userId': userId,
      'username': '${response['username'] ?? 'admin'}',
      'pin': onlinePin,
      'expiresAt': payload.expiresAt,
    };
  }

  Future<void> _showOnlineCredentials(Map<String, dynamic>? credentials) async {
    if (!mounted || credentials == null) return;
    final text = 'اطلاعات ورود آنلاین StoreMaster\n'
        'کد فروشگاه: ${credentials['storeCode']}\n'
        'شناسه کاربر: ${credentials['userId']}\n'
        'نام کاربری: ${credentials['username']}\n'
        'رمز / PIN: ${credentials['pin']}\n'
        'اعتبار تا: ${DateTime.fromMillisecondsSinceEpoch((credentials['expiresAt'] as num).toInt())}\n\n'
        'این اطلاعات را فقط به صاحب فروشگاه تحویل دهید.';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اطلاعات ورود آنلاین ایجاد شد'),
        content: SelectableText(text, textDirection: ui.TextDirection.rtl),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) _msg('اطلاعات ورود کپی شد؛ آن را امن به مشتری تحویل دهید.');
            },
            child: const Text('کپی اطلاعات ورود'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن')),
        ],
      ),
    );
  }

  Future<void> _deleteHistoryItem(
    Map<String, dynamic> item,
  ) async {
    final id = item['licenseId']?.toString().trim() ?? '';
    if (id.isEmpty) {
      _msg(
        'شناسه لایسنس پیدا نشد.',
        error: true,
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف سابقه'),
        content: Text(
          'سابقه محلی لایسنس «$id» حذف شود؟\n\n'
          'برای لایسنس‌هایی که در سرور ثبت شده‌اند، ابتدا وضعیت سرور به لغوشده تغییر می‌کند. '
          'حذف سابقه به معنی حذف سوابق حسابرسی سرور نیست.', 
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final isServerSynced = item['serverSynced'] == true;
      if (OnlineAdminService.onlineEnabled && isServerSynced) {
        await OnlineAdminService.instance.setLicenseStatus(id, 'CANCELLED');
      }
      final deleted = await LicenseRepository.instance.deleteByLicenseId(id);
      if (!mounted) return;
      await _load();
      final message = !deleted
          ? 'سابقه پیدا نشد.'
          : OnlineAdminService.onlineEnabled && isServerSynced
              ? 'لایسنس در سرور لغو و سابقه محلی حذف شد.'
              : 'سابقه محلی حذف شد؛ این لایسنس در سرور ثبت نشده بود و از راه دور باطل نشد.';
      _msg(message, error: !deleted);
    } catch (e) {
      if (mounted) {
        _msg(
          'خطا در حذف سابقه: $e',
          error: true,
        );
      }
    }
  }

  Future<void> _clearHistory() async {
    if (_history.isEmpty) {
      _msg(
        'سابقه‌ای برای حذف وجود ندارد.',
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف همه سوابق'),
        content: Text(
          'تمام ${_history.length} سابقه حذف شود؟\n\n'
          'این کار فقط آرشیو License Manager را '
          'پاک می‌کند.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف همه'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final count = await LicenseRepository.instance.clearHistory();
      if (!mounted) return;
      await _load();
      _msg('$count سابقه حذف شد.');
    } catch (e) {
      if (mounted) {
        _msg(
          'خطا در حذف سوابق: $e',
          error: true,
        );
      }
    }
  }

  Future<void> _exportRevocationPackage() async {
    try {
      final path = await LicenseRevocationService.instance.exportSignedPackage();
      if (!mounted) return;
      _msg('بسته ابطال آفلاین ساخته شد: $path');
    } catch (e) {
      if (mounted) _msg('خطا در ساخت بسته ابطال: $e', error: true);
    }
  }

  Future<void> _changeStatus(
    Map<String, dynamic> item,
    String status,
  ) async {
    final id = item['licenseId']?.toString().trim() ?? '';
    if (id.isEmpty) return;
    final label = status == 'SUSPENDED' ? 'تعلیق' : 'لغو';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label لایسنس'),
        content: Text(
          'وضعیت لایسنس «$id» به «$label» تغییر کند؟\n\n'
          'این تغییر در سوابق License Manager ثبت می‌شود.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  status == 'SUSPENDED' ? Colors.orange : Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(label),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final isServerSynced = item['serverSynced'] == true;
      if (OnlineAdminService.onlineEnabled && isServerSynced) {
        await OnlineAdminService.instance.setLicenseStatus(id, status);
      }
      final changed = await LicenseRepository.instance.updateStatus(
        id,
        status,
      );
      if (!mounted) return;
      await _load();
      final message = !changed
          ? 'لایسنس پیدا نشد.'
          : OnlineAdminService.onlineEnabled && isServerSynced
              ? 'وضعیت لایسنس در سرور و License Manager تغییر کرد.'
              : 'وضعیت فقط در این License Manager تغییر کرد؛ این لایسنس به سرور متصل نیست.';
      _msg(message, error: !changed);
    } catch (e) {
      if (mounted) {
        _msg(
          'خطا در تغییر وضعیت: $e',
          error: true,
        );
      }
    }
  }

  Future<void> _renew(
    Map<String, dynamic> item,
  ) async {
    final selectedDays = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('تمدید لایسنس'),
        children: [
          for (final days in const [
            30,
            90,
            180,
            365,
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(
                ctx,
                days,
              ),
              child: Text(
                '${switch (days) {
                  30 => '۱ ماهه',
                  90 => '۳ ماهه',
                  180 => '۶ ماهه',
                  365 => '۱۲ ماهه',
                  _ => '$days روز',
                }} • ${NumberFormat(
                  '#,##0',
                  'en_US',
                ).format(
                  _prices[days] ?? 0,
                )} $_currency',
              ),
            ),
        ],
      ),
    );
    if (selectedDays == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final price = _prices[selectedDays] ?? 0;
      if (price <= 0) {
        throw StateError(
          'قیمت مدت انتخاب‌شده تعیین نشده است.',
        );
      }
      final oldId = item['licenseId']?.toString() ?? '';
      final id = 'SM-${_randomReadable()}';
      final business = item['businessTypes'] is List
          ? (item['businessTypes'] as List)
              .map(
                (e) => e.toString(),
              )
              .toList()
          : <String>[];
      final payload = LicensePayload(
        licenseId: id,
        customerName: item['customerName']?.toString() ?? '',
        phone: item['phone']?.toString() ?? '',
        businessTypes: business,
        deviceId: item['deviceId']?.toString() ?? '',
        platform: item['platform']?.toString() ?? 'WINDOWS',
        plan: switch (selectedDays) {
          30 => '1M',
          90 => '3M',
          180 => '6M',
          365 => '12M',
          _ => 'CUSTOM',
        },
        durationDays: selectedDays,
        issuedAt: now.millisecondsSinceEpoch,
        expiresAt: now
            .add(
              Duration(
                days: selectedDays,
              ),
            )
            .millisecondsSinceEpoch,
        priceAtPurchase: price,
        currency: _currency,
        features: const <String>[
          'FULL',
        ],
      );
      final signature = await LicenseSigner.sign(payload);
      if (!await LicenseSigner.selfTest(payload, signature)) {
        throw StateError('خطای داخلی امضای لایسنس: کلید خصوصی و عمومی با هم منطبق نیستند.');
      }
      final doc = LicenseDocument(
        payload: payload,
        signatureBase64: signature,
      );
      final oldIsServerSynced = item['serverSynced'] == true;
      var oldRemoteSuspended = false;
      if (OnlineAdminService.onlineEnabled && oldIsServerSynced) {
        await OnlineAdminService.instance.setLicenseStatus(oldId, 'RENEWED');
        oldRemoteSuspended = true;
      }
      Map<String, dynamic>? onlineCredentials;
      try {
        onlineCredentials = await _registerOnlineLicense(
          payload,
          originalPrice: price,
          finalPrice: price,
        );
      } catch (_) {
        if (oldRemoteSuspended) {
          try {
            await OnlineAdminService.instance.setLicenseStatus(oldId, 'ACTIVE');
          } catch (_) {
            // The UI reports the original error; a later server check is required if rollback also fails.
          }
        }
        rethrow;
      }
      await LicenseRepository.instance.updateStatus(
        oldId,
        'RENEWED',
        note: 'با لایسنس $id تمدید شد.',
      );
      await LicenseRepository.instance.add(
        payload,
        status: 'ACTIVE',
        note: 'تمدید لایسنس $oldId',
        originalPrice: price,
        finalPrice: price,
        serverSynced: OnlineAdminService.onlineEnabled,
      );
      final path = await _saveFile(
        doc.toJson(),
        id,
      );
      if (!mounted) return;
      await _load();
      _msg(
        'لایسنس جدید برای تمدید صادر شد و در $path ذخیره شد.',
      );
      await _showOnlineCredentials(onlineCredentials);
    } catch (e) {
      if (mounted) {
        _msg(
          'خطا در تمدید: $e',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(
          () => _busy = false,
        );
      }
    }
  }

  Future<String> _exportExcelHistory() async {
    final rows = _filteredHistory;
    final book = Excel.createExcel();
    const sheetName = 'سوابق لایسنس';
    final defaultSheet = book.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      book.rename(
        defaultSheet,
        sheetName,
      );
    }
    final sheet = book[sheetName];
    sheet.appendRow([
      TextCellValue(
        'شناسه لایسنس',
      ),
      TextCellValue('مشتری'),
      TextCellValue('تلفن'),
      TextCellValue('Device ID'),
      TextCellValue('پلتفرم'),
      TextCellValue('پلن'),
      TextCellValue('مبلغ'),
      TextCellValue('واحد پول'),
      TextCellValue('وضعیت'),
      TextCellValue('شروع'),
      TextCellValue('انقضا'),
      TextCellValue('شغل‌ها'),
    ]);
    for (final item in rows) {
      sheet.appendRow([
        TextCellValue(
          item['licenseId']?.toString() ?? '',
        ),
        TextCellValue(
          item['customerName']?.toString() ?? '',
        ),
        TextCellValue(
          item['phone']?.toString() ?? '',
        ),
        TextCellValue(
          item['deviceId']?.toString() ?? '',
        ),
        TextCellValue(
          item['platform']?.toString() ?? '',
        ),
        TextCellValue(
          item['plan']?.toString() ?? '',
        ),
        DoubleCellValue(
          item['priceAtPurchase'] is num
              ? (item['priceAtPurchase'] as num).toDouble()
              : double.tryParse(
                    item['priceAtPurchase']?.toString() ?? '',
                  ) ??
                  0,
        ),
        TextCellValue(
          item['currency']?.toString() ?? _currency,
        ),
        TextCellValue(
          _statusLabel(
            item['status']?.toString(),
          ),
        ),
        TextCellValue(
          _formatDateMillis(
            item['issuedAt'],
          ),
        ),
        TextCellValue(
          _formatDateMillis(
            item['expiresAt'],
          ),
        ),
        TextCellValue(
          item['businessTypes'] is List
              ? (item['businessTypes'] as List).join('، ')
              : '',
        ),
      ]);
    }
    for (var i = 0; i < 12; i++) {
      sheet.setColumnWidth(
        i,
        i == 0 || i == 3 ? 28 : 18,
      );
    }
    final bytes = book.save();
    if (bytes == null) {
      throw StateError(
        'ساخت Excel ناموفق بود.',
      );
    }
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(
      p.join(
        dir.path,
        'StoreMasterLicenseManager',
        'exports',
      ),
    );
    await folder.create(
      recursive: true,
    );
    final file = File(
      p.join(
        folder.path,
        'سوابق_لایسنس_'
        '${DateTime.now().millisecondsSinceEpoch}.xlsx',
      ),
    );
    await file.writeAsBytes(
      bytes,
      flush: true,
    );
    return file.path;
  }

  Future<String> _exportPdfHistory() async {
    final rows = _filteredHistory;
    final pdf = pw.Document(
      title: 'سوابق لایسنس StoreMaster',
    );
    final font = await _loadPdfFont();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(
          24,
        ),
        build: (_) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'سوابق لایسنس StoreMaster',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(
                  height: 6,
                ),
                pw.Text(
                  'تعداد: ${rows.length}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 9,
                  ),
                ),
                pw.SizedBox(
                  height: 12,
                ),
                pw.TableHelper.fromTextArray(
                  headers: const [
                    'وضعیت',
                    'مشتری',
                    'پلن',
                    'پلتفرم',
                    'مبلغ',
                    'تاریخ انقضا',
                  ],
                  data: rows.map(
                    (item) {
                      final price = item['priceAtPurchase'] is num
                          ? (item['priceAtPurchase'] as num).toDouble()
                          : double.tryParse(
                                item['priceAtPurchase']?.toString() ?? '',
                              ) ??
                              0;
                      return [
                        _statusLabel(
                          item['status']?.toString(),
                        ),
                        item['customerName']?.toString() ?? '',
                        item['plan']?.toString() ?? '',
                        item['platform']?.toString() ?? '',
                        '${NumberFormat(
                          '#,##0',
                          'en_US',
                        ).format(
                          price,
                        )} '
                            '${item['currency'] ?? _currency}',
                        _formatDateMillis(
                          item['expiresAt'],
                        ),
                      ];
                    },
                  ).toList(),
                  headerStyle: pw.TextStyle(
                    font: font,
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  cellStyle: pw.TextStyle(
                    font: font,
                    fontSize: 7,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                  cellAlignment: pw.Alignment.center,
                  border: pw.TableBorder.all(
                    color: PdfColors.grey500,
                    width: .4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(
      p.join(
        dir.path,
        'StoreMasterLicenseManager',
        'exports',
      ),
    );
    await folder.create(
      recursive: true,
    );
    final file = File(
      p.join(
        folder.path,
        'سوابق_لایسنس_'
        '${DateTime.now().millisecondsSinceEpoch}.pdf',
      ),
    );
    await file.writeAsBytes(
      bytes,
      flush: true,
    );
    return file.path;
  }

  // =======================
  // PDF FONT
  // =====================
  Future<pw.Font> _loadPdfFont() async {
    final candidates = <String>[
      if (Platform.isWindows) r'C:\Windows\Fonts\tahoma.ttf',
      if (Platform.isWindows) r'C:\Windows\Fonts\arial.ttf',
      if (Platform.isLinux) '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ];
    for (final path in candidates) {
      final file = File(path);
      if (!await file.exists()) {
        continue;
      }
      try {
        final bytes = await file.readAsBytes();
        final byteData = bytes.buffer.asByteData(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
        return pw.Font.ttf(
          byteData,
        );
      } catch (_) {
        continue;
      }
    }
    return pw.Font.helvetica();
  }

  String _formatDateMillis(
    dynamic value,
  ) {
    final millis = value is num
        ? value.toInt()
        : int.tryParse(
              value?.toString() ?? '',
            ) ??
            0;
    if (millis <= 0) {
      return '—';
    }
    return DateFormat(
      'yyyy/MM/dd HH:mm',
    ).format(
      DateTime.fromMillisecondsSinceEpoch(
        millis,
      ),
    );
  }

  String _statusLabel(
    String? raw,
  ) {
    switch ((raw ?? 'ACTIVE').toUpperCase()) {
      case 'SUSPENDED':
        return 'تعلیق';
      case 'CANCELLED':
        return 'لغو شده';
      case 'RENEWED':
        return 'تمدید شده';
      case 'ACTIVE':
        return 'فعال';
      default:
        return raw ?? 'فعال';
    }
  }

  Future<void> _importDeviceCard() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }
      final picked = result.files.single;
      final bytes = picked.bytes;
      final text = bytes != null
          ? utf8.decode(
              bytes,
            )
          : (picked.path == null
              ? ''
              : await File(
                  picked.path!,
                ).readAsString());
      if (text.trim().isEmpty) {
        throw const FormatException(
          'فایل مشخصات دستگاه خالی است.',
        );
      }
      String? importedDevice;
      String? importedPlatform;
      for (final rawLine in text.split(
        RegExp(
          r'\r?\n',
        ),
      )) {
        final line = rawLine.trim();
        final lower = line.toLowerCase();
        if (lower.startsWith(
          'device id:',
        )) {
          importedDevice = line
              .substring(
                line.indexOf(':') + 1,
              )
              .trim();
        } else if (lower.startsWith(
          'platform:',
        )) {
          importedPlatform = line
              .substring(
                line.indexOf(':') + 1,
              )
              .trim()
              .toUpperCase();
        }
      }
      if (importedDevice == null || importedDevice!.trim().isEmpty) {
        throw const FormatException(
          'Device ID داخل فایل پیدا نشد.',
        );
      }
      final normalizedDevice = importedDevice.trim().toUpperCase();
      if (!RegExp(
        r'^[0-9A-F]{64}$',
      ).hasMatch(
        normalizedDevice,
      )) {
        throw const FormatException(
          'Device ID باید ۶۴ کاراکتر هگزادسیمال باشد.',
        );
      }
      if (importedPlatform != 'ANDROID' && importedPlatform != 'WINDOWS') {
        throw const FormatException(
          'پلتفرم دستگاه باید ANDROID یا WINDOWS باشد.',
        );
      }
      if (!mounted) return;
      setState(() {
        device.text = normalizedDevice;
        platform = importedPlatform!;
      });
      _msg(
        'شناسه دستگاه و پلتفرم با موفقیت وارد شد.',
      );
    } catch (e) {
      if (mounted) {
        _msg(
          'خطا در خواندن مشخصات دستگاه: $e',
          error: true,
        );
      }
    }
  }

  Future<void> _openDiscountDialog() async {
    final codeCtrl = TextEditingController(text: discountCode.text);
    final percentCtrl = TextEditingController(text: '10');
    final fixedCtrl = TextEditingController(text: '0');
    final maxUsesCtrl = TextEditingController(text: '0');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ساخت کد تخفیف'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: codeCtrl,
                      textDirection: ui.TextDirection.ltr,
                      decoration: const InputDecoration(labelText: 'کد تخفیف')),
                  TextField(
                      controller: percentCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'درصد تخفیف')),
                  TextField(
                      controller: fixedCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'تخفیف مبلغی ($_currency)')),
                  TextField(
                      controller: maxUsesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'حداکثر دفعات استفاده (۰ = نامحدود)')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('انصراف')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('ساخت کد')),
          ],
        ),
      );
      if (ok != true) return;
      final code = codeCtrl.text.trim().toUpperCase();
      final percent = int.tryParse(percentCtrl.text.trim()) ?? 0;
      final fixed =
          double.tryParse(fixedCtrl.text.replaceAll(',', '').trim()) ?? 0;
      final maxUses = int.tryParse(maxUsesCtrl.text.trim()) ?? 0;
      if (code.isEmpty) throw StateError('کد تخفیف الزامی است.');
      await OnlineAdminService.instance.createDiscount(
        code: code,
        percent: percent.clamp(0, 100),
        fixedAmount: fixed < 0 ? 0 : fixed,
        maxUses: maxUses < 0 ? 0 : maxUses,
      );
      if (!mounted) return;
      discountCode.text = code;
      _msg('کد تخفیف $code با موفقیت روی سرور ثبت شد.');
      setState(() {});
    } catch (e) {
      if (mounted) _msg('خطا در ساخت کد تخفیف: $e', error: true);
    } finally {
      codeCtrl.dispose();
      percentCtrl.dispose();
      fixedCtrl.dispose();
      maxUsesCtrl.dispose();
    }
  }

  Future<void> _applyDiscount() async {
    final code = discountCode.text.trim();
    if (code.isEmpty) {
      _msg(
        'ابتدا کد تخفیف را وارد کنید.',
        error: true,
      );
      return;
    }
    final original = _prices[duration] ?? 0;
    try {
      // ==========================
      // ONLINE DISCOUNT - FUTURE
      // فعال‌سازی در آینده
      // final quote =
      //     await OnlineAdminService.instance.quoteDiscount(
      //       code: code,
      //       originalPrice: original,
      //     );
      //
      // final finalPrice =
      //     (quote['finalPrice'] as num?)?.toDouble();
      //
      // if (finalPrice == null) {
      //   throw StateError(
      //     'قیمت نهایی از سرور دریافت نشد.',
      //   );
      // }
      // ======================
      // حالت فعلی آفلاین
      setState(() {
        _quotedOriginalPrice = original;
        _quotedFinalPrice = original;
        _discountPercent = 0;
        _appliedDiscountCode = code;
      });
      _msg(
        'کد تخفیف ذخیره شد.',
      );
    } catch (e) {
      if (mounted) {
        _msg(
          'خطا در اعمال تخفیف: $e',
          error: true,
        );
      }
    }
  }

  Future<void> _createTrial(List<BusinessProfile> profiles) async {
    final trialBusinesses = <String>{...selected};
    final trialFeatures = <String>{...selectedTrialFeatures};
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('ساخت Trial برای لایسنس'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Trial اینجا به‌عنوان یک لایسنس واقعی ثبت می‌شود و دقیقاً ۱۵ روز اعتبار دارد.',
                    textDirection: ui.TextDirection.rtl,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: const [
                      Icon(Icons.timer_outlined),
                      SizedBox(width: 8),
                      Expanded(child: Text('مدت Trial: ۱۵ روز')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('مشاغل مجاز',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      FilterChip(
                        label: const Text('همه مشاغل'),
                        selected: trialBusinesses.contains('*'),
                        onSelected: (v) => setDialogState(() {
                          trialBusinesses.clear();
                          if (v) trialBusinesses.add('*');
                        }),
                      ),
                      ...profiles.map((profile) => FilterChip(
                            label: Text(profile.label),
                            selected: trialBusinesses.contains(profile.code),
                            onSelected: (v) => setDialogState(() {
                              trialBusinesses.remove('*');
                              if (v) {
                                trialBusinesses.add(profile.code);
                              } else {
                                trialBusinesses.remove(profile.code);
                              }
                            }),
                          )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('دسترسی ماژول‌ها',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...FeatureCatalog.allFeatures.map((feature) => FilterChip(
                            label: Text(_featureLabel(feature)),
                            selected: trialFeatures.contains(feature),
                            onSelected: (v) => setDialogState(() {
                              if (v) {
                                trialFeatures.add(feature);
                              } else {
                                trialFeatures.remove(feature);
                              }
                            }),
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('انصراف')),
            FilledButton.icon(
              onPressed: () {
                if (trialBusinesses.isEmpty) return;
                if (trialFeatures.isEmpty) return;
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.verified_rounded),
              label: const Text('ساخت Trial'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    if (trialBusinesses.isEmpty) {
      _msg('حداقل یک شغل برای Trial انتخاب کنید.', error: true);
      return;
    }
    if (trialFeatures.isEmpty) {
      _msg('حداقل یک دسترسی برای Trial انتخاب کنید.', error: true);
      return;
    }
    if (customer.text.trim().isEmpty) {
      _msg('نام مشتری / کسبه برای ساخت Trial الزامی است.', error: true);
      return;
    }
    final trialShared = platform == 'ALL' && !OnlineAdminService.onlineEnabled;
    final normalizedDevice = trialShared ? 'SHARED' : device.text.trim().toUpperCase();
    if (!trialShared && !RegExp(r'^[0-9A-F]{64}$').hasMatch(normalizedDevice)) {
      _msg('شناسه دستگاه Trial باید ۶۴ کاراکتر هگزادسیمال باشد.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      var finalTrialBusinesses = <String>{...trialBusinesses};
      var finalTrialFeatures = <String>{...trialFeatures};
      if (OnlineAdminService.onlineEnabled) {
        final policy = await OnlineAdminService.instance.getTrialPolicy();
        final permittedBusinesses = <String>{
          for (final value in (policy['businessTypes'] as List? ?? const []))
            '$value'.trim().toUpperCase(),
        };
        final permittedFeatures = <String>{
          for (final value in (policy['features'] as List? ?? const []))
            '$value'.trim().toLowerCase(),
        };
        if (permittedBusinesses.isEmpty || permittedFeatures.isEmpty) {
          throw StateError('سیاست مرکزی Trial در سرور خالی است؛ ابتدا آن را در تنظیمات تعیین کنید.');
        }
        if (finalTrialBusinesses.contains('*')) {
          if (!permittedBusinesses.contains('*')) {
            finalTrialBusinesses = permittedBusinesses;
          }
        } else if (!permittedBusinesses.contains('*')) {
          finalTrialBusinesses = finalTrialBusinesses.intersection(permittedBusinesses);
        }
        finalTrialFeatures = finalTrialFeatures.intersection(permittedFeatures);
        if (finalTrialBusinesses.isEmpty || finalTrialFeatures.isEmpty) {
          throw StateError('انتخاب این Trial با سیاست مرکزی مدیر هم‌خوانی ندارد. تنظیمات Trial را بررسی کنید.');
        }
      }
      final effectiveShared = platform == 'ALL' && !OnlineAdminService.onlineEnabled;
      if (OnlineAdminService.onlineEnabled && (finalTrialBusinesses.contains('*') || finalTrialBusinesses.length != 1)) {
        throw StateError('برای Trial آنلاین، یک نوع کسب‌وکار مشخص انتخاب کنید تا کنترل لایسنس دقیق باشد.');
      }
      final now = DateTime.now();
      final expires = now.add(const Duration(days: 15));
      final id = 'TRIAL-${_randomReadable()}';
      final payload = LicensePayload(
        licenseId: id,
        customerName: customer.text.trim(),
        phone: phone.text.trim(),
        businessTypes: finalTrialBusinesses.toList(),
        deviceId: normalizedDevice,
        platform: platform,
        deviceBinding: effectiveShared ? 'STORE_SHARED' : 'DEVICE',
        maxDevices: effectiveShared ? 10 : 1,
        plan: 'TRIAL',
        durationDays: 15,
        issuedAt: now.millisecondsSinceEpoch,
        expiresAt: expires.millisecondsSinceEpoch,
        priceAtPurchase: 0,
        currency: _currency,
        features: finalTrialFeatures.toList(),
      );
      final signature = await LicenseSigner.sign(payload);
      if (!await LicenseSigner.selfTest(payload, signature)) {
        throw StateError('خطای داخلی امضای لایسنس: کلید خصوصی و عمومی با هم منطبق نیستند.');
      }
      final document =
          LicenseDocument(payload: payload, signatureBase64: signature);
      final onlineCredentials = await _registerOnlineLicense(
        payload,
        originalPrice: 0,
        finalPrice: 0,
      );
      await LicenseRepository.instance.add(
        payload,
        status: 'ACTIVE',
        note: 'Trial ۱۵ روزه با دسترسی مجاز مدیر',
        originalPrice: 0,
        finalPrice: 0,
        serverSynced: OnlineAdminService.onlineEnabled,
      );
      final path = await _saveFile(document.toJson(), id);
      if (!mounted) return;
      setState(() => _lastLicense = document.toJson());
      await _load();
      _msg('Trial ۱۵ روزه ساخته شد و در $path ذخیره شد.');
      await _showOnlineCredentials(onlineCredentials);
      if (mounted) setState(() => _section = 2);
    } catch (e) {
      if (mounted) _msg('خطا در ساخت Trial: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _featureLabel(String feature) {
    switch (feature) {
      case FeatureCatalog.sales:
        return 'فروش';
      case FeatureCatalog.customers:
        return 'مشتریان';
      case FeatureCatalog.products:
        return 'کالاها';
      case FeatureCatalog.inventory:
        return 'انبار';
      case FeatureCatalog.reports:
        return 'گزارش‌ها';
      case FeatureCatalog.accounting:
        return 'حسابداری';
      case FeatureCatalog.attendance:
        return 'حضور و غیاب';
      case FeatureCatalog.businessModules:
        return 'ماژول‌های شغلی';
      case FeatureCatalog.multiWarehouse:
        return 'چند انبار';
      case FeatureCatalog.sms:
        return 'پیامک';
      case FeatureCatalog.advancedReports:
        return 'گزارش پیشرفته';
      default:
        return feature;
    }
  }

  Future<void> _issue() async {
    if (customer.text.trim().isEmpty) {
      _msg(
        'نام مشتری الزامی است',
        error: true,
      );
      return;
    }
    final sharedLicense = platform == 'ALL' && !OnlineAdminService.onlineEnabled;
    final normalizedDevice = sharedLicense ? 'SHARED' : device.text.trim().toUpperCase();
    if (!sharedLicense && normalizedDevice.isEmpty) {
      _msg(
        'شناسه دستگاه الزامی است',
        error: true,
      );
      return;
    }
    if (!sharedLicense && !RegExp(r'^[0-9A-F]{64}$').hasMatch(normalizedDevice)) {
      _msg(
        'شناسه دستگاه نامعتبر است؛ باید ۶۴ کاراکتر هگزادسیمال باشد.',
        error: true,
      );
      return;
    }
    if (platform != 'ANDROID' && platform != 'WINDOWS' && platform != 'ALL') {
      _msg(
        'پلتفرم لایسنس نامعتبر است.',
        error: true,
      );
      return;
    }
    if (selected.isEmpty) {
      _msg(
        'حداقل یک شغل انتخاب کنید',
        error: true,
      );
      return;
    }
    if (!selected.contains('*') &&
        selected.any(
          (code) => !BusinessCatalog.containsCode(
            code,
          ),
        )) {
      _msg(
        'یک یا چند کد شغل با کاتالوگ مشترک StoreMaster هماهنگ نیست.',
        error: true,
      );
      return;
    }
    setState(
      () => _busy = true,
    );
    try {
      final now = DateTime.now();
      final expires = now.add(
        Duration(
          days: duration,
        ),
      );
      final originalPrice = _prices[duration] ?? 0;
      var price = originalPrice;
      if (_quotedFinalPrice != null && _quotedOriginalPrice == originalPrice) {
        price = _quotedFinalPrice!;
      }
      if (price <= 0) {
        throw StateError(
          'قیمت این مدت لایسنس تعیین نشده است.',
        );
      }
      final id = 'SM-${_randomReadable()}';
      final payload = LicensePayload(
        licenseId: id,
        customerName: customer.text.trim(),
        phone: phone.text.trim(),
        businessTypes: selected.toList(),
        deviceId: normalizedDevice,
        platform: platform,
        deviceBinding: sharedLicense ? 'STORE_SHARED' : 'DEVICE',
        maxDevices: sharedLicense ? 10 : 1,
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
        features: const <String>[
          'FULL',
        ],
      );
      final signature = await LicenseSigner.sign(
        payload,
      );
      if (!await LicenseSigner.selfTest(payload, signature)) {
        throw StateError('خطای داخلی امضای لایسنس: کلید خصوصی و عمومی با هم منطبق نیستند.');
      }
      final document = LicenseDocument(
        payload: payload,
        signatureBase64: signature,
      );
      final onlineCredentials = await _registerOnlineLicense(
        payload,
        originalPrice: originalPrice,
        finalPrice: price,
        discountCode: _appliedDiscountCode,
      );
      await LicenseRepository.instance.add(
        payload,
        status: 'ACTIVE',
        note: note.text.trim(),
        originalPrice: originalPrice,
        finalPrice: price,
        discountCode:
            _appliedDiscountCode.isEmpty ? null : _appliedDiscountCode,
        serverSynced: OnlineAdminService.onlineEnabled,
      );
      final text = document.toJson();
      final path = await _saveFile(
        text,
        id,
      );
      if (!mounted) return;
      setState(() {
        _lastLicense = text;
        _quotedOriginalPrice = null;
        _quotedFinalPrice = null;
        _appliedDiscountCode = '';
        discountCode.clear();
      });
      _msg(
        'لایسنس با موفقیت صادر شد و در $path ذخیره شد.',
      );
      await _load();
      await _showOnlineCredentials(onlineCredentials);
      if (mounted) {
        setState(
          () => _section = 2,
        );
      }
    } catch (e) {
      if (mounted) {
        _msg(
          'خطا در صدور لایسنس: $e',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(
          () => _busy = false,
        );
      }
    }
  }

  Future<String> _saveFile(
    String text,
    String id,
  ) async {
    final bytes = Uint8List.fromList(
      utf8.encode(text),
    );

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

    return result;
  }

  String _randomReadable() {
    final value = DateTime.now()
        .microsecondsSinceEpoch
        .toRadixString(
          36,
        )
        .toUpperCase();
    final prefix = value.length > 4
        ? value.substring(
            0,
            4,
          )
        : value;
    final suffix = (value.hashCode.abs() % 1000000).toString().padLeft(
          6,
          '0',
        );
    return '$prefix-$suffix';
  }

  void _msg(
    String text, {
    bool error = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            textDirection: ui.TextDirection.rtl,
          ),
          backgroundColor: error ? Colors.red.shade700 : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _selectSection(
    int value,
  ) {
    if (!mounted) return;
    setState(() {
      _section = value;
    });
  }

  ThemeData _themeData() {
    final seed = _palette[_seedIndex];
    return ThemeData(
      useMaterial3: true,
      brightness: _dark ? Brightness.dark : Brightness.light,
      colorSchemeSeed: seed,
      scaffoldBackgroundColor: _dark
          ? const Color(
              0xFF101119,
            )
          : const Color(
              0xFFF5F7FB,
            ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(
              12,
            ),
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.zero,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Theme(
      data: _themeData(),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(
            context,
          );
          // BusinessProfile و BusinessCatalog
          // متعلق به همین پروژه License Manager هستند.
          final List<BusinessProfile> profiles = BusinessCatalog.all();
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            drawer: _buildDrawer(
              theme,
            ),
            body: SafeArea(
              child: Directionality(
                textDirection: ui.TextDirection.rtl,
                child: Row(
                  children: [
                    if (MediaQuery.sizeOf(
                          context,
                        ).width >=
                        980)
                      _buildSidebar(
                        theme,
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          _buildTopBar(
                            theme,
                          ),
                          Expanded(
                            child: _buildContent(
                              theme,
                              profiles,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Drawer _buildDrawer(
    ThemeData theme,
  ) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _drawerHeader(
              theme,
            ),
            const Divider(
              height: 1,
            ),
            Expanded(
              child: _navList(
                theme,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerHeader(
    ThemeData theme,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        18,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
      ),
      child: Row(
        textDirection: ui.TextDirection.rtl,
        children: const [
          CircleAvatar(
            radius: 24,
            child: Icon(
              Icons.key_rounded,
            ),
          ),
          SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              'StoreMaster\nLicense Manager',
              textDirection: ui.TextDirection.rtl,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navList(
    ThemeData theme,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(
        12,
      ),
      itemCount: _navItems.length,
      separatorBuilder: (_, __) => const SizedBox(
        height: 5,
      ),
      itemBuilder: (_, i) {
        final item = _navItems[i];
        return Material(
          color: Colors.transparent,
          type: MaterialType.transparency,
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                14,
              ),
            ),
            selected: _section == i,
            selectedTileColor: theme.colorScheme.primary.withValues(
              alpha: .12,
            ),
            leading: Icon(
              item.icon,
            ),
            title: Text(
              item.title,
              textDirection: ui.TextDirection.rtl,
            ),
            onTap: () {
              Navigator.of(
                context,
              ).maybePop();
              _selectSection(
                i,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSidebar(
    ThemeData theme,
  ) {
    return Container(
      width: 255,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          left: BorderSide(
            color: theme.dividerColor.withValues(
              alpha: .5,
            ),
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(
              18,
            ),
            child: Row(
              textDirection: ui.TextDirection.rtl,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                      15,
                    ),
                  ),
                  child: const Icon(
                    Icons.key_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                const Expanded(
                  child: Text(
                    'StoreMaster\nLicense Manager',
                    textDirection: ui.TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
          ),
          Expanded(
            child: _navList(
              theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    ThemeData theme,
  ) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: .96,
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(
              alpha: .45,
            ),
          ),
        ),
      ),
      child: Row(
        textDirection: ui.TextDirection.rtl,
        children: [
          if (MediaQuery.sizeOf(
                context,
              ).width <
              980)
            Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(
                  context,
                ).openDrawer(),
                icon: const Icon(
                  Icons.menu_rounded,
                ),
              ),
            ),
          const SizedBox(
            width: 4,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _navItems[_section].title,
                  textDirection: ui.TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'مرکز صدور و کنترل مجوزهای StoreMaster',
                  textDirection: ui.TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'حالت روشن/تیره',
            onPressed: () => setState(
              () => _dark = !_dark,
            ),
            icon: Icon(
              _dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
          IconButton(
            tooltip: 'به‌روزرسانی',
            onPressed: _busy ? null : _load,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    List<BusinessProfile> profiles,
  ) {
    final padding = MediaQuery.sizeOf(
              context,
            ).width <
            700
        ? 12.0
        : 20.0;
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        padding,
      ),
      child: switch (_section) {
        0 => _dashboard(
            theme,
            profiles,
          ),
        1 => _issuePage(
            theme,
            profiles,
          ),
        2 => const StoresScreen(),
        3 => _historyPage(
            theme,
          ),
        4 => const SupportInboxScreen(),
        _ => _settingsPage(
            theme,
          ),
      },
    );
  }

  Widget _dashboard(
    ThemeData theme,
    List<BusinessProfile> profiles,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHero(
          theme,
        ),
        const SizedBox(
          height: 16,
        ),
        _buildStats(
          theme,
        ),
        const SizedBox(
          height: 16,
        ),
        _buildQuickActions(
          theme,
        ),
        const SizedBox(
          height: 16,
        ),
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  _buildIssueCard(
                    theme,
                    profiles,
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  _buildHistoryCard(
                    theme,
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: ui.TextDirection.rtl,
              children: [
                Expanded(
                  flex: 6,
                  child: _buildIssueCard(
                    theme,
                    profiles,
                  ),
                ),
                const SizedBox(
                  width: 16,
                ),
                Expanded(
                  flex: 5,
                  child: _buildHistoryCard(
                    theme,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActions(
    ThemeData theme,
  ) {
    final items = [
      _actionCard(
        theme,
        Icons.vpn_key_rounded,
        'صدور لایسنس',
        'ساخت لایسنس جدید',
        1,
      ),
      _actionCard(
        theme,
        Icons.history_rounded,
        'سوابق',
        'مشاهده و بررسی لایسنس‌ها',
        3,
      ),
      _actionCard(
        theme,
        Icons.settings_rounded,
        'تنظیمات',
        'ظاهر و تنظیمات مدیر',
        4,
      ),
    ];
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  const SizedBox(
                    height: 10,
                  ),
                items[i],
              ],
            ],
          );
        }
        return Row(
          textDirection: ui.TextDirection.rtl,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                const SizedBox(
                  width: 12,
                ),
              Expanded(
                child: items[i],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _actionCard(
    ThemeData theme,
    IconData icon,
    String title,
    String subtitle,
    int section,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(
        16,
      ),
      onTap: () => _selectSection(
        section,
      ),
      child: Container(
        padding: const EdgeInsets.all(
          14,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(
            16,
          ),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(
              alpha: .15,
            ),
          ),
        ),
        child: Row(
          textDirection: ui.TextDirection.rtl,
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: .12,
              ),
              foregroundColor: theme.colorScheme.primary,
              child: Icon(
                icon,
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    textDirection: ui.TextDirection.rtl,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    subtitle,
                    textDirection: ui.TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
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

  Widget _issuePage(
    ThemeData theme,
    List<BusinessProfile> profiles,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHero(
          theme,
        ),
        const SizedBox(
          height: 16,
        ),
        _buildIssueCard(
          theme,
          profiles,
        ),
      ],
    );
  }

  Widget _historyPage(
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHero(
          theme,
        ),
        const SizedBox(
          height: 16,
        ),
        _buildHistoryCard(
          theme,
          tall: true,
        ),
      ],
    );
  }

  Future<void> _configureOnlineTrialPolicy() async {
    if (!OnlineAdminService.onlineEnabled) {
      _msg('برای تنظیم سیاست تریال سرور، License Manager را با STORE_MASTER_ADMIN_ONLINE_ENABLED=true و آدرس HTTPS بسازید.', error: true);
      return;
    }
    try {
      final current = await OnlineAdminService.instance.getTrialPolicy();
      final businesses = <String>{
        for (final x in (current['businessTypes'] as List? ?? const [])) '$x',
      };
      final features = <String>{
        for (final x in (current['features'] as List? ?? const [])) '$x',
      };
      if (businesses.isEmpty) businesses.add('*');
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('سیاست مرکزی تریال ۱۵روزه'),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('مدت تریال ثابت و ۱۵ روز است. این تنظیم تعیین می‌کند کدام کسب‌وکارها اجازه شروع تریال دارند و کدام قابلیت‌ها به تریال داده می‌شود؛ کاربر هنگام ثبت‌نام نمی‌تواند این موارد را تغییر دهد.'),
                    const SizedBox(height: 16),
                    const Text('کسب‌وکارهای مجاز', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        FilterChip(
                          label: const Text('همه کسب‌وکارها'),
                          selected: businesses.contains('*'),
                          onSelected: (v) => setDialogState(() {
                            businesses.clear();
                            if (v) businesses.add('*');
                          }),
                        ),
                        ...BusinessCatalog.profiles.map((profile) {
                          final code = profile['code'] ?? '';
                          final label = profile['label'] ?? code;
                          return FilterChip(
                            label: Text(label),
                            selected: businesses.contains(code),
                            onSelected: (v) => setDialogState(() {
                              businesses.remove('*');
                              if (v) { businesses.add(code); } else { businesses.remove(code); }
                            }),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text('قابلیت‌های تریال', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: FeatureCatalog.allFeatures.map((feature) => FilterChip(
                        label: Text(_featureLabel(feature)),
                        selected: features.contains(feature),
                        onSelected: (v) => setDialogState(() {
                          if (v) { features.add(feature); } else { features.remove(feature); }
                        }),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
              FilledButton.icon(
                onPressed: () {
                  if (businesses.isEmpty || features.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حداقل یک کسب‌وکار و یک قابلیت انتخاب کنید.')));
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('ذخیره روی سرور'),
              ),
            ],
          ),
        ),
      );
      if (saved != true) return;
      await OnlineAdminService.instance.updateTrialPolicy(
        features: features.toList()..sort(),
        businessTypes: businesses.toList()..sort(),
      );
      if (mounted) _msg('سیاست مرکزی تریال ذخیره شد؛ ثبت‌نام‌های آنلاین بعدی از همین دسترسی‌ها استفاده می‌کنند.');
    } catch (e) {
      if (mounted) _msg('ذخیره سیاست تریال ناموفق بود: $e', error: true);
    }
  }

  Widget _settingsPage(
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHero(
          theme,
        ),
        const SizedBox(
          height: 16,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(
              18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'تنظیمات ظاهر',
                  textDirection: ui.TextDirection.rtl,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                SwitchListTile.adaptive(
                  value: _dark,
                  onChanged: (v) => setState(
                    () => _dark = v,
                  ),
                  title: const Text(
                    'حالت تاریک',
                  ),
                  subtitle: const Text(
                    'ظاهر برنامه در حالت شب',
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                const Text(
                  'رنگ اصلی',
                  textDirection: ui.TextDirection.rtl,
                ),
                const SizedBox(
                  height: 10,
                ),
                Wrap(
                  spacing: 10,
                  children: List.generate(
                    _palette.length,
                    (i) {
                      final active = i == _seedIndex;
                      return InkWell(
                        onTap: () => setState(
                          () => _seedIndex = i,
                        ),
                        borderRadius: BorderRadius.circular(
                          30,
                        ),
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
                              width: 3,
                            ),
                          ),
                          child: active
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('سیاست تریال آنلاین', textDirection: ui.TextDirection.rtl, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 8),
                const Text('مدت تریال ۱۵ روز است. دسترسی مشاغل و ماژول‌ها از اینجا روی سرور ذخیره می‌شود و در ثبت‌نام آنلاین توسط کاربر قابل انتخاب نیست.', textDirection: ui.TextDirection.rtl),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _configureOnlineTrialPolicy,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('تنظیم کسب‌وکارها و دسترسی‌های تریال'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(
              18,
            ),
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
                const SizedBox(
                  height: 12,
                ),
                for (final days in const [
                  30,
                  90,
                  180,
                  365,
                ])
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 10,
                    ),
                    child: TextFormField(
                      key: ValueKey(
                        'price-$days-${_prices[days]}',
                      ),
                      initialValue: (_prices[days] ?? 0).round().toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: switch (days) {
                          30 => '۱ ماهه',
                          90 => '۳ ماهه',
                          180 => '۶ ماهه',
                          365 => '۱۲ ماهه',
                          _ => 'پلن',
                        },
                        suffixText: _currency,
                      ),
                      onChanged: (value) {
                        _prices[days] = double.tryParse(
                              value
                                  .replaceAll(
                                    ',',
                                    '',
                                  )
                                  .replaceAll(
                                    '٬',
                                    '',
                                  ),
                            ) ??
                            (_prices[days] ?? 0);
                      },
                    ),
                  ),
                FilledButton.icon(
                  onPressed: () async {
                    await LicenseRepository.instance.setPrices(
                      _prices,
                    );
                    await _load();
                    if (mounted) {
                      _msg(
                        'قیمت‌های جدید ذخیره شدند.',
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.save_rounded,
                  ),
                  label: const Text(
                    'ذخیره قیمت‌ها',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero(
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(
        22,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(
          24,
        ),
      ),
      child: Row(
        textDirection: ui.TextDirection.rtl,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: .15,
              ),
              borderRadius: BorderRadius.circular(
                16,
              ),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرکز حرفه‌ای صدور لایسنس',
                  textDirection: ui.TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                SizedBox(
                  height: 5,
                ),
                Text(
                  'لایسنس امضاشده برای Android و Windows',
                  textDirection: ui.TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(
    ThemeData theme,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _statCard(
          theme,
          Icons.receipt_long_rounded,
          'کل لایسنس‌ها',
          '${_history.length}',
          theme.colorScheme.primary,
        ),
        _statCard(
          theme,
          Icons.android_rounded,
          'Android',
          '${_history.where((x) => x['platform'] == 'ANDROID').length}',
          Colors.green.shade700,
        ),
        _statCard(
          theme,
          Icons.desktop_windows_rounded,
          'Windows',
          '${_history.where((x) => x['platform'] == 'WINDOWS').length}',
          Colors.indigo.shade700,
        ),
        _statCard(
          theme,
          Icons.schedule_rounded,
          'آخرین صدور',
          _history.isEmpty ? '—' : (_history.first['plan']?.toString() ?? '—'),
          Colors.orange.shade800,
        ),
      ],
    );
  }

  Widget _statCard(
    ThemeData theme,
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      width: 205,
      padding: const EdgeInsets.all(
        15,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: color.withValues(
            alpha: .2,
          ),
        ),
      ),
      child: Row(
        textDirection: ui.TextDirection.rtl,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(
              alpha: .12,
            ),
            foregroundColor: color,
            child: Icon(
              icon,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textDirection: ui.TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(
    ThemeData theme,
    List<BusinessProfile> profiles,
  ) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(
          18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              textDirection: ui.TextDirection.rtl,
              children: [
                const Expanded(
                  child: Text(
                    'صدور لایسنس جدید',
                    textDirection: ui.TextDirection.rtl,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : () => _createTrial(profiles),
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('ساخت Trial ۱۵ روزه'),
                ),
              ],
            ),
            const SizedBox(
              height: 16,
            ),
            _input(
              customer,
              'نام مشتری / کسبه',
              Icons.person_outline_rounded,
            ),
            const SizedBox(
              height: 10,
            ),
            _input(
              phone,
              'شماره تماس',
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(
              height: 10,
            ),
            _input(
              device,
              'Hardware / Device ID',
              Icons.devices_other_rounded,
            ),
            const SizedBox(
              height: 8,
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _importDeviceCard,
                icon: const Icon(
                  Icons.upload_file_rounded,
                ),
                label: const Text(
                  'وارد کردن مشخصات دستگاه',
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: discountCode,
                    textDirection: ui.TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'کد تخفیف',
                      prefixIcon: Icon(Icons.local_offer_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _busy ? null : _applyDiscount,
                  child: const Text('اعمال'),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'ساخت کد تخفیف',
                  onPressed: _busy ? null : _openDiscountDialog,
                  icon: const Icon(Icons.add_box_outlined),
                ),
              ],
            ),
            if (_quotedFinalPrice != null && _quotedOriginalPrice != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: RichText(
                    textDirection: ui.TextDirection.rtl,
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        const TextSpan(text: 'قیمت اصلی: '),
                        TextSpan(
                          text:
                              '${NumberFormat('#,##0', 'en_US').format(_quotedOriginalPrice)} $_currency',
                          style: const TextStyle(
                              decoration: TextDecoration.lineThrough),
                        ),
                        TextSpan(
                          text:
                              '   قیمت تخفیفی: ${NumberFormat('#,##0', 'en_US').format(_quotedFinalPrice)} $_currency',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_discountPercent > 0)
                          TextSpan(text: '   ($_discountPercent٪)'),
                      ],
                    ),
                  ),
                ),
              ),
            _input(
              note,
              'یادداشت',
              Icons.notes_rounded,
              maxLines: 2,
            ),
            const SizedBox(
              height: 16,
            ),
            const Text(
              'مدت لایسنس',
              textDirection: ui.TextDirection.rtl,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _durationChip(
                  30,
                  '۱ ماهه',
                ),
                _durationChip(
                  90,
                  '۳ ماهه',
                ),
                _durationChip(
                  180,
                  '۶ ماهه',
                ),
                _durationChip(
                  365,
                  '۱۲ ماهه',
                ),
              ],
            ),
            const SizedBox(
              height: 16,
            ),
            const Text(
              'پلتفرم',
              textDirection: ui.TextDirection.rtl,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'ALL',
                  label: Text('مشترک Android + Windows'),
                  icon: Icon(Icons.devices),
                ),
                ButtonSegment(
                  value: 'ANDROID',
                  label: Text('Android'),
                  icon: Icon(Icons.android),
                ),
                ButtonSegment(
                  value: 'WINDOWS',
                  label: Text('Windows'),
                  icon: Icon(Icons.desktop_windows),
                ),
              ],
              selected: {
                platform,
              },
              onSelectionChanged: (values) {
                if (values.isNotEmpty) {
                  setState(
                    () => platform = values.first,
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'لایسنس مشترک: با انتخاب «مشترک Android + Windows»، همان یک لایسنس روی Windows و Android قابل فعال‌سازی است؛ شناسه دستگاه به‌صورت مشترک مدیریت می‌شود.',
              textDirection: ui.TextDirection.rtl,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'نوع شغل / فروشگاه',
              textDirection: ui.TextDirection.rtl,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: .45,
                ),
                borderRadius: BorderRadius.circular(
                  14,
                ),
                border: Border.all(
                  color: theme.dividerColor.withValues(
                    alpha: .45,
                  ),
                ),
              ),
              child: Scrollbar(
                controller: _jobsScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _jobsScrollController,
                  padding: const EdgeInsets.all(
                    10,
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      FilterChip(
                        label: const Text(
                          'همه مشاغل',
                        ),
                        selected: selected.contains(
                          '*',
                        ),
                        onSelected: _selectAllJobs,
                      ),
                      ...profiles.map(
                        _jobChip,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _issue,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.verified_rounded,
                    ),
              label: Text(
                _busy ? 'در حال صدور...' : 'صدور و ذخیره لایسنس',
              ),
            ),
            if (_lastLicense != null) ...[
              const SizedBox(
                height: 12,
              ),
              SelectableText(
                _lastLicense!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textDirection: ui.TextDirection.rtl,
      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
        ),
        labelText: label,
      ),
    );
  }

  void _selectAllJobs(
    bool value,
  ) {
    setState(() {
      selected.clear();
      if (value) {
        selected.add('*');
      }
    });
  }

  Widget _jobChip(
    BusinessProfile profile,
  ) {
    return FilterChip(
      label: Text(
        profile.label,
      ),
      selected: selected.contains(
        profile.code,
      ),
      onSelected: (value) {
        setState(() {
          selected.remove('*');

          if (value) {
            selected.add(
              profile.code,
            );
          } else {
            selected.remove(
              profile.code,
            );
          }
        });
      },
    );
  }

  Widget _durationChip(
    int value,
    String label,
  ) {
    final original = _prices[value] ?? 0;
    final discounted = value == duration &&
            _quotedOriginalPrice == original &&
            _quotedFinalPrice != null
        ? _quotedFinalPrice!
        : original;
    return ChoiceChip(
      label: discounted < original
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${NumberFormat('#,##0', 'en_US').format(original)} $_currency',
                  style:
                      const TextStyle(decoration: TextDecoration.lineThrough),
                ),
                const SizedBox(width: 6),
                Text(
                  '${NumberFormat('#,##0', 'en_US').format(discounted)} $_currency',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            )
          : Text(
              '$label • ${NumberFormat('#,##0', 'en_US').format(original)} $_currency',
            ),
      selected: duration == value,
      onSelected: _busy
          ? null
          : (_) => setState(
                () => duration = value,
              ),
    );
  }

  Widget _buildHistoryCard(
    ThemeData theme, {
    bool tall = false,
  }) {
    final height = tall ? 680.0 : 560.0;
    return Card(
      elevation: 0,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(
            18,
          ),
          child: Column(
            children: [
              Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  const Expanded(
                    child: Text(
                      'سوابق لایسنس',
                      textDirection: ui.TextDirection.rtl,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _history.isEmpty ? null : _clearHistory,
                    tooltip: 'حذف همه سوابق',
                    icon: const Icon(
                      Icons.delete_sweep_rounded,
                      color: Colors.red,
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    tooltip: 'بازخوانی',
                    icon: const Icon(
                      Icons.refresh_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 6,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _historySearch,
                      onChanged: (_) => setState(
                        () {},
                      ),
                      textDirection: ui.TextDirection.rtl,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(
                          Icons.search_rounded,
                        ),
                        labelText: 'جستجو در سوابق',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'وضعیت',
                    onSelected: (value) => setState(
                      () => _historyStatusFilter = value,
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'ALL',
                        child: Text(
                          'همه',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'ACTIVE',
                        child: Text(
                          'فعال',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'SUSPENDED',
                        child: Text(
                          'تعلیق',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'CANCELLED',
                        child: Text(
                          'لغو شده',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'RENEWED',
                        child: Text(
                          'تمدید شده',
                        ),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(
                        8,
                      ),
                      child: Icon(
                        Icons.filter_alt_outlined,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 8,
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: _exportRevocationPackage,
                    icon: const Icon(Icons.gpp_bad_outlined),
                    label: const Text('خروجی ابطال آفلاین'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _filteredHistory.isEmpty
                        ? null
                        : () async {
                            try {
                              final path = await _exportExcelHistory();

                              if (mounted) {
                                _msg(
                                  'Excel ذخیره شد: $path',
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                _msg(
                                  'خطا در Excel: $e',
                                  error: true,
                                );
                              }
                            }
                          },
                    icon: const Icon(
                      Icons.table_view_rounded,
                    ),
                    label: const Text(
                      'Excel',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _filteredHistory.isEmpty
                        ? null
                        : () async {
                            try {
                              final path = await _exportPdfHistory();

                              if (mounted) {
                                _msg(
                                  'PDF ذخیره شد: $path',
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                _msg(
                                  'خطا در PDF: $e',
                                  error: true,
                                );
                              }
                            }
                          },
                    icon: const Icon(
                      Icons.picture_as_pdf_rounded,
                    ),
                    label: const Text(
                      'PDF',
                    ),
                  ),
                  Chip(
                    label: Text(
                      'نمایش ${_filteredHistory.length} مورد',
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              Expanded(
                child: _filteredHistory.isEmpty
                    ? const Center(
                        child: Text(
                          'موردی برای نمایش وجود ندارد.',
                        ),
                      )
                    : Scrollbar(
                        controller: _historyScrollController,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: _historyScrollController,
                          itemCount: _filteredHistory.length,
                          separatorBuilder: (
                            _,
                            __,
                          ) =>
                              const SizedBox(
                            height: 8,
                          ),
                          itemBuilder: (
                            context,
                            index,
                          ) =>
                              _historyTile(
                            theme,
                            _filteredHistory[index],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyTile(
    ThemeData theme,
    Map<String, dynamic> item,
  ) {
    final name = item['customerName']?.toString().trim().isEmpty ?? true
        ? 'بدون نام'
        : item['customerName'].toString();
    final id = item['licenseId']?.toString() ?? '';
    final plan = item['plan']?.toString() ?? '';
    final price = item['priceAtPurchase'] is num
        ? (item['priceAtPurchase'] as num).toDouble()
        : double.tryParse(
              item['priceAtPurchase']?.toString() ?? '',
            ) ??
            0;
    final currency = item['currency']?.toString().trim().isEmpty ?? true
        ? _currency
        : item['currency'].toString();
    final platformValue = item['platform']?.toString().toUpperCase() ?? '';
    final deviceId = item['deviceId']?.toString() ?? '';
    final status = item['status']?.toString().toUpperCase() ?? 'ACTIVE';
    final business = item['businessTypes'] is List
        ? (item['businessTypes'] as List).join('، ')
        : '—';
    final isSuspended = status == 'SUSPENDED';
    final isCancelled = status == 'CANCELLED';
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(
          14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              textDirection: ui.TextDirection.rtl,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: .12,
                  ),
                  foregroundColor: theme.colorScheme.primary,
                  child: Icon(
                    platformValue == 'ANDROID'
                        ? Icons.android_rounded
                        : Icons.desktop_windows_rounded,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        '$plan • $platformValue',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${NumberFormat('#,##0', 'en_US').format(price)} $currency',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        _statusLabel(
                          status,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: .55,
                ),
                borderRadius: BorderRadius.circular(
                  10,
                ),
              ),
              child: Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 17,
                  ),
                  const SizedBox(
                    width: 7,
                  ),
                  Expanded(
                    child: SelectableText(
                      id,
                      textDirection: ui.TextDirection.ltr,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'دستگاه: $deviceId',
              textDirection: ui.TextDirection.rtl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              'شغل: $business',
              textDirection: ui.TextDirection.rtl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            Wrap(
              textDirection: ui.TextDirection.rtl,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _renew(
                            item,
                          ),
                  icon: const Icon(
                    Icons.autorenew_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'تمدید',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _busy || isSuspended || isCancelled
                      ? null
                      : () => _changeStatus(
                            item,
                            'SUSPENDED',
                          ),
                  icon: const Icon(
                    Icons.pause_circle_outline_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'تعلیق',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _busy || isCancelled
                      ? null
                      : () => _changeStatus(
                            item,
                            'CANCELLED',
                          ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  icon: const Icon(
                    Icons.block_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'لغو لایسنس',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _deleteHistoryItem(
                            item,
                          ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'حذف سابقه',
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 5,
            ),
            Text(
              switch (status) {
                'SUSPENDED' => 'این لایسنس در License Manager تعلیق شده است.',
                'CANCELLED' => 'این لایسنس در License Manager لغو شده است.',
                'RENEWED' => 'این رکورد با یک لایسنس جدید تمدید شده است.',
                _ => 'این رکورد در وضعیت فعال قرار دارد.',
              },
              textDirection: ui.TextDirection.rtl,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
