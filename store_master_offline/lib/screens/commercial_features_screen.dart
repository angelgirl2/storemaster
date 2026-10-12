// ============================================================================
// CommercialFeaturesScreen - کنترل امکانات تجاری پیشرفته
// ============================================================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/accounting_models.dart';
import '../utils/shamsi_date_utils.dart';

import '../models/commercial_models.dart';
import '../services/store_repository.dart';
import '../viewmodels/main_viewmodel.dart';

class CommercialFeaturesScreen extends StatefulWidget {
  const CommercialFeaturesScreen({super.key});

  @override
  State<CommercialFeaturesScreen> createState() =>
      _CommercialFeaturesScreenState();
}

class _CommercialFeaturesScreenState extends State<CommercialFeaturesScreen> {
  final StoreRepository _repo = StoreRepository();
  int _tab = 0;
  bool _busy = true;
  List<FiscalYear> _years = [];
  List<CheckRecord> _checks = [];
  List<InstallmentRecord> _installments = [];
  List<BankReconciliation> _reconciliations = [];
  List<WarehouseRecord> _warehouses = [];
  List<PriceListRecord> _priceLists = [];
  List<SerialNumberRecord> _serials = [];
  List<TaxRuleRecord> _taxRules = [];
  List<CostCenterRecord> _costCenters = [];
  List<CashBankAccount> _cashBanks = [];
  int? _selectedReconcileBankId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      await _repo.ensureAccountingSeed();
      _years = await _repo.getFiscalYears();
      _checks = await _repo.getChecks();
      _installments = await _repo.getInstallments();
      _reconciliations = await _repo.getBankReconciliations();
      _warehouses = await _repo.getWarehouses();
      _priceLists = await _repo.getPriceLists();
      _serials = await _repo.getSerials();
      _taxRules = await _repo.getTaxRules();
      _costCenters = await _repo.getCostCenters();
      _cashBanks = await _repo.getCashBankAccounts();
    _selectedReconcileBankId ??= _cashBanks.isNotEmpty ? _cashBanks.first.id : null;
    if (_selectedReconcileBankId != null && !_cashBanks.any((x) => x.id == _selectedReconcileBankId)) {
      _selectedReconcileBankId = _cashBanks.isNotEmpty ? _cashBanks.first.id : null;
    }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainViewModel>();
    final currency = vm.config?.currency ?? 'تومان';
    final tabs = const [
      'دوره مالی',
      'چک‌ها',
      'اقساط',
      'تطبیق بانک',
      'انبارها',
      'قیمت‌گذاری',
      'سریال کالا',
      'مالیات',
      'مراکز هزینه'
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت تجاری پیشرفته'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(10),
                  child: Row(
                      children: List.generate(
                          tabs.length,
                          (i) => Padding(
                                padding:
                                    const EdgeInsetsDirectional.only(end: 6),
                                child: ChoiceChip(
                                    label: Text(tabs[i]),
                                    selected: _tab == i,
                                    onSelected: (_) =>
                                        setState(() => _tab = i)),
                              ))),
                ),
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _buildTab(vm, currency))),
              ],
            ),
    );
  }

  Widget _buildTab(MainViewModel vm, String currency) {
    switch (_tab) {
      case 0:
        return _yearsTab();
      case 1:
        return _checksTab(vm, currency);
      case 2:
        return _installmentsTab(vm, currency);
      case 3:
        return _reconcileTab(vm, currency);
      case 4:
        return _warehousesTab();
      case 5:
        return _priceListsTab();
      case 6:
        return _serialsTab();
      case 7:
        return _taxRulesTab();
      default:
        return _costCentersTab();
    }
  }

  Widget _yearsTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        FilledButton.icon(
            onPressed: _addCurrentYear,
            icon: const Icon(Icons.add),
            label: const Text('افزودن سال مالی جاری')),
        const SizedBox(width: 8),
        const Expanded(
            child: Text(
                'هر سال مالی مستقل است و پس از بستن، عملیات اصلاحی باید با سند اصلاحی انجام شود.')),
      ]),
      const SizedBox(height: 12),
      Expanded(
          child: ListView.builder(
              itemCount: _years.length,
              itemBuilder: (_, i) {
                final y = _years[i];
                return Card(
                    child: ListTile(
                  leading: CircleAvatar(child: Text('${y.year % 100}')),
                  title: Text('سال مالی ${y.year}'),
                  subtitle:
                      Text('${_date(y.startMillis)} تا ${_date(y.endMillis)}'),
                  trailing: y.isClosed
                      ? const Chip(label: Text('بسته شده'))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              tooltip: 'ویرایش سال مالی',
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _editYear(y)),
                          IconButton(
                              tooltip: 'حذف سال مالی',
                              icon: const Icon(Icons.delete,
                                  size: 18, color: Colors.red),
                              onPressed: () => _deleteYear(y)),
                          FilledButton.tonal(
                              onPressed: () => _closeYear(y),
                              child: const Text('بستن سال')),
                        ]),
                ));
              }))
    ]);
  }

  Future<void> _addCurrentYear() async {
    final year = Jalali.now().year;
    final start = Jalali(year, 1, 1).toDateTime();
    final end = Jalali(year + 1, 1, 1).toDateTime().subtract(const Duration(milliseconds: 1));
    await _repo.saveFiscalYear(FiscalYear(
      year: year,
      startMillis: start.millisecondsSinceEpoch,
      endMillis: end.millisecondsSinceEpoch,
    ));
    await _load();
  }

  Future<void> _closeYear(FiscalYear y) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('بستن سال مالی'),
              content: Text(
                  'سال ${y.year} بسته شود؟ پس از بستن، بهتر است اصلاحات با سند جدید انجام شود.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('انصراف')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('بستن سال'))
              ],
            ));
    if (ok == true) {
      await _repo.closeFiscalYear(y.id);
      await _load();
    }
  }

  Future<void> _editYear(FiscalYear y) async {
    final sy = TextEditingController(
        text: '${Jalali.fromDateTime(DateTime.fromMillisecondsSinceEpoch(y.startMillis)).year}');
    final ey = TextEditingController(
        text: '${Jalali.fromDateTime(DateTime.fromMillisecondsSinceEpoch(y.endMillis)).year}');
    final ok = await _simpleDialog('ویرایش سال مالی ${y.year}', [sy, ey],
        ['سال شروع (شمسی)', 'سال پایان (شمسی)']);
    if (ok) {
      final s = int.tryParse(sy.text.trim()) ?? Jalali.now().year;
      final e = int.tryParse(ey.text.trim()) ?? Jalali.now().year + 1;
      await _repo.saveFiscalYear(FiscalYear(
        id: y.id,
        year: s,
        startMillis: Jalali(s, 1, 1).toDateTime().millisecondsSinceEpoch,
        endMillis: Jalali(e, 1, 1)
            .toDateTime()
            .subtract(const Duration(milliseconds: 1))
            .millisecondsSinceEpoch,
        isClosed: y.isClosed,
      ));
      await _load();
    }
    sy.dispose();
    ey.dispose();
  }

  Future<void> _deleteYear(FiscalYear y) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('حذف سال مالی'),
              content: Text('سال مالی ${y.year} حذف شود؟'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('انصراف')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('حذف'))
              ],
            ));
    if (ok == true) {
      await _repo.deleteFiscalYear(y.id);
      await _load();
    }
  }

  Widget _checksTab(MainViewModel vm, String currency) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        FilledButton.icon(onPressed: () => _addCheck(vm), icon: const Icon(Icons.add), label: const Text('ثبت چک')),
        const SizedBox(width: 8), Text('تعداد: ${_checks.length}'), const Spacer(),
        if (_checks.isNotEmpty) OutlinedButton.icon(onPressed: () async { if (await _confirmDelete('پاک کردن سابقه چک‌ها','تمام چک‌ها حذف شوند؟')) { await _repo.deleteAllChecks(); await _load(); } }, icon: const Icon(Icons.delete_sweep, color: Colors.red), label: const Text('پاک کردن سابقه'))
      ]),
      const SizedBox(height: 10),
      Expanded(
          child: ListView.builder(
              itemCount: _checks.length,
              itemBuilder: (_, i) {
                final c = _checks[i];
                return Card(
                    child: ListTile(
                  leading: Icon(
                      c.type == 'RECEIVED'
                          ? Icons.call_received
                          : Icons.north_east,
                      color:
                          c.type == 'RECEIVED' ? Colors.green : Colors.orange),
                  title: Text('${c.number} - ${c.contactName}'),
                  subtitle: Text(
                      '${c.bankName.isEmpty ? 'بدون بانک' : c.bankName} | سررسید ${_date(c.dueDateMillis)} | ${c.status}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_money(c.amount, currency), style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.edit, size: 18), tooltip: 'ویرایش چک', onPressed: () => _editCheck(vm, c)),
                    IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), tooltip: 'حذف چک', onPressed: () async {
                      if (await _confirmDelete('حذف چک', 'چک ${c.number} حذف شود؟')) {
                        await _repo.deleteCheck(c.id);
                        await _load();
                      }
                    }),
                  ]),
                ));
              }))
    ]);
  }

  Future<void> _editCheck(MainViewModel vm, CheckRecord c) async {
    final number = TextEditingController(text: c.number);
    final amount = TextEditingController(text: c.amount.toStringAsFixed(0));
    final bank = TextEditingController(text: c.bankName);
    final contact = TextEditingController(text: c.contactName);
    String type = c.type;
    try {
      final ok = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('ویرایش چک'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: type, items: const [DropdownMenuItem(value:'RECEIVED',child:Text('چک دریافتی')),DropdownMenuItem(value:'PAYABLE',child:Text('چک پرداختی'))], onChanged:(v)=>setS(()=>type=v??type)),
          TextField(controller:number, decoration:const InputDecoration(labelText:'شماره چک')), TextField(controller:contact, decoration:const InputDecoration(labelText:'طرف حساب')), TextField(controller:bank, decoration:const InputDecoration(labelText:'بانک')), TextField(controller:amount, keyboardType:TextInputType.number, decoration:const InputDecoration(labelText:'مبلغ')),
        ])), actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('ذخیره'))])));
      if (ok == true) { await _repo.saveCheck(CheckRecord(id:c.id,type:type,number:number.text.trim(),contactName:contact.text.trim(),bankName:bank.text.trim(),amount:double.tryParse(amount.text.replaceAll(',',''))??0,dueDateMillis:c.dueDateMillis,status:c.status,cashBankId:c.cashBankId,settlementId:c.settlementId,clearedDateMillis:c.clearedDateMillis,description:c.description,userId:c.userId,userName:c.userName)); await _load(); }
    } finally { for (final x in [number,amount,bank,contact]) x.dispose(); }
  }

  Future<void> _addCheck(MainViewModel vm) async {
    final number = TextEditingController();
    final amount = TextEditingController();
    final bank = TextEditingController();
    final contact = TextEditingController();
    String type = 'RECEIVED';
    try {
      final ok = await showDialog<bool>(
          context: context,
          builder: (_) => StatefulBuilder(
              builder: (ctx, setS) => AlertDialog(
                    title: const Text('ثبت چک'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<String>(
                          initialValue: type,
                          items: const [
                            DropdownMenuItem(
                                value: 'RECEIVED', child: Text('چک دریافتی')),
                            DropdownMenuItem(
                                value: 'PAYABLE', child: Text('چک پرداختی'))
                          ],
                          onChanged: (v) => setS(() => type = v ?? type)),
                      TextField(
                          controller: number,
                          decoration:
                              const InputDecoration(labelText: 'شماره چک')),
                      TextField(
                          controller: contact,
                          decoration:
                              const InputDecoration(labelText: 'طرف حساب')),
                      TextField(
                          controller: bank,
                          decoration: const InputDecoration(labelText: 'بانک')),
                      TextField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'مبلغ')),
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('انصراف')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('ثبت'))
                    ],
                  )));
      if (ok == true && number.text.trim().isNotEmpty) {
        final user = vm.currentUser;
        await _repo.saveCheck(CheckRecord(
            type: type,
            number: number.text.trim(),
            contactName: contact.text.trim(),
            bankName: bank.text.trim(),
            amount: double.tryParse(amount.text.replaceAll(',', '')) ?? 0,
            dueDateMillis: DateTime.now()
                .add(const Duration(days: 30))
                .millisecondsSinceEpoch,
            userId: user?.id ?? 0,
            userName: user?.name ?? ''));
        await _load();
      }
    } finally {
      number.dispose();
      amount.dispose();
      bank.dispose();
      contact.dispose();
    }
  }

  Future<void> _addInstallment(MainViewModel vm) async {
    final contact = TextEditingController();
    final amount = TextEditingController();
    final days = TextEditingController(text: '30');
    final ok = await _simpleDialog('قسط جدید', [contact, amount, days],
        ['طرف حساب', 'مبلغ', 'سررسید پس از (روز)']);
    if (ok) {
      await _repo.saveInstallment(InstallmentRecord(
          transactionId: 0,
          contactName: contact.text.trim(),
          amount: double.tryParse(amount.text.replaceAll(',', '')) ?? 0,
          dueDateMillis: DateTime.now()
              .add(Duration(days: int.tryParse(days.text) ?? 30))
              .millisecondsSinceEpoch,
          status: 'OPEN'));
      await _load();
    }
    contact.dispose();
    amount.dispose();
    days.dispose();
  }

  Widget _installmentsTab(MainViewModel vm, String currency) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: Text('سررسید شده: ${_installments.where((x) => x.status != 'PAID' && x.dueDateMillis < now).length}')), FilledButton.icon(onPressed: () => _addInstallment(vm), icon: const Icon(Icons.add), label: const Text('افزودن قسط')), const SizedBox(width:8), if(_installments.isNotEmpty) OutlinedButton.icon(onPressed:() async {if(await _confirmDelete('پاک کردن سابقه اقساط','تمام اقساط حذف شوند؟')){await _repo.deleteAllInstallments();await _load();}},icon:const Icon(Icons.delete_sweep,color:Colors.red),label:const Text('پاک کردن سابقه'))]),
      const SizedBox(height: 8),
      Expanded(
          child: ListView.builder(
              itemCount: _installments.length,
              itemBuilder: (_, i) {
                final x = _installments[i];
                final remain = x.amount - x.paidAmount;
                return Card(
                    child: ListTile(
                        title: Text(
                            '${x.contactName} - فاکتور #${x.transactionId}'),
                        subtitle: Text(
                            'سررسید ${_date(x.dueDateMillis)} | ${x.status}'),
                        trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_money(remain, currency),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              if (remain > 0)
                                TextButton(
                                    onPressed: () async {
                                      await _repo.applyInstallmentPayment(
                                          x.id, remain);
                                      await _load();
                                    },
                                    child: const Text('تسویه کامل')),
                              IconButton(
                                  tooltip: 'حذف قسط',
                                  icon: const Icon(Icons.delete,
                                      size: 18, color: Colors.red),
                                  onPressed: () async {
                                    await _repo.deleteInstallment(x.id);
                                    await _load();
                                  })
                            ])));
              }))
    ]);
  }

  Widget _reconcileTab(MainViewModel vm, String currency) {
    CashBankAccount? selected;
    for (final account in _cashBanks) {
      if (account.id == _selectedReconcileBankId) { selected = account; break; }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: DropdownButtonFormField<int>(
              initialValue: _selectedReconcileBankId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'حساب بانکی / صندوق',
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
              items: _cashBanks
                  .map((x) => DropdownMenuItem<int>(value: x.id, child: Text(x.name)))
                  .toList(),
              onChanged: _cashBanks.isEmpty
                  ? null
                  : (v) => setState(() => _selectedReconcileBankId = v),
            ),
          ),
          FilledButton.icon(
            onPressed: selected == null ? null : () => _addReconciliation(vm),
            icon: const Icon(Icons.sync_alt),
            label: const Text('ثبت تطبیق بانکی'),
          ),
          if (_cashBanks.isEmpty)
            const Text(
              'ابتدا از بخش حسابداری، یک حساب بانکی ثبت کنید.',
              style: TextStyle(color: Colors.orange),
            ),
        ],
      ),
      const SizedBox(height: 10),
      if (selected != null)
        Builder(
          builder: (_) {
            final account = selected!;
            return FutureBuilder<double>(
              future: _repo.getCashBankBalance(account),
              builder: (_, snap) => Card(
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text('مانده دفاتر: ${_money(snap.data ?? 0, currency)}'),
                  subtitle: Text(account.type == 'BANK' && account.bankName.isNotEmpty
                      ? '${account.bankName}${account.accountNumber.isEmpty ? '' : ' | ${account.accountNumber}'}'
                      : 'صندوق'),
                ),
              ),
            );
          },
        ),
      const SizedBox(height: 6),
      Expanded(
        child: _reconciliations.isEmpty
            ? const Center(child: Text('هنوز موردی برای تطبیق ثبت نشده است.'))
            : ListView.builder(
                itemCount: _reconciliations.length,
                itemBuilder: (_, i) {
                  final x = _reconciliations[i];
                  final bankName = _cashBanks.firstWhere((b) => b.id == x.cashBankId, orElse: () => CashBankAccount(id: 0, name: 'حساب', type: 'CASH', ledgerAccountId: 0)).name;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.rule_folder_outlined),
                      title: Text('$bankName | تطبیق ${_date(x.statementDateMillis)}'),
                      subtitle: Text(
                          'مانده دفاتر: ${_money(x.bookBalance, currency)} | صورت‌حساب: ${_money(x.statementBalance, currency)}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_money(x.difference, currency),
                            style: TextStyle(
                                color: x.difference.abs() < .01 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold)),
                        IconButton(
                            tooltip: 'حذف تطبیق بانکی',
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () async {
                              await _repo.deleteBankReconciliation(x.id);
                              await _load();
                            }),
                      ]),
                    ),
                  );
                }),
      )
    ]);
  }

  Future<void> _addReconciliation(MainViewModel vm) async {
    final bank = _cashBanks.firstWhere((x) => x.id == _selectedReconcileBankId, orElse: () => _cashBanks.first);
    final statement = TextEditingController();
    final notes = TextEditingController();
    final book = await _repo.getCashBankBalance(bank);
    try {
      final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
                  title: const Text('تطبیق بانکی'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        'مانده دفاتر: ${_money(book, vm.config?.currency ?? 'تومان')}'),
                    TextField(
                        controller: statement,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'مانده صورت‌حساب')),
                    TextField(
                        controller: notes,
                        decoration: const InputDecoration(labelText: 'یادداشت'))
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('انصراف')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('ثبت'))
                  ]));
      if (ok == true) {
        final s = double.tryParse(statement.text.replaceAll(',', '')) ?? 0;
        final user = vm.currentUser;
        await _repo.saveBankReconciliation(BankReconciliation(
            cashBankId: bank.id,
            statementDateMillis: DateTime.now().millisecondsSinceEpoch,
            statementBalance: s,
            bookBalance: book,
            difference: s - book,
            notes: notes.text.trim(),
            userId: user?.id ?? 0,
            userName: user?.name ?? ''));
        await _load();
      }
    } finally {
      statement.dispose();
      notes.dispose();
    }
  }

  Widget _warehousesTab() => _masterList<WarehouseRecord>(
          _warehouses, (w) => '${w.code} - ${w.name}', (w) => w.location, () async {
        final c = TextEditingController();
        final n = TextEditingController();
        final ok = await _simpleDialog(
            'انبار جدید', [c, n], ['کد انبار', 'نام انبار']);
        if (ok) {
          await _repo.saveWarehouse(
              WarehouseRecord(code: c.text.trim(), name: n.text.trim()));
          await _load();
        }
        c.dispose();
        n.dispose();
      });
  Widget _priceListsTab() => _masterList<PriceListRecord>(
          _priceLists, (x) => x.name, (x) => x.isDefault ? 'لیست اصلی' : 'قیمت‌گذاری',
          () async {
        final n = TextEditingController();
        final ok = await _simpleDialog('لیست قیمت جدید', [n], ['نام لیست']);
        if (ok) {
          await _repo.savePriceList(PriceListRecord(name: n.text.trim()));
          await _load();
        }
        n.dispose();
      });
  Widget _serialsTab() => _masterList<SerialNumberRecord>(
          _serials, (x) => x.serial, (x) => 'محصول #${x.productId} | ${x.status}',
          () async {
        final p = TextEditingController();
        final s = TextEditingController();
        final ok = await _simpleDialog(
            'ثبت سریال', [p, s], ['شناسه کالا', 'شماره سریال']);
        if (ok) {
          await _repo.saveSerial(SerialNumberRecord(
              productId: int.tryParse(p.text.trim()) ?? 0,
              serial: s.text.trim()));
          await _load();
        }
        p.dispose();
        s.dispose();
      });
  Widget _taxRulesTab() => _masterList<TaxRuleRecord>(
          _taxRules, (x) => '${x.code} - ${x.name}', (x) => 'نرخ ${x.rate}٪',
          () async {
        final c = TextEditingController();
        final n = TextEditingController();
        final r = TextEditingController(text: '0');
        final ok = await _simpleDialog(
            'قاعده مالیاتی', [c, n, r], ['کد', 'نام', 'نرخ درصد']);
        if (ok) {
          await _repo.saveTaxRule(TaxRuleRecord(
              code: c.text.trim(),
              name: n.text.trim(),
              rate: double.tryParse(r.text) ?? 0));
          await _load();
        }
        c.dispose();
        n.dispose();
        r.dispose();
      });
  Widget _costCentersTab() => _masterList<CostCenterRecord>(
          _costCenters, (x) => '${x.code} - ${x.name}', (x) => 'مرکز هزینه فعال',
          () async {
        final c = TextEditingController();
        final n = TextEditingController();
        final ok =
            await _simpleDialog('مرکز هزینه جدید', [c, n], ['کد', 'نام']);
        if (ok) {
          await _repo.saveCostCenter(
              CostCenterRecord(code: c.text.trim(), name: n.text.trim()));
          await _load();
        }
        c.dispose();
        n.dispose();
      });

  Widget _masterList<T>(List<T> items, String Function(T) title,
      String Function(T) subtitle, Future<void> Function() add) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children:[FilledButton.icon(onPressed:add, icon:const Icon(Icons.add), label:const Text('افزودن')), const SizedBox(width:8), Text('تعداد: ${items.length}')]),
      const SizedBox(height: 10),
      Expanded(child: ListView.builder(itemCount:items.length,itemBuilder:(_,i){
        final item=items[i];
        Future<void> doEdit() async {
          if (item is WarehouseRecord) { final c=TextEditingController(text:item.code), n=TextEditingController(text:item.name); final ok=await _simpleDialog('ویرایش انبار',[c,n],['کد انبار','نام انبار']); if(ok) await _repo.saveWarehouse(WarehouseRecord(id:item.id,code:c.text.trim(),name:n.text.trim(),location:item.location,isDefault:item.isDefault,isActive:item.isActive)); c.dispose(); n.dispose(); }
          else if(item is PriceListRecord){final n=TextEditingController(text:item.name); final ok=await _simpleDialog('ویرایش لیست قیمت',[n],['نام لیست']); if(ok) await _repo.savePriceList(PriceListRecord(id:item.id,name:n.text.trim(),isDefault:item.isDefault,isActive:item.isActive)); n.dispose();}
          else if(item is SerialNumberRecord){final p=TextEditingController(text:'${item.productId}'), s=TextEditingController(text:item.serial); final ok=await _simpleDialog('ویرایش سریال',[p,s],['شناسه کالا','شماره سریال']); if(ok) await _repo.saveSerial(SerialNumberRecord(id:item.id,productId:int.tryParse(p.text.trim())??item.productId,serial:s.text.trim(),status:item.status,warehouseId:item.warehouseId,transactionId:item.transactionId)); p.dispose(); s.dispose();}
          else if(item is TaxRuleRecord){final c=TextEditingController(text:item.code), n=TextEditingController(text:item.name), r=TextEditingController(text:'${item.rate}'); final ok=await _simpleDialog('ویرایش قاعده مالیاتی',[c,n,r],['کد','نام','نرخ درصد']); if(ok) await _repo.saveTaxRule(TaxRuleRecord(id:item.id,code:c.text.trim(),name:n.text.trim(),rate:double.tryParse(r.text)??item.rate,type:item.type,isActive:item.isActive)); c.dispose(); n.dispose(); r.dispose();}
          else if(item is CostCenterRecord){final c=TextEditingController(text:item.code), n=TextEditingController(text:item.name); final ok=await _simpleDialog('ویرایش مرکز هزینه',[c,n],['کد','نام']); if(ok) await _repo.saveCostCenter(CostCenterRecord(id:item.id,code:c.text.trim(),name:n.text.trim(),isActive:item.isActive)); c.dispose(); n.dispose();}
          await _load();
        }
        Future<void> doDelete() async {
          final ok=await _confirmDelete('حذف', '${title(item)} حذف شود؟'); if(!ok) return;
          if(item is WarehouseRecord) await _repo.deleteWarehouse(item.id);
          else if(item is PriceListRecord) await _repo.deletePriceList(item.id);
          else if(item is SerialNumberRecord) await _repo.deleteSerial(item.id);
          else if(item is TaxRuleRecord) await _repo.deleteTaxRule(item.id);
          else if(item is CostCenterRecord) await _repo.deleteCostCenter(item.id);
          await _load();
        }
        return Card(child:ListTile(title:Text(title(item)),subtitle:Text(subtitle(item)),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(icon:const Icon(Icons.edit,size:18), onPressed:doEdit, tooltip:'ویرایش'),IconButton(icon:const Icon(Icons.delete,size:18,color:Colors.red),onPressed:doDelete, tooltip:'حذف')])));
      }))
    ]);
  }

  Future<bool> _confirmDelete(String title, String message) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text(title), content: Text(message), actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('حذف'))]));
    return ok == true;
  }

  Future<bool> _simpleDialog(String title, List<TextEditingController> fields,
      List<String> labels) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: Text(title),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                        fields.length,
                        (i) => TextField(
                            controller: fields[i],
                            keyboardType: i == fields.length - 1 &&
                                    labels[i].contains('نرخ')
                                ? TextInputType.number
                                : TextInputType.text,
                            decoration:
                                InputDecoration(labelText: labels[i])))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('انصراف')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('ثبت'))
                ]));
    return ok == true && fields.every((x) => x.text.trim().isNotEmpty);
  }

  String _date(int millis) => faDateMillis(millis);
  String _money(num value, String currency) =>
      '${NumberFormat('#,##0', 'en_US').format(value)} $currency';
}
