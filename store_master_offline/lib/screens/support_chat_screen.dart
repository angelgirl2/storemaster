import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/online_api_service.dart';
import '../services/online_config.dart';
import '../services/online_session_store.dart';
import '../services/license/license_service.dart';
import '../viewmodels/main_viewmodel.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});
  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _subject = TextEditingController();
  final _firstMessage = TextEditingController();
  final _reply = TextEditingController();
  final _scroll = ScrollController();
  final _formKey = GlobalKey<FormState>();
  Timer? _pollTimer;
  List<Map<String, dynamic>> _messages = [];
  String? _ticketCode;
  String? _accessKey;
  String _ticketStatus = 'OPEN';
  int _lastId = 0;
  bool _busy = false;
  bool _polling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedTicket();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _subject.dispose();
    _firstMessage.dispose();
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _canConnect {
    final url = OnlineConfig.instance.baseUrl.trim();
    return OnlineApiService.onlineEnabled && url.isNotEmpty &&
        !url.contains('YOUR-DOMAIN') && !url.contains('localhost:8080');
  }

  Future<void> _loadSavedTicket() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('support_ticket_last_code');
      if (code == null || code.trim().isEmpty) return;
      final key = prefs.getString('support_ticket_access_$code');
      if (key == null || key.isEmpty || !mounted) return;
      setState(() { _ticketCode = code; _accessKey = key; });
      await _pollMessages();
      _startPolling();
    } catch (_) {
      // Support must not block the main app if local preferences are unavailable.
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    if (_ticketCode == null || _accessKey == null || !_canConnect) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollMessages());
  }

  Future<void> _pollMessages() async {
    if (_polling) return;
    final code = _ticketCode;
    final key = _accessKey;
    if (code == null || key == null || !_canConnect) return;
    _polling = true;
    try {
      final response = await OnlineApiService.instance.supportMessages(
        ticketCode: code, accessKey: key, afterId: _lastId);
      if (!mounted) return;
      final items = List<Map<String, dynamic>>.from(response['items'] ?? const []);
      setState(() {
        for (final item in items) {
          final id = (item['id'] as num?)?.toInt() ?? 0;
          if (id > _lastId) {
            _messages.add(item);
            _lastId = id;
          }
        }
        _messages.sort((a, b) => ((a['id'] as num?)?.toInt() ?? 0)
            .compareTo((b['id'] as num?)?.toInt() ?? 0));
        final serverStatus = '${response['status'] ?? _ticketStatus}'.toUpperCase();
        _ticketStatus = serverStatus;
        _error = null;
      });
      if (items.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(_scroll.position.maxScrollExtent,
                duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'اتصال گفت‌وگو موقتاً قطع شده؛ برنامه دوباره تلاش می‌کند.');
    } finally {
      _polling = false;
    }
  }

  Future<void> _createTicket() async {
    if (!_canConnect) {
      setState(() => _error = 'برای گفت‌وگوی زنده، اتصال Railway و Build آنلاین باید فعال باشد. درخواست آفلاین ثبت نمی‌شود مگر آن را در صف درخواست‌های پشتیبانی ذخیره کنید.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _busy = true; _error = null; });
    try {
      final vm = context.read<MainViewModel>();
      final session = await OnlineSessionStore.instance.read();
      final device = await LicenseService.instance.getDeviceId();
      final response = await OnlineApiService.instance.createLiveSupportTicket(
        type: _subject.text.trim().isEmpty ? 'SUPPORT' : _subject.text.trim(),
        storeCode: '${session['storeCode'] ?? ''}',
        licenseId: '${session['licenseId'] ?? ''}',
        username: vm.currentUser?.name ?? '${session['name'] ?? 'کاربر'}',
        deviceId: device,
        contact: '${session['phone'] ?? ''}',
        message: _firstMessage.text.trim(),
      );
      final code = '${response['ticketCode'] ?? ''}';
      final key = '${response['accessKey'] ?? ''}';
      if (code.isEmpty || key.isEmpty) throw StateError('سرور کد دسترسی گفت‌وگو برنگرداند.');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('support_ticket_last_code', code);
      await prefs.setString('support_ticket_access_$code', key);
      await prefs.setString('support_ticket_subject_$code', _subject.text.trim());
      if (!mounted) return;
      setState(() { _ticketCode = code; _accessKey = key; _messages = []; _lastId = 0; _ticketStatus = 'OPEN'; _firstMessage.clear(); });
      await _pollMessages();
      _startPolling();
    } catch (e) {
      if (mounted) setState(() => _error = 'ثبت تیکت ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendReply() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _ticketCode == null || _accessKey == null || _busy) return;
    if (!_canConnect) { setState(() => _error = 'برای ارسال پیام، اتصال اینترنت لازم است.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      await OnlineApiService.instance.sendSupportMessage(
        ticketCode: _ticketCode!, accessKey: _accessKey!, message: text);
      _reply.clear();
      await _pollMessages();
    } catch (e) {
      if (mounted) setState(() => _error = 'پیام ارسال نشد؛ متن را کپی کرده و دوباره تلاش کنید. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newTicket() async {
    _pollTimer?.cancel();
    setState(() { _ticketCode = null; _accessKey = null; _messages = []; _lastId = 0; _subject.clear(); _firstMessage.clear(); _error = null; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('پشتیبانی و گفت‌وگوی زنده'), actions: [
        if (_ticketCode != null) IconButton(tooltip: 'تیکت جدید', onPressed: _busy ? null : _newTicket, icon: const Icon(Icons.add_comment_outlined)),
        IconButton(tooltip: 'به‌روزرسانی پیام‌ها', onPressed: _pollMessages, icon: const Icon(Icons.refresh)),
      ]),
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 950), child: Padding(
        padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!_canConnect) Card(color: theme.colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(12), child: Text(
            'حالت محلی فعال است؛ پیام‌ها تا زمان اتصال اینترنتی و فعال‌سازی Build آنلاین به گفت‌وگوی زنده ارسال نمی‌شوند.',
            style: TextStyle(color: theme.colorScheme.onErrorContainer)))),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
          if (_ticketCode == null) Expanded(child: SingleChildScrollView(child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.support_agent_rounded, size: 54), const SizedBox(height: 8),
            Text('درخواست پشتیبانی جدید', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextFormField(controller: _subject, decoration: const InputDecoration(labelText: 'موضوع درخواست', prefixIcon: Icon(Icons.subject_outlined)), maxLength: 40),
            TextFormField(controller: _firstMessage, minLines: 4, maxLines: 8, maxLength: 5000, decoration: const InputDecoration(labelText: 'شرح مشکل یا درخواست', alignLabelWithHint: true, border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'شرح درخواست را وارد کنید.' : null),
            const SizedBox(height: 12), FilledButton.icon(onPressed: _busy ? null : _createTicket, icon: _busy ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.send), label: Text(_busy ? 'در حال ثبت...' : 'ثبت و شروع گفت‌وگو')),
          ])))))) else ...[
            Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal:14, vertical:10), child: Row(children: [const Icon(Icons.confirmation_number_outlined), const SizedBox(width:8), Expanded(child: Text('کد تیکت: $_ticketCode', style: const TextStyle(fontWeight: FontWeight.bold))), Chip(label: Text(switch (_ticketStatus) { 'CLOSED' => 'بسته', 'WAITING_CUSTOMER' => 'پاسخ پشتیبانی', 'WAITING_ADMIN' => 'در انتظار پشتیبانی', _ => 'باز' }))]))),
            Expanded(child: Container(decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.dividerColor)), child: _messages.isEmpty ? const Center(child: CircularProgressIndicator()) : ListView.builder(controller: _scroll, padding: const EdgeInsets.all(12), itemCount: _messages.length, itemBuilder: (context, i) {
              final msg = _messages[i]; final isAdmin = '${msg['senderRole'] ?? ''}'.toUpperCase() == 'ADMIN';
              final when = DateTime.tryParse('${msg['createdAt'] ?? ''}')?.toLocal();
              return Align(alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight, child: Container(constraints: const BoxConstraints(maxWidth: 650), margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isAdmin ? theme.colorScheme.secondaryContainer : theme.colorScheme.primaryContainer, borderRadius: BorderRadius.only(topLeft: const Radius.circular(14), topRight: const Radius.circular(14), bottomLeft: Radius.circular(isAdmin ? 2 : 14), bottomRight: Radius.circular(isAdmin ? 14 : 2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${msg['senderName'] ?? (isAdmin ? 'پشتیبانی' : 'شما')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 4), SelectableText('${msg['message'] ?? ''}'), if (when != null) Padding(padding: const EdgeInsets.only(top:5), child: Text('${when.year}/${when.month.toString().padLeft(2,'0')}/${when.day.toString().padLeft(2,'0')} ${when.hour.toString().padLeft(2,'0')}:${when.minute.toString().padLeft(2,'0')}', style: theme.textTheme.labelSmall))])));
            })),),
            const SizedBox(height: 10), Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: TextField(controller: _reply, minLines: 1, maxLines: 4, enabled: !_busy && _ticketStatus != 'CLOSED', decoration: const InputDecoration(hintText: 'پیام خود را بنویسید…', border: OutlineInputBorder()))), const SizedBox(width:8), IconButton.filled(onPressed: _busy || _ticketStatus == 'CLOSED' ? null : _sendReply, icon: const Icon(Icons.send_rounded), tooltip: 'ارسال پیام')]),
            const SizedBox(height: 4), Text('پیام‌ها هر ۳ ثانیه به‌روزرسانی می‌شوند. ارسال لینک یا پیامک پولی لازم نیست.', style: theme.textTheme.bodySmall),
          ],
        ]),
      )))),
    );
  }
}
