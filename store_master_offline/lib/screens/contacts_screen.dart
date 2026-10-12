// ============================================================================
// ContactsScreen - نسخه اصلاح‌شده و بدون باگ
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/contact.dart';
import '../viewmodels/main_viewmodel.dart';
import '../services/exporter.dart';
import '../utils/shamsi_date_utils.dart';
import 'package:file_picker/file_picker.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  int selectedTab = 0;
  String searchQuery = '';
  bool showFormDialog = false;
  bool showDebtDialog = false;
  bool showDeleteAllDialog = false;

  Contact? editingContact;
  Contact? debtTargetContact;
  String debtType = 'ADD';
  bool showAllContacts = true;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainViewModel>();
    final currency = vm.config?.currency ?? 'تومان';

    final allContacts = vm.allContacts;
    final debtors = vm.debtors;
    final creditors = vm.creditors;
    final base = showAllContacts ? allContacts : (selectedTab == 0 ? debtors : creditors);

    final filtered = base
        .where((c) =>
            c.name.contains(searchQuery) ||
            c.phone.contains(searchQuery) ||
            c.note.contains(searchQuery))
        .toList();

    // -------------------------------
    // اجرای دیالوگ‌ها به روش صحیح
    // -------------------------------
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (showFormDialog) {
        showFormDialog = false;
        // باز کردن دیالوگ افزودن/ویرایش طرف حساب
        showDialog<void>(
          context: context,
          builder: (_) => _ContactFormDialog(
            vm: vm,
            existing: editingContact,
            onSave: (c) async {
              await vm.saveContact(c);
            },
          ),
        );
      }

      if (showDebtDialog && debtTargetContact != null) {
        showDebtDialog = false;
        // باز کردن دیالوگ افزودن/کسر بدهی
        showDialog<void>(
          context: context,
          builder: (_) => _DebtAdjustDialog(
            vm: vm,
            target: debtTargetContact!,
            initialType: debtType,
            currency: currency,
            onConfirm: (amount, note, type) async {
              final c = debtTargetContact!;
              final isDebtor = c.type == 'CUSTOMER_DEBTOR' ||
                  c.type == 'CUSTOMER' ||
                  c.type == 'BOTH';
              try {
                if (type == 'ADD') {
                  final updated = Contact(
                    id: c.id,
                    name: c.name,
                    phone: c.phone,
                    type: c.type,
                    totalDebt: isDebtor ? c.totalDebt + amount : c.totalDebt,
                    totalPayable:
                        isDebtor ? c.totalPayable : c.totalPayable + amount,
                    note: c.note,
                    notes: '',
                  );
                  await vm.saveContact(updated);
                } else {
                  await vm.recordDebtPayment(c.id, amount, isDebtor);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('ثبت شد')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطا: $e')),
                  );
                }
              }
            },
          ),
        );
      }

      if (showDeleteAllDialog) {
        showDeleteAllDialog = false;
        // تأیید حذف همه‌ی طرف‌حساب‌ها
        showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('حذف همه طرف حساب‌ها'),
            content: const Text('همه طرف حساب‌های مالی حذف شوند؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        ).then((ok) async {
          if (ok == true && mounted) {
            for (final c in allContacts) {
              await vm.deleteContact(c);
            }
          }
        });
      }
    });

    // -------------------------------
    // UI اصلی صفحه
    // -------------------------------
    return Scaffold(
      appBar: AppBar(title: const Text('بدهکاران و طلب‌ها / طرف‌حساب‌ها')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          editingContact = null;
          showFormDialog = true;
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'مدیریت طرف‌حساب‌های مالی فروشگاه (خریداران نسیه، تامین‌کنندگان، طلب‌ها)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),

            // جستجو + خروجی CSV + پاکسازی
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'جستجو در نام، تلفن یا یادداشت‌ها',
                    ),
                    onChanged: (v) => setState(() => searchQuery = v),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final all = [...debtors, ...creditors];
                    final pdf = await Exporter.exportTableToPdf(
                      filenamePrefix: 'لیست_طرف_حساب‌ها',
                      title: 'لیست طرف حساب‌های مالی',
                      storeName: vm.config?.storeName ?? 'فروشگاه',
                      headers: [
                        'نام',
                        'تلفن',
                        'وضعیت',
                        'مبلغ بدهی/طلب ($currency)',
                        'یادداشت'
                      ],
                      rows: all
                          .map((c) => [
                                c.name,
                                c.phone,
                                c.type,
                                c.totalDebt.toStringAsFixed(0),
                                c.note
                              ])
                          .toList(),
                    );
                    if (pdf != null && mounted) {
                      await Exporter.printPdfFile(pdf,
                          jobName: 'لیست طرف حساب‌ها');
                    }
                  },
                  icon: const Icon(Icons.print, color: Color(0xFF6750A4)),
                ),
                IconButton(
                  onPressed: () async {
                    final all = [...debtors, ...creditors];
                    final f = await Exporter.exportExcel(
                      filenamePrefix: 'لیست_طرف_حساب‌ها',
                      sheetName: 'طرف حساب‌ها',
                      title: 'لیست طرف حساب‌های مالی',
                      headers: [
                        'نام',
                        'تلفن',
                        'وضعیت',
                        'مبلغ بدهی/طلب ($currency)',
                        'یادداشت'
                      ],
                      rows: all
                          .map((c) => [
                                c.name,
                                c.phone,
                                c.type,
                                c.totalDebt.toStringAsFixed(0),
                                c.note
                              ])
                          .toList(),
                      storeName: vm.config?.storeName,
                    );
                    if (f != null && mounted) {
                      // نمایش فایل برای کاربر: ویندوز → Explorer، موبایل → پنجره‌ی ذخیره
                      final shown = await Exporter.shareFile(f.path);
                      if (!shown) {
                        try {
                          final bytes = await f.readAsBytes();
                          final saved = await FilePicker.platform.saveFile(
                            fileName: f.uri.pathSegments.last,
                            bytes: bytes,
                          );
                          if (saved != null && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'خروجی اکسل ذخیره شد: ${saved.split('/').last}')),
                            );
                          }
                        } catch (_) {}
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('خروجی اکسل ذخیره شد: ${f.path}')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.table_chart, color: Color(0xFF6750A4)),
                ),
                if (base.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      showDeleteAllDialog = true;
                      setState(() {});
                    },
                    icon: const Icon(Icons.delete_sweep, color: Colors.red),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // کارت‌های خلاصه بدهکاران/بستانکاران
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Theme.of(context)
                        .colorScheme
                        .errorContainer
                        .withValues(alpha: 0.4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تعداد بدهکاران ${debtors.length}',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFFAD1457))),
                          Text(
                            NumberFormat('#,##0', 'en_US').format(
                                    debtors.fold<double>(
                                        0, (s, c) => s + c.totalDebt)) +
                                ' $currency',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC2185B),
                                fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تعداد بستانکاران ${creditors.length}',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF8C5A8B))),
                          Text(
                            NumberFormat('#,##0', 'en_US').format(
                                    creditors.fold<double>(
                                        0, (s, c) => s + c.totalPayable)) +
                                ' $currency',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8E24AA),
                                fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // تب‌ها
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text(
                      'بدهکاران (طلب‌های ما) (${debtors.length})',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    selected: selectedTab == 0,
                    onSelected: (_) => setState(() { selectedTab = 0; showAllContacts = false; }),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ChoiceChip(
                    label: Text(
                      'بستانکاران (بدهی‌های ما) (${creditors.length})',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    selected: selectedTab == 1,
                    onSelected: (_) => setState(() { selectedTab = 1; showAllContacts = false; }),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ChoiceChip(
                    label: Text('همه مشتریان و طرف‌حساب‌ها (${allContacts.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    selected: showAllContacts,
                    onSelected: (_) => setState(() => showAllContacts = true),
                  ),
                ),
              ],
            ),

            // لیست طرف‌حساب‌ها
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('هیچ نتیجه‌ای یافت نشد',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        return Card(
                          color: c.totalDebt > 0 ? Colors.orange.shade50 : null,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        c.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        debtTargetContact = c;
                                        debtType = 'ADD';
                                        showDebtDialog = true;
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.add_circle,
                                          color: Colors.green),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        debtTargetContact = c;
                                        debtType = 'PAY';
                                        showDebtDialog = true;
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.remove_circle,
                                          color: Colors.orange),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        editingContact = c;
                                        showFormDialog = true;
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                    ),
                                    IconButton(
                                      onPressed: () => vm.deleteContact(c),
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                    ),
                                  ],
                                ),
                                if (c.phone.isNotEmpty)
                                  Text('تلفن: ${c.phone}',
                                      style:
                                          const TextStyle(color: Colors.grey)),
                                if (c.note.isNotEmpty)
                                  Text('یادداشت: ${c.note}',
                                      style:
                                          const TextStyle(color: Colors.grey)),
                                Row(
                                  children: [
                                    if (c.totalDebt > 0)
                                      Text(
                                        'مبلغ بدهکار/طلب: ${NumberFormat('#,##0', 'en_US').format(c.totalDebt)} $currency',
                                        style: const TextStyle(
                                            color: Color(0xFFC2185B),
                                            fontWeight: FontWeight.bold),
                                      ),
                                    const Spacer(),
                                    if (c.updatedAt > 0)
                                      Text(
                                        'آخرین تراکنش: ${faDateMillis(c.updatedAt)}',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.grey),
                                      ),
                                  ],
                                ),
                              ],
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

