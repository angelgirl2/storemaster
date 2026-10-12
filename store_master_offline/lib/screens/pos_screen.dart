// pos_screen.dart
// نسخه اصلاح‌شده، پایدار و سازگار PosScreen

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/shamsi_date_utils.dart';

import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/store_transaction.dart';
import '../services/exporter.dart';
import '../viewmodels/main_viewmodel.dart';
import '../widgets/barcode_scanner_dialog.dart';


// Shared cart editor used by both the main POS page and the cart panel.
Future<void> _showEditCartItemDialog(BuildContext context, MainViewModel vm, CartItem cartItem) async {
    final quantity = TextEditingController(
      text: cartItem.quantity % 1 == 0 ? cartItem.quantity.toInt().toString() : cartItem.quantity.toString(),
    );
    final price = TextEditingController(text: cartItem.unitPrice.toStringAsFixed(0));
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('ویرایش ${cartItem.product.name}'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: quantity,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'تعداد دلخواه'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'قیمت واحد دلخواه (${vm.config?.currency ?? 'تومان'})'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('ذخیره')),
          ],
        ),
      );
      if (result != true) return;
      final q = double.tryParse(quantity.text.replaceAll(',', '').replaceAll('٬', '').replaceAll('،', '').trim());
      final p = double.tryParse(price.text.replaceAll(',', '').replaceAll('٬', '').replaceAll('،', '').trim());
      if (q == null || q <= 0 || p == null || p < 0) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعداد یا قیمت معتبر نیست.')));
        return;
      }
      vm.setCartItemQuantity(cartItem.product.id, q);
      vm.setCartItemPrice(cartItem.product.id, p);
    } finally {
      quantity.dispose();
      price.dispose();
    }
  }


