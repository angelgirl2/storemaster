// users_screen_fixed.dart
// نسخه اصلاح‌شده UsersScreen — بدون extension اشتباه، دیالوگ‌ها ایمن و کنترلرها مدیریت‌شده

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../viewmodels/main_viewmodel.dart';
import '../services/permission_service.dart';
import '../shared_src/permission_catalog.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({Key? key}) : super(key: key);
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  bool showAddDialog = false;
  User? editingUser;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainViewModel>();
    final users = vm.users;
    final currency = vm.config?.currency ?? 'تومان';

    // schedule dialog after frame to avoid returning void from build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (showAddDialog) {
        showAddDialog = false;
        showDialog(
          context: context,
          builder: (_) => _UserFormDialog(
            vm: vm,
            currency: currency,
            existing: editingUser,
            onSave: (u) async {
              await vm.saveUser(u);
              if (mounted) setState(() => editingUser = null);
            },
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('مدیریت کاربران و پرسنل')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() {
          editingUser = null;
          showAddDialog = true;
        }),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('مدیریت کاربران و پرسنل فروشگاه',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                        'مدیر قابل تغییر: نام، پین‌کد، نقش، درصد پورسانت. تنها مدیران امکان تعریف کاربر را دارند.',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: users.isEmpty
                ? const Center(
                    child: Text('کاربری تعریف نشده',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (_, i) {
                      final u = users[i];
                      final isAdmin = u.role == 'ADMIN' || u.role == 'OWNER';
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: isAdmin
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                    child: Icon(
                                        isAdmin
                                            ? Icons.admin_panel_settings
                                            : Icons.person,
                                        color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Row(children: [
                                          Text(u.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16)),
                                          const SizedBox(width: 6),
                                          Chip(
                                            label: Text(
                                                {'OWNER':'مالک','ADMIN':'مدیر کل','MANAGER':'مدیر','SELLER':'فروشنده','WAREHOUSE':'انباردار','ACCOUNTANT':'حسابدار','CASHIER':'صندوقدار'}[u.role] ?? u.role,
                                                style: const TextStyle(
                                                    fontSize: 10)),
                                            backgroundColor: isAdmin
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.2)
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .secondary
                                                    .withValues(alpha: 0.2),
                                          ),
                                        ]),
                                        Text(
                                          'حقوق پایه: ${u.baseSalary.toStringAsFixed(0)} $currency | پورسانت فروشنده: ${u.commissionPercent.toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        ),
                                      ])),
                                  IconButton(
                                      onPressed: () => setState(() {
                                            editingUser = u;
                                            showAddDialog = true;
                                          }),
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue)),
                                  if (!isAdmin)
                                    IconButton(
                                      onPressed: () async {
                                        try {
                                          await vm.deleteUser(u);
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e.toString().replaceFirst('Bad state: ', ''),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                    ),
                                ]),
                                const SizedBox(height: 8),
                                Row(children: [
                                  Text(
                                      'فروش: ${u.totalSalesAmount.toStringAsFixed(0)} $currency',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary)),
                                  const Spacer(),
                                  Text(
                                      'پورسانت: ${u.totalCommission.toStringAsFixed(0)} $currency',
                                      style: const TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontWeight: FontWeight.bold)),
                                ]),
                              ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  final MainViewModel vm;
  final String currency;
  final User? existing;
  final Future<void> Function(User) onSave;
  const _UserFormDialog(
      {required this.vm,
      required this.currency,
      this.existing,
      required this.onSave});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  String _permissionLabel(String p) {
    final m = <String, String>{
      'ALL': 'دسترسی کامل',
      'dashboard_view': 'مشاهده داشبورد',
      'sales_create': 'ثبت فروش',
      'invoices_edit': 'ویرایش فاکتور',
      'invoices_delete': 'حذف فاکتور',
      'products_view': 'مشاهده کالاها',
      'inventory_view': 'مشاهده انبار',
      'inventory_manage': 'مدیریت موجودی',
      'customers_view': 'مشاهده مشتریان و طرف‌حساب‌ها',
      'accounting_expenses': 'ثبت و مشاهده هزینه‌ها',
      'accounting_manage': 'مدیریت حسابداری',
      'reports_view': 'مشاهده گزارش‌ها',
      'reports_advanced': 'گزارش‌های پیشرفته',
      'users_manage': 'مدیریت کاربران',
      'roles_manage': 'مدیریت نقش‌ها و دسترسی‌ها',
      'settings_manage': 'مدیریت تنظیمات',
      'warehouses_manage': 'مدیریت انبارها',
    };
    return m[p] ?? p;
  }
  late TextEditingController nameCtrl;
  late TextEditingController pinCtrl;
  late TextEditingController salaryCtrl;
  late TextEditingController commCtrl;
  late String selRole;
  String? error;
  Set<String> selectedPermissions = <String>{};

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    pinCtrl = TextEditingController(text: widget.existing?.pin ?? '');
    salaryCtrl = TextEditingController(
        text: (widget.existing?.baseSalary ?? 0).toStringAsFixed(0));
    commCtrl = TextEditingController(
        text: (widget.existing?.commissionPercent ?? 7).toStringAsFixed(1));
    selRole = widget.existing?.role ?? 'SELLER';
    final existingPermissions = widget.existing?.permissions ?? const <String>[];
    selectedPermissions = existingPermissions.isEmpty ? PermissionService.defaultPermissionsForRole(selRole) : {...existingPermissions};
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    pinCtrl.dispose();
    salaryCtrl.dispose();
    commCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.existing == null ? 'افزودن کارمند یا پرسنل' : 'ویرایش کارمند'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'نام و نام خانوادگی')),
            TextField(
                controller: pinCtrl,
                decoration:
                    const InputDecoration(labelText: 'پین‌کد (۴–۶ رقم عددی)'),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6),
            TextField(
                controller: salaryCtrl,
                decoration: InputDecoration(
                    labelText: 'حقوق پایه (${widget.currency})'),
                keyboardType: TextInputType.number),
            TextField(
                controller: commCtrl,
                decoration:
                    const InputDecoration(labelText: 'درصد پورسانت فروش (%)'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in const ['MANAGER','SELLER','WAREHOUSE','ACCOUNTANT','CASHIER','ADMIN','CUSTOM'])
                  ChoiceChip(
                    label: Text({'MANAGER':'مدیر','SELLER':'فروشنده','WAREHOUSE':'انباردار','ACCOUNTANT':'حسابدار','CASHIER':'صندوقدار','ADMIN':'مدیر کل','CUSTOM':'سفارشی'}[r]!),
                    selected: selRole == r,
                    onSelected: (_) => setState(() {
                      selRole = r;
                      selectedPermissions = PermissionService.defaultPermissionsForRole(r);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Align(alignment: AlignmentDirectional.centerStart, child: Text('دسترسی‌های اختصاصی این کاربر', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 4),
            ...PermissionCatalog.all.map((permission) => CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(_permissionLabel(permission), style: const TextStyle(fontSize: 12)),
              value: selectedPermissions.contains(permission),
              onChanged: (v) => setState(() { if (v == true) selectedPermissions.add(permission); else selectedPermissions.remove(permission); }),
            )),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child:
                      Text(error!, style: const TextStyle(color: Colors.red))),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف')),
        ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) {
                setState(() => error = 'نام الزامی است');
                return;
              }
              if (!RegExp(r'^\d{4,6}$').hasMatch(pinCtrl.text.trim())) {
                setState(() => error = 'پین باید ۴ تا ۶ رقم باشد');
                return;
              }
              final user = User(
                id: widget.existing?.id ?? 0,
                name: nameCtrl.text.trim(),
                pin: pinCtrl.text.trim(),
                role: selRole,
                baseSalary:
                    double.tryParse(salaryCtrl.text.replaceAll(',', '')) ?? 0,
                commissionPercent:
                    double.tryParse(commCtrl.text.replaceAll(',', '')) ?? 7,
                totalSalesAmount: widget.existing?.totalSalesAmount ?? 0,
                totalCommission: widget.existing?.totalCommission ?? 0,
                pinCode: '',
                permissions: selectedPermissions.toList(),
                storeId: widget.existing?.storeId ?? 0,
                serverUserId: widget.existing?.serverUserId ?? 0,
              );
              try {
                await widget.onSave(user);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) setState(() => error = e.toString().replaceFirst('Bad state: ', '').replaceFirst('Invalid argument(s): ', ''));
              }
            },
            child: const Text('ذخیره')),
      ],
    );
  }
}
