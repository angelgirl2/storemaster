import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/service_price_catalog.dart';
import '../viewmodels/main_viewmodel.dart';

class ServicePricingScreen extends StatefulWidget {
  const ServicePricingScreen({super.key});

  @override
  State<ServicePricingScreen> createState() => _ServicePricingScreenState();
}

class _ServicePricingScreenState extends State<ServicePricingScreen> {
  String? _selectedBusinessCode;
  String _query = '';
  bool _loading = true;
  bool _dependenciesInitialized = false;
  List<Map<String, dynamic>> _items = const [];
  int _loadGeneration = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesInitialized) return;
    _dependenciesInitialized = true;
    _selectedBusinessCode ??=
        _defaultBusinessCode(context.read<MainViewModel>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  String _defaultBusinessCode(MainViewModel vm) {
    final parts = vm.config?.storeType.split(',') ?? const <String>[];
    final code = parts.isEmpty ? 'GENERAL' : parts.first.trim();
    return ServicePriceCatalog.businesses.any((b) => b['code'] == code)
        ? code
        : 'GENERAL';
  }

  Future<void> _load() async {
    final businessCode = _selectedBusinessCode;
    if (businessCode == null || !mounted) return;

    final generation = ++_loadGeneration;
    setState(() => _loading = true);

    try {
      final items = await context.read<MainViewModel>().getServicePriceCatalog(
            businessCode: businessCode,
          );

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;

      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بارگذاری خدمات: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_query.isEmpty) return _items;
    final q = _query.toLowerCase();
    return _items
        .where((item) => item['name'].toString().toLowerCase().contains(q))
        .toList();
  }

  Future<void> _editPrice(Map<String, dynamic> item) async {
    final controller = TextEditingController(
      text: ((item['sellPrice'] as num?)?.toDouble() ?? 0).toStringAsFixed(0),
    );
    final name = item['name']?.toString() ?? '';
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('قیمت «$name»'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'قیمت فروش خدمت',
              suffixText: 'تومان',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () {
                final normalized = controller.text
                    .replaceAll(',', '')
                    .replaceAll('٬', '')
                    .replaceAll('٫', '.');
                final value = double.tryParse(normalized);
                if (value == null || value < 0) return;
                Navigator.pop(dialogContext, value);
              },
              child: const Text('ذخیره'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (result == null || !mounted || _selectedBusinessCode == null) return;
    try {
      await context.read<MainViewModel>().saveServicePrice(
            id: (item['id'] as num?)?.toInt() ?? 0,
            businessCode: _selectedBusinessCode!,
            name: name,
            sellPrice: result,
            unit: item['unit']?.toString() ?? 'خدمت',
            note: item['note']?.toString() ?? '',
          );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ذخیره قیمت ناموفق بود: $e')),
        );
      }
    }
  }

  Future<void> _addService() async {
    if (_selectedBusinessCode == null) return;
    final nameController = TextEditingController();
    final priceController = TextEditingController(text: '0');
    final unitController = TextEditingController(text: 'خدمت');

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('افزودن خدمت جدید'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'نام خدمت'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'قیمت'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(labelText: 'واحد'),
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
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('افزودن'),
          ),
        ],
      ),
    );

    final name = nameController.text.trim();
    final price =
        double.tryParse(priceController.text.replaceAll(',', '').trim()) ?? 0;
    final unit = unitController.text.trim();
    nameController.dispose();
    priceController.dispose();
    unitController.dispose();

    if (result != true || name.isEmpty || price < 0 || !mounted) return;

    try {
      await context.read<MainViewModel>().saveServicePrice(
            businessCode: _selectedBusinessCode!,
            name: name,
            sellPrice: price,
            unit: unit.isEmpty ? 'خدمت' : unit,
          );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('افزودن خدمت ناموفق بود: $e')),
        );
      }
    }
  }

  Future<void> _seedAllBusinesses() async {
    final vm = context.read<MainViewModel>();
    try {
      for (final business in ServicePriceCatalog.businesses) {
        final code = business['code']!;
        await vm.getServicePriceCatalog(businessCode: code);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'فهرست خدمات همه مشاغل آماده شد. قیمت‌ها قابل ویرایش هستند.')),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('آماده‌سازی فهرست خدمات ناموفق بود: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainViewModel>();
    final currency = vm.config?.currency ?? 'تومان';
    final businessLabel =
        ServicePriceCatalog.labelFor(_selectedBusinessCode ?? 'GENERAL');

    return Scaffold(
      appBar: AppBar(
        title: const Text('فهرست و قیمت خدمات'),
        actions: [
          IconButton(
            tooltip: 'آماده‌سازی خدمات همه مشاغل',
            onPressed: _seedAllBusinesses,
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: vm.isAdmin ? _addService : null,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('افزودن خدمت'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedBusinessCode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'نوع کسب‌وکار',
                  prefixIcon: Icon(Icons.storefront_outlined),
                  border: OutlineInputBorder(),
                ),
                items: ServicePriceCatalog.businesses.map((business) {
                  final code = business['code']!;
                  return DropdownMenuItem<String>(
                    value: code,
                    child: Text(
                      business['label']!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => _selectedBusinessCode = value);
                  await _load();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'جستجوی خدمت',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '$businessLabel — قیمت‌ها به $currency',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredItems.isEmpty
                      ? const Center(
                          child: Text('برای این شغل خدمتی ثبت نشده است.'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                          itemCount: _filteredItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final price =
                                (item['sellPrice'] as num?)?.toDouble() ?? 0;
                            return Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.design_services_outlined),
                                ),
                                title: Text(
                                  item['name']?.toString() ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  'واحد: ${item['unit'] ?? 'خدمت'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: TextButton.icon(
                                  onPressed: vm.isAdmin
                                      ? () => _editPrice(item)
                                      : null,
                                  icon: const Icon(Icons.edit_outlined),
                                  label: Text(
                                    '${price.toStringAsFixed(0)} $currency',
                                  ),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
