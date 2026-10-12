// ============================================================================
// AccountingScreen - حسابداری تجاری کامل StoreMaster Pro
// ============================================================================
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/shamsi_date_utils.dart';

import '../models/accounting_models.dart';
import '../models/transaction_item.dart';
import '../viewmodels/main_viewmodel.dart';
import '../shared_src/permission_catalog.dart';

class AccountingScreen extends StatefulWidget {
  final int initialTab;
  const AccountingScreen({super.key, this.initialTab = 0});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  late int _tab;
  bool _loading = true;

  List<ChartAccount> _accounts = [];
  List<JournalEntry> _journals = [];
  List<CashBankAccount> _cashBanks = [];
  List<SettlementRecord> _settlements = [];
  List<PayrollRecord> _payroll = [];
  List<Map<String, dynamic>> _ledger = [];
  List<Map<String, dynamic>> _agingDetails = [];
  List<Map<String, dynamic>> _taxAnnual = [];
  Map<String, double> _profitLoss = {};
  Map<String, double> _balanceSheet = {};
  Map<String, double> _aging = {};
  Map<String, double> _tax = {};

  int? _selectedDebitAccountId;
  int? _selectedCreditAccountId;
  int? _selectedLedgerAccountId;
  int? _selectedPayrollUserId;
  int? _selectedTransferFrom;
  int? _selectedTransferTo;
  int? _selectedSettlementContact;
  int? _selectedSettlementCashBank;
  String _selectedAccountType = 'ASSET';
  String _settlementType = 'RECEIPT';
  int _selectedYear = Jalali.now().year;
  int _selectedMonth = Jalali.now().month;
  double _taxRate = 0;

