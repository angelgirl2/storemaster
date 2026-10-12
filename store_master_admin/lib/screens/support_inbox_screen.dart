import 'dart:async';
import 'package:flutter/material.dart';
import '../services/online_admin_service.dart';

class SupportInboxScreen extends StatefulWidget {
  const SupportInboxScreen({super.key});
  @override
  State<SupportInboxScreen> createState() => _SupportInboxScreenState();
}

class _SupportInboxScreenState extends State<SupportInboxScreen> {
  Timer? _timer;
  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic>? _selected;
  List<Map<String, dynamic>> _messages = [];
  final _reply = TextEditingController();
  int _lastId = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadTickets(silent: true);
      if (_selected != null) _loadMessages(silent: true);
    });
  }
  @override
  void dispose() { _timer?.cancel(); _reply.dispose(); super.dispose(); }

  Future<void> _loadTickets({bool silent = false}) async {
    if (!OnlineAdminService.onlineEnabled) {
      if (!silent && mounted) setState(() => _error = 'این برنامه با STORE_MASTER_ADMIN_ONLINE_ENABLED=true ساخته نشده است.');
      return;
    }
    try {
      final items = await OnlineAdminService.instance.supportTickets();
      if (!mounted) return;
      final selectedCode = _selected?['ticketCode']?.toString();
      setState(() {
        _tickets = items;
        _error = null;
        if (selectedCode != null) {
          final matches = items.where((x) => x['ticketCode']?.toString() == selectedCode);
          if (matches.isEmpty) {
            _selected = null;
            _messages = [];
            _lastId = 0;
          } else {
            _selected = matches.first;
          }
        }
      });
    } catch (e) { if (!silent && mounted) setState(() => _error = 'دریافت تیکت‌ها ناموفق بود: $e'); }
  }

  Future<void> _select(Map<String, dynamic> ticket) async {
    setState(() { _selected = ticket; _messages = []; _lastId = 0; _error = null; });
    await _loadMessages();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    final code = _selected?['ticketCode']?.toString();
    if (code == null || code.isEmpty || !OnlineAdminService.onlineEnabled) return;
    try {
      final rows = await OnlineAdminService.instance.supportTicketMessages(code, afterId: _lastId);
      if (!mounted) return;
      if (rows.isNotEmpty) setState(() {
        for (final row in rows) { final id = (row['id'] as num?)?.toInt() ?? 0; if (id > _lastId) { _messages.add(row); _lastId = id; } }
        _messages.sort((a,b) => ((a['id'] as num?)?.toInt() ?? 0).compareTo((b['id'] as num?)?.toInt() ?? 0));
      });
    } catch (e) { if (!silent && mounted) setState(() => _error = 'دریافت پیام‌ها ناموفق بود: $e'); }
  }

  Future<void> _sendReply() async {
    final ticket = _selected; final message = _reply.text.trim();
    if (ticket == null || message.isEmpty || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await OnlineAdminService.instance.replyToSupportTicket('${ticket['ticketCode']}', message);
      _reply.clear();
      await _loadMessages();
      await _loadTickets(silent: true);
    } catch (e) { if (mounted) setState(() => _error = 'ارسال پاسخ ناموفق بود: $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _setStatus(String status) async {
    final ticket = _selected; if (ticket == null) return;
    try {
      await OnlineAdminService.instance.updateSupportTicketStatus('${ticket['ticketCode']}', status);
      await _loadTickets();
    } catch (e) { if (mounted) setState(() => _error = 'تغییر وضعیت ناموفق بود: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!OnlineAdminService.onlineEnabled) return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Icon(Icons.cloud_off, size: 42), const SizedBox(height: 8), const Text('صندوق پشتیبانی آنلاین غیرفعال است', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6), const Text('برای فعال‌سازی در Build، STORE_MASTER_ADMIN_ONLINE_ENABLED=true و STORE_MASTER_API_URL و STORE_MASTER_ADMIN_KEY را تنظیم کنید.', textAlign: TextAlign.center)])));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: Text('صندوق تیکت‌ها', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))), IconButton(onPressed: _busy ? null : _loadTickets, icon: const Icon(Icons.refresh), tooltip: 'به‌روزرسانی')]),
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
      Text('تیکت‌ها هر ۳ ثانیه به‌روزرسانی می‌شوند. پیام‌ها در PostgreSQL نگهداری می‌شوند.', style: theme.textTheme.bodySmall),
      const SizedBox(height: 10),
      if (_tickets.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('تیکتی ثبت نشده است.')))
      else ..._tickets.take(60).map((ticket) {
        final code = '${ticket['ticketCode'] ?? ''}'; final chosen = _selected?['ticketCode'] == code;
        final status = '${ticket['status'] ?? 'OPEN'}';
        return Card(color: chosen ? theme.colorScheme.secondaryContainer : null, child: ListTile(
          selected: chosen, leading: Icon(status == 'CLOSED' ? Icons.check_circle_outline : Icons.mark_unread_chat_alt_outlined),
          title: Text('$code • ${ticket['username'] ?? 'کاربر'}', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${ticket['type'] ?? 'SUPPORT'} | ${ticket['storeCode'] ?? ''}\n${ticket['message'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Chip(label: Text(status)), onTap: () => _select(ticket)));
      }),
      if (_selected != null) ...[
        const Divider(height: 28),
        Row(children: [Expanded(child: Text('گفت‌وگو: ${_selected!['ticketCode']}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
          PopupMenuButton<String>(tooltip: 'وضعیت تیکت', onSelected: _setStatus, itemBuilder: (_) => const [PopupMenuItem(value:'OPEN',child:Text('باز')),PopupMenuItem(value:'WAITING_ADMIN',child:Text('در انتظار ادمین')),PopupMenuItem(value:'WAITING_CUSTOMER',child:Text('در انتظار مشتری')),PopupMenuItem(value:'CLOSED',child:Text('بستن تیکت'))], child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.more_horiz))) ]),
        if (_messages.isEmpty) const Padding(padding: EdgeInsets.all(10), child: Text('پیامی دریافت نشده یا در حال دریافت است.'))
        else ..._messages.map((m) {
          final admin = '${m['senderRole'] ?? ''}'.toUpperCase() == 'ADMIN';
          return Align(alignment: admin ? Alignment.centerRight : Alignment.centerLeft, child: Container(width: double.infinity, margin: const EdgeInsets.symmetric(vertical: 3), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: admin ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${m['senderName'] ?? (admin ? 'ادمین' : 'مشتری')}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), const SizedBox(height: 4), SelectableText('${m['message'] ?? ''}')] )));
        }),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: TextField(controller: _reply, minLines: 1, maxLines: 4, enabled: !_busy && '${_selected!['status'] ?? ''}' != 'CLOSED', decoration: const InputDecoration(labelText: 'پاسخ به مشتری', border: OutlineInputBorder()))), const SizedBox(width: 8), FilledButton.icon(onPressed: _busy ? null : _sendReply, icon: _busy ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.send), label: const Text('ارسال پاسخ'))]),
      ],
    ]);
  }
}