// -------------------------------
// دیالوگ‌ها بدون تغییر
// -------------------------------

class _ContactFormDialog extends StatefulWidget {
  final MainViewModel vm;
  final Contact? existing;
  final Function(Contact) onSave;

  const _ContactFormDialog({
    required this.vm,
    this.existing,
    required this.onSave,
  });

  @override
  State<_ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends State<_ContactFormDialog> {
  late TextEditingController nameCtrl, phoneCtrl, notesCtrl;
  late String selType;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    nameCtrl = TextEditingController(text: e?.name ?? '');
    phoneCtrl = TextEditingController(text: e?.phone ?? '');
    notesCtrl = TextEditingController(text: e?.note ?? '');
    selType = e?.type ?? 'CUSTOMER_DEBTOR';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.existing == null ? 'افزودن طرف حساب جدید' : 'ویرایش طرف حساب'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'نام')),
              TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'شماره تماس')),
              TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'یادداشت'),
                  maxLines: 3),
              const SizedBox(height: 8),
              const Text('طبقه‌بندی طرف حساب:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              RadioGroup<String>(
                groupValue: selType,
                onChanged: (v) {
                  if (v != null) {
                    setState(() => selType = v);
                  }
                },
                child: Column(
                  children: [
                    for (final opt in const [
                      ('CUSTOMER', 'مشتری'),
                      ('CUSTOMER_DEBTOR', 'خریدار / بدهکار'),
                      ('SUPPLIER_CREDITOR', 'تامین‌کننده / بستانکار'),
                      ('BOTH', 'مشتری و تامین‌کننده'),
                    ])
                      RadioListTile<String>(
                        title: Text(opt.$2, style: const TextStyle(fontSize: 12)),
                        value: opt.$1,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف')),
        ElevatedButton(
          onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) { setState(() {}); return; }
            try {
              await widget.onSave(
              Contact(
                id: widget.existing?.id ?? 0,
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text,
                type: selType,
                notes: notesCtrl.text,
                totalDebt: widget.existing?.totalDebt ?? 0,
                totalPayable: widget.existing?.totalPayable ?? 0,
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              ),
              );
              if (mounted) Navigator.pop(context);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ذخیره طرف حساب ناموفق بود: $e')));
              }
            }
          },
          child: const Text('ذخیره'),
        ),
      ],
    );
  }
}

