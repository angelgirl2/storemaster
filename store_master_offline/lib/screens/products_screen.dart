// ============================================================================
// ProductsScreen - مدیریت کالا، خدمات و دسته‌بندی‌های سفارشی
// ============================================================================
// فایل اصلاح‌شده برای رفع:
// 1) Undefined name '_editingProduct'
// 2) Undefined name '_unitSuggestions' در دیالوگ افزودن کالا/خدمت
//
// نکته: _unitSuggestions عمداً در سطح فایل قرار گرفته تا هم
// _ProductsScreenState و هم _ProductFormDialogState به آن دسترسی داشته باشند.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/business_profile.dart';
import '../models/product.dart';
import '../services/exporter.dart';
import '../services/store_repository.dart';
import '../viewmodels/main_viewmodel.dart';
import '../widgets/barcode_scanner_dialog.dart';

const List<String> _unitSuggestions = <String>[
  'عدد',
  'کیلوگرم',
  'گرم',
  'متر',
  'سانتی‌متر',
  'لیتر',
  'بسته',
  'کارتن',
  'جفت',
  'ساعت',
  'روز',
  'جلسه',
  'برگ',
  'سرویس',
  'نوبت',
  'سریال',
  'دستگاه',
  'مترمربع',
  'فیلم',
  'فایل',
  'سفر',
];

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final StoreRepository _repo = StoreRepository();
  final TextEditingController _searchCtrl = TextEditingController();

  int _selectedTab = 0;
  String _selectedCategory = '';
  List<ProductCategory> _customCategories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final items = await _repo.getProductCategories();
      if (mounted) setState(() => _customCategories = items);
    } catch (_) {
      // Existing databases may not have migrated yet; keep screen usable.
    }
  }

  Future<void> _addCategory() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('دسته‌بندی جدید'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'نام دسته‌بندی',
                    hintText: 'مثلاً روغن موتور، دارو، طلا و جواهر...',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'توضیحات دسته‌بندی',
                    hintText: 'توضیح، کاربرد یا موارد این دسته...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;

                await _repo.saveProductCategory(
                  ProductCategory(
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                  ),
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('ذخیره دسته'),
            ),
          ],
        ),
      );

      if (result == true && mounted) {
        await _loadCategories();
        setState(() => _selectedCategory = nameCtrl.text.trim());
      }
    } finally {
      nameCtrl.dispose();
      descCtrl.dispose();
    }
  }

  Future<void> _openProductForm(
    MainViewModel vm, {
    Product? product,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductFormDialog(
        vm: vm,
        currency: vm.config?.currency ?? 'تومان',
        existing: product,
        categories: _allCategories(vm),
        onSave: (item) async {
          await vm.saveProduct(item);
        },
      ),
    );

    if (saved == true) {
      await _loadCategories();
      if (mounted) {
        setState(() {});
      }
    }
  }

  List<ProductCategory> _allCategories(MainViewModel vm) {
    final map = <String, ProductCategory>{};

    void add(String name, [String description = '']) {
      final clean = name.trim();
      if (clean.isEmpty) return;

      map.putIfAbsent(
        clean,
        () => ProductCategory(
          name: clean,
          description: description,
        ),
      );
    }

    for (final c in BusinessCatalog.categoriesFor(vm.config?.storeType)) {
      add(c);
    }

    for (final c in BusinessCatalog.servicesFor(vm.config?.storeType)) {
      add(c, 'دسته خدمات آماده بر اساس نوع کسب‌وکار');
    }

    for (final c in _customCategories) {
      add(c.name, c.description);
    }

    for (final p in vm.products) {
      add(p.category);
    }

    return map.values.toList();
  }

  Future<void> _exportExcel(MainViewModel vm) async {
    final currency = vm.config?.currency ?? 'تومان';

    final headers = [
      'شناسه',
      'نوع',
      'بارکد / شناسه',
      'نام',
      'دسته‌بندی',
      'توضیحات',
      'واحد',
      'قیمت خرید ($currency)',
      'قیمت فروش ($currency)',
      'موجودی',
      'حداقل هشدار',
    ];

    final rows = vm.products
        .map(
          (p) => [
            p.id,
            p.isService ? 'خدمت' : 'کالا',
            p.barcode,
            p.name,
            p.category,
            p.note,
            p.unit,
            p.buyPrice,
            p.sellPrice,
            p.isService ? 0 : p.stockQuantity,
            p.isService ? 0 : p.minStockAlert,
          ],
        )
        .toList();

    final file = await Exporter.exportExcel(
      filenamePrefix: 'لیست_کالا_و_خدمات',
      sheetName: 'کالا و خدمات',
      title: 'فهرست کالاها و خدمات',
      headers: headers,
      rows: rows,
      storeName: vm.config?.storeName,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            file == null
                ? 'ساخت فایل Excel ناموفق بود.'
                : 'فایل Excel ساخته شد: ${file.path.split(RegExp(r'[\\/]')).last}',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainViewModel>();
    final all = vm.products;
    final low = vm.lowStockProducts;
    final categories = _allCategories(vm);
    final base = _selectedTab == 1 ? low : all;

    final filtered = base.where((product) {
      final search = _searchCtrl.text.trim();

      return (_selectedCategory.isEmpty ||
              product.category == _selectedCategory) &&
          (search.isEmpty ||
              product.name.contains(search) ||
              product.category.contains(search) ||
              product.barcode.contains(search) ||
              product.note.contains(search));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('انبار و کالاها'),
        actions: [
          IconButton(
            tooltip: 'خروجی Excel',
            onPressed: all.isEmpty ? null : () => _exportExcel(vm),
            icon: const Icon(Icons.table_view_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductForm(vm),
        icon: const Icon(Icons.add),
        label: const Text('افزودن'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'جستجوی کالا، خدمت، بارکد یا توضیحات',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'اسکن بارکد',
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (_) => BarcodeScannerDialog(
                        allProducts: vm.products,
                        onScanned: (product) {
                          Navigator.pop(context);
                          _openProductForm(vm, product: product);
                        },
                        onCustomSubmit: (code) {
                          _searchCtrl.text = code;
                          setState(() {});
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _CategoryStrip(
              categories: categories,
              selected: _selectedCategory,
              onSelected: (value) => setState(() => _selectedCategory = value),
              onAdd: _addCategory,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text('همه (${all.length})'),
                    selected: _selectedTab == 0,
                    onSelected: (_) => setState(() => _selectedTab = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Text('کمبود موجودی (${low.length})'),
                    selected: _selectedTab == 1,
                    onSelected: (_) => setState(() => _selectedTab = 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('موردی برای نمایش وجود ندارد.'),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final product = filtered[index];
                        final isLow = !product.isService &&
                            product.stockQuantity <= product.minStockAlert;

                        final profit = product.sellPrice - product.buyPrice;

                        ProductCategory? category;
                        for (final c in categories) {
                          if (c.name == product.category) {
                            category = c;
                            break;
                          }
                        }

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Chip(
                                      avatar: Icon(
                                        product.isService
                                            ? Icons.design_services_outlined
                                            : Icons.inventory_2_outlined,
                                        size: 16,
                                      ),
                                      label: Text(
                                        product.isService ? 'خدمت' : 'کالا',
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'ویرایش',
                                      onPressed: () => _openProductForm(
                                        vm,
                                        product: product,
                                      ),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف',
                                      onPressed: () async {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('حذف'),
                                            content: Text(
                                              'آیا «${product.name}» حذف شود؟',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('انصراف'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text('حذف'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (ok == true) {
                                          await vm.deleteProduct(
                                            product,
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'دسته‌بندی: ${product.category}',
                                ),
                                if (category != null &&
                                    category.description.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      category.description,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                if (product.note.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Text(
                                      'توضیحات: ${product.note}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 6,
                                  children: [
                                    Text(
                                      'خرید: ${product.buyPrice.toStringAsFixed(0)} ${vm.config?.currency ?? 'تومان'}',
                                    ),
                                    Text(
                                      'فروش: ${product.sellPrice.toStringAsFixed(0)} ${vm.config?.currency ?? 'تومان'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'سود: ${profit.toStringAsFixed(0)} ${vm.config?.currency ?? 'تومان'}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                product.isService
                                    ? Text(
                                        'واحد خدمت: ${product.unit}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : Text(
                                        'موجودی: ${product.stockQuantity} ${product.unit}  |  حداقل هشدار: ${product.minStockAlert}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isLow ? Colors.red : null,
                                        ),
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

class _CategoryStrip extends StatelessWidget {
  final List<ProductCategory> categories;
  final String selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;

  const _CategoryStrip({
    required this.categories,
    required this.selected,
    required this.onSelected,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('دسته'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, index) {
                  if (index == 0) {
                    return ChoiceChip(
                      label: const Text('همه'),
                      selected: selected.isEmpty,
                      onSelected: (_) => onSelected(''),
                    );
                  }

                  final category = categories[index - 1];

                  return Tooltip(
                    message: category.description.trim().isEmpty
                        ? category.name
                        : category.description,
                    child: ChoiceChip(
                      label: Text(category.name),
                      selected: selected == category.name,
                      onSelected: (_) => onSelected(
                        selected == category.name ? '' : category.name,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  final MainViewModel vm;
  final String currency;
  final Product? existing;
  final List<ProductCategory> categories;
  final Future<void> Function(Product product) onSave;

  const _ProductFormDialog({
    required this.vm,
    required this.currency,
    required this.categories,
    required this.onSave,
    this.existing,
  });

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _category;
  late final TextEditingController _categoryDescription;
  late final TextEditingController _unit;
  late final TextEditingController _buy;
  late final TextEditingController _sell;
  late final TextEditingController _stock;
  late final TextEditingController _min;
  late final TextEditingController _note;

  bool _isService = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final p = widget.existing;
    _isService = p?.isService ?? false;

    _name = TextEditingController(text: p?.name ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _category = TextEditingController(
      text: p?.category ??
          (widget.categories.isEmpty ? 'عمومی' : widget.categories.first.name),
    );
    _categoryDescription = TextEditingController();
    _unit = TextEditingController(text: p?.unit ?? 'عدد');
    _buy = TextEditingController(
      text: (p?.buyPrice ?? 0).toStringAsFixed(0),
    );
    _sell = TextEditingController(
      text: (p?.sellPrice ?? 0).toStringAsFixed(0),
    );
    _stock = TextEditingController(
      text: (p?.stockQuantity ?? 0).toString(),
    );
    _min = TextEditingController(
      text: (p?.minStockAlert ?? 5).toString(),
    );
    _note = TextEditingController(text: p?.note ?? '');

    _syncCategoryDescription();
  }

  void _syncCategoryDescription() {
    final found =
        widget.categories.where((c) => c.name == _category.text.trim());

    _categoryDescription.text = found.isEmpty ? '' : found.first.description;
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _category.dispose();
    _categoryDescription.dispose();
    _unit.dispose();
    _buy.dispose();
    _sell.dispose();
    _stock.dispose();
    _min.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'نام کالا/خدمت الزامی است.');
      return;
    }

    if (_category.text.trim().isEmpty) {
      setState(() => _error = 'دسته‌بندی را وارد کنید.');
      return;
    }

    if (_unit.text.trim().isEmpty) {
      setState(() => _error = 'واحد را وارد کنید.');
      return;
    }

    final buy = double.tryParse(_buy.text.replaceAll(',', '')) ?? 0;
    final sell = double.tryParse(_sell.text.replaceAll(',', '')) ?? 0;
    final stock = double.tryParse(_stock.text.replaceAll(',', '')) ?? 0;
    final min = double.tryParse(_min.text.replaceAll(',', '')) ?? 0;

    if (buy < 0 || sell < 0 || stock < 0 || min < 0) {
      setState(() => _error = 'مقادیر منفی قابل قبول نیستند.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await StoreRepository().saveProductCategory(
        ProductCategory(
          name: _category.text.trim(),
          description: _categoryDescription.text.trim(),
        ),
      );

      final product = Product(
        id: widget.existing?.id ?? 0,
        name: _name.text.trim(),
        barcode: _barcode.text.trim(),
        category: _category.text.trim(),
        buyPrice: buy,
        sellPrice: sell,
        stockQuantity: _isService ? 0 : stock,
        unit: _unit.text.trim(),
        isService: _isService,
        minStockAlert: _isService ? 0 : min,
        note: _note.text.trim(),
        updatedAt: widget.existing?.updatedAt,
      );

      await widget.onSave(product);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'افزودن کالا / خدمت' : 'ویرایش کالا / خدمت',
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.inventory_2_outlined),
                    label: Text('کالا'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.design_services_outlined),
                    label: Text('خدمت'),
                  ),
                ],
                selected: {_isService},
                onSelectionChanged: (value) =>
                    setState(() => _isService = value.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: _isService ? 'نام خدمت' : 'نام کالا',
                  hintText: _isService
                      ? 'مثلاً دیاگ، تعویض روغن، چاپ، اجرت تعمیر...'
                      : 'نام کالا',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _barcode,
                decoration: const InputDecoration(
                  labelText: 'بارکد / شناسه (اختیاری)',
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'دسته‌بندی',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 42,
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, index) {
                      final c = widget.categories[index];

                      return ChoiceChip(
                        label: Text(c.name),
                        selected: _category.text == c.name,
                        onSelected: (_) {
                          setState(() {
                            _category.text = c.name;
                            _categoryDescription.text = c.description;
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _category,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'نام دسته‌بندی دلخواه',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _categoryDescription,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'توضیحات دسته‌بندی',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _isService ? 'توضیحات خدمت' : 'توضیحات کالا',
                  hintText: 'توضیحات، ویژگی‌ها، کاربرد و یادداشت...',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _buy,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'قیمت خرید (${widget.currency})',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _sell,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _isService
                            ? 'تعرفه خدمت (${widget.currency})'
                            : 'قیمت فروش (${widget.currency})',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'واحد دلخواه',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _unitSuggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 5),
                    itemBuilder: (_, index) {
                      final unit = _unitSuggestions[index];

                      return ActionChip(
                        label: Text(unit),
                        onPressed: () => setState(() => _unit.text = unit),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _unit,
                decoration: const InputDecoration(
                  labelText: 'واحد کالا/خدمت',
                  hintText: 'هر واحد دلخواه، مثلاً ساعت، برگ، سریال، جلسه...',
                ),
              ),
              const SizedBox(height: 10),
              if (!_isService)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _stock,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'موجودی اولیه',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _min,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'حداقل هشدار موجودی',
                        ),
                      ),
                    ),
                  ],
                ),
              if (_isService)
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'خدمت موجودی انبار ندارد و مقدار آن در انبار صفر باقی می‌ماند.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('انصراف'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('ذخیره'),
        ),
      ],
    );
  }
}
