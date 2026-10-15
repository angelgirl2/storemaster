// invoices_screen_fixed.dart
// نسخه اصلاح‌شده مدیریت فاکتورها

// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/shamsi_date_utils.dart';
import '../utils/persian_date_picker.dart';

import '../models/store_transaction.dart';
import '../models/contact.dart';
import '../models/transaction_item.dart';
import '../services/exporter.dart';
import '../services/online_api_service.dart';
import '../shared_src/permission_catalog.dart';
import '../viewmodels/main_viewmodel.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  bool _isPurchaseDialogOpen = false;
  final Set<int> _printingInvoiceIds = <int>{};
  final Set<int> _printingReceiptIds = <int>{};
  final Set<int> _sendingInvoiceIds = <int>{};
  final Set<int> _mutatingInvoiceIds = <int>{};


  Future<void> _customInvoiceDialog(BuildContext context, MainViewModel vm) async {
    if (vm.products.isEmpty) {
      _showMessage(context, 'ابتدا حداقل یک کالا یا خدمت ثبت کنید.', backgroundColor: Colors.orange);
      return;
    }

    final formKey = GlobalKey<FormState>();
    final number = TextEditingController();
    final paid = TextEditingController(text: '0');
    final discount = TextEditingController(text: '0');
    final qty = TextEditingController(text: '1');
    final draftItems = <TransactionItem>[];
    var dateTime = DateTime.now();
    dynamic selectedProduct = vm.products.first;
    Contact? selectedCustomer;
    String paymentMethod = 'CASH';
    bool isSaving = false;

    double subtotal() => draftItems.fold<double>(0, (sum, item) => sum + item.totalPrice);

    void addDraftItem(StateSetter setDialogState) {
      final product = selectedProduct;
      final quantity = _parseNumber(qty.text) ?? 0;
      if (product == null || quantity <= 0) return;
      final index = draftItems.indexWhere((x) => x.productId == product.id && x.unitPrice == (product.sellPrice as num).toDouble());
      final price = (product.sellPrice as num).toDouble();
      if (index >= 0) {
        final old = draftItems[index];
        final nextQty = old.quantity + quantity;
        draftItems[index] = TransactionItem(
          id: old.id,
          transactionId: 0,
          productId: old.productId,
          productName: old.productName,
          quantity: nextQty,
          unitPrice: old.unitPrice,
          costPrice: old.costPrice,
          totalPrice: nextQty * old.unitPrice,
        );
      } else {
        draftItems.add(TransactionItem(
          transactionId: 0,
          productId: product.id,
          productName: product.name,
          quantity: quantity,
          unitPrice: price,
          costPrice: product.buyPrice,
          totalPrice: quantity * price,
        ));
      }
      setDialogState(() {
        qty.text = '1';
      });
    }

    try {
      final result = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            final total = subtotal();
            final d = (_parseNumber(discount.text) ?? 0).clamp(0.0, total).toDouble();
            final payable = (total - d).clamp(0.0, double.infinity).toDouble();
            return AlertDialog(
              title: const Text('فاکتور فروش دلخواه'),
              content: SizedBox(
                width: 680,
                height: 560,
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: number,
                            decoration: const InputDecoration(labelText: 'شماره فاکتور دلخواه', prefixIcon: Icon(Icons.tag)),
                            validator: (v) => v == null || v.trim().isEmpty ? 'شماره فاکتور الزامی است.' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('تاریخ و ساعت'),
                            subtitle: Text(faDateTime(dateTime)),
                            leading: const Icon(Icons.schedule),
                            onTap: () async {
                              final selected = await showPersianDateTimePicker(context: ctx, initialDate: dateTime);
                              if (selected == null || !ctx.mounted) return;
                              setDialogState(() => dateTime = selected);
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<dynamic>(
                            initialValue: selectedProduct,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'انتخاب کالا / خدمت'),
                            items: vm.products.map((product) => DropdownMenuItem<dynamic>(value: product, child: Text('${product.name} | ${_formatMoney(product.sellPrice, vm.config?.currency ?? 'تومان')}'))).toList(),
                            onChanged: (v) => setDialogState(() => selectedProduct = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(width: 120, child: TextField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'تعداد'))),
                        const SizedBox(width: 8),
                        FilledButton.icon(onPressed: () => addDraftItem(setDialogState), icon: const Icon(Icons.add), label: const Text('افزودن قلم')),
                      ]),
                      const SizedBox(height: 10),
                      Expanded(
                        child: draftItems.isEmpty
                            ? const Center(child: Text('هنوز قلمی به فاکتور اضافه نشده است.'))
                            : ListView.separated(
                                itemCount: draftItems.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final item = draftItems[index];
                                  return ListTile(
                                    title: Text(item.productName),
                                    subtitle: Text('${_formatQuantity(item.quantity)} × ${_formatMoney(item.unitPrice, vm.config?.currency ?? 'تومان')}'),
                                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Text(_formatMoney(item.totalPrice, vm.config?.currency ?? 'تومان')), 
                                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setDialogState(() => draftItems.removeAt(index))),
                                    ]),
                                  );
                                },
                              ),
                      ),
                      const Divider(),
                      Row(children: [
                        Expanded(child: TextField(controller: discount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تخفیف'), onChanged: (_) => setDialogState(() {}))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: paid, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ دریافتی'), onChanged: (_) => setDialogState(() {}))),
                      ]),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text('مشتری / طرف حساب', style: Theme.of(ctx).textTheme.labelLarge),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<Contact?>(
                        initialValue: selectedCustomer,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          hintText: 'انتخاب مشتری (برای نسیه الزامی است)',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<Contact?>(
                            value: null,
                            child: Text('مشتری آزاد / عمومی'),
                          ),
                          for (final c in vm.allContacts.where((c) => c.type == 'CUSTOMER' || c.type == 'BOTH'))
                            DropdownMenuItem<Contact?>(value: c, child: Text(c.name, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (c) => setDialogState(() => selectedCustomer = c),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(label: const Text('نقدی'), selected: paymentMethod == 'CASH', onSelected: (_) => setDialogState(() => paymentMethod = 'CASH')),
                          ChoiceChip(label: const Text('کارتخوان'), selected: paymentMethod == 'CARD', onSelected: (_) => setDialogState(() => paymentMethod = 'CARD')),
                          ChoiceChip(label: const Text('کارت به کارت'), selected: paymentMethod == 'TRANSFER', onSelected: (_) => setDialogState(() => paymentMethod = 'TRANSFER')),
                          ChoiceChip(label: const Text('نسیه / دفتری'), selected: paymentMethod == 'CREDIT', onSelected: (_) => setDialogState(() { paymentMethod = 'CREDIT'; paid.text = '0'; })),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(alignment: AlignmentDirectional.centerEnd, child: Text('قابل پرداخت: ${_formatMoney(payable, vm.config?.currency ?? 'تومان')}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('انصراف')),
                FilledButton.icon(
                  onPressed: isSaving ? null : () async {
                    if (!formKey.currentState!.validate() || draftItems.isEmpty) {
                      if (draftItems.isEmpty) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('حداقل یک قلم به فاکتور اضافه کنید.')));
                      return;
                    }
                    final available = await vm.getInvoiceNumberAvailability(number.text.trim());
                    if (!available) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('این شماره فاکتور قبلاً استفاده شده است.'), backgroundColor: Colors.red));
                      return;
                    }
                    if (paymentMethod == 'CREDIT' && selectedCustomer == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('برای ثبت نسیه باید مشتری یا طرف حساب انتخاب شود.'), backgroundColor: Colors.orange, duration: Duration(seconds: 3)));
                      return;
                    }
                    if (paymentMethod == 'CREDIT' && (_parseNumber(paid.text) ?? 0) > 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('برای ثبت نسیه، مبلغ دریافتی باید صفر باشد.'), backgroundColor: Colors.orange, duration: Duration(seconds: 3)));
                      return;
                    }
                    setDialogState(() => isSaving = true);
                    try {
                      final total = subtotal();
                      final d = (_parseNumber(discount.text) ?? 0).clamp(0.0, total).toDouble();
                      final maxPaid = total - d;
                      final p = (_parseNumber(paid.text) ?? 0).clamp(0.0, maxPaid).toDouble();
                      final id = await vm.createCustomInvoice(
                        items: List<TransactionItem>.from(draftItems),
                        paidAmount: p,
                        discount: d,
                        paymentMethod: paymentMethod,
                        customer: selectedCustomer,
                        customDateMillis: dateTime.millisecondsSinceEpoch,
                        customInvoiceNumber: number.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx, id);
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('خطا در ثبت: $e'), backgroundColor: Colors.red));
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: Text(isSaving ? 'در حال ثبت...' : 'ثبت فاکتور'),
                ),
              ],
            );
          },
        ),
      );
      if (result != null && mounted) {
        _showMessage(context, 'فاکتور شماره ${number.text.trim()} با موفقیت ثبت شد. چاپ جداگانه از دکمه چاپ انجام می‌شود.');
      }
    } finally {
      number.dispose();
      paid.dispose();
      discount.dispose();
      qty.dispose();
    }
  }

  // --------------------------------------------------
  // دیالوگ ثبت فاکتور خرید
  // --------------------------------------------------

  Future<void> _purchaseDialog(
    BuildContext context,
    MainViewModel vm,
  ) async {
    if (_isPurchaseDialogOpen) {
      return;
    }

    if (vm.products.isEmpty) {
      _showMessage(
        context,
        'ابتدا حداقل یک کالا ثبت کنید.',
        backgroundColor: Colors.orange,
      );
      return;
    }

    _isPurchaseDialogOpen = true;

    final formKey = GlobalKey<FormState>();

    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController(
      text: vm.products.first.buyPrice.toStringAsFixed(0),
    );
    final supplierController = TextEditingController();
    final paidController = TextEditingController(text: '0');

    dynamic selectedProduct = vm.products.first;
    bool isSaving = false;
    String? formError;

    try {
      final invoiceId = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final quantity = _parseNumber(quantityController.text) ?? 0.0;
              final unitPrice = _parseNumber(priceController.text) ?? 0.0;
              final totalAmount = quantity * unitPrice;

              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.add_shopping_cart),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('فاکتور خرید / ورودی کالا'),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 500,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<dynamic>(
                            initialValue: selectedProduct,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'کالا',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                              border: OutlineInputBorder(),
                            ),
                            items: vm.products.map((product) {
                              return DropdownMenuItem<dynamic>(
                                value: product,
                                child: Text(
                                  '${product.name} | '
                                  'موجودی: ${_formatQuantity(product.stockQuantity)} '
                                  '${product.unit}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: isSaving
                                ? null
                                : (product) {
                                    if (product == null) {
                                      return;
                                    }

                                    setDialogState(() {
                                      selectedProduct = product;
                                      priceController.text =
                                          product.buyPrice.toStringAsFixed(0);
                                      formError = null;
                                    });
                                  },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: quantityController,
                                  enabled: !isSaving,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(
                                        r'[0-9۰-۹٠-٩.,٫٬]',
                                      ),
                                    ),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'تعداد',
                                    prefixIcon: Icon(Icons.numbers),
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) {
                                    setDialogState(() {
                                      formError = null;
                                    });
                                  },
                                  validator: (value) {
                                    final quantity = _parseNumber(value ?? '');

                                    if (quantity == null) {
                                      return 'تعداد معتبر نیست.';
                                    }

                                    if (quantity <= 0) {
                                      return 'بیشتر از صفر وارد کنید.';
                                    }

                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: priceController,
                                  enabled: !isSaving,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(
                                        r'[0-9۰-۹٠-٩.,٫٬]',
                                      ),
                                    ),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'قیمت خرید واحد',
                                    prefixIcon: Icon(
                                      Icons.payments_outlined,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) {
                                    setDialogState(() {
                                      formError = null;
                                    });
                                  },
                                  validator: (value) {
                                    final price = _parseNumber(value ?? '');

                                    if (price == null) {
                                      return 'قیمت معتبر نیست.';
                                    }

                                    if (price <= 0) {
                                      return 'بیشتر از صفر وارد کنید.';
                                    }

                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: supplierController,
                            enabled: !isSaving,
                            textInputAction: TextInputAction.next,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: 'تأمین‌کننده',
                              hintText: 'در صورت خالی بودن، تأمین‌کننده عمومی',
                              prefixIcon: Icon(Icons.business_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: paidController,
                            enabled: !isSaving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9۰-۹٠-٩.,٫٬]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'مبلغ پرداختی',
                              hintText: 'برای خرید نسیه می‌تواند صفر باشد',
                              prefixIcon: Icon(Icons.account_balance_wallet),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              setDialogState(() {
                                formError = null;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }

                              final paid = _parseNumber(value);

                              if (paid == null) {
                                return 'مبلغ پرداختی معتبر نیست.';
                              }

                              if (paid < 0) {
                                return 'مبلغ نمی‌تواند منفی باشد.';
                              }

                              final quantity = _parseNumber(
                                    quantityController.text,
                                  ) ??
                                  0.0;
                              final unitPrice = _parseNumber(
                                    priceController.text,
                                  ) ??
                                  0.0;
                              final total = quantity * unitPrice;

                              if (total > 0 && paid > total) {
                                return 'پرداختی بیشتر از کل فاکتور است.';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(dialogContext)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'مبلغ کل فاکتور',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatMoney(
                                    totalAmount,
                                    vm.config?.currency ?? 'تومان',
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(dialogContext)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (formError != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(dialogContext)
                                    .colorScheme
                                    .errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 20,
                                    color: Theme.of(dialogContext)
                                        .colorScheme
                                        .error,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      formError!,
                                      style: TextStyle(
                                        color: Theme.of(dialogContext)
                                            .colorScheme
                                            .onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text('انصراف'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isSaving
                        ? null
                        : () async {
                            FocusScope.of(dialogContext).unfocus();

                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }

                            final quantity = _parseNumber(
                                  quantityController.text,
                                ) ??
                                0.0;
                            final unitPrice = _parseNumber(
                                  priceController.text,
                                ) ??
                                0.0;
                            final paidAmount =
                                paidController.text.trim().isEmpty
                                    ? 0.0
                                    : _parseNumber(
                                          paidController.text,
                                        ) ??
                                        0.0;

                            final total = quantity * unitPrice;

                            if (quantity <= 0 || unitPrice <= 0 || total <= 0) {
                              setDialogState(() {
                                formError =
                                    'تعداد و قیمت خرید باید بیشتر از صفر باشند.';
                              });
                              return;
                            }

                            if (paidAmount < 0 || paidAmount > total) {
                              setDialogState(() {
                                formError =
                                    'مبلغ پرداختی باید بین صفر و مبلغ کل فاکتور باشد.';
                              });
                              return;
                            }

                            setDialogState(() {
                              isSaving = true;
                              formError = null;
                            });

                            try {
                              final product = selectedProduct;

                              final item = TransactionItem(
                                transactionId: 0,
                                productId: product.id,
                                productName: product.name,
                                quantity: quantity,
                                unitPrice: unitPrice,
                                costPrice: unitPrice,
                                totalPrice: total,
                              );

                              final id = await vm.createPurchaseInvoice(
                                items: [item],
                                paidAmount: paidAmount,
                                contactId: null,
                                contactName:
                                    supplierController.text.trim().isEmpty
                                        ? 'تأمین‌کننده عمومی'
                                        : supplierController.text.trim(),
                              );

                              if (!dialogContext.mounted) {
                                return;
                              }

                              Navigator.of(dialogContext).pop(id);
                            } catch (error) {
                              if (!dialogContext.mounted) {
                                return;
                              }

                              setDialogState(() {
                                isSaving = false;
                                formError = 'خطا در ثبت فاکتور خرید: $error';
                              });
                            }
                          },
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      isSaving ? 'در حال ثبت...' : 'ثبت فاکتور خرید',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (invoiceId != null && mounted) {
        _showMessage(
          context,
          'فاکتور خرید #$invoiceId با موفقیت ثبت شد.',
        );
      }
    } finally {
      quantityController.dispose();
      priceController.dispose();
      supplierController.dispose();
      paidController.dispose();
      _isPurchaseDialogOpen = false;
    }
  }


  Future<void> _editInvoice(BuildContext context, MainViewModel vm, StoreTransaction transaction) async {
    final number = TextEditingController(text: transaction.invoiceNumber);
    final discount = TextEditingController(text: transaction.discount.toStringAsFixed(0));
    final paid = TextEditingController(text: transaction.paidAmount.toStringAsFixed(0));
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(transaction.dateMillis);
    try {
      final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: Text('ویرایش ${transaction.type == 'PURCHASE' ? 'فاکتور خرید' : 'فاکتور فروش'}'),
          content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller:number, decoration:const InputDecoration(labelText:'شماره فاکتور')),
            const SizedBox(height:8),
            ListTile(contentPadding:EdgeInsets.zero, title:const Text('تاریخ و ساعت'), subtitle:Text(faDateTime(dateTime)), onTap:() async {
              final selected = await showPersianDateTimePicker(context: ctx, initialDate: dateTime);
              if (selected == null || !ctx.mounted) return;
              setState(() => dateTime = selected);
            }),
            TextField(controller:discount, keyboardType:TextInputType.number, decoration:const InputDecoration(labelText:'تخفیف')),
            TextField(controller:paid, keyboardType:TextInputType.number, decoration:const InputDecoration(labelText:'مبلغ پرداخت‌شده')),
          ])),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false), child:const Text('انصراف')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true), child:const Text('ادامه')),
          ],
        );
      }));
      if (ok != true || !mounted) return;
      final items=await vm.getTransactionItems(transaction.id);
      final discountValue=(double.tryParse(discount.text.replaceAll(',',''))??0).clamp(0.0, transaction.totalAmount).toDouble();
      final finalAmount=(transaction.totalAmount-discountValue).clamp(0.0,double.infinity).toDouble();
      final paidValue=(double.tryParse(paid.text.replaceAll(',',''))??0).clamp(0.0,finalAmount).toDouble();
      final updated=transaction.copyWith(invoiceNumber:number.text.trim(), discount:discountValue, finalAmount:finalAmount, paidAmount:paidValue, debtAmount:(finalAmount-paidValue).clamp(0.0,double.infinity).toDouble(), dateMillis:dateTime.millisecondsSinceEpoch);
      await vm.updateTransaction(updated, items:items);
      if (mounted) _showMessage(context,'فاکتور با موفقیت ویرایش شد.');
    } catch(e) { if(mounted)_showMessage(context,'خطا در ویرایش فاکتور: $e', backgroundColor:Colors.red); }
    finally { number.dispose(); discount.dispose(); paid.dispose(); }
  }

  Future<void> _deleteInvoice(BuildContext context, MainViewModel vm, StoreTransaction transaction) async {
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('حذف فاکتور'),content:Text('فاکتور ${transaction.invoiceNumber.isEmpty?'#${transaction.id}':transaction.invoiceNumber} حذف شود؟\nموجودی و آثار حسابداری نیز برگردانده می‌شود.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),style:FilledButton.styleFrom(backgroundColor:Colors.red),child:const Text('حذف'))]));
    if(ok!=true||!mounted)return;
    try { await vm.deleteTransaction(transaction); if(mounted)_showMessage(context,'فاکتور حذف شد.'); } catch(e) { if(mounted)_showMessage(context,'خطا در حذف فاکتور: $e',backgroundColor:Colors.red); }
  }

  // --------------------------------------------------
  // چاپ فاکتور
  // --------------------------------------------------

  Future<void> _printInvoice(
    BuildContext context,
    MainViewModel vm,
    StoreTransaction transaction,
  ) async {
    if (_printingInvoiceIds.contains(transaction.id)) {
      return;
    }

    setState(() {
      _printingInvoiceIds.add(transaction.id);
    });

    try {
      final items = await vm.getTransactionItems(transaction.id);

      final file = await Exporter.exportInvoicePdf(
        filenamePrefix: 'فاکتور_${transaction.id}',
        storeName: vm.config?.storeName ?? 'فروشگاه',
        storePhone: vm.config?.storePhone ?? '',
        businessTitle: vm.config?.businessTitle ?? 'فروشگاه',
        logoBase64: vm.config?.logoBase64 ?? '',
        transactionId: transaction.id,
        invoiceNumber: transaction.invoiceNumber,
        dateStr: _formatDate(transaction.dateMillis),
        customerName: transaction.contactName.trim().isEmpty
            ? transaction.type == 'PURCHASE'
                ? 'تأمین‌کننده عمومی'
                : 'مشتری حضوری'
            : transaction.contactName,
        userName: transaction.userName,
        items: items.map((item) {
          return [item.productName, item.quantity, item.unitPrice];
        }).toList(),
        totalAmount: transaction.totalAmount,
        discount: transaction.discount,
        finalAmount: transaction.finalAmount,
        paidAmount: transaction.paidAmount,
        debtAmount: transaction.debtAmount,
        currency: vm.config?.currency ?? 'تومان',
        paymentMethod: transaction.paymentMethod,
        invoiceType: transaction.type,
        paperSize: vm.config?.printPaperSize ?? 'A4',
        orientation: vm.config?.printOrientation ?? 'PORTRAIT',
        marginMm: vm.config?.printMarginMm ?? 8.0,
        customWidthMm: vm.config?.customPaperWidthMm ?? 210.0,
        customHeightMm: vm.config?.customPaperHeightMm ?? 297.0,
      );

      if (file == null) {
        throw Exception('ساخت فایل PDF فاکتور انجام نشد.');
      }

      final printed = await Exporter.printPdfFile(
        file,
        jobName: 'فاکتور_${transaction.invoiceNumber.isEmpty ? transaction.id : transaction.invoiceNumber}',
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        context,
        printed
            ? 'فاکتور ${transaction.invoiceNumber.isEmpty ? '#${transaction.id}' : 'شماره ${transaction.invoiceNumber}'} به پنجره چاپ ارسال شد.'
            : 'پنجره چاپ توسط سیستم باز نشد؛ فایل PDF ذخیره شد.',
        backgroundColor: printed ? null : Colors.orange,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        context,
        'خطا در چاپ فاکتور: $error',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _printingInvoiceIds.remove(transaction.id);
        });
      }
    }
  }

  // رسید هر فاکتور به‌صورت مستقل و با قالب مشترک رسید صندوق چاپ می‌شود.
  Future<void> _printReceipt(
    BuildContext context,
    MainViewModel vm,
    StoreTransaction transaction,
  ) async {
    if (_printingReceiptIds.contains(transaction.id)) return;

    setState(() => _printingReceiptIds.add(transaction.id));
    try {
      final items = await vm.getTransactionItems(transaction.id);
      final file = await Exporter.exportThermalReceiptPdf(
        storeName: vm.config?.storeName ?? 'فروشگاه',
        storePhone: vm.config?.storePhone ?? '',
        businessTitle: vm.config?.businessTitle ?? 'فروشگاه',
        logoBase64: vm.config?.logoBase64 ?? '',
        transactionId: transaction.id,
        invoiceNumber: transaction.invoiceNumber,
        dateStr: _formatDate(transaction.dateMillis),
        customerName: transaction.contactName.trim().isEmpty
            ? (transaction.type.toUpperCase() == 'PURCHASE'
                ? 'تأمین‌کننده عمومی'
                : 'مشتری حضوری')
            : transaction.contactName,
        userName: transaction.userName.trim().isEmpty
            ? (vm.currentUser?.name ?? 'فروشنده')
            : transaction.userName,
        items: items.map((item) => [
          item.productName,
          item.quantity,
          item.unitPrice,
        ]).toList(),
        totalAmount: transaction.totalAmount,
        discount: transaction.discount,
        finalAmount: transaction.finalAmount,
        paidAmount: transaction.paidAmount,
        debtAmount: transaction.debtAmount,
        currency: vm.config?.currency ?? 'تومان',
        paymentMethod: transaction.paymentMethod,
        invoiceType: transaction.type,
        paperSize: (vm.config?.printPaperSize == 'R58' ||
                vm.config?.printPaperSize == 'R80')
            ? vm.config!.printPaperSize
            : 'R80',
        orientation: 'PORTRAIT',
        marginMm: 3.0,
        customWidthMm: vm.config?.customPaperWidthMm ?? 80.0,
        customHeightMm: vm.config?.customPaperHeightMm ?? 220.0,
      );

      if (file == null) throw Exception('ساخت فایل PDF رسید انجام نشد.');
      final label = transaction.invoiceNumber.trim().isEmpty
          ? '#${transaction.id}'
          : 'شماره ${transaction.invoiceNumber}';
      final printed = await Exporter.printPdfFile(
        file,
        jobName: 'رسید_$label',
      );
      if (!mounted) return;
      _showMessage(
        context,
        printed
            ? 'رسید $label برای چاپ ارسال شد.'
            : 'پنجره چاپ باز نشد؛ فایل رسید ذخیره شد.',
        backgroundColor: printed ? null : Colors.orange,
      );
    } catch (error) {
      if (mounted) {
        _showMessage(
          context,
          'خطا در چاپ رسید: $error',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _printingReceiptIds.remove(transaction.id));
    }
  }

  Future<void> _exportInvoiceExcel(
    BuildContext context,
    MainViewModel vm,
    StoreTransaction transaction,
  ) async {
    try {
      final items = await vm.getTransactionItems(transaction.id);
      final file = await Exporter.exportExcel(
        filenamePrefix: 'فاکتور_${transaction.invoiceNumber.isEmpty ? transaction.id : transaction.invoiceNumber}',
        sheetName: 'فاکتور',
        title: '${transaction.type == 'PURCHASE' ? 'فاکتور خرید' : 'فاکتور فروش'} | شماره ${transaction.invoiceNumber.isEmpty ? transaction.id : transaction.invoiceNumber}',
        storeName: vm.config?.storeName ?? 'فروشگاه',
        headers: const ['کالا / خدمت', 'تعداد', 'قیمت واحد', 'مبلغ کل'],
        rows: items.map((item) => [item.productName, item.quantity, item.unitPrice, item.quantity * item.unitPrice]).toList(),
      );
      if (!mounted) return;
      if (file == null) {
        _showMessage(context, 'ساخت فایل Excel انجام نشد.', backgroundColor: Colors.red);
      } else {
        _showMessage(context, 'فایل Excel ساخته شد و در سیستم باز می‌شود.');
      }
    } catch (e) {
      if (mounted) _showMessage(context, 'خطا در خروجی Excel: $e', backgroundColor: Colors.red);
    }
  }

  // --------------------------------------------------
  // ارسال فاکتور
  // --------------------------------------------------

  Future<void> _sendInvoice(
    BuildContext context,
    MainViewModel vm,
    StoreTransaction transaction,
  ) async {
    if (_sendingInvoiceIds.contains(transaction.id)) {
      return;
    }

    final destinationController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String selectedChannel = 'WHATSAPP';
    bool isSending = false;
    String? sendError;

    try {
      final sent = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              return StatefulBuilder(
                builder: (dialogContext, setDialogState) {
                  return AlertDialog(
                    title: Row(
                      children: [
                        const Icon(Icons.send_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ارسال فاکتور ${transaction.invoiceNumber.isEmpty ? '#${transaction.id}' : 'شماره ${transaction.invoiceNumber}'}',
                          ),
                        ),
                      ],
                    ),
                    content: SizedBox(
                      width: 420,
                      child: Form(
                        key: formKey,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: selectedChannel,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'روش ارسال',
                                  prefixIcon: Icon(Icons.share_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem<String>(
                                    value: 'WHATSAPP',
                                    child: Text('واتساپ'),
                                  ),
                                  DropdownMenuItem<String>(
                                    value: 'SMS',
                                    child: Text('پیامک'),
                                  ),
                                  DropdownMenuItem<String>(
                                    value: 'EMAIL',
                                    child: Text('ایمیل'),
                                  ),
                                  DropdownMenuItem<String>(
                                    value: 'FILE',
                                    child: Text('فایل / اشتراک‌گذاری'),
                                  ),
                                  DropdownMenuItem<String>(
                                    value: 'ONLINE_LINK',
                                    child: Text('لینک آنلاین روی Railway (بدون پیامک)'),
                                  ),
                                ],
                                onChanged: isSending
                                    ? null
                                    : (value) {
                                        if (value == null) {
                                          return;
                                        }

                                        setDialogState(() {
                                          selectedChannel = value;
                                          sendError = null;
                                        });
                                      },
                              ),
                              const SizedBox(height: 12),
                              if (selectedChannel != 'ONLINE_LINK') TextFormField(
                                controller: destinationController,
                                enabled: !isSending,
                                keyboardType: _destinationKeyboardType(
                                  selectedChannel,
                                ),
                                decoration: InputDecoration(
                                  labelText: _destinationLabel(
                                    selectedChannel,
                                  ),
                                  hintText: _destinationHint(
                                    selectedChannel,
                                  ),
                                  prefixIcon: Icon(
                                    _channelIcon(
                                      selectedChannel,
                                    ),
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (selectedChannel == 'FILE' || selectedChannel == 'ONLINE_LINK') {
                                    return null;
                                  }

                                  if (value == null || value.trim().isEmpty) {
                                    return 'مقصد ارسال را وارد کنید.';
                                  }

                                  if (selectedChannel == 'EMAIL' &&
                                      !_isValidEmail(value.trim())) {
                                    return 'ایمیل معتبر وارد کنید.';
                                  }

                                  return null;
                                },
                              ),
                              if (sendError != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(dialogContext)
                                        .colorScheme
                                        .errorContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    sendError!,
                                    style: TextStyle(
                                      color: Theme.of(dialogContext)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: isSending
                            ? null
                            : () {
                                Navigator.of(dialogContext).pop(false);
                              },
                        child: const Text('انصراف'),
                      ),
                      ElevatedButton.icon(
                        onPressed: isSending
                            ? null
                            : () async {
                                if (!(formKey.currentState?.validate() ??
                                    false)) {
                                  return;
                                }

                                setDialogState(() {
                                  isSending = true;
                                  sendError = null;
                                });

                                if (mounted) {
                                  setState(() {
                                    _sendingInvoiceIds.add(transaction.id);
                                  });
                                }

                                try {
                                  var destination = selectedChannel == 'FILE'
                                      ? 'اشتراک‌گذاری فایل'
                                      : destinationController.text.trim();
                                  final invoiceText = _buildInvoiceShareText(
                                    transaction: transaction,
                                    vm: vm,
                                  );
                                  var clipboardText = invoiceText;
                                  if (selectedChannel == 'ONLINE_LINK') {
                                    final invoiceItems = await vm.getTransactionItems(transaction.id);
                                    final response = await OnlineApiService.instance.createOnlineInvoiceShare(
                                      invoiceNumber: transaction.invoiceNumber.isEmpty ? '#${transaction.id}' : transaction.invoiceNumber,
                                      dateText: _formatDate(transaction.dateMillis),
                                      customerName: transaction.contactName.trim().isEmpty ? 'مشتری حضوری' : transaction.contactName.trim(),
                                      currency: vm.config?.currency ?? 'تومان',
                                      storePhone: vm.config?.storePhone ?? '',
                                      items: invoiceItems.map((item) => <String, dynamic>{
                                        'name': item.productName,
                                        'quantity': item.quantity,
                                        'unitPrice': item.unitPrice,
                                        'lineTotal': item.quantity * item.unitPrice,
                                      }).toList(),
                                      totalAmount: transaction.totalAmount,
                                      discount: transaction.discount,
                                      finalAmount: transaction.finalAmount,
                                      paidAmount: transaction.paidAmount,
                                      debtAmount: transaction.debtAmount,
                                    );
                                    final url = '${response['url'] ?? ''}'.trim();
                                    final parsedUrl = Uri.tryParse(url);
                                    if (parsedUrl == null || !parsedUrl.hasScheme ||
                                        !(parsedUrl.scheme == 'https' || parsedUrl.scheme == 'http')) {
                                      throw StateError('لینک معتبر از سرور دریافت نشد.');
                                    }
                                    destination = url;
                                    clipboardText = '$invoiceText\n\nمشاهده فاکتور آنلاین:\n$url';
                                  }

                                  await vm.recordInvoiceDelivery(
                                    invoiceId: transaction.id,
                                    channel: selectedChannel,
                                    destination: destination,
                                  );
                                  await Clipboard.setData(ClipboardData(text: clipboardText));

                                  if (!dialogContext.mounted) {
                                    return;
                                  }

                                  Navigator.of(dialogContext).pop(true);
                                } catch (error) {
                                  if (!dialogContext.mounted) {
                                    return;
                                  }

                                  setDialogState(() {
                                    isSending = false;
                                    sendError = 'خطا در ثبت ارسال: $error';
                                  });

                                  if (mounted) {
                                    setState(() {
                                      _sendingInvoiceIds.remove(
                                        transaction.id,
                                      );
                                    });
                                  }
                                }
                              },
                        icon: isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(
                          isSending ? 'در حال ثبت...' : 'ثبت ارسال و کپی',
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ) ??
          false;

      if (sent && mounted) {
        _showMessage(
          context,
          'ONLINE_LINK' == selectedChannel ? 'لینک امن فاکتور در Railway ساخته و همراه خلاصه فاکتور کپی شد؛ آن را برای مشتری ارسال کنید.' : 'ارسال فاکتور ثبت و اطلاعات آن کپی شد.',
        );
      }
    } finally {
      destinationController.dispose();

      if (mounted) {
        setState(() {
          _sendingInvoiceIds.remove(transaction.id);
        });
      }
    }
  }

  // --------------------------------------------------
  // رابط کاربری
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainViewModel>();
    final currency = vm.config?.currency ?? 'تومان';

    final invoices = vm.transactions
        .where(
          (transaction) =>
              transaction.type == 'SALE' || transaction.type == 'PURCHASE',
        )
        .toList()
      ..sort(
        (first, second) => second.dateMillis.compareTo(first.dateMillis),
      );

    final salesCount =
        invoices.where((transaction) => transaction.type == 'SALE').length;

    final purchasesCount =
        invoices.where((transaction) => transaction.type == 'PURCHASE').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت فاکتورها'),
        actions: [
          IconButton(
            onPressed: () => _customInvoiceDialog(context, vm),
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'فاکتور فروش جدید / دلخواه',
          ),
          IconButton(
            onPressed: () => _purchaseDialog(context, vm),
            icon: const Icon(Icons.add_shopping_cart),
            tooltip: 'ثبت فاکتور خرید',
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'new-sales-invoice',
            onPressed: () => _customInvoiceDialog(context, vm),
            icon: const Icon(Icons.receipt_long),
            label: const Text('فاکتور فروش'),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: 'new-purchase-invoice',
            onPressed: () => _purchaseDialog(context, vm),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('فاکتور خرید'),
          ),
        ],
      ),
      body: SafeArea(
        child: invoices.isEmpty
            ? _EmptyInvoicesView(
                onAddPurchase: () => _purchaseDialog(context, vm),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: _InvoiceSummary(
                      totalCount: invoices.length,
                      salesCount: salesCount,
                      purchasesCount: purchasesCount,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        12,
                        8,
                        12,
                        90,
                      ),
                      itemCount: invoices.length,
                      itemBuilder: (context, index) {
                        final transaction = invoices[index];
                        final isPurchase = transaction.type == 'PURCHASE';

                        return _InvoiceCard(
                          transaction: transaction,
                          currency: currency,
                          isPurchase: isPurchase,
                          isPrinting:
                              _printingInvoiceIds.contains(transaction.id),
                          isPrintingReceipt:
                              _printingReceiptIds.contains(transaction.id),
                          isSending:
                              _sendingInvoiceIds.contains(transaction.id),
                          isMutating:
                              _mutatingInvoiceIds.contains(transaction.id),
                          onPrint: () => _printInvoice(
                            context,
                            vm,
                            transaction,
                          ),
                          onPrintReceipt: () => _printReceipt(
                            context,
                            vm,
                            transaction,
                          ),
                          onSend: isPurchase
                              ? null
                              : () => _sendInvoice(
                                    context,
                                    vm,
                                    transaction,
                                  ),
                          onExportExcel: () => _exportInvoiceExcel(
                            context, vm, transaction),
                          onEdit: vm.hasPermission(PermissionCatalog.invoicesEdit) &&
                                  vm.canEditOrDeleteTransaction(transaction)
                              ? () => _editInvoice(context, vm, transaction)
                              : null,
                          onDelete: vm.hasPermission(PermissionCatalog.invoicesDelete) &&
                                  vm.canEditOrDeleteTransaction(transaction)
                              ? () => _deleteInvoice(context, vm, transaction)
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // --------------------------------------------------
  // متدهای کمکی
  // --------------------------------------------------

  static double? _parseNumber(String input) {
    var normalized = input.trim();

    if (normalized.isEmpty) {
      return null;
    }

    normalized = _convertDigits(normalized)
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .replaceAll('٫', '.')
        .replaceAll(' ', '');

    return double.tryParse(normalized);
  }

  static String _convertDigits(String input) {
    const persianDigits = [
      '۰',
      '۱',
      '۲',
      '۳',
      '۴',
      '۵',
      '۶',
      '۷',
      '۸',
      '۹',
    ];

    const arabicDigits = [
      '٠',
      '١',
      '٢',
      '٣',
      '٤',
      '٥',
      '٦',
      '٧',
      '٨',
      '٩',
    ];

    var result = input;

    for (int index = 0; index < 10; index++) {
      result = result.replaceAll(
        persianDigits[index],
        index.toString(),
      );
      result = result.replaceAll(
        arabicDigits[index],
        index.toString(),
      );
    }

    return result;
  }

  static String _formatMoney(num value, String currency) {
    final formatted = NumberFormat('#,##0', 'en_US').format(value);

    return currency.trim().isEmpty ? formatted : '$formatted $currency';
  }

  static String _formatQuantity(num value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return NumberFormat('#,##0.##', 'en_US').format(value);
  }

  static String _formatDate(int dateMillis) {
    return faDateTime(
      DateTime.fromMillisecondsSinceEpoch(dateMillis),
    );
  }

  String _buildInvoiceShareText({
    required StoreTransaction transaction,
    required MainViewModel vm,
  }) {
    final currency = vm.config?.currency ?? 'تومان';
    final storeName = vm.config?.storeName ?? 'فروشگاه';

    return [
      storeName,
      'فاکتور فروش ${transaction.invoiceNumber.isEmpty ? '#${transaction.id}' : 'شماره ${transaction.invoiceNumber}'}',
      'تاریخ: ${_formatDate(transaction.dateMillis)}',
      if (transaction.contactName.trim().isNotEmpty)
        'مشتری: ${transaction.contactName}',
      'مبلغ کل: ${_formatMoney(transaction.finalAmount, currency)}',
      'پرداختی: ${_formatMoney(transaction.paidAmount, currency)}',
      if (transaction.debtAmount > 0)
        'باقی‌مانده: ${_formatMoney(transaction.debtAmount, currency)}',
    ].join('\n');
  }

  TextInputType _destinationKeyboardType(String channel) {
    switch (channel) {
      case 'WHATSAPP':
      case 'SMS':
        return TextInputType.phone;
      case 'EMAIL':
        return TextInputType.emailAddress;
      default:
        return TextInputType.text;
    }
  }

  String _destinationLabel(String channel) {
    switch (channel) {
      case 'WHATSAPP':
        return 'شماره واتساپ';
      case 'SMS':
        return 'شماره موبایل';
      case 'EMAIL':
        return 'آدرس ایمیل';
      case 'ONLINE_LINK':
        return 'لینک آنلاین به‌صورت خودکار ساخته می‌شود';
      default:
        return 'نام یا توضیح مقصد';
    }
  }

  String _destinationHint(String channel) {
    switch (channel) {
      case 'WHATSAPP':
      case 'SMS':
        return 'مثال: 09123456789';
      case 'EMAIL':
        return 'مثال: customer@example.com';
      case 'ONLINE_LINK':
        return 'با سرور Railway لینک امن ساخته می‌شود؛ پیامک لازم نیست';
      default:
        return 'اختیاری';
    }
  }

  IconData _channelIcon(String channel) {
    switch (channel) {
      case 'WHATSAPP':
        return Icons.chat_outlined;
      case 'SMS':
        return Icons.sms_outlined;
      case 'EMAIL':
        return Icons.email_outlined;
      case 'ONLINE_LINK':
        return Icons.link_rounded;
      default:
        return Icons.file_present_outlined;
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  void _showMessage(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}

// --------------------------------------------------
// خلاصه فاکتورها
// --------------------------------------------------

class _InvoiceSummary extends StatelessWidget {
  final int totalCount;
  final int salesCount;
  final int purchasesCount;

  const _InvoiceSummary({
    required this.totalCount,
    required this.salesCount,
    required this.purchasesCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 18,
          runSpacing: 10,
          alignment: WrapAlignment.spaceAround,
          children: [
            _SummaryItem(
              title: 'کل فاکتورها',
              value: totalCount.toString(),
              icon: Icons.receipt_long,
              color: Theme.of(context).colorScheme.primary,
            ),
            _SummaryItem(
              title: 'فاکتور فروش',
              value: salesCount.toString(),
              icon: Icons.point_of_sale,
              color: const Color(0xFF2E7D32),
            ),
            _SummaryItem(
              title: 'فاکتور خرید',
              value: purchasesCount.toString(),
              icon: Icons.shopping_cart_checkout,
              color: const Color(0xFFE65100),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withAlpha(28),
          child: Icon(
            icon,
            color: color,
            size: 19,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --------------------------------------------------
// کارت فاکتور
// --------------------------------------------------

class _InvoiceCard extends StatelessWidget {
  final StoreTransaction transaction;
  final String currency;
  final bool isPurchase;
  final bool isPrinting;
  final bool isPrintingReceipt;
  final bool isSending;
  final bool isMutating;
  final VoidCallback onPrint;
  final VoidCallback onPrintReceipt;
  final VoidCallback onExportExcel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSend;

  const _InvoiceCard({
    required this.transaction,
    required this.currency,
    required this.isPurchase,
    required this.isPrinting,
    required this.isPrintingReceipt,
    required this.isSending,
    required this.isMutating,
    required this.onPrint,
    required this.onPrintReceipt,
    required this.onExportExcel,
    required this.onEdit,
    required this.onDelete,
    this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final contactName = transaction.contactName.trim().isEmpty
        ? isPurchase
            ? 'تأمین‌کننده عمومی'
            : 'مشتری حضوری'
        : transaction.contactName;

    final typeColor =
        isPurchase ? const Color(0xFFE65100) : const Color(0xFF2E7D32);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: typeColor.withAlpha(28),
                  child: Icon(
                    isPurchase
                        ? Icons.shopping_cart_checkout
                        : Icons.receipt_long,
                    color: typeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${isPurchase ? 'فاکتور خرید' : 'فاکتور فروش'} '
                        'شماره ${transaction.invoiceNumber.isEmpty ? transaction.id : transaction.invoiceNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contactName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPurchase ? 'خرید' : 'فروش',
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: Colors.grey,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _formatDate(transaction.dateMillis),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ),
                Text(
                  _formatMoney(
                    transaction.finalAmount,
                    currency,
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (transaction.debtAmount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'باقی‌مانده: ${_formatMoney(transaction.debtAmount, currency)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            if (transaction.userName.trim().isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'ثبت توسط: ${transaction.userName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            const Divider(height: 18),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 2,
              runSpacing: 0,
              children: [
                if (onEdit != null)
                  IconButton(
                    tooltip: 'ویرایش فاکتور',
                    onPressed: isMutating ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'حذف فاکتور',
                    onPressed: isMutating ? null : onDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                IconButton(
                  tooltip: 'چاپ فاکتور',
                  onPressed: isPrinting ? null : onPrint,
                  icon: isPrinting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_outlined),
                ),
                IconButton(
                  tooltip: 'چاپ رسید مستقل',
                  onPressed: isPrintingReceipt ? null : onPrintReceipt,
                  icon: isPrintingReceipt
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.receipt_long_outlined),
                ),
                IconButton(
                  tooltip: 'خروجی Excel فاکتور',
                  onPressed: onExportExcel,
                  icon: const Icon(Icons.table_view_outlined),
                ),
                if (onSend != null)
                  IconButton(
                    tooltip: 'ارسال فاکتور',
                    onPressed: isSending ? null : onSend,
                    icon: isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(int dateMillis) {
    return faDateTime(
      DateTime.fromMillisecondsSinceEpoch(dateMillis),
    );
  }

  static String _formatMoney(num value, String currency) {
    final formatted = NumberFormat('#,##0', 'en_US').format(value);

    return currency.trim().isEmpty ? formatted : '$formatted $currency';
  }
}

// --------------------------------------------------
// صفحه خالی
// --------------------------------------------------

class _EmptyInvoicesView extends StatelessWidget {
  final VoidCallback onAddPurchase;

  const _EmptyInvoicesView({
    required this.onAddPurchase,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary.withAlpha(130),
            ),
            const SizedBox(height: 16),
            const Text(
              'هنوز فاکتوری ثبت نشده است',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'فاکتورهای فروش و خرید در این بخش نمایش داده می‌شوند.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAddPurchase,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('ثبت فاکتور خرید'),
            ),
          ],
        ),
      ),
    );
  }
}