  final _accountName = TextEditingController();
  final _accountCode = TextEditingController();
  final _journalDescription = TextEditingController();
  final _journalDebit = TextEditingController();
  final _journalCredit = TextEditingController();
  final _bankName = TextEditingController();
  final _bankNumber = TextEditingController();
  final _cashOpening = TextEditingController(text: '0');
  final _payrollBase = TextEditingController();
  final _payrollOvertime = TextEditingController(text: '0');
  final _payrollDeduction = TextEditingController(text: '0');
  final _settlementAmount = TextEditingController();
  final _settlementDescription = TextEditingController();
  final _transferAmount = TextEditingController();
  final _transferDescription = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    Future.microtask(_load);
  }

  @override
  void dispose() {
    for (final c in [
      _accountName,
      _accountCode,
      _journalDescription,
      _journalDebit,
      _journalCredit,
      _bankName,
      _bankNumber,
      _cashOpening,
      _payrollBase,
      _payrollOvertime,
      _payrollDeduction,
      _settlementAmount,
      _settlementDescription,
      _transferAmount,
      _transferDescription,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  String _money(num value, MainViewModel vm) =>
      '${NumberFormat('#,##0', 'en_US').format(value)} ${vm.config?.currency ?? 'تومان'}';

  static const List<String> _persianMonthNames = <String>[
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  String _persianMonthName(int month) {
    if (month < 1 || month > 12) return 'ماه';
    return _persianMonthNames[month - 1];
  }

  int _startOfMonth(int year, int month) =>
      Jalali(year, month, 1).toDateTime().millisecondsSinceEpoch;

  int _endOfMonth(int year, int month) {
    final next = month == 12 ? Jalali(year + 1, 1, 1) : Jalali(year, month + 1, 1);
    return next.toDateTime().millisecondsSinceEpoch - 1;
  }

  Future<void> _load() async {
    final vm = context.read<MainViewModel>();
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await vm.ensureAccountingSeed();
      _accounts = await vm.getChartAccounts();
      _selectedDebitAccountId ??= _findAccount('1101')?.id ??
          (_accounts.isNotEmpty ? _accounts.first.id : null);
      _selectedCreditAccountId ??= _findAccount('4101')?.id ??
          (_accounts.length > 1 ? _accounts[1].id : _selectedDebitAccountId);
      _selectedPayrollUserId ??= vm.users.isNotEmpty ? vm.users.first.id : null;
      _selectedTransferFrom ??= _cashBanks.isNotEmpty ? _cashBanks.first.id : null;

      _journals = await vm.getJournalEntries(limit: 500);
      _cashBanks = await vm.getCashBankAccounts();
      _settlements = await vm.getSettlements();
      _payroll = await vm.getPayroll(year: _selectedYear, month: _selectedMonth);

      _selectedTransferFrom ??= _cashBanks.isNotEmpty ? _cashBanks.first.id : null;
      _selectedTransferTo ??= _cashBanks.length > 1
          ? _cashBanks[1].id
          : (_cashBanks.isNotEmpty ? _cashBanks.first.id : null);
      _selectedSettlementContact ??= vm.allContacts.isNotEmpty ? vm.allContacts.first.id : null;
      _selectedSettlementCashBank ??= _cashBanks.isNotEmpty ? _cashBanks.first.id : null;

      final start = _startOfMonth(_selectedYear, _selectedMonth);
      final end = _endOfMonth(_selectedYear, _selectedMonth);
      _profitLoss = await vm.getProfitLossReport(start, end);
      _balanceSheet = await vm.getBalanceSheetReport(end);
      _ledger = await vm.getGeneralLedger(
        accountId: _selectedLedgerAccountId,
        startMillis: start,
        endMillis: end,
      );
      _aging = await vm.getAgingSummary();
      _agingDetails = await vm.getAgingDetails();
      _taxRate = (vm.config?.taxPercentage ?? 0) / 100;
      _tax = await vm.getTaxReport(_selectedYear, _selectedMonth, _taxRate);
      _taxAnnual = await vm.getTaxAnnualReport(_selectedYear, _taxRate);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ChartAccount? _findAccount(String code) {
    for (final a in _accounts) {
      if (a.code == code) return a;
    }
    return null;
  }

  Future<bool> _confirmDelete(String title, String message) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text(title), content: Text(message), actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('حذف'))]));
    return ok == true;
  }

  Future<void> _editAccount(MainViewModel vm, ChartAccount a) async {
    final code=TextEditingController(text:a.code), name=TextEditingController(text:a.name);
    String type=a.type;
    final types={'ASSET':'دارایی','LIABILITY':'بدهی','EQUITY':'سرمایه','REVENUE':'درآمد','EXPENSE':'هزینه'};
    try { final ok=await showDialog<bool>(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setS)=>AlertDialog(title:const Text('ویرایش سرفصل'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:code,decoration:const InputDecoration(labelText:'کد حساب')),TextField(controller:name,decoration:const InputDecoration(labelText:'نام سرفصل')),DropdownButtonFormField<String>(initialValue:type,items:types.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setS(()=>type=v??type))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('ذخیره'))]))); if(ok==true){await vm.saveChartAccount(ChartAccount(id:a.id,code:code.text.trim(),name:name.text.trim(),type:type,parentId:a.parentId,isCashOrBank:a.isCashOrBank,isActive:a.isActive)); await _load();} } catch(e){_message('$e',error:true);} finally{code.dispose();name.dispose();}
  }

  Future<void> _editCashBank(MainViewModel vm, CashBankAccount a) async {
    final name=TextEditingController(text:a.name), number=TextEditingController(text:a.accountNumber), opening=TextEditingController(text:'${a.openingBalance}');
    try { final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('ویرایش حساب صندوق / بانک'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'نام')),TextField(controller:number,decoration:const InputDecoration(labelText:'شماره حساب / کارت')),TextField(controller:opening,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'موجودی افتتاحیه'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('ذخیره'))])); if(ok==true){await vm.saveCashBankAccount(CashBankAccount(id:a.id,name:name.text.trim(),type:a.type,bankName:a.bankName,accountNumber:number.text.trim(),openingBalance:double.tryParse(opening.text.replaceAll(',',''))??a.openingBalance,ledgerAccountId:a.ledgerAccountId,isActive:a.isActive)); await _load();} } finally{name.dispose();number.dispose();opening.dispose();}
  }

  Future<void> _addAccount() async {
    final vm = context.read<MainViewModel>();
    final code = _accountCode.text.trim();
    final name = _accountName.text.trim();
    if (code.isEmpty || name.isEmpty) return;
    await vm.saveChartAccount(
      ChartAccount(
        code: code,
        name: name,
        type: _selectedAccountType,
      ),
    );
    _accountCode.clear();
    _accountName.clear();
    await _load();
  }

  Future<void> _addManualJournal() async {
    final vm = context.read<MainViewModel>();
    final debit = _num(_journalDebit);
    final credit = _num(_journalCredit);
    if (debit <= 0 || credit <= 0 || (debit - credit).abs() > .01) {
      _message('جمع بدهکار و بستانکار باید برابر و بزرگ‌تر از صفر باشد.', error: true);
      return;
    }
    final debitAccount = _accounts.where((a) => a.id == _selectedDebitAccountId).isNotEmpty
        ? _accounts.firstWhere((a) => a.id == _selectedDebitAccountId)
        : null;
    final creditAccount = _accounts.where((a) => a.id == _selectedCreditAccountId).isNotEmpty
        ? _accounts.firstWhere((a) => a.id == _selectedCreditAccountId)
        : null;
    if (debitAccount == null || creditAccount == null) return;

    await vm.addBalancedJournal(
      description: _journalDescription.text.trim().isEmpty
          ? 'سند دستی'
          : _journalDescription.text.trim(),
      lines: [
        JournalLine(
          journalId: 0,
          accountId: debitAccount.id,
          accountCode: debitAccount.code,
          accountName: debitAccount.name,
          debit: debit,
        ),
        JournalLine(
          journalId: 0,
          accountId: creditAccount.id,
          accountCode: creditAccount.code,
          accountName: creditAccount.name,
          credit: credit,
        ),
      ],
    );
    _journalDescription.clear();
    _journalDebit.clear();
    _journalCredit.clear();
    await _load();
  }

  Future<void> _addCashBank() async {
    final vm = context.read<MainViewModel>();
    final name = _bankName.text.trim();
    if (name.isEmpty) return;
    final type = _bankNumber.text.trim().isEmpty ? 'CASH' : 'BANK';
    int ledgerAccountId;
    if (type == 'BANK') {
      final used = _accounts.map((a) => a.code).toSet();
      var code = '1110';
      var n = 1110;
      while (used.contains(code)) {
        n++;
        code = n.toString();
      }
      ledgerAccountId = await vm.saveChartAccount(
        ChartAccount(
          code: code,
          name: name,
          type: 'ASSET',
          isCashOrBank: true,
        ),
      );
    } else {
      final source = _findAccount('1101') ??
          _accounts.firstWhere(
            (a) => a.isCashOrBank,
            orElse: () => _accounts.first,
          );
      ledgerAccountId = source.id;
    }
    await vm.saveCashBankAccount(
      CashBankAccount(
        name: name,
        type: type,
        bankName: type == 'BANK' ? name : '',
        accountNumber: _bankNumber.text.trim(),
        openingBalance: _num(_cashOpening),
        ledgerAccountId: ledgerAccountId,
      ),
    );
    _bankName.clear();
    _bankNumber.clear();
    _cashOpening.text = '0';
    await _load();
  }

  Future<void> _transferCashBank() async {
    final vm = context.read<MainViewModel>();
    final amount = _num(_transferAmount);
    if (amount <= 0 || _selectedTransferFrom == null || _selectedTransferTo == null) return;
    final from = _cashBanks.firstWhere((x) => x.id == _selectedTransferFrom);
    final to = _cashBanks.firstWhere((x) => x.id == _selectedTransferTo);
    try {
      await vm.transferCashBank(
        from: from,
        to: to,
        amount: amount,
        description: _transferDescription.text.trim(),
      );
      _transferAmount.clear();
      _transferDescription.clear();
      _message('انتقال وجه با موفقیت ثبت شد.');
      await _load();
    } catch (e) {
      _message(e.toString(), error: true);
    }
  }

  Future<void> _createPayroll() async {
    final vm = context.read<MainViewModel>();
    if (vm.users.isEmpty || _selectedPayrollUserId == null) return;
    final user = vm.users.firstWhere((u) => u.id == _selectedPayrollUserId);
    final base = _num(_payrollBase) > 0 ? _num(_payrollBase) : user.baseSalary;
    final overtime = _num(_payrollOvertime);
    final deductions = _num(_payrollDeduction);
    final commission = user.totalCommission;
    await vm.savePayrollRecord(
      PayrollRecord(
        userId: user.id,
        userName: user.name,
        periodYear: _selectedYear,
        periodMonth: _selectedMonth,
        baseSalary: base,
        commission: commission,
        overtime: overtime,
        deductions: deductions,
        netSalary: base + commission + overtime - deductions,
      ),
    );
    _payrollBase.clear();
    _payrollOvertime.text = '0';
    _payrollDeduction.text = '0';
    await _load();
  }

  Future<void> _payPayroll(PayrollRecord payroll) async {
    final vm = context.read<MainViewModel>();
    final cashId = _cashBanks.isNotEmpty ? _cashBanks.first.id : null;
    try {
      await vm.markPayrollPaid(
        payroll,
        cashBankId: cashId,
        cashBankName: cashId == null ? 'صندوق' : _cashBanks.first.name,
      );
      _message('حقوق ${payroll.userName} پرداخت و سند حسابداری ثبت شد.');
      await _load();
    } catch (e) {
      _message(e.toString(), error: true);
    }
  }

  Future<void> _showSettlementDialog(MainViewModel vm) async {
    if (vm.allContacts.isEmpty || _cashBanks.isEmpty) return;
    int? contactId = _selectedSettlementContact ?? vm.allContacts.first.id;
    int? cashBankId = _selectedSettlementCashBank ?? _cashBanks.first.id;
    String type = _settlementType;
    final amount = TextEditingController();
    final description = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            final contact = vm.allContacts.firstWhere((c) => c.id == contactId);
            final cashBank = _cashBanks.firstWhere((c) => c.id == cashBankId);
            final balance = type == 'RECEIPT' ? contact.totalDebt : contact.totalPayable;
            return AlertDialog(
              title: const Text('ثبت تسویه حساب'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: contactId,
                        decoration: const InputDecoration(labelText: 'طرف حساب'),
                        items: vm.allContacts.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: (v) => setDialogState(() => contactId = v),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(labelText: 'نوع تسویه'),
                        items: const [
                          DropdownMenuItem(value: 'RECEIPT', child: Text('دریافت از مشتری')),
                          DropdownMenuItem(value: 'PAYMENT', child: Text('پرداخت به تأمین‌کننده')),
                        ],
                        onChanged: (v) => setDialogState(() => type = v ?? 'RECEIPT'),
                      ),
                      DropdownButtonFormField<int>(
                        initialValue: cashBankId,
                        decoration: const InputDecoration(labelText: 'صندوق / بانک'),
                        items: _cashBanks.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: (v) => setDialogState(() => cashBankId = v),
                      ),
                      TextField(
                        controller: amount,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'مبلغ', helperText: 'مانده: ${_money(balance, vm)}'),
                      ),
                      TextField(
                        controller: description,
                        decoration: const InputDecoration(labelText: 'شرح'),
                      ),
                      const SizedBox(height: 8),
                      Text('حساب منتخب: ${cashBank.name}'),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
                FilledButton(
                  onPressed: () async {
                    final value = double.tryParse(amount.text.replaceAll(',', '')) ?? 0;
                    if (contactId == null || cashBankId == null || value <= 0) return;
                    await vm.settleContact(
                      contactId: contactId!,
                      contactName: contact.name,
                      type: type,
                      amount: value,
                      cashBankId: cashBankId!,
                      cashBankName: cashBank.name,
                      description: description.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  },
                  child: const Text('ثبت تسویه'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      amount.dispose();
      description.dispose();
    }
  }


  Future<void> _editSettlement(MainViewModel vm, SettlementRecord old) async {
    int? contactId = old.contactId;
    int? cashBankId = old.cashBankId;
    String type = old.type;
    final amount = TextEditingController(text: old.amount.toStringAsFixed(0));
    final description = TextEditingController(text: old.description);
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
          final contact = vm.allContacts.where((c) => c.id == contactId).isNotEmpty
              ? vm.allContacts.firstWhere((c) => c.id == contactId)
              : (vm.allContacts.isNotEmpty ? vm.allContacts.first : null);
          final bank = _cashBanks.where((c) => c.id == cashBankId).isNotEmpty
              ? _cashBanks.firstWhere((c) => c.id == cashBankId)
              : (_cashBanks.isNotEmpty ? _cashBanks.first : null);
          return AlertDialog(
            title: const Text('ویرایش تسویه'),
            content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int>(
                initialValue: contact?.id,
                decoration: const InputDecoration(labelText: 'طرف حساب'),
                items: vm.allContacts.map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => contactId = v),
              ),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'نوع تسویه'),
                items: const [
                  DropdownMenuItem(value: 'RECEIPT', child: Text('دریافت از مشتری')),
                  DropdownMenuItem(value: 'PAYMENT', child: Text('پرداخت به تأمین‌کننده')),
                ],
                onChanged: (v) => setState(() => type = v ?? type),
              ),
              DropdownButtonFormField<int>(
                initialValue: bank?.id,
                decoration: const InputDecoration(labelText: 'صندوق / بانک'),
                items: _cashBanks.map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => cashBankId = v),
              ),
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ')),
              TextField(controller: description, decoration: const InputDecoration(labelText: 'شرح')),
            ]))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
              FilledButton(onPressed: () async {
                final a = double.tryParse(amount.text.replaceAll(',', '').trim()) ?? 0;
                if (contact == null || bank == null || a <= 0) return;
                try {
                  await vm.updateSettlement(SettlementRecord(
                    id: old.id,
                    contactId: contact.id,
                    contactName: contact.name,
                    type: type,
                    amount: a,
                    cashBankId: bank.id,
                    cashBankName: bank.name,
                    dateMillis: old.dateMillis,
                    description: description.text.trim(),
                    userId: old.userId,
                    userName: old.userName,
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                } catch (e) {
                  if (ctx.mounted) _message('$e', error: true);
                }
              }, child: const Text('ذخیره تغییرات')),
            ],
          );
        }),
      );
    } finally { amount.dispose(); description.dispose(); }
  }

  Future<void> _editPayroll(MainViewModel vm, PayrollRecord old) async {
    final base = TextEditingController(text: old.baseSalary.toStringAsFixed(0));
    final overtime = TextEditingController(text: old.overtime.toStringAsFixed(0));
    final commission = TextEditingController(text: old.commission.toStringAsFixed(0));
    final deductions = TextEditingController(text: old.deductions.toStringAsFixed(0));
    try {
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('ویرایش حقوق'),
        content: SizedBox(width: 460, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('پرسنل: ${old.userName}'),
          TextField(controller: base, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حقوق پایه')),
          TextField(controller: commission, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'پورسانت')),
          TextField(controller: overtime, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'اضافه‌کاری')),
          TextField(controller: deductions, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'کسورات')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          FilledButton(onPressed: () async {
            final b = double.tryParse(base.text.replaceAll(',', '')) ?? old.baseSalary;
            final c = double.tryParse(commission.text.replaceAll(',', '')) ?? old.commission;
            final o = double.tryParse(overtime.text.replaceAll(',', '')) ?? old.overtime;
            final d = double.tryParse(deductions.text.replaceAll(',', '')) ?? old.deductions;
            try {
              await vm.savePayrollRecord(PayrollRecord(id: old.id, userId: old.userId, userName: old.userName, periodYear: old.periodYear, periodMonth: old.periodMonth, baseSalary: b, commission: c, overtime: o, deductions: d, netSalary: b+c+o-d, paid: old.paid, paidDateMillis: old.paidDateMillis));
              if (ctx.mounted) Navigator.pop(ctx);
              await _load();
            } catch(e) { if (ctx.mounted) _message('$e', error:true); }
          }, child: const Text('ذخیره تغییرات')),
        ],
      ));
    } finally { base.dispose(); overtime.dispose(); commission.dispose(); deductions.dispose(); }
  }

  Future<void> _editManualJournal(MainViewModel vm, JournalEntry journal) async {
    final lines = await vm.getJournalLines(journal.id);
    if (!mounted) return;
    final accounts = _accounts;
    if (accounts.length < 2 || lines.length < 2) {
      _message('سند دستی برای ویرایش باید حداقل یک بدهکار و یک بستانکار داشته باشد.', error: true);
      return;
    }
    int? debitId = lines.firstWhere((l) => l.debit > 0, orElse: () => lines.first).accountId;
    int? creditId = lines.firstWhere((l) => l.credit > 0, orElse: () => lines.last).accountId;
    final amount0 = lines.fold<double>(0, (v,l)=>v+l.debit);
    final amount = TextEditingController(text: amount0.toStringAsFixed(0));
    final desc = TextEditingController(text: journal.description);
    try {
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text('ویرایش سند ${journal.number}'),
        content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(initialValue: debitId, decoration: const InputDecoration(labelText:'حساب بدهکار'), items: accounts.map((a)=>DropdownMenuItem(value:a.id, child: Text('${a.code} - ${a.name}'))).toList(), onChanged:(v)=>debitId=v),
          DropdownButtonFormField<int>(initialValue: creditId, decoration: const InputDecoration(labelText:'حساب بستانکار'), items: accounts.map((a)=>DropdownMenuItem(value:a.id, child: Text('${a.code} - ${a.name}'))).toList(), onChanged:(v)=>creditId=v),
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText:'مبلغ')),
          TextField(controller: desc, decoration: const InputDecoration(labelText:'شرح سند')),
        ])),
        actions: [
          TextButton(onPressed:()=>Navigator.pop(ctx), child:const Text('انصراف')),
          FilledButton(onPressed:() async {
            final a=double.tryParse(amount.text.replaceAll(',',''))??0;
            final da=accounts.where((x)=>x.id==debitId).isNotEmpty?accounts.firstWhere((x)=>x.id==debitId):null;
            final ca=accounts.where((x)=>x.id==creditId).isNotEmpty?accounts.firstWhere((x)=>x.id==creditId):null;
            if(a<=0||da==null||ca==null||da.id==ca.id) return;
            try {
              await vm.updateJournalEntry(id: journal.id, description: desc.text.trim(), lines:[
                JournalLine(journalId: journal.id, accountId: da.id, accountCode: da.code, accountName: da.name, debit: a),
                JournalLine(journalId: journal.id, accountId: ca.id, accountCode: ca.code, accountName: ca.name, credit: a),
              ], dateMillis: journal.dateMillis);
              if(ctx.mounted) Navigator.pop(ctx); await _load();
            } catch(e) { if(ctx.mounted) _message('$e', error:true); }
          }, child:const Text('ذخیره تغییرات')),
        ],
      ));
    } finally { amount.dispose(); desc.dispose(); }
  }

  Future<void> _showReturnDialog(MainViewModel vm, dynamic transaction) async {
    if (!vm.hasPermission(PermissionCatalog.invoicesReturn)) { _message('شما دسترسی برگشت فاکتور را ندارید.', error: true); return; }
    final items = await vm.getTransactionItems(transaction.id);
    if (items.isEmpty) {
      _message('برای این فاکتور قلم قابل برگشت پیدا نشد.', error: true);
      return;
    }
    final controllers = <int, TextEditingController>{};
    for (final item in items) {
      controllers[item.id] = TextEditingController(text: '0');
    }
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(transaction.type == 'SALE' ? 'برگشت جزئی فروش' : 'برگشت جزئی خرید'),
          content: SizedBox(
            width: 620,
            height: 420,
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final item = items[i];
                final c = controllers[item.id]!;
                return ListTile(
                  title: Text(item.productName),
                  subtitle: Text('خرید/فروش ثبت‌شده: ${item.quantity} ${item.productName.isEmpty ? '' : 'عدد'}'),
                  trailing: SizedBox(
                    width: 110,
                    child: TextField(
                      controller: c,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'برگشت'),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            FilledButton(
              onPressed: () async {
                final selected = <TransactionItem>[];
                for (final item in items) {
                  final qty = double.tryParse(controllers[item.id]!.text.replaceAll(',', '')) ?? 0;
                  if (qty <= 0) continue;
                  if (qty > item.quantity) {
                    _message('مقدار برگشت نمی‌تواند از مقدار فاکتور بیشتر باشد.', error: true);
                    return;
                  }
                  selected.add(item.copyWith(quantity: qty));
                }
                if (selected.isEmpty) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('برای برگشت حداقل مقدار یک قلم را بیشتر از صفر وارد کنید.')),
                    );
                  }
                  return;
                }
                try {
                  final id = await vm.recordReturn(
                    original: transaction,
                    items: selected,
                    saleReturn: transaction.type == 'SALE',
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _message('برگشت با موفقیت ثبت شد. شماره سند: $id');
                  await _load();
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('خطا در ثبت برگشت: $e'), backgroundColor: Colors.red.shade700));
                }
              },
              child: const Text('ثبت برگشت'),
            ),
          ],
        ),
      );
    } finally {
      for (final c in controllers.values) c.dispose();
    }
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red.shade700 : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابداری تجاری'),
        actions: [
          IconButton(
            tooltip: 'به‌روزرسانی',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(vm, theme),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _tabButton('دفتر کل و اسناد', 0),
                      _tabButton('سرفصل‌ها', 1),
                      _tabButton('صندوق و بانک', 2),
                      _tabButton('تسویه حساب', 3),
                      _tabButton('حقوق و دستمزد', 4),
                      _tabButton('سود و زیان', 5),
                      _tabButton('ترازنامه', 6),
                      _tabButton('مالیات و سن حساب', 7),
                      _tabButton('برگشت خرید و فروش', 8),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: _buildTab(vm)),
              ],
            ),
    );
  }

  Widget _buildHeader(MainViewModel vm, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _summaryMetric('فروش ماه', _money(_profitLoss['revenue'] ?? 0, vm), Icons.trending_up_rounded),
              _summaryMetric('هزینه ماه', _money(_profitLoss['expense'] ?? 0, vm), Icons.receipt_long_rounded),
              _summaryMetric('سود خالص', _money(_profitLoss['netProfit'] ?? 0, vm), Icons.account_balance_wallet_rounded),
              _summaryMetric('دارایی', _money(_balanceSheet['assets'] ?? 0, vm), Icons.account_balance_rounded),
              _summaryMetric('بدهی', _money(_balanceSheet['liabilities'] ?? 0, vm), Icons.money_off_csred_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryMetric(String title, String value, IconData icon) {
    return SizedBox(
      width: 190,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              child: Icon(icon, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String text, int index) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: ChoiceChip(
          label: Text(text),
          selected: _tab == index,
          onSelected: (_) => setState(() => _tab = index),
        ),
      );

  Widget _buildTab(MainViewModel vm) {
    switch (_tab) {
      case 1:
        return _accountsTab(vm);
      case 2:
        return _cashBankTab(vm);
      case 3:
        return _settlementsTab(vm);
      case 4:
        return _payrollTab(vm);
      case 5:
        return _profitLossTab(vm);
      case 6:
        return _balanceSheetTab(vm);
      case 7:
        return _taxAgingTab(vm);
      case 8:
        return _returnsTab(vm);
      default:
        return _ledgerTab(vm);
    }
  }

  Widget _ledgerTab(MainViewModel vm) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final fields = [
                      DropdownButtonFormField<int>(
                        initialValue: _selectedDebitAccountId,
                        decoration: const InputDecoration(labelText: 'حساب بدهکار'),
                        items: _accounts.map((a) => DropdownMenuItem<int>(value: a.id, child: Text('${a.code} - ${a.name}'))).toList(),
                        onChanged: (v) => setState(() => _selectedDebitAccountId = v),
                      ),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedCreditAccountId,
                        decoration: const InputDecoration(labelText: 'حساب بستانکار'),
                        items: _accounts.map((a) => DropdownMenuItem<int>(value: a.id, child: Text('${a.code} - ${a.name}'))).toList(),
                        onChanged: (v) => setState(() => _selectedCreditAccountId = v),
                      ),
                    ];
                    if (c.maxWidth < 700) {
                      return Column(children: [fields[0], const SizedBox(height: 8), fields[1]]);
                    }
                    return Row(children: [Expanded(child: fields[0]), const SizedBox(width: 8), Expanded(child: fields[1])]);
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: _journalDescription, decoration: const InputDecoration(labelText: 'شرح سند')),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, c) {
                    final children = [
                      TextField(controller: _journalDebit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'بدهکار')),
                      TextField(controller: _journalCredit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'بستانکار')),
                    ];
                    if (c.maxWidth < 700) {
                      return Column(children: [children[0], const SizedBox(height: 8), children[1], const SizedBox(height: 8), Align(alignment: AlignmentDirectional.centerStart, child: FilledButton.icon(onPressed: _addManualJournal, icon: const Icon(Icons.add_task_rounded), label: const Text('ثبت سند')))]);
                    }
                    return Row(children: [Expanded(child: children[0]), const SizedBox(width: 8), Expanded(child: children[1]), const SizedBox(width: 8), FilledButton.icon(onPressed: _addManualJournal, icon: const Icon(Icons.add_task_rounded), label: const Text('ثبت سند'))]);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _selectedLedgerAccountId,
                  decoration: const InputDecoration(labelText: 'فیلتر دفتر کل بر اساس حساب'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('همه حساب‌ها')),
                    ..._accounts.map((a) => DropdownMenuItem<int?>(value: a.id, child: Text('${a.code} - ${a.name}'))),
                  ],
                  onChanged: (v) async {
                    setState(() => _selectedLedgerAccountId = v);
                    await _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _ledger.isEmpty
              ? const Center(child: Text('گردش حسابی برای این بازه وجود ندارد.'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _ledger.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final r = _ledger[i];
                    final debit = (r['debit'] as num?)?.toDouble() ?? 0;
                    final credit = (r['credit'] as num?)?.toDouble() ?? 0;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${i + 1}')),
                        title: Text('${r['accountCode']} - ${r['accountName']}'),
                        subtitle: Text('${r['number']} • ${r['journalDescription']}\n${faDateTime(DateTime.fromMillisecondsSinceEpoch((r['dateMillis'] as num).toInt()))}'),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (debit > 0) Text('بدهکار ${_money(debit, vm)}'),
                            if (credit > 0) Text('بستانکار ${_money(credit, vm)}', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                          ],
                        ),
                        onTap: () => _showJournalDetails(vm, (r['journalId'] as num).toInt()),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _accountsTab(MainViewModel vm) {
    final labels = {
      'ASSET': 'دارایی',
      'LIABILITY': 'بدهی',
      'EQUITY': 'سرمایه',
      'REVENUE': 'درآمد',
      'EXPENSE': 'هزینه',
    };
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, c) {
                final widgets = [
                  TextField(controller: _accountCode, decoration: const InputDecoration(labelText: 'کد حساب')),
                  TextField(controller: _accountName, decoration: const InputDecoration(labelText: 'نام سرفصل')),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedAccountType,
                    decoration: const InputDecoration(labelText: 'ماهیت'),
                    items: labels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setState(() => _selectedAccountType = v ?? 'ASSET'),
                  ),
                  FilledButton.icon(onPressed: vm.isAdmin ? _addAccount : null, icon: const Icon(Icons.add_rounded), label: const Text('افزودن سرفصل')),
                ];
                if (c.maxWidth < 780) {
                  return Column(children: [widgets[0], const SizedBox(height: 8), widgets[1], const SizedBox(height: 8), widgets[2], const SizedBox(height: 8), Align(alignment: AlignmentDirectional.centerStart, child: widgets[3])]);
                }
                return Row(children: [Expanded(child: widgets[0]), const SizedBox(width: 8), Expanded(flex: 2, child: widgets[1]), const SizedBox(width: 8), Expanded(child: widgets[2]), const SizedBox(width: 8), widgets[3]]);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _accounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final a = _accounts[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(a.code.length >= 2 ? a.code.substring(0, 2) : a.code)),
                  title: Text(a.name),
                  subtitle: Text('${a.code} • ${labels[a.type] ?? a.type}${a.isCashOrBank ? ' • نقدی/بانکی' : ''}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(a.isActive ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded),
                    IconButton(icon: const Icon(Icons.edit, size: 18), tooltip: 'ویرایش سرفصل', onPressed: () => _editAccount(vm, a)),
                    if (!['1101','1102','1201','1301','2101','2201','3101','4101','4201','5101','5201','5301'].contains(a.code))
                      IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), tooltip: 'حذف سرفصل', onPressed: () async { if (await _confirmDelete('حذف سرفصل', '${a.code} - ${a.name} حذف شود؟')) { try { await vm.deleteChartAccount(a.id); await _load(); } catch(e) { _message('$e', error:true); } } }),
                  ]),
                  onTap: () => _showAccountBalance(vm, a),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _cashBankTab(MainViewModel vm) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final fields = [
                      TextField(controller: _bankName, decoration: const InputDecoration(labelText: 'نام صندوق / بانک')),
                      TextField(controller: _bankNumber, decoration: const InputDecoration(labelText: 'شماره حساب / کارت')),
                      TextField(controller: _cashOpening, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'موجودی افتتاحیه')),
                    ];
                    if (c.maxWidth < 700) {
                      return Column(children: [fields[0], const SizedBox(height: 8), fields[1], const SizedBox(height: 8), fields[2], const SizedBox(height: 8), Align(alignment: AlignmentDirectional.centerStart, child: FilledButton.icon(onPressed: vm.isAdmin ? _addCashBank : null, icon: const Icon(Icons.add_business_rounded), label: const Text('ثبت حساب')))]);
                    }
                    return Row(children: [Expanded(child: fields[0]), const SizedBox(width: 8), Expanded(child: fields[1]), const SizedBox(width: 8), Expanded(child: fields[2]), const SizedBox(width: 8), FilledButton.icon(onPressed: vm.isAdmin ? _addCashBank : null, icon: const Icon(Icons.add_business_rounded), label: const Text('ثبت حساب'))]);
                  },
                ),
                const Divider(height: 24),
                LayoutBuilder(
                  builder: (context, c) {
                    final from = DropdownButtonFormField<int>(
                      initialValue: _selectedTransferFrom,
                      decoration: const InputDecoration(labelText: 'مبدأ انتقال'),
                      items: _cashBanks.map((x) => DropdownMenuItem<int>(value: x.id, child: Text(x.name))).toList(),
                      onChanged: (v) => setState(() => _selectedTransferFrom = v),
                    );
                    final to = DropdownButtonFormField<int>(
                      initialValue: _selectedTransferTo,
                      decoration: const InputDecoration(labelText: 'مقصد انتقال'),
                      items: _cashBanks.map((x) => DropdownMenuItem<int>(value: x.id, child: Text(x.name))).toList(),
                      onChanged: (v) => setState(() => _selectedTransferTo = v),
                    );
                    final amount = TextField(controller: _transferAmount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ انتقال'));
                    if (c.maxWidth < 700) {
                      return Column(children: [from, const SizedBox(height: 8), to, const SizedBox(height: 8), amount, const SizedBox(height: 8), TextField(controller: _transferDescription, decoration: const InputDecoration(labelText: 'شرح انتقال')), const SizedBox(height: 8), Align(alignment: AlignmentDirectional.centerStart, child: FilledButton.icon(onPressed: _cashBanks.length < 2 ? null : _transferCashBank, icon: const Icon(Icons.swap_horiz_rounded), label: const Text('انتقال وجه')))]);
                    }
                    return Column(children: [Row(children: [Expanded(child: from), const SizedBox(width: 8), Expanded(child: to), const SizedBox(width: 8), Expanded(child: amount)]), const SizedBox(height: 8), Row(children: [Expanded(child: TextField(controller: _transferDescription, decoration: const InputDecoration(labelText: 'شرح انتقال'))), const SizedBox(width: 8), FilledButton.icon(onPressed: _cashBanks.length < 2 ? null : _transferCashBank, icon: const Icon(Icons.swap_horiz_rounded), label: const Text('انتقال وجه'))])]);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _cashBanks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final a = _cashBanks[i];
              return FutureBuilder<double>(
                future: vm.getCashBankBalance(a),
                builder: (_, snap) => Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(a.type == 'BANK' ? Icons.account_balance_rounded : Icons.point_of_sale_rounded)),
                    title: Text(a.name),
                    subtitle: Text(a.accountNumber.isEmpty ? (a.bankName.isEmpty ? 'صندوق' : a.bankName) : '${a.bankName} • ${a.accountNumber}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_money(snap.data ?? 0, vm), style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.edit, size: 18), tooltip: 'ویرایش حساب', onPressed: () => _editCashBank(vm, a)),
                      IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), tooltip: 'حذف حساب', onPressed: () async { if (await _confirmDelete('حذف حساب', '${a.name} حذف شود؟')) { try { await vm.deleteCashBankAccount(a.id); await _load(); } catch(e) { _message('$e', error:true); } } }),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _settlementsTab(MainViewModel vm) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: vm.allContacts.isEmpty || _cashBanks.isEmpty ? null : () => _showSettlementDialog(vm),
                  icon: const Icon(Icons.payments_rounded),
                  label: const Text('ثبت تسویه جدید'),
                ),
                Chip(label: Text('دریافت ${_settlements.where((x) => x.type == 'RECEIPT').length} مورد')),
                Chip(label: Text('پرداخت ${_settlements.where((x) => x.type == 'PAYMENT').length} مورد')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _settlements.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final s = _settlements[i];
              final receipt = s.type == 'RECEIPT';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(receipt ? Icons.call_received_rounded : Icons.call_made_rounded)),
                  title: Text('${s.contactName} • ${_money(s.amount, vm)}'),
                  subtitle: Text('${receipt ? 'دریافت' : 'پرداخت'} • ${s.cashBankName} • ${s.description}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(faDateMillis(s.dateMillis)),
                    IconButton(icon: const Icon(Icons.edit, size: 18), tooltip:'ویرایش تسویه', onPressed:()=>_editSettlement(vm,s)),
                    IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), tooltip:'حذف تسویه', onPressed: () async { if (await _confirmDelete('حذف تسویه','این تسویه حذف و مانده طرف حساب اصلاح شود؟')) { try { await vm.deleteSettlement(s.id); await _load(); } catch(e) { _message('$e', error:true); } } }),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _payrollTab(MainViewModel vm) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _selectedPayrollUserId,
                  decoration: const InputDecoration(labelText: 'پرسنل'),
                  items: vm.users.map((u) => DropdownMenuItem<int>(value: u.id, child: Text('${u.name} • پایه ${_money(u.baseSalary, vm)}'))).toList(),
                  onChanged: (v) => setState(() => _selectedPayrollUserId = v),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, c) {
                    final fields = [
                      TextField(controller: _payrollBase, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حقوق پایه')), 
                      TextField(controller: _payrollOvertime, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'اضافه‌کاری')),
                      TextField(controller: _payrollDeduction, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'کسورات')),
                    ];
                    if (c.maxWidth < 700) {
                      return Column(children: [fields[0], const SizedBox(height: 8), fields[1], const SizedBox(height: 8), fields[2], const SizedBox(height: 8), Align(alignment: AlignmentDirectional.centerStart, child: FilledButton.icon(onPressed: vm.isAdmin ? _createPayroll : null, icon: const Icon(Icons.calculate_rounded), label: const Text('محاسبه حقوق')))]);
                    }
                    return Row(children: [Expanded(child: fields[0]), const SizedBox(width: 8), Expanded(child: fields[1]), const SizedBox(width: 8), Expanded(child: fields[2]), const SizedBox(width: 8), FilledButton.icon(onPressed: vm.isAdmin ? _createPayroll : null, icon: const Icon(Icons.calculate_rounded), label: const Text('محاسبه حقوق'))]);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _payroll.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final p = _payroll[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(p.paid ? Icons.check_rounded : Icons.badge_outlined)),
                  title: Text(p.userName),
                  subtitle: Text('${p.periodYear}/${p.periodMonth.toString().padLeft(2, '0')} • پایه ${_money(p.baseSalary, vm)} • پورسانت ${_money(p.commission, vm)} • کسورات ${_money(p.deductions, vm)}'),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(_money(p.netSalary, vm), style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (!p.paid) ...[IconButton(icon:const Icon(Icons.edit,size:18),tooltip:'ویرایش حقوق',onPressed:()=>_editPayroll(vm,p)), OutlinedButton.icon(onPressed: vm.isAdmin ? () => _payPayroll(p) : null, icon: const Icon(Icons.payments_outlined), label: const Text('پرداخت')), IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), tooltip:'حذف حقوق', onPressed: () async { if (await _confirmDelete('حذف رکورد حقوق','این رکورد حذف شود؟')) { try { await vm.deletePayroll(p.id); await _load(); } catch(e) { _message('$e', error:true); } } })],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _profitLossTab(MainViewModel vm) {
    final revenue = _profitLoss['revenue'] ?? 0;
    final expense = _profitLoss['expense'] ?? 0;
    final net = _profitLoss['netProfit'] ?? 0;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _reportCard('درآمد عملیاتی', _money(revenue, vm), Icons.trending_up_rounded),
        _reportCard('هزینه‌ها', _money(expense, vm), Icons.receipt_long_rounded),
        _reportCard('سود / زیان خالص', _money(net, vm), net >= 0 ? Icons.emoji_events_outlined : Icons.warning_amber_rounded, highlight: true),
        const SizedBox(height: 12),
        _reportCard('فرمول', 'درآمد - هزینه = سود/زیان خالص', Icons.calculate_outlined),
      ],
    );
  }

  Widget _balanceSheetTab(MainViewModel vm) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _reportCard('جمع دارایی‌ها', _money(_balanceSheet['assets'] ?? 0, vm), Icons.account_balance_rounded),
        _reportCard('جمع بدهی‌ها', _money(_balanceSheet['liabilities'] ?? 0, vm), Icons.money_off_csred_rounded),
        _reportCard('حقوق صاحبان سرمایه', _money(_balanceSheet['equity'] ?? 0, vm), Icons.pie_chart_rounded),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _taxAgingTab(MainViewModel vm) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DropdownButton<int>(
                  value: _selectedYear,
                  items: List.generate(8, (i) => _selectedYear - 4 + i)
                      .map((y) => DropdownMenuItem(
                            value: y,
                            child: Text('سال ${ShamsiDateUtils.faDigits(y)}'),
                          ))
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _selectedYear = v);
                    await _load();
                  },
                ),
                DropdownButton<int>(
                  value: _selectedMonth,
                  items: List.generate(12, (i) => i + 1)
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              '${_persianMonthName(m)} (${ShamsiDateUtils.faDigits(m)})',
                            ),
                          ))
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _selectedMonth = v);
                    await _load();
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('گزارش مالیاتی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        _reportCard('فروش', _money(_tax['sales'] ?? 0, vm), Icons.point_of_sale_rounded),
        _reportCard('خرید', _money(_tax['purchases'] ?? 0, vm), Icons.shopping_cart_rounded),
        _reportCard('هزینه', _money(_tax['expenses'] ?? 0, vm), Icons.receipt_long_rounded),
        _reportCard('مبلغ مشمول', _money(_tax['taxable'] ?? 0, vm), Icons.calculate_rounded),
        _reportCard('مالیات برآوردی', _money(_tax['tax'] ?? 0, vm), Icons.account_balance_rounded, highlight: true),
        const SizedBox(height: 12),
        const Text('گزارش سالانه مالیات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        Card(
          child: Column(
            children: _taxAnnual.map((r) => ListTile(
              dense: true,
              title: Text('${_persianMonthName((r['month'] as num?)?.toInt() ?? 1)}'),
              subtitle: Text('فروش ${_money(r['sales'] ?? 0, vm)} • خرید ${_money(r['purchases'] ?? 0, vm)}'),
              trailing: Text(_money(r['tax'] ?? 0, vm), style: const TextStyle(fontWeight: FontWeight.bold)),
            )).toList(),
          ),
        ),
        const SizedBox(height: 12),
        const Text('گزارش سنی بدهکاران', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        _reportCard('۰ تا ۳۰ روز', _money(_aging['0_30'] ?? 0, vm), Icons.schedule_rounded),
        _reportCard('۳۱ تا ۶۰ روز', _money(_aging['31_60'] ?? 0, vm), Icons.schedule_outlined),
        _reportCard('۶۱ تا ۹۰ روز', _money(_aging['61_90'] ?? 0, vm), Icons.history_rounded),
        _reportCard('بیش از ۹۰ روز', _money(_aging['90_plus'] ?? 0, vm), Icons.warning_amber_rounded, highlight: true),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: _agingDetails.map((r) {
              final age = (r['ageDays'] as int?) ?? 0;
              return ListTile(
                dense: true,
                leading: CircleAvatar(child: Text(age > 99 ? '90+' : '$age')),
                title: Text('${r['contactName']} • فاکتور #${r['id']}'),
                subtitle: Text(faDate(DateTime.fromMillisecondsSinceEpoch((r['dateMillis'] as num).toInt()))),
                trailing: Text(_money(r['debtAmount'] ?? 0, vm), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _returnsTab(MainViewModel vm) {
    final transactions = vm.transactions.where((t) => t.type == 'SALE' || t.type == 'PURCHASE').take(200).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final t = transactions[i];
        final isSale = t.type == 'SALE';
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(isSale ? Icons.undo_rounded : Icons.assignment_return_rounded)),
            title: Text('${isSale ? 'فروش' : 'خرید'} #${t.id} • ${t.contactName.isEmpty ? 'بدون طرف حساب' : t.contactName}'),
            subtitle: Text('${_money(t.finalAmount, vm)} • ${faDateMillis(t.dateMillis)}'),
            trailing: FilledButton.tonal(
              onPressed: vm.hasPermission(PermissionCatalog.invoicesReturn) ? () => _showReturnDialog(vm, t) : null,
              child: Text(isSale ? 'برگشت فروش' : 'برگشت خرید'),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showJournalDetails(MainViewModel vm, int journalId) async {
    final lines = await vm.getJournalLines(journalId);
    final journal = _journals.where((j) => j.id == journalId).isNotEmpty ? _journals.firstWhere((j) => j.id == journalId) : null;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(journal == null ? 'جزئیات سند' : '${journal.number} • ${journal.description}'),
        content: SizedBox(
          width: 680,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: lines.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final l = lines[i];
              return ListTile(
                title: Text('${l.accountCode} - ${l.accountName}'),
                trailing: Text('د: ${_money(l.debit, vm)} | ب: ${_money(l.credit, vm)}'),
              );
            },
          ),
        ),
        actions: [
          if (journal != null && journal.sourceType == 'MANUAL') TextButton(onPressed: () async { Navigator.pop(ctx); await _editManualJournal(vm, journal); }, child: const Text('ویرایش')),
          if (journal != null && journal.sourceType == 'MANUAL') TextButton(onPressed: () async { if (await _confirmDelete('حذف سند', 'این سند دستی حذف شود؟')) { try { await vm.deleteJournalEntry(journal.id); if (mounted) await _load(); } catch(e) { _message('$e',error:true); } } Navigator.pop(ctx); }, child: const Text('حذف', style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))
        ],
      ),
    );
  }

  Future<void> _showAccountBalance(MainViewModel vm, ChartAccount account) async {
    final rows = await vm.getGeneralLedger(accountId: account.id);
    final debit = rows.fold<double>(0, (s, r) => s + ((r['debit'] as num?)?.toDouble() ?? 0));
    final credit = rows.fold<double>(0, (s, r) => s + ((r['credit'] as num?)?.toDouble() ?? 0));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${account.code} - ${account.name}'),
        content: Text('جمع بدهکار: ${_money(debit, vm)}\nجمع بستانکار: ${_money(credit, vm)}\nمانده خالص: ${_money((debit - credit).abs(), vm)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))
        ],
      ),
    );
  }

  Widget _reportCard(String title, String value, IconData icon, {bool highlight = false}) {
    return Card(
      color: highlight ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
