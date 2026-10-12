// ============================================================================
// custom_sale_dialog.dart
// ثبت فروش دلخواه: تاریخ و ساعت دلخواه، شماره فاکتور دلخواه و اقلام سفارشی
// از صفحه صندوق فروش (POS) و صفحه مدیریت فاکتورها استفاده می‌شود.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../models/contact.dart';
import '../models/product.dart';
import '../models/transaction_item.dart';
import '../viewmodels/main_viewmodel.dart';

/// دیالوگ «ثبت فروش دلخواه» — بعد از ثبت موفق، شناسه فاکتور را برمی‌گرداند.
Future<int?> showCustomSaleDialog(
  BuildContext context,
  MainViewModel vm,
) async {
  if (vm.products.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ابتدا حداقل یک کالا ثبت کنید.'),
        backgroundColor: Colors.orange,
      ),
    );
    return null;
  }
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CustomSaleDialog(vm: vm),
  );
}

class _CustomSaleDialog extends StatefulWidget {
  const _CustomSaleDialog({required this.vm});

  final MainViewModel vm;

  @override
  State<_CustomSaleDialog> createState() => _CustomSaleDialogState();
}

class _CustomSaleDialogState extends State<_CustomSaleDialog> {
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _paidCtrl = TextEditingController(text: '0');
  final TextEditingController _discountCtrl = TextEditingController(text: '0');
  final TextEditingController _numberCtrl = TextEditingController();

  Product? _product;
  Contact? _customer;
  final List<({Product product, double qty, double price})> _items = [];

  late int _jy;
  late int _jm;
  late int _jd;
  late int _hh;
  late int _mm;
  String _method = 'CASH';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final jn = Jalali.now();
    _jy = jn.year;
    _jm = jn.month;
    _jd = jn.day;
    final t = DateTime.now();
    _hh = t.hour;
    _mm = t.minute;
    _product = widget.vm.products.isNotEmpty ? widget.vm.products.first : null;
    _priceCtrl.text = (_product?.sellPrice ?? 0).toStringAsFixed(0);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _paidCtrl.dispose();
    _discountCtrl.dispose();
    _numberCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold<double>(0, (s, i) => s + i.qty * i.price);
  double get _discount => _num(_discountCtrl.text);
  double get _final => (_subtotal - _discount).clamp(0, double.infinity).toDouble();
  double get _paid => _num(_paidCtrl.text).clamp(0.0, _final).toDouble();

  double _num(String v) =>
      double.tryParse(v.replaceAll(',', '').replaceAll('٬', '').trim()) ?? 0;

