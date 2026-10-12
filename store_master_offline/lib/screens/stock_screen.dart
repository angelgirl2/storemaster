// stock_screen_fixed.dart
// نسخه اصلاح‌شده StockScreen — بدون خطا و قابل اجرا

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stock_movement.dart';
import '../models/product.dart';
import '../viewmodels/main_viewmodel.dart';
import '../services/exporter.dart';
import '../utils/shamsi_date_utils.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({Key? key}) : super(key: key);
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  int selectedTab = 0;
  String searchQuery = '';
  bool showDialogFlag = false;
  String movementType = 'IN';
  StockMovement? editingMovement;
  StockMovement? deletingMovement;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainViewModel>();
    final currency = vm.config?.currency ?? 'تومان';
    final list = vm.stockMovements;
    final products = vm.products;
    final totalIn =
        list.where((m) => m.type == 'IN').fold(0.0, (s, m) => s + m.quantity);
    final totalOut =
        list.where((m) => m.type == 'OUT').fold(0.0, (s, m) => s + m.quantity);

    final filtered = list.where((m) {
      if (selectedTab == 1 && m.type != 'IN') return false;
      if (selectedTab == 2 && m.type != 'OUT') return false;
      if (searchQuery.isEmpty) return true;
      final cat = products
          .firstWhere((p) => p.id == m.productId,
              orElse: () => Product(
                  name: '',
                  category: '',
                  buyPrice: 0,
                  sellPrice: 0,
                  stockQuantity: 0))
          .category;
      return m.productName.contains(searchQuery) ||
          cat.contains(searchQuery) ||
          m.partyName.contains(searchQuery) ||
          m.refNumber.contains(searchQuery) ||
          m.userName.contains(searchQuery);
    }).toList();

    // schedule dialogs safely after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (showDialogFlag) {
        showDialogFlag = false;
        showDialog(
          context: context,
          builder: (_) => _MovementFormDialog(
            vm: vm,
            type: movementType,
            existing: editingMovement,
            onSave: (m) {
              vm.saveStockMovement(
                id: editingMovement?.id ?? 0,
                old: editingMovement,
                productId: m.productId,
                productName: m.productName,
                type: m.type,
                quantity: m.quantity,
                unit: m.unit,
                pricePerUnit: m.pricePerUnit,
                partyName: m.partyName,
                refNumber: m.refNumber,
                note: m.note,
              );
              if (mounted) setState(() {});
            },
          ),
        );
      }

      if (deletingMovement != null) {
        final m = deletingMovement!;
        deletingMovement = null;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('حذف گردش انبار'),
            content: Text(
                'آیا از حذف "${m.productName}" اطمینان دارید؟ موجودی اصلاح می‌شود.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('انصراف')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  vm.deleteStockMovement(m);
                  Navigator.pop(context);
                  if (mounted) setState(() {});
                },
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('ورود و خروج کالا')),
      floatingActionButton:
          Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton.extended(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          onPressed: () {
            editingMovement = null;
            movementType = 'IN';
            showDialogFlag = true;
            setState(() {});
          },
          icon: const Icon(Icons.add),
          label: const Text('ورود کالا (+)'),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.extended(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          onPressed: () {
            editingMovement = null;
            movementType = 'OUT';
            showDialogFlag = true;
            setState(() {});
          },
          icon: const Icon(Icons.remove),
          label: const Text('خروج کالا (-)'),
        ),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                  Text('ورود و خروج کالا (انبارداری شرکتی)',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                      'مدیریت دقیق ورود و خروج اجناس به همراه خروجی PDF و اکسل',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ])),
            OutlinedButton.icon(
              onPressed: () async {
                final f = await Exporter.exportExcel(
                  filenamePrefix: 'گزارش_ورود_و_خروج_انبار',
                  sheetName: 'انبار',
                  title: 'گزارش ورود و خروج انبار',
                  storeName: vm.config?.storeName,
                  headers: const ['نوع','کالا','مقدار','واحد','قیمت واحد','مبلغ کل','طرف حساب','شماره مرجع','تاریخ'],
                  rows: filtered.map((m) => [m.type, m.productName, m.quantity, m.unit, m.pricePerUnit, m.totalPrice, m.partyName, m.refNumber, faDateTimeMillis(m.dateMillis)]).toList(),
                );
                if (f != null && mounted)
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Excel: ${f.path.split('/').last}')));
              },
              icon: const Icon(Icons.table_chart, size: 16),
              label: const Text('اکسل', style: TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 4),
            ElevatedButton.icon(
              onPressed: () async {
                final file = await Exporter.exportTableToPdf(
                  filenamePrefix: 'گزارش_ورود_و_خروج_انبار',
                  title: 'گزارش ورود و خروج انبار',
                  storeName: vm.config?.storeName ?? 'فروشگاه',
                  headers: const ['نوع','کالا','مقدار','واحد','قیمت واحد','مبلغ کل','طرف حساب','مرجع'],
                  rows: filtered.map((m) => [
                    m.type == 'IN' ? 'ورودی' : 'خروجی',
                    m.productName,
                    m.quantity.toString(),
                    m.unit,
                    m.pricePerUnit.toStringAsFixed(0),
                    m.totalPrice.toStringAsFixed(0),
                    m.partyName,
                    m.refNumber,
                  ]).toList(),
                );
                if (file == null) throw Exception('ساخت PDF انجام نشد.');
                final printed = await Exporter.printPdfFile(
                  file,
                  jobName: 'گزارش_ورود_و_خروج_انبار',
                );
                if (!printed) {
                  await Exporter.openExportFile(file.path);
                }
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        printed
                            ? 'گزارش انبار مستقیماً برای چاپ ارسال شد.'
                            : 'PDF گزارش انبار ساخته شد، اما چاپگر در دسترس نبود.',
                      ),
                      backgroundColor: printed ? null : Colors.orange,
                    ),
                  );
              },
              icon: const Icon(Icons.picture_as_pdf, size: 16),
              label: const Text('چاپ PDF', style: TextStyle(fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: Card(
                    color: const Color(0xFFE8F5E9),
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('کل ورودی‌های انبار',
                                  style: TextStyle(
                                      fontSize: 11, color: Color(0xFF1B5E20))),
                              Text('${totalIn.toStringAsFixed(0)} واحد',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF2E7D32))),
                            ])))),
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
                              const Text('کل خروجی‌های انبار',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.red)),
                              Text('${totalOut.toStringAsFixed(0)} واحد',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.red)),
                            ])))),
          ]),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
                labelText:
                    'جستجوی سریع (نام کالا / دسته‌بندی / طرف حساب / شماره فاکتور)'),
            onChanged: (v) => setState(() => searchQuery = v),
          ),
          Row(children: [
            Expanded(
                child: ChoiceChip(
                    label: Text('همه گردش‌ها (${list.length})'),
                    selected: selectedTab == 0,
                    onSelected: (_) => setState(() => selectedTab = 0))),
            Expanded(
                child: ChoiceChip(
                    label: Text(
                        'ورودی (${list.where((m) => m.type == 'IN').length})',
                        style: const TextStyle(color: Color(0xFF2E7D32))),
                    selected: selectedTab == 1,
                    onSelected: (_) => setState(() => selectedTab = 1))),
            Expanded(
                child: ChoiceChip(
                    label: Text(
                        'خروجی (${list.where((m) => m.type == 'OUT').length})',
                        style: const TextStyle(color: Colors.red)),
                    selected: selectedTab == 2,
                    onSelected: (_) => setState(() => selectedTab = 2))),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('هیچ رسید ورود یا خروجی ثبت نشده است.',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final m = filtered[i];
                      final isIn = m.type == 'IN';
                      final date = faDateTimeMillis(m.dateMillis);
                      return Card(
                        color: isIn ? const Color(0xFFF1F8E9) : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: isIn
                                            ? const Color(0xFF2E7D32)
                                            : Colors.red,
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                        isIn
                                            ? 'ورود کالا (+)'
                                            : 'خروج کالا (-)',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(m.productName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16))),
                                  IconButton(
                                      onPressed: () {
                                        editingMovement = m;
                                        movementType = m.type;
                                        showDialogFlag = true;
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue)),
                                  IconButton(
                                      onPressed: () {
                                        deletingMovement = m;
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red)),
                                ]),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Text('مقدار: ${m.quantity} ${m.unit}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isIn
                                              ? const Color(0xFF1B5E20)
                                              : Colors.red,
                                          fontSize: 14)),
                                  const Spacer(),
                                  if (m.pricePerUnit > 0)
                                    Text(
                                        'فی: ${m.pricePerUnit.toStringAsFixed(0)} | جمع: ${m.totalPrice.toStringAsFixed(0)} $currency',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                ]),
                                if (m.partyName.isNotEmpty ||
                                    m.refNumber.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(children: [
                                      if (m.partyName.isNotEmpty)
                                        Text(
                                            '${isIn ? 'تامین‌کننده' : 'متقاضی/تحویل‌گیرنده'}: ${m.partyName}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                      const Spacer(),
                                      if (m.refNumber.isNotEmpty)
                                        Text(
                                            'شماره مرجع/فاکتور: ${m.refNumber}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                    ]),
                                  ),
                                const SizedBox(height: 6),
                                Text(date,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
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

class _MovementFormDialog extends StatefulWidget {
  final MainViewModel vm;
  final String type;
  final StockMovement? existing;
  final Function(StockMovement) onSave;
  const _MovementFormDialog(
      {required this.vm,
      required this.type,
      this.existing,
      required this.onSave});

  @override
  State<_MovementFormDialog> createState() => _MovementFormDialogState();
}

class _MovementFormDialogState extends State<_MovementFormDialog> {
  late TextEditingController qtyCtrl;
  late TextEditingController priceCtrl;
  late TextEditingController partyCtrl;
  late TextEditingController refCtrl;
  late TextEditingController noteCtrl;
  int? selectedProductId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    selectedProductId = (e?.productId == 0) ? null : e?.productId;
    qtyCtrl = TextEditingController(text: (e?.quantity ?? 1).toString());
    priceCtrl = TextEditingController(text: (e?.pricePerUnit ?? 0).toString());
    partyCtrl = TextEditingController(text: e?.partyName ?? '');
    refCtrl = TextEditingController(text: e?.refNumber ?? '');
    noteCtrl = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
    partyCtrl.dispose();
    refCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.vm.products;
    return AlertDialog(
      title: Text(widget.type == 'IN' ? 'ثبت ورود کالا' : 'ثبت خروج کالا'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int?>(
              decoration: const InputDecoration(labelText: 'انتخاب کالا'),
              initialValue: selectedProductId,
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('سایر (غیر از انبار)')),
                ...products.map(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
              ],
              onChanged: (v) => setState(() => selectedProductId = v),
            ),
            const SizedBox(height: 8),
            TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(labelText: 'مقدار'),
                keyboardType: TextInputType.number),
            TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: 'قیمت واحد'),
                keyboardType: TextInputType.number),
            TextField(
                controller: partyCtrl,
                decoration: InputDecoration(
                    labelText: widget.type == 'IN'
                        ? 'تامین‌کننده'
                        : 'متقاضی/تحویل‌گیرنده')),
            TextField(
                controller: refCtrl,
                decoration:
                    const InputDecoration(labelText: 'شماره فاکتور/حواله')),
            TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'توضیحات'),
                maxLines: 2),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف')),
        ElevatedButton(
            onPressed: () {
              final prod = widget.vm.products.firstWhere(
                (p) => p.id == selectedProductId,
                orElse: () => Product(
                    name: 'سایر',
                    category: '',
                    buyPrice: 0,
                    sellPrice: 0,
                    stockQuantity: 0),
              );
              final m = StockMovement(
                id: widget.existing?.id ?? 0,
                productId: selectedProductId ?? 0,
                productName: prod.name,
                type: widget.type,
                quantity:
                    double.tryParse(qtyCtrl.text.replaceAll(',', '')) ?? 1,
                unit: (prod.unit.isEmpty ? 'عدد' : prod.unit),
                pricePerUnit:
                    double.tryParse(priceCtrl.text.replaceAll(',', '')) ?? 0,
                partyName: partyCtrl.text.trim(),
                refNumber: refCtrl.text.trim(),
                note: noteCtrl.text.trim(),
                userId: 0,
                userName: '',
              );
              widget.onSave(m);
              Navigator.pop(context);
            },
            child: const Text('ذخیره')),
      ],
    );
  }
}
