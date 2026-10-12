import 'package:flutter/material.dart';
import '../services/backup_manager.dart';
import '../services/store_repository.dart';

class EnterpriseControlScreen extends StatefulWidget {
  const EnterpriseControlScreen({super.key});

  @override
  State<EnterpriseControlScreen> createState() => _EnterpriseControlScreenState();
}

class _EnterpriseControlScreenState extends State<EnterpriseControlScreen> {
  final StoreRepository repo = StoreRepository();
  bool loading = true;
  Map<String, double> balances = {};
  int tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      await repo.ensureAccountingSeed();
      balances = await repo.getCurrentBalances();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const tabs = ['داشبورد مالی', 'عملیات آفلاین', 'انبار و خدمات', 'سفارشات', 'پشتیبان'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('مرکز عملیات تجاری'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: loading
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
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: ChoiceChip(
                          label: Text(tabs[i]),
                          selected: tab == i,
                          onSelected: (_) => setState(() => tab = i),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: _body(tabs[tab]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _body(String title) {
    switch (tab) {
      case 0:
        return _financial(title);
      case 1:
        return _offline(title);
      case 2:
        return _catalog(title);
      case 3:
        return _orders(title);
      default:
        return _backup(title);
    }
  }

  Widget _financial(String title) {
    return ListView(
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...balances.entries.map(
          (e) => Card(
            child: ListTile(
              title: Text(e.key),
              trailing: Text(e.value.toStringAsFixed(0)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _offline(String title) {
    return ListView(
      children: const [
        Card(
          child: ListTile(
            leading: Icon(Icons.cloud_off),
            title: Text('ذخیره‌سازی آفلاین'),
            subtitle: Text(
              'فروش، خرید، انبار، حسابداری، صندوق، بانک، چک، اقساط، حقوق و تنظیمات در SQLite محلی ذخیره می‌شوند.',
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.security),
            title: Text('Audit Log'),
            subtitle: Text('عملیات حساس با کاربر و زمان ثبت می‌شوند.'),
          ),
        ),
      ],
    );
  }

  Widget _catalog(String title) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.getServiceItems(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        return ListView(
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...rows.map(
              (r) => Card(
                child: ListTile(
                  title: Text(r['name']?.toString() ?? ''),
                  subtitle: Text(r['category']?.toString() ?? ''),
                  trailing: Text((r['sellPrice'] ?? 0).toString()),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _orders(String title) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.getSalesOrders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...snapshot.data!.map(
              (r) => Card(
                child: ListTile(
                  title: Text(r['number']?.toString() ?? ''),
                  subtitle: Text(r['customerName']?.toString() ?? ''),
                  trailing: Text(r['status']?.toString() ?? ''),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _backup(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            final file = await BackupManager.createFullDatabaseBackup();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(file == null
                    ? 'پشتیبان ایجاد نشد'
                    : 'پشتیبان ایجاد شد: ${file.path}'),
              ),
            );
          },
          icon: const Icon(Icons.backup),
          label: const Text('Backup کامل دیتابیس'),
        ),
      ],
    );
  }
}