  void _addItem() {
    final product = _product;
    if (product == null) {
      setState(() => _error = 'کالا را انتخاب کنید.');
      return;
    }
    final qty = _num(_qtyCtrl.text);
    final price = _num(_priceCtrl.text);
    if (qty <= 0 || price <= 0) {
      setState(() => _error = 'تعداد و قیمت باید بیشتر از صفر باشند.');
      return;
    }
    if (qty > product.stockQuantity) {
      setState(() => _error = 'موجودی کافی برای «${product.name}» نیست.');
      return;
    }
    setState(() {
      _items.add((product: product, qty: qty, price: price));
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_items.isEmpty) {
      setState(() => _error = 'حداقل یک قلم به فاکتور اضافه کنید.');
      return;
    }
    final customId = int.tryParse(_numberCtrl.text.trim());
    if (customId != null &&
        widget.vm.transactions.any((t) => t.id == customId)) {
      setState(() => _error = 'شماره فاکتور «$customId» قبلاً استفاده شده است.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final items = _items
          .map((i) => TransactionItem(
                transactionId: 0,
                productId: i.product.id,
                productName: i.product.name,
                quantity: i.qty,
                unitPrice: i.price,
                costPrice: i.product.buyPrice,
                totalPrice: i.qty * i.price,
              ))
          .toList();
      final g = Jalali(_jy, _jm, _jd).toDateTime();
      final dateMillis =
          DateTime(g.year, g.month, g.day, _hh, _mm).millisecondsSinceEpoch;
      final id = await widget.vm.createCustomInvoice(
        items: items,
        paidAmount: _paid,
        discount: _discount,
        paymentMethod: _method,
        customer: _customer,
        customDateMillis: dateMillis,
        customInvoiceId: customId,
      );
      if (!mounted) return;
      Navigator.pop(context, id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'خطا در ثبت فروش: $e';
      });
    }
  }

  String _money(double v) => NumberFormat('#,##0', 'en_US').format(v);

  @override
  Widget build(BuildContext context) {
    final currency = widget.vm.config?.currency ?? 'تومان';

    Widget dd(int value, List<int> values, String suffix,
        ValueChanged<int> onChanged) {
      return SizedBox(
        width: 96,
        child: DropdownButtonFormField<int>(
          initialValue: value,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: [
            for (final v in values)
              DropdownMenuItem(value: v, child: Text('$v $suffix')),
          ],
          onChanged: (v) => onChanged(v ?? value),
        ),
      );
    }

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_chart),
          SizedBox(width: 8),
          Expanded(child: Text('ثبت فروش دلخواه')),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // کالاها
              DropdownButtonFormField<Product?>(
                initialValue: _product,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'کالا / خدمت',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final p in widget.vm.products)
                    DropdownMenuItem<Product?>(
                      value: p,
                      child: Text(
                        '${p.name} | موجودی: ${_money(p.stockQuantity)} ${p.unit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (p) {
                  if (p == null) return;
                  setState(() {
                    _product = p;
                    _priceCtrl.text = p.sellPrice.toStringAsFixed(0);
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'تعداد',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'قیمت واحد ($currency)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('افزودن'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'هنوز قلمی اضافه نشده است.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                )
              else
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_items[i].product.name}  (${_money(_items[i].qty)} × ${_money(_items[i].price)})',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  '${_money(_items[i].qty * _items[i].price)} $currency',
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Colors.red, size: 18),
                                  onPressed: () =>
                                      setState(() => _items.removeAt(i)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const Divider(height: 24),
              // مشتری
              DropdownButtonFormField<Contact?>(
                initialValue: _customer,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'مشتری',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<Contact?>(
                    value: null,
                    child: Text('مشتری آزاد / عمومی'),
                  ),
                  for (final c in widget.vm.allContacts)
                    DropdownMenuItem<Contact?>(
                      value: c,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (c) => setState(() => _customer = c),
              ),
              const SizedBox(height: 10),
              // تاریخ و ساعت دلخواه
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  dd(_jy, [for (var i = _jy - 5; i <= _jy + 5; i++) i], 'سال',
                      (v) => setState(() => _jy = v)),
                  dd(_jm, [for (var i = 1; i <= 12; i++) i], 'ماه',
                      (v) => setState(() => _jm = v)),
                  dd(_jd, [for (var i = 1; i <= 31; i++) i], 'روز',
                      (v) => setState(() => _jd = v)),
                  dd(_hh, [for (var i = 0; i <= 23; i++) i], 'ساعت',
                      (v) => setState(() => _hh = v)),
                  dd(_mm, [for (var i = 0; i <= 59; i++) i], 'دقیقه',
                      (v) => setState(() => _mm = v)),
                ],
              ),
              const SizedBox(height: 10),
              // شماره فاکتور دلخواه
              TextField(
                controller: _numberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'شماره فاکتور (اختیاری)',
                  hintText: 'در صورت خالی بودن، شماره خودکار در نظر گرفته می‌شود',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _discountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'تخفیف ($currency)',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _paidCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'دریافتی ($currency)',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('نقدی'),
                    selected: _method == 'CASH',
                    onSelected: (_) => setState(() => _method = 'CASH'),
                  ),
                  ChoiceChip(
                    label: const Text('کارتخوان'),
                    selected: _method == 'CARD',
                    onSelected: (_) => setState(() => _method = 'CARD'),
                  ),
                  ChoiceChip(
                    label: const Text('نسیه / دفتری'),
                    selected: _method == 'CREDIT',
                    onSelected: (_) {
                      setState(() {
                        _method = 'CREDIT';
                        _paidCtrl.text = '0';
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('جمع کل:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Text(
                      '${_money(_subtotal)} $currency',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Text(
                'قابل پرداخت: ${_money(_final)} $currency — '
                'باقی‌مانده (نسیه): ${_money((_final - _paid).clamp(0, double.infinity))} $currency',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_saving ? 'در حال ثبت...' : 'ثبت فاکتور فروش'),
        ),
      ],
    );
  }
}