class _DebtAdjustDialog extends StatefulWidget {
  final MainViewModel vm;
  final Contact target;
  final String initialType;
  final String currency;
  final Function(double amount, String note, String type) onConfirm;

  const _DebtAdjustDialog({
    required this.vm,
    required this.target,
    required this.initialType,
    required this.currency,
    required this.onConfirm,
  });

  @override
  State<_DebtAdjustDialog> createState() => _DebtAdjustDialogState();
}

class _DebtAdjustDialogState extends State<_DebtAdjustDialog> {
  late TextEditingController amtCtrl, noteCtrl;
  late String type;

  @override
  void initState() {
    super.initState();
    amtCtrl = TextEditingController();
    noteCtrl = TextEditingController();
    type = widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        type == 'ADD'
            ? 'افزودن بدهی / ثبت نسیه ${widget.target.name}'
            : 'دریافت وجه / کم کردن بدهی ${widget.target.name}',
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amtCtrl,
              decoration:
                  InputDecoration(labelText: 'مبلغ (${widget.currency})'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'یادداشت'),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('افزودن بدهی (+)',
                        style: TextStyle(fontSize: 12)),
                    selected: type == 'ADD',
                    onSelected: (_) => setState(() => type = 'ADD'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('پرداخت / تسویه (-)',
                        style: TextStyle(fontSize: 12)),
                    selected: type == 'PAY',
                    onSelected: (_) => setState(() => type = 'PAY'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف')),
        ElevatedButton(
          onPressed: () {
            final v = double.tryParse(amtCtrl.text) ?? 0;
            if (v <= 0) return;
            widget.onConfirm(v, noteCtrl.text, type);
            Navigator.pop(context);
          },
          child: const Text('ثبت'),
        ),
      ],
    );
  }
}