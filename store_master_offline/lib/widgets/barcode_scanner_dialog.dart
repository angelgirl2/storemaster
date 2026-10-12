// ============================================================================
// BarcodeScannerDialog - دریافت بارکد از اسکنر USB/Bluetooth در حالت HID و ورود دستی
// ============================================================================
import 'package:flutter/material.dart';
import 'dart:io';
import '../models/product.dart';

class BarcodeScannerDialog extends StatefulWidget {
  final List<Product> allProducts;
  final Function(Product) onScanned;
  final Function(String) onCustomSubmit;
  const BarcodeScannerDialog(
      {super.key,
      required this.allProducts,
      required this.onScanned,
      required this.onCustomSubmit});

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  final codeCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode(debugLabel: 'hardware-barcode-input');
  String? statusMessage;
  Product? matchedProduct;
  bool scannerActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => statusMessage = 'آماده اسکن؛ بارکدخوان باید در حالت USB/Bluetooth HID (Keyboard Wedge) باشد و پس از بارکد کلید Enter بفرستد.');
    });
  }

  void _lookup() {
    if (!mounted) return;
    final code = codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => statusMessage = '⚠ بارکدی وارد نشده است');
      return;
    }
    final matches = widget.allProducts.where((p) => p.barcode.trim() == code).toList();
    codeCtrl.clear();
    if (matches.isNotEmpty) {
      setState(() => statusMessage = 'بارکد شناسایی شد: ${matches.first.name}');
      widget.onScanned(matches.first);
    } else {
      setState(() => statusMessage = 'محصولی با این بارکد پیدا نشد؛ کد در جستجو قرار گرفت.');
      widget.onCustomSubmit(code);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    codeCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اسکن بارکد / ثبت بارکد جدید'),
      content: SizedBox(
          width: 500,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (Platform.isAndroid || Platform.isIOS)
                  Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.transparent)),
                      child: Column(children: [
                        const Icon(Icons.qr_code_scanner,
                            size: 56, color: Color(0xFF6750A4)),
                        const SizedBox(height: 8),
                        const Text('ورود بارکد با کیبورد یا اسکنر خارجی',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                            scannerActive
                                ? 'دوربین در این نسخه فعال نیست؛ از اسکنر USB/Bluetooth یا ورود دستی استفاده کنید.'
                                : 'غیرفعال موقت',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11)),
                      ])),
                if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
                  Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0288D1))),
                      child: const Column(children: [
                        Icon(Icons.usb, size: 48, color: Color(0xFF0288D1)),
                        SizedBox(height: 6),
                        Text('ورودی بارکدخوان سخت‌افزاری',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                            'اسکنرهای USB یا Bluetooth که در حالت HID مانند صفحه‌کلید عمل می‌کنند، بارکد را در کادر زیر وارد می‌کنند. دستگاه Serial اختصاصی بدون درایور/پروتکل جداگانه پشتیبانی‌شده نیست.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11)),
                      ])),
                TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                        labelText: 'بارکد را اسکن کنید یا وارد کنید',
                        helperText: 'پس از خواندن بارکد، اسکنر باید Enter بفرستد.',
                        prefixIcon: const Icon(Icons.keyboard_alt)),
                    focusNode: _inputFocus,
                    onSubmitted: (_) => _lookup(),
                    autofocus: true,
                ),
                if (statusMessage != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(statusMessage!,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6750A4)))),
                if (matchedProduct != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('پیشنهاد: ${matchedProduct!.name}',
                          style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                              fontSize: 13))),
              ])),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف')),
        ElevatedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('جستجو / افزودن'),
            onPressed: _lookup),
      ],
    );
  }
}
