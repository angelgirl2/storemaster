import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../catalog/business_catalog.dart';
import '../models/license_models.dart';
import '../services/license_repository.dart';
import '../services/license_signer.dart';
import '../services/store_repository.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final _name = TextEditingController();
  final _owner = TextEditingController(text: 'مدیر فروشگاه');
  final _pin = TextEditingController();
  final _phone = TextEditingController();

  final Set<String> _types = <String>{'GENERAL'};
  int _days = 365;
  bool _busy = false;
  List<Map<String, dynamic>> _stores = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _owner.dispose();
    _pin.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final x = await StoreRepository.instance.all();
    if (mounted) setState(() => _stores = x);
  }

  String _code() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase();
    return 'SM-${now.substring(now.length - 8)}';
  }

  Future<File> _saveLicense(String code, String json) async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory(
      p.join(dir.path, 'StoreMasterLicenseManager', 'licenses'),
    );
    await out.create(recursive: true);
    final f = File(p.join(out.path, '$code.json'));
    await f.writeAsString(json, encoding: utf8, flush: true);
    return f;
  }

  List<String> _businessTypesFromStore(Map<String, dynamic> store) {
    final raw = store['businessTypes'];
    if (raw is List) {
      final values = raw.map((e) => '$e'.trim().toUpperCase()).where((e) => e.isNotEmpty).toSet();
      if (values.isNotEmpty) return values.toList();
    }
    final fallback = '${store['storeType'] ?? 'GENERAL'}'.trim().toUpperCase();
    return fallback.isEmpty ? <String>['GENERAL'] : <String>[fallback];
  }

  String _businessTitle(List<String> types) {
    final labels = types.map((code) {
      return BusinessCatalog.find(code)?.label ?? code;
    }).toList();
    return labels.join('، ');
  }

  Future<void> _selectBusinessTypes({
    required Set<String> selected,
  }) async {
    final working = <String>{...selected};
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('انتخاب دسته‌بندی شغلی'),
              content: SizedBox(
                width: 650,
                height: 430,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      FilterChip(
                        label: const Text('همه مشاغل'),
                        selected: working.contains('*'),
                        onSelected: (value) {
                          setDialogState(() {
                            working.clear();
                            if (value) working.add('*');
                          });
                        },
                      ),
                      ...BusinessCatalog.all().map(
                        (profile) => FilterChip(
                          label: Text(profile.label),
                          selected: working.contains(profile.code),
                          onSelected: (value) {
                            setDialogState(() {
                              working.remove('*');
                              if (value) {
                                working.add(profile.code);
                              } else {
                                working.remove(profile.code);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('انصراف'),
                ),
                FilledButton.icon(
                  onPressed: working.isEmpty
                      ? null
                      : () {
                          selected
                            ..clear()
                            ..addAll(working);
                          Navigator.pop(ctx);
                        },
                  icon: const Icon(Icons.check),
                  label: const Text('تأیید'),
                ),
              ],
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  void _msg(String text, [bool error = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, textDirection: ui.TextDirection.rtl),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  Future<void> _createStore() async {
    final storeName = _name.text.trim();
    final owner = _owner.text.trim();
    final pin = _pin.text.trim();

    if (storeName.isEmpty || owner.isEmpty || pin.length < 4) {
      _msg('نام فروشگاه، نام مدیر و PIN حداقل ۴ رقمی الزامی است.', true);
      return;
    }
    if (_types.isEmpty) {
      _msg('حداقل یک دسته‌بندی شغلی را انتخاب کنید.', true);
      return;
    }

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final code = _code();
      final businessTypes = _types.toList()..sort();

      final payload = LicensePayload(
        licenseId: 'LIC-${DateTime.now().microsecondsSinceEpoch}',
        customerName: owner,
        phone: _phone.text.trim(),
        businessTypes: businessTypes,
        deviceId: 'SHARED',
        platform: 'ALL',
        deviceBinding: 'STORE_SHARED',
        maxDevices: 10,
        plan: switch (_days) {
          30 => '1M',
          90 => '3M',
          180 => '6M',
          365 => '12M',
          _ => 'CUSTOM',
        },
        durationDays: _days,
        issuedAt: now.millisecondsSinceEpoch,
        expiresAt: now.add(Duration(days: _days)).millisecondsSinceEpoch,
        priceAtPurchase: 0,
        currency: 'تومان',
        features: const ['FULL'],
        storeCode: code,
        storeBinding: 'SHARED',
      );

      final sig = await LicenseSigner.sign(payload);
      if (!await LicenseSigner.selfTest(payload, sig)) {
        throw StateError('خطای داخلی امضای لایسنس: کلیدهای صدور StoreMaster منطبق نیستند.');
      }
      final doc = LicenseDocument(payload: payload, signatureBase64: sig);
      final text = doc.toJson();
      final file = await _saveLicense(code, text);

      await StoreRepository.instance.add({
        'storeCode': code,
        'storeName': storeName,
        'ownerName': owner,
        'phone': _phone.text.trim(),
        'pin': pin,
        'storeType': businessTypes.join(','),
        'businessTypes': businessTypes,
        'createdAt': now.millisecondsSinceEpoch,
        'licenseId': payload.licenseId,
        'licenseFile': file.path,
        'expiresAt': payload.expiresAt,
      });

      await LicenseRepository.instance.add(
        payload,
        status: 'ACTIVE',
        note: 'لایسنس Shared ایجادشده همراه فروشگاه',
        originalPrice: 0,
        finalPrice: 0,
      );

      await _load();
      if (mounted) {
        _name.clear();
        _phone.clear();
        _pin.clear();
        setState(() {
          _owner.text = 'مدیر فروشگاه';
          _types
            ..clear()
            ..add('GENERAL');
        });
        _msg('فروشگاه «$storeName» ساخته شد و لایسنس Shared Android + Windows آماده است.');
      }
    } catch (e) {
      _msg('خطا در ساخت فروشگاه: $e', true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editStore(Map<String, dynamic> store) async {
    final name = TextEditingController(text: '${store['storeName'] ?? ''}');
    final owner = TextEditingController(text: '${store['ownerName'] ?? ''}');
    final phone = TextEditingController(text: '${store['phone'] ?? ''}');
    final selected = <String>{..._businessTypesFromStore(store)};
    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              Future<void> save() async {
                final storeName = name.text.trim();
                final ownerName = owner.text.trim();
                if (storeName.isEmpty || ownerName.isEmpty || selected.isEmpty) return;

                setDialogState(() => saving = true);
                try {
                  final storeCode = '${store['storeCode'] ?? ''}'.trim();
                  final licensePath = '${store['licenseFile'] ?? ''}'.trim();
                  final licenseId = '${store['licenseId'] ?? ''}'.trim();

                  // اگر فایل لایسنس در دسترس باشد، همان LicenseId و تاریخ
                  // انقضا حفظ می‌شود و فقط اطلاعات قابل ویرایش با امضای جدید
                  // ثبت می‌شوند.
                  if (licensePath.isNotEmpty && await File(licensePath).exists()) {
                    final oldText = await File(licensePath).readAsString(encoding: utf8);
                    final oldDoc = LicenseDocument.fromJson(oldText);
                    final old = oldDoc.payload;
                    final updatedPayload = LicensePayload(
                      licenseId: old.licenseId,
                      customerName: ownerName,
                      phone: phone.text.trim(),
                      businessTypes: selected.toList()..sort(),
                      deviceId: old.deviceId,
                      platform: old.platform,
                      deviceBinding: old.deviceBinding,
                      maxDevices: old.maxDevices,
                      plan: old.plan,
                      durationDays: old.durationDays,
                      issuedAt: old.issuedAt,
                      expiresAt: old.expiresAt,
                      priceAtPurchase: old.priceAtPurchase,
                      currency: old.currency,
                      features: old.features,
                      storeCode: storeCode,
                      storeBinding: old.storeBinding,
                    );
                    final sig = await LicenseSigner.sign(updatedPayload);
                    if (!await LicenseSigner.selfTest(updatedPayload, sig)) {
                      throw StateError('خطای داخلی امضای لایسنس هنگام ویرایش فروشگاه.');
                    }
                    final doc = LicenseDocument(
                      payload: updatedPayload,
                      signatureBase64: sig,
                    );
                    await File(licensePath).writeAsString(
                      doc.toJson(),
                      encoding: utf8,
                      flush: true,
                    );

                    final historyData = updatedPayload.toMap()
                      ..['status'] = '${store['status'] ?? 'ACTIVE'}'
                      ..['originalPrice'] = old.priceAtPurchase
                      ..['finalPrice'] = old.priceAtPurchase
                      ..['businessTypes'] = (selected.toList()..sort());
                    final replaced = await LicenseRepository.instance.replace(
                      licenseId.isEmpty ? old.licenseId : licenseId,
                      historyData,
                    );
                    if (!replaced) {
                      await LicenseRepository.instance.add(
                        updatedPayload,
                        status: 'ACTIVE',
                        note: 'به‌روزرسانی از مدیریت فروشگاه',
                        originalPrice: old.priceAtPurchase,
                        finalPrice: old.priceAtPurchase,
                      );
                    }
                  }

                  final effectiveLicenseId = licenseId.isNotEmpty
                      ? licenseId
                      : '${store['licenseId'] ?? ''}'.trim();
                  await StoreRepository.instance.updateByStoreCode(
                    storeCode,
                    {
                      'storeName': storeName,
                      'ownerName': ownerName,
                      'phone': phone.text.trim(),
                      'storeType': selected.join(','),
                      'businessTypes': selected.toList()..sort(),
                      'licenseId': effectiveLicenseId,
                      'expiresAt': store['expiresAt'],
                      'licenseFile': store['licenseFile'],
                    },
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                  _msg('فروشگاه «$storeName» با موفقیت ویرایش شد.');
                } catch (e) {
                  _msg('خطا در ویرایش فروشگاه: $e', true);
                  setDialogState(() => saving = false);
                }
              }

              return AlertDialog(
                title: const Text('ویرایش فروشگاه'),
                content: SizedBox(
                  width: 680,
                  height: 500,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextField(
                          controller: name,
                          textDirection: ui.TextDirection.rtl,
                          decoration: const InputDecoration(
                            labelText: 'نام فروشگاه',
                            prefixIcon: Icon(Icons.store),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: owner,
                          textDirection: ui.TextDirection.rtl,
                          decoration: const InputDecoration(
                            labelText: 'نام مدیر',
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'شماره تماس',
                            prefixIcon: Icon(Icons.phone),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            'نوع شغل: ${_businessTitle(selected.toList())}',
                            textDirection: ui.TextDirection.rtl,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  await _selectBusinessTypes(selected: selected);
                                  setDialogState(() {});
                                },
                          icon: const Icon(Icons.category_outlined),
                          label: const Text('تغییر دسته‌بندی شغلی'),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: selected.map((e) {
                              return Chip(
                                avatar: const Icon(Icons.work_outline, size: 16),
                                label: Text(
                                  e == '*' ? 'همه مشاغل' : (BusinessCatalog.find(e)?.label ?? e),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(ctx),
                    child: const Text('انصراف'),
                  ),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('ذخیره تغییرات'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      name.dispose();
      owner.dispose();
      phone.dispose();
    }
  }

  Future<void> _deleteStore(Map<String, dynamic> store) async {
    final code = '${store['storeCode'] ?? ''}'.trim();
    final name = '${store['storeName'] ?? code}';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف فروشگاه'),
        content: Text(
          'فروشگاه «$name» حذف شود؟\n\n'
          'سابقه لایسنس حفظ می‌شود و وضعیت آن به REVOKED تغییر می‌کند.',
          textDirection: ui.TextDirection.rtl,
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
            child: const Text('حذف فروشگاه'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final licenseId = '${store['licenseId'] ?? ''}'.trim();
      if (licenseId.isNotEmpty) {
        await LicenseRepository.instance.updateStatus(
          licenseId,
          'REVOKED',
          note: 'فروشگاه از License Manager حذف شد.',
        );
      }

      final licensePath = '${store['licenseFile'] ?? ''}'.trim();
      if (licensePath.isNotEmpty) {
        try {
          final file = File(licensePath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }

      await StoreRepository.instance.deleteByStoreCode(code);
      await _load();
      _msg('فروشگاه «$name» حذف شد.');
    } catch (e) {
      _msg('خطا در حذف فروشگاه: $e', true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'فروشگاه‌ها',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _selectBusinessTypes(selected: _types),
                icon: const Icon(Icons.category_outlined),
                label: const Text('انتخاب شغل'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _createStore,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_business),
                label: const Text('ساخت فروشگاه'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'دسته‌بندی انتخاب‌شده: ${_businessTitle(_types.toList())}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'نام فروشگاه',
                      prefixIcon: Icon(Icons.store),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _owner,
                          decoration: const InputDecoration(
                            labelText: 'نام مدیر',
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _pin,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'PIN مدیر',
                            prefixIcon: Icon(Icons.password),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'شماره تماس',
                            prefixIcon: Icon(Icons.phone),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<int>(
                          initialValue: _days,
                          items: const [30, 90, 180, 365]
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d,
                                  child: Text('$d روز'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _days = v);
                          },
                          decoration: const InputDecoration(
                            labelText: 'مدت لایسنس',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_stores.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'هنوز فروشگاهی ساخته نشده است.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._stores.map(
              (s) {
                final business = _businessTypesFromStore(s);
                final expiresAt =
                    (s['expiresAt'] as num?)?.toInt() ?? 0;
                final expiry = expiresAt > 0
                    ? DateTime.fromMillisecondsSinceEpoch(expiresAt)
                        .toLocal()
                        .toString()
                        .split('.')
                        .first
                    : 'نامشخص';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.store),
                      ),
                      title: Text(
                        '${s['storeName'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'کد فروشگاه: ${s['storeCode'] ?? ''}\n'
                        'مدیر: ${s['ownerName'] ?? ''}  •  تلفن: ${s['phone'] ?? ''}\n'
                        'شغل: ${_businessTitle(business)}\n'
                        'License: ${s['licenseId'] ?? ''}  •  انقضا: $expiry',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'ویرایش فروشگاه',
                            onPressed: _busy ? null : () => _editStore(s),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'حذف فروشگاه',
                            color: Colors.red,
                            onPressed: _busy ? null : () => _deleteStore(s),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