class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchController = TextEditingController();

  String searchQuery = '';
  String _selectedCategory = 'همه';
  String _posLayout = '';
  int? _lastTransactionId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainViewModel>();
    final currency = vm.config?.currency ?? 'تومان';
    final layout = _posLayout.isEmpty ? (vm.config?.layoutStyle ?? 'GRID') : _posLayout;

    final categories = <String>{'همه'}
      ..addAll(vm.products.map((p) => p.category.trim()).where((c) => c.isNotEmpty));

    final products = vm.products.where((product) {
      final query = searchQuery.trim().toLowerCase();
      final categoryOk = _selectedCategory == 'همه' || product.category.trim() == _selectedCategory;
      if (!categoryOk) return false;
      if (query.isEmpty) return true;
      return product.name.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('صندوق فروش (POS)'),
        actions: [
          if (_lastTransactionId != null)
            IconButton(
              tooltip: 'چاپ آخرین فاکتور ثبت‌شده',
              icon: const Icon(Icons.print_outlined),
              onPressed: () {
                final transaction = _findTransaction(vm, _lastTransactionId!);
                if (transaction != null) _printInvoice(context, vm, transaction);
              },
            ),
          IconButton(
            tooltip: 'اسکن بارکد',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _openBarcodeScanner(context, vm),
          ),
        ],
      ),
      floatingActionButton: vm.cart.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openCheckoutDialog(context, vm),
              icon: const Icon(Icons.payment),
              label: Text(
                'تسویه (${_cartQuantity(vm)} کالا)',
              ),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'جستجوی نام کالا، دسته یا بارکد',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'پاک کردن جستجو',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  searchQuery = '';
                                });
                                vm.setSearchQuery('');
                              },
                            ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                      vm.setSearchQuery(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => _openBarcodeScanner(context, vm),
                    child: const Icon(Icons.qr_code_scanner),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    primary: false,
                    child: Row(
                      children: categories.map((category) {
                        final selected = _selectedCategory == category;
                        return Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: selected,
                            onSelected: (_) => setState(() => _selectedCategory = category),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'چیدمان کالاها',
                  icon: const Icon(Icons.view_quilt_outlined),
                  onSelected: (value) => setState(() => _posLayout = value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'GRID', child: Text('شبکه‌ای')),
                    PopupMenuItem(value: 'LIST', child: Text('لیستی')),
                    PopupMenuItem(value: 'TOUCH_TILES', child: Text('کاشی لمسی')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // در صفحه‌های کوچک، سبد خرید زیر کالاها نمایش داده شود.
                final isSmallScreen = constraints.maxWidth < 700;

                if (isSmallScreen) {
                  return Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildProductsView(
                          layout: layout,
                          products: products,
                          currency: currency,
                          onTap: vm.addToCart,
                        ),
                      ),
                      SizedBox(
                        height: 370,
                        child: _CartPanel(
                          vm: vm,
                          currency: currency,
                          onCheckout: vm.cart.isEmpty
                              ? null
                              : () => _openCheckoutDialog(context, vm),
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildProductsView(
                        layout: layout,
                        products: products,
                        currency: currency,
                        onTap: vm.addToCart,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _CartPanel(
                        vm: vm,
                        currency: currency,
                        onCheckout: vm.cart.isEmpty
                            ? null
                            : () => _openCheckoutDialog(context, vm),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsView({
    required String layout,
    required List<Product> products,
    required String currency,
    required ValueChanged<Product> onTap,
  }) {
    if (products.isEmpty) {
      return const Center(
        child: Text(
          'کالایی برای نمایش پیدا نشد.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (layout == 'TOUCH_TILES') {
      return _TouchTileGrid(
        products: products,
        currency: currency,
        onTap: onTap,
      );
    }

    if (layout == 'LIST') {
      return _ListGrid(
        products: products,
        currency: currency,
        onTap: onTap,
      );
    }

    return _CardGrid(
      products: products,
      currency: currency,
      onTap: onTap,
    );
  }

  int _cartQuantity(MainViewModel vm) {
    return vm.cart.fold<int>(
      0,
      (sum, item) => sum + item.quantity.toInt(),
    );
  }


  Future<void> _openBarcodeScanner(
    BuildContext context,
    MainViewModel vm,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return BarcodeScannerDialog(
          allProducts: vm.products,
          onScanned: (product) {
            vm.addToCart(product);
          },
          onCustomSubmit: (barcode) {
            _searchController.text = barcode;

            if (mounted) {
              setState(() {
                searchQuery = barcode;
              });
            }

            vm.setSearchQuery(barcode);
          },
        );
      },
    );
  }

  Future<void> _openCheckoutDialog(
    BuildContext context,
    MainViewModel vm,
  ) async {
    if (vm.cart.isEmpty) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _CheckoutDialog(
          vm: vm,
          paidInitial: vm.finalTotal.toStringAsFixed(0),
          discountInitial: vm.discountAmount.toStringAsFixed(0),
          methodInitial: vm.paymentMethod,
          onConfirm: (paidAmount, discountAmount, paymentMethod) async {
            vm.setDiscount(discountAmount);
            vm.setPaymentMethod(paymentMethod);

            final transactionId = await vm.checkout(paidAmount);

            if (transactionId <= 0) {
              return false;
            }

            if (mounted) {
              setState(() => _lastTransactionId = transactionId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('فروش با شماره فاکتور ${_invoiceLabel(vm, transactionId)} ثبت شد. برای چاپ، دکمه چاپ آخرین فاکتور را بزنید.'),
                  action: SnackBarAction(
                    label: 'چاپ',
                    onPressed: () {
                      final transaction = _findTransaction(vm, transactionId);
                      if (transaction != null) _printInvoice(context, vm, transaction);
                    },
                  ),
                ),
              );
            }
            return true;
          },
        );
      },
    );
  }

  String _invoiceLabel(MainViewModel vm, int transactionId) {
    final t = _findTransaction(vm, transactionId);
    if (t == null) return '#$transactionId';
    return t.invoiceNumber.trim().isEmpty ? '#${t.id}' : t.invoiceNumber;
  }

  StoreTransaction? _findTransaction(
    MainViewModel vm,
    int transactionId,
  ) {
    try {
      return vm.transactions.firstWhere(
        (transaction) => transaction.id == transactionId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _printInvoice(
    BuildContext context,
    MainViewModel vm,
    StoreTransaction transaction,
  ) async {
    final currency = vm.config?.currency ?? 'تومان';
    final items = await vm.getTransactionItems(transaction.id);

    final itemsForHtml = items
        .map(
          (item) => [
            item.productName,
            item.quantity,
            item.unitPrice,
          ],
        )
        .toList();

    final date = faDateTime(
      DateTime.fromMillisecondsSinceEpoch(transaction.dateMillis),
    );

    final customerName = transaction.contactName.isEmpty
        ? 'مشتری حضوری'
        : transaction.contactName;

    final userName = transaction.userName.isEmpty
        ? (vm.currentUser?.name ?? 'فروشنده')
        : transaction.userName;

    final file = await Exporter.exportThermalReceiptPdf(
      filenamePrefix: 'رسید_حرارتی_${transaction.id}',
      storeName: vm.config?.storeName ?? 'فروشگاه',
      storePhone: vm.config?.storePhone ?? '',
      businessTitle: vm.config?.businessTitle ?? 'فروشگاه',
      logoBase64: vm.config?.logoBase64 ?? '',
      transactionId: transaction.id,
      invoiceNumber: transaction.invoiceNumber,
      dateStr: date,
      customerName: customerName,
      userName: userName,
      items: itemsForHtml,
      totalAmount: transaction.totalAmount,
      discount: transaction.discount,
      finalAmount: transaction.finalAmount,
      paidAmount: transaction.paidAmount,
      debtAmount: transaction.debtAmount,
      currency: currency,
      paymentMethod: transaction.paymentMethod,
      invoiceType: transaction.type,
      paperSize: (vm.config?.printPaperSize == 'R58' ||
              vm.config?.printPaperSize == 'R80')
          ? vm.config!.printPaperSize
          : 'R80',
      orientation: 'PORTRAIT',
      marginMm: 3.0,
    );
    if (file == null) throw Exception('ساخت PDF رسید انجام نشد.');

    final printed = await Exporter.printPdfFile(
      file,
      jobName: 'رسید_حرارتی_${transaction.invoiceNumber.isEmpty ? transaction.id : transaction.invoiceNumber}',
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(printed
            ? 'فاکتور ${transaction.invoiceNumber.isEmpty ? '#${transaction.id}' : 'شماره ${transaction.invoiceNumber}'} برای چاپ ارسال شد.'
            : 'پنجره چاپ باز نشد؛ فایل رسید ذخیره شده است.'),
      ),
    );
  }
}

// ============================================================================
// Product widgets
// ============================================================================

class _CardGrid extends StatelessWidget {
  final List<Product> products;
  final String currency;
  final ValueChanged<Product> onTap;

  const _CardGrid({
    required this.products,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isOutOfStock = !product.isService && product.stockQuantity <= 0;

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isOutOfStock ? null : () => onTap(product),
          child: Card(
            color: isOutOfStock
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'موجودی: ${product.stockQuantity} ${product.unit}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOutOfStock ? Colors.red : Colors.grey,
                    ),
                  ),
                  if (product.category.isNotEmpty)
                    Text(
                      product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    '${NumberFormat('#,##0', 'en_US').format(product.sellPrice)} $currency',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TouchTileGrid extends StatelessWidget {
  final List<Product> products;
  final String currency;
  final ValueChanged<Product> onTap;

  const _TouchTileGrid({
    required this.products,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.3,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isOutOfStock = !product.isService && product.stockQuantity <= 0;

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isOutOfStock ? null : () => onTap(product),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isOutOfStock
                  ? Colors.grey.shade300
                  : Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  isOutOfStock
                      ? 'ناموجود'
                      : '${NumberFormat('#,##0', 'en_US').format(product.sellPrice)} $currency',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOutOfStock
                        ? Colors.red
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ListGrid extends StatelessWidget {
  final List<Product> products;
  final String currency;
  final ValueChanged<Product> onTap;

  const _ListGrid({
    required this.products,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isOutOfStock = !product.isService && product.stockQuantity <= 0;

        return Card(
          child: ListTile(
            enabled: !isOutOfStock,
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              product.barcode.isNotEmpty
                  ? 'بارکد: ${product.barcode} | موجودی: ${product.stockQuantity}'
                  : 'موجودی: ${product.stockQuantity} ${product.unit}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${NumberFormat('#,##0', 'en_US').format(product.sellPrice)} $currency',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  tooltip: 'افزودن به سبد',
                  onPressed: isOutOfStock ? null : () => onTap(product),
                  icon: const Icon(
                    Icons.add_circle,
                    color: Color(0xFF6750A4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// Cart panel
// ============================================================================

class _CartPanel extends StatelessWidget {
  final MainViewModel vm;
  final String currency;
  final VoidCallback? onCheckout;

  const _CartPanel({
    required this.vm,
    required this.currency,
    this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'سبد خرید',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (vm.cart.isNotEmpty)
                  TextButton(
                    onPressed: vm.clearCart,
                    child: const Text(
                      'خالی کردن',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      vm.selectedCustomer?.name ?? 'مشتری حضوری / عمومی',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: vm.cart.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'سبد خرید خالی است',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: vm.cart.length,
                      itemBuilder: (context, index) {
                        final cartItem = vm.cart[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cartItem.product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${NumberFormat('#,##0', 'en_US').format(cartItem.unitPrice)} $currency',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _showEditCartItemDialog(context, vm, cartItem),
                                      icon: const Icon(Icons.edit_outlined, size: 14),
                                      label: const Text('تعداد / قیمت', style: TextStyle(fontSize: 10)),
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'کاهش یک عدد',
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                onPressed: () => vm.updateCartQuantity(cartItem.product.id, -1),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => _showEditCartItemDialog(context, vm, cartItem),
                                child: Container(
                                  constraints: const BoxConstraints(minWidth: 34),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    cartItem.quantity % 1 == 0 ? cartItem.quantity.toInt().toString() : cartItem.quantity.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'افزایش یک عدد',
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                onPressed: () => vm.updateCartQuantity(cartItem.product.id, 1),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            _TotalRow(
              title: 'جمع کل:',
              value: vm.rawTotal,
              currency: currency,
            ),
            if (vm.discountAmount > 0)
              _TotalRow(
                title: 'تخفیف:',
                value: vm.discountAmount,
                currency: currency,
                valueColor: Colors.red,
                prefix: '-',
              ),
            _TotalRow(
              title: 'قابل پرداخت:',
              value: vm.finalTotal,
              currency: currency,
              isBold: true,
              valueColor: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onCheckout,
                icon: const Icon(Icons.payment),
                label: const Text('تسویه و ثبت فاکتور'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String title;
  final double value;
  final String currency;
  final Color? valueColor;
  final bool isBold;
  final String prefix;

  const _TotalRow({
    required this.title,
    required this.value,
    required this.currency,
    this.valueColor,
    this.isBold = false,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontSize: isBold ? 15 : 13,
      color: valueColor,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(title, style: style),
          const Spacer(),
          Text(
            '$prefix${NumberFormat('#,##0', 'en_US').format(value)} $currency',
            style: style,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Checkout dialog
// ============================================================================

class _CheckoutDialog extends StatefulWidget {
  final MainViewModel vm;
  final String paidInitial;
  final String discountInitial;
  final String methodInitial;

  /// true = عملیات موفق و دیالوگ بسته شود
  final Future<bool> Function(
    double paidAmount,
    double discountAmount,
    String paymentMethod,
  ) onConfirm;

  const _CheckoutDialog({
    required this.vm,
    required this.paidInitial,
    required this.discountInitial,
    required this.methodInitial,
    required this.onConfirm,
  });

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  late final TextEditingController _paidController;
  late final TextEditingController _discountController;

  late String _paymentMethod;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _paidController = TextEditingController(text: widget.paidInitial);
    _discountController = TextEditingController(text: widget.discountInitial);
    _paymentMethod = widget.methodInitial;
  }

  @override
  void dispose() {
    _paidController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double get _rawTotal => widget.vm.rawTotal;

  double get _discountAmount => _parseNumber(_discountController.text);

  double get _paidAmount => _parseNumber(_paidController.text);

  double get _finalAmount {
    return (_rawTotal - _discountAmount).clamp(0, double.infinity).toDouble();
  }

  double get _debtAmount {
    return (_finalAmount - _paidAmount).clamp(0, double.infinity).toDouble();
  }

  static double _parseNumber(String value) {
    final normalized = value
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .replaceAll('،', '')
        .trim();

    return double.tryParse(normalized) ?? 0;
  }

  String _money(double value) {
    return NumberFormat('#,##0', 'en_US').format(value);
  }

  Future<void> _submit() async {
    final discount = _discountAmount;
    final paid = _paidAmount;

    if (discount < 0 || discount > _rawTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('مبلغ تخفیف معتبر نیست.'),
        ),
      );
      return;
    }

    if (paid < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('مبلغ دریافتی معتبر نیست.'),
        ),
      );
      return;
    }

    if (_paymentMethod == 'CREDIT' && widget.vm.selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برای ثبت نسیه / دفتری باید مشتری یا طرف حساب انتخاب شود.')),
      );
      return;
    }

    if (_paymentMethod == 'CREDIT' && paid > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('برای پرداخت نسیه، مبلغ دریافتی را صفر وارد کنید.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final success = await widget.onConfirm(
        paid,
        discount,
        _paymentMethod,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ثبت فاکتور انجام نشد. دوباره تلاش کنید.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.vm.config?.currency ?? 'تومان';

    return AlertDialog(
      title: const Text('تسویه فاکتور فروش'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dialogTotalRow('مبلغ کل کالاها:', _rawTotal, currency),
              const SizedBox(height: 10),
              TextField(
                controller: _discountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'تخفیف ($currency)',
                  prefixIcon: const Icon(Icons.discount_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              _dialogTotalRow(
                'مبلغ نهایی:',
                _finalAmount,
                currency,
                isBold: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _paidController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'مبلغ دریافتی ($currency)',
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              const Text(
                'مشتری / طرف حساب:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<int?>(
                initialValue: widget.vm.selectedCustomer?.id,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline),
                  hintText: 'مشتری حضوری / عمومی',
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('مشتری حضوری / عمومی')),
                  ...widget.vm.allContacts
                      .where((c) => c.type == 'CUSTOMER' || c.type == 'BOTH')
                      .map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                ],
                onChanged: (id) {
                  final customer = id == null ? null : widget.vm.allContacts.firstWhere((c) => c.id == id);
                  widget.vm.setSelectedCustomer(customer);
                  setState(() {});
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'روش پرداخت:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('نقدی'),
                    selected: _paymentMethod == 'CASH',
                    onSelected: (_) {
                      setState(() {
                        _paymentMethod = 'CASH';
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('کارتخوان'),
                    selected: _paymentMethod == 'CARD',
                    onSelected: (_) {
                      setState(() {
                        _paymentMethod = 'CARD';
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('کارت به کارت'),
                    selected: _paymentMethod == 'TRANSFER',
                    onSelected: (_) {
                      setState(() {
                        _paymentMethod = 'TRANSFER';
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('نسیه / دفتری'),
                    selected: _paymentMethod == 'CREDIT',
                    onSelected: (_) {
                      setState(() {
                        _paymentMethod = 'CREDIT';
                        _paidController.text = '0';
                      });
                    },
                  ),
                ],
              ),
              if (_debtAmount > 0) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      'بدهی باقی‌مانده: ${_money(_debtAmount)} $currency\n'
                      'برای ${widget.vm.selectedCustomer?.name ?? 'مشتری عمومی'} ثبت می‌شود.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _submit,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check),
          label: Text(_isSaving ? 'در حال ثبت...' : 'ثبت فروش'),
        ),
      ],
    );
  }

  Widget _dialogTotalRow(
    String title,
    double value,
    String currency, {
    bool isBold = false,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const Spacer(),
        Text(
          '${_money(value)} $currency',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isBold ? 15 : 13,
          ),
        ),
      ],
    );
  }
}
