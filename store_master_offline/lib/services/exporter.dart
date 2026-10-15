// exporter_fixed.dart
// Exporter - PDF / XLSX / CSV / native print / thermal receipt
// ignore_for_file: dead_null_aware_expression

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:printing/printing.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../utils/shamsi_date_utils.dart';

class Exporter {
  /// Opens/selects a generated file locally. Fully offline on Windows.
  static Future<bool> shareFile(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', ['/select,"$filePath"']);
        return true;
      }
      if (Platform.isMacOS) {
        await Process.start('open', [filePath]);
        return true;
      }
      if (Platform.isLinux) {
        await Process.start('xdg-open', [filePath]);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openExportFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      if (Platform.isWindows) {
        // Open the generated file with its registered Windows application.
        // This is more reliable than Explorer's /select syntax for paths
        // containing Persian characters or spaces.
        await Process.start('cmd.exe', ['/c', 'start', '', file.path]);
        return true;
      }
      if (Platform.isMacOS) {
        await Process.start('open', [file.path]);
        return true;
      }
      if (Platform.isLinux) {
        await Process.start('xdg-open', [file.path]);
        return true;
      }
      return false;
    } catch (error) {
      // Opening the file is only a convenience. It must never make a
      // successfully-created export look like a failed export.
      return false;
    }
  }

  static Future<Directory> _exportDir() async {
    Directory d;
    if (Platform.isWindows) {
      d = Directory(p.join(
          Platform.environment['USERPROFILE'] ?? '.', 'storemaster_exports'));
    } else {
      d = Directory(p.join((await getApplicationDocumentsDirectory()).path,
          'storemaster_exports'));
    }
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Receipt PDFs are separated by their payment method.
  /// Windows: Documents\storemaster\<category>
  /// Android: public Downloads\storemaster when the platform exposes it;
  /// otherwise the app's external files area is used to avoid broad storage
  /// permissions on modern Android versions.
  static Future<Directory> _receiptExportDir({
    required String paymentMethod,
    required double debtAmount,
  }) async {
    final method = paymentMethod.trim().toUpperCase();
    final String category;
    switch (method) {
      case 'TRANSFER':
        category = 'کارت به کارت';
        break;
      case 'CREDIT':
        category = 'کارت نسیه';
        break;
      case 'CARD':
        category = 'کارتخوان';
        break;
      case 'CASH':
        category = 'نقدی';
        break;
      case 'MIXED':
        // Keep to the four requested folders; if debt remains, classify it
        // with credit receipts, otherwise put it in the cash folder.
        category = debtAmount > 0.0001 ? 'کارت نسیه' : 'نقدی';
        break;
      default:
        category = debtAmount > 0.0001 ? 'کارت نسیه' : 'نقدی';
    }

    late Directory root;
    if (Platform.isWindows) {
      final documents = await getApplicationDocumentsDirectory();
      root = Directory(p.join(documents.path, 'storemaster'));
    } else if (Platform.isAndroid) {
      Directory? downloads;
      try {
        downloads = await getDownloadsDirectory();
      } catch (_) {
        // Some Android versions/providers do not expose Downloads via the
        // cross-platform path_provider API.
      }
      if (downloads != null) {
        root = Directory(p.join(downloads.path, 'storemaster'));
      } else {
        final external = await getExternalStorageDirectory();
        final base = external ?? await getApplicationDocumentsDirectory();
        root = Directory(p.join(base.path, 'storemaster'));
      }
    } else {
      final documents = await getApplicationDocumentsDirectory();
      root = Directory(p.join(documents.path, 'storemaster'));
    }

    final categoryDir = Directory(p.join(root.path, category));
    if (!await categoryDir.exists()) {
      await categoryDir.create(recursive: true);
    }
    return categoryDir;
  }

  static String _sanitizeFileName(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^a-zA-Z0-9آ-ی\-_\. ]'), '_');
    return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
  }

  static String _escapeCsvCell(String v) {
    var s = v.replaceAll('"', '""');
    if (s.contains(',') || s.contains('\n') || s.contains('"')) {
      s = '"$s"';
    }
    return s;
  }

  /// Generic CSV exporter. Returns created File or null on error.
  static Future<File?> exportToCsv({
    required String filenamePrefix,
    required List<String> headers,
    required List<List<String>> rows,
    String? storeName,
  }) async {
    try {
      final dir = await _exportDir();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final cleanStore = (storeName ?? '').trim();
      final prefix = cleanStore.isNotEmpty
          ? '${_sanitizeFileName(cleanStore)}_$filenamePrefix'
          : filenamePrefix;
      final fileName = '${_sanitizeFileName(prefix)}_$stamp.csv';
      final file = File(p.join(dir.path, fileName));

      final sb = StringBuffer();
      // Add BOM for Excel compatibility with Persian
      sb.write(String.fromCharCodes([0xEF, 0xBB, 0xBF]));
      sb.writeln(headers.map(_escapeCsvCell).join(','));
      for (final row in rows) {
        sb.writeln(row.map((c) => _escapeCsvCell(c)).join(','));
      }
      await file.writeAsString(sb.toString(), encoding: utf8);
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Convenience wrapper used in UI code for expenses CSV
  static Future<File?> exportExpensesCsv({
    required String filenamePrefix,
    required List<String> headers,
    required List<List<String>> rows,
    String? storeName,
  }) =>
      exportToCsv(
          filenamePrefix: filenamePrefix,
          headers: headers,
          rows: rows,
          storeName: storeName);

  /// Convenience wrapper used in UI code for transactions CSV
  static Future<File?> exportTransactionsCsv({
    required String filenamePrefix,
    required List<String> headers,
    required List<List<String>> rows,
    String? storeName,
  }) =>
      exportToCsv(
          filenamePrefix: filenamePrefix,
          headers: headers,
          rows: rows,
          storeName: storeName);

  /// Build debtors HTML (returns HTML string)
  static String buildDebtorsHtml({
    required String storeName,
    required String storePhone,
    required String dateStr,
    required List<List<String>> debtors,
    required double totalDebtSum,
    required String currency,
  }) {
    final nf = NumberFormat('#,##0', 'en_US');
    final rowsSb = StringBuffer();
    var idx = 1;
    for (final d in debtors) {
      final name = d.length > 0 ? d[0] : '';
      final phone = d.length > 1 ? d[1] : '';
      final address = d.length > 2 ? d[2] : '';
      final note = d.length > 3 ? d[3] : '';
      final amount = d.length > 4 ? d[4] : '';
      rowsSb.writeln('''
<tr>
  <td style="text-align:center;">$idx</td>
  <td style="font-weight:bold;">${HtmlEscaper().convert(name)}</td>
  <td style="text-align:center;">${HtmlEscaper().convert(phone)}</td>
  <td>${HtmlEscaper().convert(address)}</td>
  <td>${HtmlEscaper().convert(note)}</td>
  <td style="text-align:left; font-weight:bold; color:#C62828;">${HtmlEscaper().convert(amount)}</td>
</tr>''');
      idx++;
    }

    final html = '''<!DOCTYPE html>
<html dir="rtl" lang="fa">
<head>
<meta charset="UTF-8">
<title>گزارش لیست بدهکاران - ${HtmlEscaper().convert(storeName)}</title>
<style>
  @page { size: A4; margin: 15mm; }
  body { font-family: Tahoma, "Segoe UI", sans-serif; font-size: 12px; color: #222; background: #fff; margin:0; padding:15px; }
  .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #1976D2; padding-bottom: 10px; margin-bottom: 15px; }
  .store-title { font-size: 18px; font-weight: bold; color: #1976D2; }
  .doc-title { font-size: 14px; font-weight: bold; margin-top: 4px; color: #333; }
  .meta-info { font-size: 11px; color: #555; text-align: left; }
  .summary-box { background: #FFF3E0; border: 1px solid #FFE0B2; padding: 10px 15px; border-radius: 6px; margin-bottom: 15px; display: flex; justify-content: space-between; align-items: center; }
  .summary-title { font-size: 12px; color: #E65100; font-weight: bold; }
  .summary-value { font-size: 16px; color: #E65100; font-weight: bold; }
  table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 11px; }
  th { background-color: #f0f4f8; border: 1px solid #ccc; padding: 8px; text-align: center; color: #333; font-weight: bold; }
  td { border: 1px solid #ddd; padding: 7px; vertical-align: middle; }
  tr:nth-child(even) { background-color: #fafafa; }
  .footer { margin-top: 25px; text-align: center; font-size: 10px; color: #777; border-top: 1px solid #eee; padding-top: 10px; }
</style>
</head>
<body>
  <div class="header">
    <div>
      <div class="store-title">${HtmlEscaper().convert(storeName)}</div>
      <div class="doc-title">گزارش جامع مطالبات و بدهکاران</div>
    </div>
    <div class="meta-info">
      <div>تاریخ گزارش: ${HtmlEscaper().convert(dateStr)}</div>
      ${storePhone.isNotEmpty ? '<div>تلفن: ${HtmlEscaper().convert(storePhone)}</div>' : ''}
    </div>
  </div>
  <div class="summary-box">
    <span class="summary-title">مجموع کل مطالبات (طلب فروشگاه از مشتریان):</span>
    <span class="summary-value">${nf.format(totalDebtSum)} $currency</span>
  </div>
  <table>
    <thead>
      <tr>
        <th style="width:5%;">ردیف</th>
        <th style="width:25%;">نام بدهکار</th>
        <th style="width:15%;">شماره تماس</th>
        <th style="width:20%;">آدرس</th>
        <th style="width:15%;">توضیحات</th>
        <th style="width:20%;">مبلغ بدهی / طلب</th>
      </tr>
    </thead>
    <tbody>
      ${rowsSb.toString()}
    </tbody>
  </table>
  <div class="footer">گزارش استخراج شده توسط سیستم مدیریت فروشگاه StoreMaster | تاریخ تولید: ${HtmlEscaper().convert(dateStr)}</div>
</body>
</html>''';
    return html;
  }

  /// Save debtors HTML to file
  static Future<File?> buildDebtorsHtmlFile({
    required String storeName,
    required String storePhone,
    required String dateStr,
    required List<List<String>> debtors,
    required double totalDebtSum,
    required String currency,
  }) async {
    try {
      final html = buildDebtorsHtml(
        storeName: storeName,
        storePhone: storePhone,
        dateStr: dateStr,
        debtors: debtors,
        totalDebtSum: totalDebtSum,
        currency: currency,
      );
      final dir = await _exportDir();
      final file = File(p.join(dir.path,
          '${_sanitizeFileName(storeName)}_لیست_بدهکاران_${DateTime.now().millisecondsSinceEpoch}.html'));
      await file.writeAsString(html, encoding: utf8);
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Thermal receipt HTML builder
  static String buildThermalReceiptHtml({
    required String storeName,
    required String storePhone,
    String businessTitle = 'فروشگاه',
    String logoBase64 = '',
    required int transactionId,
    String invoiceNumber = '',
    required String dateStr,
    required String customerName,
    required String userName,
    required List<List<dynamic>> items,
    required double totalAmount,
    required double discount,
    required double finalAmount,
    required double paidAmount,
    required double debtAmount,
    required String currency,
  }) {
    final nf = NumberFormat('#,##0', 'en_US');
    final invoiceLabel = invoiceNumber.trim().isEmpty ? transactionId.toString() : invoiceNumber.trim();
    final rowsSb = StringBuffer();
    for (final item in items) {
      final name = item.length > 0 ? item[0].toString() : '';
      final qty = (item.length > 1)
          ? (item[1] is num
              ? (item[1] as num).toDouble()
              : double.tryParse(item[1].toString()) ?? 0.0)
          : 0.0;
      final unitPrice = (item.length > 2)
          ? (item[2] is num
              ? (item[2] as num).toDouble()
              : double.tryParse(item[2].toString()) ?? 0.0)
          : 0.0;
      final lineTotal = qty * unitPrice;
      rowsSb.writeln('''
<tr>
  <td style="text-align:right; padding:4px 0;">${HtmlEscaper().convert(name)}</td>
  <td style="text-align:center; padding:4px 0;">${nf.format(qty)}</td>
  <td style="text-align:left; padding:4px 0;">${nf.format(lineTotal)}</td>
</tr>''');
    }

    return '''<!DOCTYPE html>
<html dir="rtl" lang="fa">
<head>
<meta charset="UTF-8">
<style>
  @page { size: 80mm auto; margin: 0; }
  body { width: 78mm; margin: 0 auto; padding: 5mm; font-family: Tahoma, "Segoe UI", sans-serif; font-size: 11px; color: #000; background: #fff; }
  .text-center { text-align: center; }
  .dashed { border-top: 1px dashed #000; margin: 6px 0; }
  .bold { font-weight: bold; }
  table { width: 100%; border-collapse: collapse; font-size: 11px; }
  th { border-bottom: 1px solid #000; padding: 4px 0; text-align: right; }
  .row-flex { display: flex; justify-content: space-between; margin: 3px 0; }
</style>
</head>
<body>
  <div class="text-center bold" style="font-size: 14px;">${HtmlEscaper().convert(storeName)}</div>
  <div class="text-center" style="font-size: 10px; margin-top:2px;">رسید فاکتور فروش حرارتی</div>
  ${storePhone.isNotEmpty ? "<div class='text-center' style='font-size:10px;'>تلفن: ${HtmlEscaper().convert(storePhone)}</div>" : ''}
  <div class="dashed"></div>
  <div class="row-flex"><span>شماره فاکتور: #$invoiceLabel</span><span>${HtmlEscaper().convert(dateStr)}</span></div>
  <div class="row-flex"><span>خریدار: ${HtmlEscaper().convert(customerName.isEmpty ? 'مشتری حضوری' : customerName)}</span><span>صندوق: ${HtmlEscaper().convert(userName)}</span></div>
  <div class="dashed"></div>
  <table>
    <thead>
      <tr>
        <th style="width:50%;">نام کالا</th>
        <th style="width:20%; text-align:center;">تعداد</th>
        <th style="width:30%; text-align:left;">مبلغ ($currency)</th>
      </tr>
    </thead>
    <tbody>${rowsSb.toString()}</tbody>
  </table>
  <div class="dashed"></div>
  <div class="row-flex"><span>جمع کل:</span><span class="bold">${nf.format(totalAmount)} $currency</span></div>
  ${discount > 0 ? "<div class='row-flex'><span>تخفیف:</span><span>${nf.format(discount)} $currency</span></div>" : ''}
  <div class="row-flex bold" style="font-size:12px;"><span>مبلغ نهایی:</span><span>${nf.format(finalAmount)} $currency</span></div>
  <div class="row-flex"><span>پرداختی:</span><span>${nf.format(paidAmount)} $currency</span></div>
  ${debtAmount > 0 ? "<div class='row-flex bold' style='color:red;'><span>مانده نسیه (بدهی):</span><span>${nf.format(debtAmount)} $currency</span></div>" : ''}
  <div class="dashed"></div>
  <div class="text-center bold" style="font-size:10px; margin-top:6px;">با تشکر از اعتماد شما، از خریدتان سپاسگزاریم</div>
  <div class="text-center" style="font-size:9px; margin-top:3px;">${HtmlEscaper().convert(storeName.trim().isEmpty ? 'فروشگاه' : storeName.trim())}</div>
</body>
</html>''';
  }

  /// Invoice HTML builder (detailed)
  static String buildInvoiceHtml({
    required String storeName,
    required String storePhone,
    String businessTitle = 'فروشگاه',
    String logoBase64 = '',
    required int transactionId,
    required String dateStr,
    required String customerName,
    required String userName,
    required List<List<dynamic>> items,
    required double totalAmount,
    required double discount,
    required double finalAmount,
    required double paidAmount,
    required double debtAmount,
    required String currency,
  }) {
    final nf = NumberFormat('#,##0', 'en_US');
    final rowsSb = StringBuffer();
    var idx = 1;
    for (final item in items) {
      final name = item.length > 0 ? item[0].toString() : '';
      final qty = (item.length > 1)
          ? (item[1] is num
              ? (item[1] as num).toDouble()
              : double.tryParse(item[1].toString()) ?? 0.0)
          : 0.0;
      final unitPrice = (item.length > 2)
          ? (item[2] is num
              ? (item[2] as num).toDouble()
              : double.tryParse(item[2].toString()) ?? 0.0)
          : 0.0;
      final lineTotal = qty * unitPrice;
      rowsSb.writeln('''
<tr>
  <td style="border:1px solid #ccc; padding:8px; text-align:center;">$idx</td>
  <td style="border:1px solid #ccc; padding:8px;">${HtmlEscaper().convert(name)}</td>
  <td style="border:1px solid #ccc; padding:8px; text-align:center;">${nf.format(qty)}</td>
  <td style="border:1px solid #ccc; padding:8px; text-align:left;">${nf.format(unitPrice)} $currency</td>
  <td style="border:1px solid #ccc; padding:8px; text-align:left;">${nf.format(lineTotal)} $currency</td>
</tr>''');
      idx++;
    }

    return '''<!DOCTYPE html>
<html dir="rtl" lang="fa">
<head>
<meta charset="UTF-8">
<title>فاکتور فروش #$transactionId</title>
<style>
  body { font-family: Tahoma, 'Segoe UI', sans-serif; padding: 24px; color: #1f2937; background:#f8fafc; direction:rtl; }
  .header { text-align: right; border: 1px solid #dbe4f0; border-right: 5px solid #3949ab; border-radius: 12px; padding: 16px 20px; margin-bottom: 18px; background:linear-gradient(130deg,#fff,#eef2ff); }
  .header h2 { margin:0 0 6px; font-size:22px; color:#1e2a78; } .header p{margin:0;color:#64748b}
  .info { width:100%; margin-bottom: 18px; font-size: 13px; background:#fff; border:1px solid #e2e8f0; border-radius:10px; } .info td{padding:10px 12px}
  table.items { width: 100%; border-collapse: separate; border-spacing:0; margin-bottom: 18px; background:#fff; border:1px solid #dbe4f0; border-radius:10px; overflow:hidden; }
  table.items th { background-color: #303f9f; color:#fff; border:0; padding:11px 9px; text-align: center; }
  table.items td { border-bottom:1px solid #e8edf5; padding:10px 9px; } table.items tbody tr:nth-child(even){background:#f5f7fc} table.items tbody tr:last-child td{border-bottom:0}
  .totals { width: min(360px,100%); margin-right: auto; text-align: right; font-size: 13px; background:#fff; border:1px solid #dbe4f0; border-radius:10px; padding:12px 16px; box-sizing:border-box; }
  .totals div { padding: 6px 0; border-bottom:1px dashed #e2e8f0; } .totals div:last-child{border-bottom:0;font-weight:bold;color:#1e2a78}
  .footer { text-align: center; margin-top: 24px; font-size: 11px; color: #64748b; border-top:1px dashed #cbd5e1; padding-top:12px; }
  @media print { body{background:#fff;padding:0} .header{background:#fff} table.items th{-webkit-print-color-adjust:exact;print-color-adjust:exact} }
</style>
</head>
<body>
  <div class="header">
    <h2>${HtmlEscaper().convert(storeName)}</h2>
    <p>فاکتور فروش رسمی | شماره: #$transactionId</p>
  </div>
  <table class="info" style="width:100%; border:none;">
    <tr>
      <td><strong>خریدار:</strong> ${HtmlEscaper().convert(customerName.isEmpty ? 'مشتری حضوری' : customerName)}</td>
      <td><strong>تاریخ:</strong> ${HtmlEscaper().convert(dateStr)}</td>
    </tr>
    <tr>
      <td><strong>صندوق‌دار:</strong> ${HtmlEscaper().convert(userName)}</td>
      <td><strong>تلفن فروشگاه:</strong> ${HtmlEscaper().convert(storePhone)}</td>
    </tr>
  </table>
  <table class="items">
    <thead>
      <tr><th>ردیف</th><th>کالا / خدمات</th><th>تعداد</th><th>قیمت واحد</th><th>مبلغ کل</th></tr>
    </thead>
    <tbody>${rowsSb.toString()}</tbody>
  </table>
  <div class="totals">
    <div><strong>جمع کل:</strong> ${nf.format(totalAmount)} $currency</div>
    <div><strong>تخفیف:</strong> ${nf.format(discount)} $currency</div>
    <div><strong>مبلغ قابل پرداخت:</strong> ${nf.format(finalAmount)} $currency</div>
    <div><strong>پرداختی:</strong> ${nf.format(paidAmount)} $currency</div>
    ${debtAmount > 0 ? "<div style='color:red;'><strong>باقی‌مانده (بدهی):</strong> ${nf.format(debtAmount)} $currency</div>" : ''}
  </div>
  <div class="footer"><p>با تشکر از اعتماد شما، از خریدتان سپاسگزاریم</p><p>${HtmlEscaper().convert(storeName.trim().isEmpty ? 'فروشگاه' : storeName.trim())}</p></div>
</body>
</html>''';
  }

  /// Stock report HTML builder (used earlier)
  static String buildStockReportHtml({
    required String storeName,
    required String currency,
    required List<Map<String, dynamic>> movements,
  }) {
    final nf = NumberFormat('#,##0', 'en_US');
    final rowsSb = StringBuffer();
    var idx = 1;
    for (final m in movements) {
      final isIn = (m['type'] ?? 'IN') == 'IN';
      final dateMillis = (m['dateMillis'] is int) ? m['dateMillis'] as int : 0;
      final date = dateMillis > 0
          ? DateTime.fromMillisecondsSinceEpoch(dateMillis)
          : DateTime.now();
      rowsSb.writeln('''
<tr>
  <td style="border:1px solid #ddd;padding:6px;text-align:center;">$idx</td>
  <td style="border:1px solid #ddd;padding:6px;">${faDateTime(date)}</td>
  <td style="border:1px solid #ddd;padding:6px;">${isIn ? 'ورودی' : 'خروجی'}</td>
  <td style="border:1px solid #ddd;padding:6px;">${HtmlEscaper().convert(m['productName']?.toString() ?? '')}</td>
  <td style="border:1px solid #ddd;padding:6px;">${nf.format((m['quantity'] ?? 0).toDouble())} ${HtmlEscaper().convert(m['unit']?.toString() ?? '')}</td>
  <td style="border:1px solid #ddd;padding:6px;">${nf.format((m['pricePerUnit'] ?? 0).toDouble())}</td>
  <td style="border:1px solid #ddd;padding:6px;">${nf.format((m['totalPrice'] ?? 0).toDouble())}</td>
  <td style="border:1px solid #ddd;padding:6px;">${HtmlEscaper().convert(m['partyName']?.toString() ?? '')}</td>
  <td style="border:1px solid #ddd;padding:6px;">${HtmlEscaper().convert(m['refNumber']?.toString() ?? '')}</td>
</tr>''');
      idx++;
    }

    return '''<!DOCTYPE html>
<html dir="rtl" lang="fa">
<head><meta charset="UTF-8"><title>گزارش ورود و خروج انبار - ${HtmlEscaper().convert(storeName)}</title>
<style>
  body { font-family: Tahoma,sans-serif; padding: 15px; }
  h1 { color: #1976D2; border-bottom: 2px solid #1976D2; padding-bottom: 8px; }
  table { width: 100%; border-collapse: collapse; font-size: 11px; }
  th { background: #f0f4f8; padding: 8px; border: 1px solid #ccc; }
  td { border: 1px solid #ddd; padding: 6px; }
</style></head>
<body>
  <h1>گزارش ورود و خروج انبار</h1>
  <div>فروشگاه: ${HtmlEscaper().convert(storeName)} | تاریخ: ${faDateTime(DateTime.now())}</div>
  <table>
    <thead><tr><th>ردیف</th><th>تاریخ</th><th>نوع</th><th>کالا</th><th>مقدار</th><th>فی</th><th>جمع</th><th>طرف حساب</th><th>شماره مرجع</th></tr></thead>
    <tbody>${rowsSb.toString()}</tbody>
  </table>
</body></html>''';
  }

  static String buildExpensesReportHtml({
    required String storeName,
    required String currency,
    required List<Map<String, dynamic>> expenses,
    required double total,
  }) {
    final nf = NumberFormat('#,##0', 'en_US');
    final rows = StringBuffer();
    var index = 1;
    for (final expense in expenses) {
      final dateMillis = (expense['dateMillis'] as num?)?.toInt() ?? 0;
      final date = dateMillis > 0
          ? DateTime.fromMillisecondsSinceEpoch(dateMillis)
          : DateTime.now();
      final title = expense['title']?.toString() ?? '';
      final category = expense['category']?.toString() ?? 'سایر';
      final amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
      final userName = expense['userName']?.toString() ?? '';
      final note = expense['note']?.toString() ?? '';
      rows.writeln(
          '''<tr><td style="text-align:center;">$index</td><td>${HtmlEscaper().convert(faDateTime(date))}</td><td>${HtmlEscaper().convert(title)}</td><td>${HtmlEscaper().convert(category)}</td><td style="text-align:left;font-weight:bold;">${nf.format(amount)} $currency</td><td>${HtmlEscaper().convert(userName)}</td><td>${HtmlEscaper().convert(note)}</td></tr>''');
      index++;
    }
    return '''<!DOCTYPE html><html dir="rtl" lang="fa"><head><meta charset="UTF-8"><title>گزارش هزینه‌های فروشگاه</title><style>@page{size:A4;margin:15mm}body{font-family:Tahoma,"Segoe UI",sans-serif;font-size:12px;color:#222;background:#fff;margin:0;padding:15px}.header{display:flex;justify-content:space-between;align-items:center;border-bottom:2px solid #E65100;padding-bottom:10px;margin-bottom:15px}.store{font-size:18px;font-weight:bold;color:#E65100}.title{font-size:14px;font-weight:bold;margin-top:4px}.summary{background:#FFF3E0;border:1px solid #FFE0B2;border-radius:8px;padding:12px 15px;display:flex;justify-content:space-between;margin-bottom:15px}.summary-value{font-size:17px;font-weight:bold;color:#C62828}table{width:100%;border-collapse:collapse;font-size:10.5px}th{background:#f5f5f5;border:1px solid #ccc;padding:7px;text-align:center}td{border:1px solid #ddd;padding:6px;vertical-align:middle}tr:nth-child(even){background:#fafafa}.footer{margin-top:25px;text-align:center;font-size:10px;color:#777}</style></head><body><div class="header"><div><div class="store">${HtmlEscaper().convert(storeName)}</div><div class="title">گزارش هزینه‌های فروشگاه</div></div><div>تاریخ تولید: ${faDateTime(DateTime.now())}</div></div><div class="summary"><span><strong>مجموع هزینه‌ها:</strong></span><span class="summary-value">${nf.format(total)} $currency</span></div><table><thead><tr><th>ردیف</th><th>تاریخ</th><th>عنوان هزینه</th><th>دسته‌بندی</th><th>مبلغ</th><th>ثبت توسط</th><th>توضیحات</th></tr></thead><tbody>${rows.toString()}</tbody></table><div class="footer">گزارش استخراج شده توسط سامانه مدیریت فروشگاه StoreMaster</div></body></html>''';
  }

  static String buildFullReportHtml({
    required String storeName,
    required String startDate,
    required String endDate,
    required String currency,
    required double sales,
    required double profitCoeff,
    required double expenses,
    required double totalDebts,
    required double totalPayables,
    required int lowStock,
    required List<dynamic> transactions,
  }) {
    final nf = NumberFormat('#,##0', 'en_US');
    final grossProfit = sales * profitCoeff;
    final netProfit = grossProfit - expenses;
    final rows = StringBuffer();
    var index = 1;
    for (final raw in transactions) {
      Map<String, dynamic> t;
      if (raw is Map<String, dynamic>) {
        t = raw;
      } else if (raw is Map) {
        t = Map<String, dynamic>.from(raw);
      } else {
        try {
          final mapped = (raw as dynamic).toMap();
          t = Map<String, dynamic>.from(mapped as Map);
        } catch (_) {
          continue;
        }
      }
      final dateMillis = (t['dateMillis'] as num?)?.toInt() ?? 0;
      final date = dateMillis > 0
          ? DateTime.fromMillisecondsSinceEpoch(dateMillis)
          : DateTime.now();
      final id = t['id']?.toString() ?? '';
      final rawCustomer = t['contactName']?.toString() ?? '';
      final customer = rawCustomer.trim().isEmpty ? 'مشتری حضوری' : rawCustomer;
      final amount = (t['finalAmount'] as num?)?.toDouble() ?? 0.0;
      final paid = (t['paidAmount'] as num?)?.toDouble() ?? 0.0;
      final debt = (t['debtAmount'] as num?)?.toDouble() ?? 0.0;
      final userName = t['userName']?.toString() ?? '';
      rows.writeln(
          '''<tr><td>$index</td><td>${HtmlEscaper().convert(id)}</td><td>${HtmlEscaper().convert(faDateTime(date))}</td><td>${HtmlEscaper().convert(customer)}</td><td>${nf.format(amount)} $currency</td><td>${nf.format(paid)} $currency</td><td>${nf.format(debt)} $currency</td><td>${HtmlEscaper().convert(userName)}</td></tr>''');
      index++;
    }
    return '''<!DOCTYPE html><html dir="rtl" lang="fa"><head><meta charset="UTF-8"><title>گزارش جامع فروشگاه</title><style>@page{size:A4;margin:12mm}body{font-family:Tahoma,"Segoe UI",sans-serif;color:#222;margin:0;padding:15px;font-size:11px}h1{margin:0;color:#1976D2;font-size:20px}.header{border-bottom:2px solid #1976D2;padding-bottom:10px;margin-bottom:14px}.muted{color:#666;margin-top:4px}.cards{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:10px}.card{flex:1;min-width:130px;border:1px solid #ddd;border-radius:7px;padding:9px;background:#fafafa}.label{color:#666;font-size:10px}.value{font-size:14px;font-weight:bold;margin-top:4px}.profit{color:#2E7D32}.loss{color:#C62828}table{width:100%;border-collapse:collapse;font-size:9.5px}th{background:#f0f4f8;border:1px solid #ccc;padding:6px}td{border:1px solid #ddd;padding:5px}.footer{margin-top:20px;text-align:center;color:#777;font-size:9px}</style></head><body><div class="header"><h1>${HtmlEscaper().convert(storeName)}</h1><div class="muted">گزارش جامع مدیریتی و مالی | از ${HtmlEscaper().convert(startDate)} تا ${HtmlEscaper().convert(endDate)}</div><div class="muted">تاریخ تولید: ${faDateTime(DateTime.now())}</div></div><div class="cards"><div class="card"><div class="label">فروش کل</div><div class="value">${nf.format(sales)} $currency</div></div><div class="card"><div class="label">هزینه‌ها</div><div class="value loss">${nf.format(expenses)} $currency</div></div><div class="card"><div class="label">سود تخمینی</div><div class="value profit">${nf.format(grossProfit)} $currency</div></div><div class="card"><div class="label">${netProfit >= 0 ? 'سود خالص برآوردی' : 'زیان خالص برآوردی'}</div><div class="value ${netProfit >= 0 ? 'profit' : 'loss'}">${nf.format(netProfit.abs())} $currency</div></div></div><div class="cards"><div class="card"><div class="label">کل طلب‌ها</div><div class="value">${nf.format(totalDebts)} $currency</div></div><div class="card"><div class="label">کل بدهی‌ها</div><div class="value">${nf.format(totalPayables)} $currency</div></div><div class="card"><div class="label">کالاهای کم‌موجودی</div><div class="value">$lowStock</div></div><div class="card"><div class="label">ضریب سود</div><div class="value">${(profitCoeff * 100).toStringAsFixed(0)}٪</div></div></div><h2>فاکتورهای فروش در بازه</h2><table><thead><tr><th>ردیف</th><th>شناسه</th><th>تاریخ</th><th>مشتری</th><th>مبلغ نهایی</th><th>پرداختی</th><th>بدهی</th><th>ثبت توسط</th></tr></thead><tbody>${rows.isEmpty ? '<tr><td colspan="8">فاکتوری ثبت نشده است.</td></tr>' : rows.toString()}</tbody></table><div class="footer">سامانه مدیریت فروشگاه StoreMaster</div></body></html>''';
  }

  // ========================================================================
  // Native PDF / XLSX export
  // ========================================================================

  static Future<Map<String, pw.Font>> _loadPdfFonts() async {
    final candidates = <String>[
      if (Platform.isWindows) ...[
        r'C:\Windows\Fonts\tahoma.ttf',
        r'C:\Windows\Fonts\arial.ttf',
        r'C:\Windows\Fonts\segoeui.ttf',
      ],
      if (Platform.isLinux) ...[
        '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
        '/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf',
      ],
      if (Platform.isMacOS) ...[
        '/System/Library/Fonts/Supplemental/Arial.ttf',
        '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
      ],
      if (Platform.isAndroid) ...[
        '/system/fonts/NotoNaskhArabicUI-Regular.ttf',
        '/system/fonts/NotoNaskhArabic-Regular.ttf',
        '/system/fonts/NotoSansArabicUI-Regular.ttf',
        '/system/fonts/NotoSansArabic-Regular.ttf',
        '/system/fonts/DroidSansArabic.ttf',
        '/system/fonts/DroidSansFallback.ttf',
      ],
    ];
    final boldCandidates = <String>[
      if (Platform.isWindows) ...[
        r'C:\Windows\Fonts\tahomabd.ttf',
        r'C:\Windows\Fonts\arialbd.ttf',
        r'C:\Windows\Fonts\segoeuib.ttf',
      ],
      if (Platform.isLinux) ...[
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
        '/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf',
      ],
      if (Platform.isMacOS) ...[
        '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
      ],
      if (Platform.isAndroid) ...[
        '/system/fonts/NotoNaskhArabicUI-Bold.ttf',
        '/system/fonts/NotoNaskhArabic-Bold.ttf',
        '/system/fonts/NotoSansArabicUI-Bold.ttf',
        '/system/fonts/NotoSansArabic-Bold.ttf',
      ],
    ];

    Future<pw.Font?> loadFirst(List<String> paths) async {
      for (final path in paths) {
        try {
          final f = File(path);
          if (await f.exists()) {
            final bytes = await f.readAsBytes();
            return pw.Font.ttf(bytes.buffer.asByteData());
          }
        } catch (_) {
          // Try the next installed system font if a font cannot be read or
          // parsed on this OS/device.
        }
      }
      return null;
    }

    final regular = await loadFirst(candidates);
    final bold = await loadFirst(boldCandidates);

    return {
      'regular': regular ?? pw.Font.helvetica(),
      'bold': bold ?? regular ?? pw.Font.helveticaBold(),
    };
  }

  static pw.Text _pdfText(
    String text,
    pw.Font font, {
    double size = 9,
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.right,
    PdfColor? color,
  }) {
    return pw.Text(
      text,
      textDirection: pw.TextDirection.rtl,
      textAlign: align,
      style: pw.TextStyle(
        font: font,
        fontSize: size,
        color: color,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    );
  }

  static PdfPageFormat pageFormatForPaper({
    required String paperSize,
    String orientation = 'PORTRAIT',
    double marginMm = 8.0,
    double customWidthMm = 210.0,
    double customHeightMm = 297.0,
  }) {
    PdfPageFormat base;
    switch (paperSize.toUpperCase()) {
      case 'A5':
        base = PdfPageFormat.a5;
        break;
      case 'LETTER':
        base = PdfPageFormat.letter;
        break;
      case 'LEGAL':
        base = PdfPageFormat.legal;
        break;
      case 'B5':
        base = const PdfPageFormat(
          176 * PdfPageFormat.mm,
          250 * PdfPageFormat.mm,
        );
        break;
      case 'R58':
        base = const PdfPageFormat(
          58 * PdfPageFormat.mm,
          220 * PdfPageFormat.mm,
        );
        break;
      case 'R80':
        base = const PdfPageFormat(
          80 * PdfPageFormat.mm,
          260 * PdfPageFormat.mm,
        );
        break;
      case 'CUSTOM':
        base = PdfPageFormat(
          customWidthMm * PdfPageFormat.mm,
          customHeightMm * PdfPageFormat.mm,
        );
        break;
      case 'A4':
      default:
        base = PdfPageFormat.a4;
        break;
    }

    if (orientation.toUpperCase() == 'LANDSCAPE') {
      base = base.landscape;
    }

    final margin = marginMm.clamp(0.0, 30.0) * PdfPageFormat.mm;
    return base.copyWith(
      marginLeft: margin,
      marginRight: margin,
      marginTop: margin,
      marginBottom: margin,
    );
  }

  static Future<bool> printPdfFile(
    File file, {
    String jobName = 'StoreMaster',
  }) async {
    if (!await file.exists()) return false;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return false;

    // Windows: try the actual default printer first. This avoids forcing the
    // user to save the PDF and print it from another application.
    if (Platform.isWindows) {
      try {
        final printers = await Printing.listPrinters();
        final available = printers.where((p) => p.isAvailable).toList();
        if (available.isNotEmpty) {
          final printer = available.firstWhere(
            (p) => p.isDefault,
            orElse: () => available.first,
          );
          return await Printing.directPrintPdf(
            printer: printer,
            name: jobName,
            usePrinterSettings: true,
            onLayout: (_) async => bytes,
          );
        }
      } catch (_) {
        // Fall through to the normal system print dialog.
      }
    }

    try {
      return await Printing.layoutPdf(
        name: jobName,
        usePrinterSettings: true,
        onLayout: (_) async => bytes,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> printPdfBytes(
    Uint8List bytes, {
    String jobName = 'StoreMaster',
  }) async {
    return Printing.layoutPdf(
      name: jobName,
      onLayout: (_) async => bytes,
    );
  }

  static Future<File?> exportTableToPdf({
    required String filenamePrefix,
    required String title,
    required String storeName,
    required List<String> headers,
    required List<List<String>> rows,
    String? subtitle,
    String paperSize = 'A4',
    String orientation = 'PORTRAIT',
    double marginMm = 8.0,
    double customWidthMm = 210.0,
    double customHeightMm = 297.0,
  }) async {
    try {
      final dir = await _exportDir();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(p.join(
        dir.path,
        '${_sanitizeFileName(filenamePrefix)}_$stamp.pdf',
      ));

      final fonts = await _loadPdfFonts();
      final regular = fonts['regular']!;
      final bold = fonts['bold']!;
      final document = pw.Document();

      document.addPage(
        pw.MultiPage(
          pageFormat: pageFormatForPaper(
              paperSize: paperSize,
              orientation: orientation,
              marginMm: marginMm,
              customWidthMm: customWidthMm,
              customHeightMm: customHeightMm),
          margin: pw.EdgeInsets.all(marginMm),
          build: (context) {
            return [
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _pdfText(storeName, bold, size: 18),
                    pw.SizedBox(height: 5),
                    _pdfText(title, bold, size: 13),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      _pdfText(subtitle, regular, size: 9),
                    ],
                    pw.SizedBox(height: 14),
                    pw.Table(
                      border: pw.TableBorder.all(
                        color: PdfColors.grey500,
                        width: 0.5,
                      ),
                      columnWidths: {
                        for (var i = 0; i < headers.length; i++)
                          i: const pw.FlexColumnWidth(),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey200,
                          ),
                          children: headers.map((h) {
                            return pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: _pdfText(
                                h,
                                bold,
                                size: 8,
                                align: pw.TextAlign.center,
                              ),
                            );
                          }).toList(),
                        ),
                        ...rows.map((row) {
                          return pw.TableRow(
                            children: List.generate(headers.length, (i) {
                              final value = i < row.length ? row[i] : '';
                              return pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: _pdfText(
                                  value,
                                  regular,
                                  size: 8,
                                  align: pw.TextAlign.right,
                                ),
                              );
                            }),
                          );
                        }),
                      ],
                    ),
                    pw.SizedBox(height: 16),
                    _pdfText(
                      'تاریخ ایجاد: ${faDateTime(DateTime.now())}',
                      regular,
                      size: 8,
                      color: PdfColors.grey700,
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      await file.writeAsBytes(await document.save(), flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  static Future<File?> exportInvoicePdf({
    required String filenamePrefix,
    required String storeName,
    required String storePhone,
    String businessTitle = 'فروشگاه',
    String logoBase64 = '',
    required int transactionId,
    String invoiceNumber = '',
    required String dateStr,
    required String customerName,
    required String userName,
    required List<List<dynamic>> items,
    required double totalAmount,
    required double discount,
    required double finalAmount,
    required double paidAmount,
    required double debtAmount,
    required String currency,
    String invoiceType = 'SALE',
    String? storeAddress,
    String? storeTaxId,
    String? customerPhone,
    String? customerAddress,
    String? paymentMethod,
    String paperSize = 'A4',
    String orientation = 'PORTRAIT',
    double marginMm = 8.0,
    double customWidthMm = 210.0,
    double customHeightMm = 297.0,
  }) async {
    try {
      final dir = await _exportDir();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(p.join(
        dir.path,
        '${_sanitizeFileName(filenamePrefix)}_$stamp.pdf',
      ));

      final fonts = await _loadPdfFonts();
      final regular = fonts['regular']!;
      final bold = fonts['bold']!;
      final nf = NumberFormat('#,##0', 'en_US');
      final invoiceLabel = invoiceNumber.trim().isEmpty ? transactionId.toString() : invoiceNumber.trim();
      final pdf = pw.Document(
        title: 'فاکتور شماره $invoiceLabel',
        author: storeName.trim().isEmpty ? 'فاکتور فروشگاه' : storeName.trim(),
      );

      final pageFormat = pageFormatForPaper(
        paperSize: paperSize,
        orientation: orientation,
        marginMm: marginMm,
        customWidthMm: customWidthMm,
        customHeightMm: customHeightMm,
      );

      final isPurchase = invoiceType.toUpperCase() == 'PURCHASE';
      final invoiceTitle = isPurchase ? 'فاکتور خرید' : 'فاکتور فروش';
      final accent = isPurchase ? PdfColors.deepOrange : PdfColors.indigo;
      final accentDark =
          isPurchase ? PdfColors.deepOrange800 : PdfColors.indigo800;
      final customerLabel = isPurchase ? 'تأمین‌کننده' : 'خریدار';
      String paymentLabel(String value) {
        switch (value.toUpperCase()) {
          case 'CASH': return 'نقدی';
          case 'CARD': return 'کارتخوان';
          case 'TRANSFER': return 'کارت به کارت';
          case 'CREDIT': return 'نسیه / دفتری';
          case 'MIXED': return 'ترکیبی';
          default: return value.trim().isEmpty ? 'ثبت نشده' : value.trim();
        }
      }
      final statusPaid = debtAmount <= 0.0001;
      final statusText = statusPaid ? 'تسویه شده' : 'دارای مانده';
      final statusColor = statusPaid ? PdfColors.green : PdfColors.orange;

      final rows = items.map((item) {
        final name = item.isNotEmpty ? item[0].toString() : '';
        final qty = item.length > 1
            ? (item[1] is num
                ? (item[1] as num).toDouble()
                : double.tryParse(item[1].toString()) ?? 0.0)
            : 0.0;
        final unit = item.length > 2
            ? (item[2] is num
                ? (item[2] as num).toDouble()
                : double.tryParse(item[2].toString()) ?? 0.0)
            : 0.0;
        final lineTotal = qty * unit;
        return [
          name,
          nf.format(qty),
          '${nf.format(unit)} $currency',
          '${nf.format(lineTotal)} $currency',
        ];
      }).toList();

      final itemCount = rows.length;
      final effectiveCustomer = customerName.trim().isEmpty
          ? (isPurchase ? 'تأمین‌کننده عمومی' : 'مشتری حضوری')
          : customerName.trim();

      pw.Widget infoCard(String label, String value, {double width = 0}) {
        final child = pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(9),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfText(label, regular, size: 7.5, color: PdfColors.grey700),
              pw.SizedBox(height: 3),
              _pdfText(value.trim().isEmpty ? '—' : value, bold, size: 9.5),
            ],
          ),
        );
        return width > 0 ? pw.SizedBox(width: width, child: child) : child;
      }

      final logoImage = logoBase64.trim().isNotEmpty
          ? pw.MemoryImage(base64Decode(logoBase64))
          : null;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          footer: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfText(
                  '${storeName.trim().isEmpty ? 'فروشگاه' : storeName.trim()} • ${invoiceTitle}',
                  regular,
                  size: 7.5,
                  color: PdfColors.grey600,
                ),
                _pdfText(
                  'صفحه ${context.pageNumber} از ${context.pagesCount}',
                  regular,
                  size: 7.5,
                  color: PdfColors.grey600,
                ),
              ],
            ),
          ),
          build: (context) => [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // ----------------------------------------------------------------
                  // Modern header
                  // ----------------------------------------------------------------
                  pw.Container(
                    padding: const pw.EdgeInsets.all(18),
                    decoration: pw.BoxDecoration(
                      gradient: pw.LinearGradient(
                        colors: [accentDark, accent],
                        begin: pw.Alignment.topRight,
                        end: pw.Alignment.bottomLeft,
                      ),
                      borderRadius: pw.BorderRadius.circular(16),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 58,
                          height: 58,
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(14),
                          ),
                          child: logoImage != null
                              ? pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Image(logoImage,
                                      fit: pw.BoxFit.contain),
                                )
                              : _pdfText(
                                  'SM',
                                  bold,
                                  size: 14,
                                  color: accentDark,
                                  align: pw.TextAlign.center,
                                ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _pdfText(
                                storeName,
                                bold,
                                size: 19,
                                color: PdfColors.white,
                              ),
                              if (businessTitle.trim().isNotEmpty)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(top: 2),
                                  child: _pdfText(
                                    businessTitle.trim(),
                                    regular,
                                    size: 9,
                                    color: PdfColors.white,
                                  ),
                                ),
                              if (storePhone.trim().isNotEmpty ||
                                  (storeAddress?.trim().isNotEmpty ??
                                      false)) ...[
                                pw.SizedBox(height: 4),
                                _pdfText(
                                  [
                                    if (storePhone.trim().isNotEmpty)
                                      'تلفن: ${storePhone.trim()}',
                                    if (storeAddress?.trim().isNotEmpty ??
                                        false)
                                      'آدرس: ${storeAddress!.trim()}',
                                  ].join('   •   '),
                                  regular,
                                  size: 8,
                                  color: PdfColors.white,
                                ),
                              ],
                              if (storeTaxId?.trim().isNotEmpty ?? false) ...[
                                pw.SizedBox(height: 2),
                                _pdfText(
                                  'شناسه مالیاتی: ${storeTaxId!.trim()}',
                                  regular,
                                  size: 7.5,
                                  color: PdfColors.white,
                                ),
                              ],
                            ],
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(12),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              _pdfText(
                                invoiceTitle,
                                bold,
                                size: 10.5,
                                color: accentDark,
                                align: pw.TextAlign.center,
                              ),
                              pw.SizedBox(height: 3),
                              _pdfText(
                                '#$invoiceLabel',
                                bold,
                                size: 13,
                                color: PdfColors.black,
                                align: pw.TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  // ----------------------------------------------------------------
                  // Status strip
                  // ----------------------------------------------------------------
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: pw.BoxDecoration(
                      color:
                          statusPaid ? PdfColors.green50 : PdfColors.orange50,
                      borderRadius: pw.BorderRadius.circular(10),
                      border: pw.Border.all(
                        color: statusPaid
                            ? PdfColors.green200
                            : PdfColors.orange200,
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _pdfText(
                          'وضعیت سند: $statusText',
                          bold,
                          size: 9,
                          color: statusColor,
                        ),
                        _pdfText(
                          paymentMethod?.trim().isEmpty ?? true
                              ? 'روش پرداخت: —'
                              : 'روش پرداخت: ${paymentLabel(paymentMethod!)}',
                          regular,
                          size: 8.5,
                          color: PdfColors.grey800,
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  // ----------------------------------------------------------------
                  // Meta cards
                  // ----------------------------------------------------------------
                  pw.Row(
                    children: [
                      pw.Expanded(
                          child: infoCard(customerLabel, effectiveCustomer)),
                      pw.SizedBox(width: 8),
                      pw.Expanded(child: infoCard('تاریخ', dateStr)),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                          child: infoCard('صندوق‌دار / ثبت‌کننده',
                              userName.trim().isEmpty ? 'سیستم' : userName)),
                    ],
                  ),
                  if ((customerPhone ?? '').trim().isNotEmpty ||
                      (customerAddress ?? '').trim().isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        if ((customerPhone ?? '').trim().isNotEmpty)
                          pw.Expanded(
                              child: infoCard('تماس $customerLabel',
                                  customerPhone!.trim())),
                        if ((customerPhone ?? '').trim().isNotEmpty &&
                            (customerAddress ?? '').trim().isNotEmpty)
                          pw.SizedBox(width: 8),
                        if ((customerAddress ?? '').trim().isNotEmpty)
                          pw.Expanded(
                              child: infoCard('آدرس $customerLabel',
                                  customerAddress!.trim())),
                      ],
                    ),
                  ],
                  pw.SizedBox(height: 14),

                  // ----------------------------------------------------------------
                  // Items table
                  // ----------------------------------------------------------------
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(13),
                      border: pw.Border.all(
                        color: PdfColors.grey300,
                        width: 0.7,
                      ),
                    ),
                    child: pw.Table(
                      border: pw.TableBorder.symmetric(
                        inside: pw.BorderSide(
                          color: PdfColors.grey300,
                          width: 0.45,
                        ),
                      ),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(0.7),
                        1: pw.FlexColumnWidth(3.8),
                        2: pw.FlexColumnWidth(1.1),
                        3: pw.FlexColumnWidth(2.1),
                        4: pw.FlexColumnWidth(2.35),
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: accentDark,
                          ),
                          children: [
                            'ردیف',
                            'کالا / خدمت',
                            'تعداد',
                            'قیمت واحد',
                            'مبلغ کل',
                          ].map((h) {
                            return pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: _pdfText(
                                h,
                                bold,
                                size: 8,
                                align: pw.TextAlign.center,
                                color: PdfColors.white,
                              ),
                            );
                          }).toList(),
                        ),
                        ...rows.asMap().entries.map((entry) {
                          final rowIndex = entry.key;
                          final row = entry.value;
                          return pw.TableRow(
                            decoration: pw.BoxDecoration(
                              color: rowIndex.isEven
                                  ? PdfColors.white
                                  : PdfColors.grey50,
                            ),
                            children: [
                              _pdfText('${rowIndex + 1}', regular,
                                  size: 8, align: pw.TextAlign.center),
                              _pdfText(row[0].toString(), regular, size: 8.2),
                              _pdfText(row[1].toString(), regular,
                                  size: 8, align: pw.TextAlign.center),
                              _pdfText(row[2].toString(), regular,
                                  size: 8, align: pw.TextAlign.center),
                              _pdfText(row[3].toString(), bold,
                                  size: 8, align: pw.TextAlign.center),
                            ]
                                .map((w) => pw.Padding(
                                      padding: const pw.EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 8),
                                      child: w,
                                    ))
                                .toList(),
                          );
                        }),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _pdfText(
                    'تعداد اقلام: $itemCount',
                    regular,
                    size: 7.5,
                    color: PdfColors.grey700,
                  ),
                  pw.SizedBox(height: 12),

                  // ----------------------------------------------------------------
                  // Totals and payment card
                  // ----------------------------------------------------------------
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(13),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey50,
                            borderRadius: pw.BorderRadius.circular(12),
                            border: pw.Border.all(
                              color: PdfColors.grey300,
                              width: 0.7,
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            children: [
                              _pdfText(
                                'خلاصه مالی',
                                bold,
                                size: 10,
                                color: accentDark,
                              ),
                              pw.SizedBox(height: 6),
                              _pdfSummaryLine(
                                  'جمع کل',
                                  '${nf.format(totalAmount)} $currency',
                                  regular),
                              _pdfSummaryLine('تخفیف',
                                  '${nf.format(discount)} $currency', regular),
                              _pdfSummaryLine(
                                  'پرداختی',
                                  '${nf.format(paidAmount)} $currency',
                                  regular),
                              pw.Divider(color: PdfColors.grey400),
                              _pdfSummaryLine(
                                'مبلغ نهایی',
                                '${nf.format(finalAmount)} $currency',
                                bold,
                                big: true,
                              ),
                              if (debtAmount > 0) ...[
                                pw.SizedBox(height: 4),
                                _pdfSummaryLine(
                                  'مانده قابل پرداخت',
                                  '${nf.format(debtAmount)} $currency',
                                  bold,
                                  big: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(14),
                          decoration: pw.BoxDecoration(
                            color: statusPaid
                                ? PdfColors.green50
                                : PdfColors.orange50,
                            borderRadius: pw.BorderRadius.circular(12),
                            border: pw.Border.all(
                              color: statusPaid
                                  ? PdfColors.green200
                                  : PdfColors.orange200,
                              width: 0.8,
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            children: [
                              _pdfText(
                                statusPaid ? 'پرداخت کامل' : 'پرداخت ناقص',
                                bold,
                                size: 12,
                                color: statusColor,
                                align: pw.TextAlign.center,
                              ),
                              pw.SizedBox(height: 6),
                              _pdfText(
                                statusPaid
                                    ? 'این فاکتور به‌طور کامل تسویه شده است.'
                                    : 'مبلغ باقیمانده در حساب ${isPurchase ? 'تأمین‌کننده' : 'مشتری'} ثبت شده است.',
                                regular,
                                size: 8.5,
                                color: PdfColors.grey800,
                                align: pw.TextAlign.center,
                              ),
                              pw.SizedBox(height: 10),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  borderRadius: pw.BorderRadius.circular(9),
                                ),
                                child: _pdfText(
                                  '${nf.format(statusPaid ? finalAmount : debtAmount)} $currency',
                                  bold,
                                  size: 15,
                                  color: statusColor,
                                  align: pw.TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),

                  // ----------------------------------------------------------------
                  // Footer branding
                  // ----------------------------------------------------------------
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _pdfText(
                          'با تشکر از اعتماد شما، از خریدتان سپاسگزاریم',
                          bold,
                          size: 8,
                          color: accentDark,
                        ),
                        _pdfText(
                          storeName.trim().isEmpty ? 'فروشگاه' : storeName.trim(),
                          regular,
                          size: 7.5,
                          color: PdfColors.grey700,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _pdfSummaryLine(
    String label,
    String value,
    pw.Font font, {
    bool big = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _pdfText(label, font, size: big ? 10 : 8),
          _pdfText(value, font, size: big ? 11 : 8, bold: big),
        ],
      ),
    );
  }

  static Future<File?> exportThermalReceiptPdf({
    required String storeName,
    required String storePhone,
    String businessTitle = 'فروشگاه',
    String logoBase64 = '',
    required int transactionId,
    String invoiceNumber = '',
    required String dateStr,
    required String customerName,
    required String userName,
    required List<List<dynamic>> items,
    required double totalAmount,
    required double discount,
    required double finalAmount,
    required double paidAmount,
    required double debtAmount,
    required String currency,
    String paymentMethod = '',
    String customerAddress = '',
    String storeAddress = '',
    String taxId = '',
    String invoiceType = 'SALE',
    String paperSize = 'R80',
    String orientation = 'PORTRAIT',
    double marginMm = 3.0,
    double customWidthMm = 80.0,
    double customHeightMm = 220.0,
  }) async {
    try {
      final dir = await _receiptExportDir(
        paymentMethod: paymentMethod,
        debtAmount: debtAmount,
      );
      final invoiceLabel = invoiceNumber.trim().isEmpty
          ? transactionId.toString()
          : invoiceNumber.trim();
      // A stable name keeps one current PDF per transaction. Pressing Print
      // again replaces that receipt instead of creating timestamped duplicates.
      final receiptName = 'رسید_${_sanitizeFileName(invoiceLabel)}_شناسه_$transactionId.pdf';
      final file = File(p.join(dir.path, receiptName));
      final fonts = await _loadPdfFonts();
      final regular = fonts['regular']!;
      final bold = fonts['bold']!;
      final nf = NumberFormat('#,##0', 'en_US');
      final isPurchase = invoiceType.toUpperCase() == 'PURCHASE';
      final documentTitle = isPurchase ? 'رسید خرید' : 'رسید فروش';
      final customerLabel = isPurchase ? 'تأمین‌کننده' : 'مشتری';

      String paymentLabel(String value) {
        switch (value.toUpperCase()) {
          case 'CASH':
            return 'نقدی';
          case 'CARD':
            return 'کارتخوان';
          case 'TRANSFER':
            return 'کارت به کارت';
          case 'CREDIT':
            return 'نسیه / دفتری';
          case 'MIXED':
            return 'ترکیبی';
          default:
            return value.trim().isEmpty ? 'ثبت نشده' : value.trim();
        }
      }

      final pdf = pw.Document(
        title: '$documentTitle $invoiceLabel',
        author: storeName.trim().isEmpty ? 'فاکتور فروشگاه' : storeName.trim(),
      );
      final logo = logoBase64.trim().isNotEmpty
          ? pw.MemoryImage(base64Decode(logoBase64))
          : null;

      pw.Widget line({PdfColor color = PdfColors.grey400, double width = 0.8}) =>
          pw.Container(height: width, color: color, margin: const pw.EdgeInsets.symmetric(vertical: 6));

      pw.Widget metaRow(String label, String value, {bool strong = false}) =>
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _pdfText(
                    value.trim().isEmpty ? '-' : value.trim(),
                    strong ? bold : regular,
                    size: strong ? 8.2 : 7.6,
                    align: pw.TextAlign.left,
                  ),
                ),
                pw.SizedBox(width: 6),
                _pdfText(label, regular, size: 7.6, color: PdfColors.grey700),
              ],
            ),
          );

      pw.Widget totalRow(String label, double value, {bool primary = false}) =>
          pw.Container(
            padding: pw.EdgeInsets.symmetric(vertical: primary ? 5 : 2.5, horizontal: primary ? 5 : 0),
            decoration: primary
                ? pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                  )
                : null,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfText(
                  '${nf.format(value)} $currency',
                  primary ? bold : regular,
                  size: primary ? 10 : 7.8,
                  align: pw.TextAlign.left,
                ),
                _pdfText(label, primary ? bold : regular, size: primary ? 8.4 : 7.8),
              ],
            ),
          );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormatForPaper(
            paperSize: paperSize,
            orientation: orientation,
            marginMm: marginMm,
            customWidthMm: customWidthMm,
            customHeightMm: customHeightMm,
          ),
          build: (context) => [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                      borderRadius: pw.BorderRadius.circular(9),
                    ),
                    child: pw.Column(
                      children: [
                        if (logo != null)
                          pw.Container(
                            width: 42,
                            height: 42,
                            padding: const pw.EdgeInsets.all(3),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Image(logo, fit: pw.BoxFit.contain),
                          ),
                        if (logo != null) pw.SizedBox(height: 3),
                        _pdfText(storeName, bold, size: 12.5, align: pw.TextAlign.center),
                        if (businessTitle.trim().isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: _pdfText(
                              businessTitle.trim(), regular, size: 7.8, align: pw.TextAlign.center,
                            ),
                          ),
                        if (storePhone.trim().isNotEmpty || storeAddress.trim().isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: _pdfText(
                              [
                                if (storePhone.trim().isNotEmpty) 'تلفن: ${storePhone.trim()}',
                                if (storeAddress.trim().isNotEmpty) 'آدرس: ${storeAddress.trim()}',
                              ].join('  |  '),
                              regular, size: 6.7, align: pw.TextAlign.center,
                            ),
                          ),
                        if (taxId.trim().isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: _pdfText('شناسه مالیاتی: ${taxId.trim()}', regular, size: 6.3, align: pw.TextAlign.center),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(7),
                    ),
                    child: pw.Column(
                      children: [
                        _pdfText(documentTitle, bold, size: 9.3, align: pw.TextAlign.center),
                        pw.SizedBox(height: 2),
                        _pdfText('شماره فاکتور: $invoiceLabel', bold, size: 8.2, align: pw.TextAlign.center),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  metaRow('تاریخ و ساعت', dateStr),
                  metaRow(customerLabel, customerName.trim().isEmpty ? (isPurchase ? 'تأمین‌کننده عمومی' : 'مشتری حضوری') : customerName),
                  if (customerAddress.trim().isNotEmpty) metaRow('آدرس', customerAddress),
                  metaRow('صندوق‌دار', userName.trim().isEmpty ? 'فروشنده' : userName),
                  if (paymentMethod.trim().isNotEmpty) metaRow('روش پرداخت', paymentLabel(paymentMethod), strong: true),
                  line(),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: PdfColors.blue100, width: 0.5),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(flex: 5, child: _pdfText('کالا / خدمات', bold, size: 7.1)),
                        pw.Expanded(flex: 2, child: _pdfText('تعداد', bold, size: 7.1, align: pw.TextAlign.center)),
                        pw.Expanded(flex: 3, child: _pdfText('مبلغ', bold, size: 7.1, align: pw.TextAlign.left)),
                      ],
                    ),
                  ),
                  line(color: PdfColors.grey500, width: 0.7),
                  ...items.map((item) {
                    final name = item.isNotEmpty ? item[0].toString() : '';
                    final qty = item.length > 1
                        ? (item[1] is num
                            ? (item[1] as num).toDouble()
                            : double.tryParse(item[1].toString()) ?? 0)
                        : 0.0;
                    final unit = item.length > 2
                        ? (item[2] is num
                            ? (item[2] as num).toDouble()
                            : double.tryParse(item[2].toString()) ?? 0)
                        : 0.0;
                    final lineTotal = qty * unit;
                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.45)),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 5,
                            child: _pdfText(name, regular, size: 7.4),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: _pdfText(nf.format(qty), regular, size: 7.2, align: pw.TextAlign.center),
                          ),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                _pdfText('${nf.format(lineTotal)} $currency', bold, size: 7.2, align: pw.TextAlign.left),
                                if ((qty - 1).abs() > 0.0001)
                                  _pdfText('فی: ${nf.format(unit)}', regular, size: 5.8, color: PdfColors.grey700, align: pw.TextAlign.left),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  pw.SizedBox(height: 5),
                  totalRow('جمع کل', totalAmount),
                  if (discount > 0.0001) totalRow('تخفیف', discount),
                  totalRow('مبلغ نهایی', finalAmount, primary: true),
                  totalRow('پرداختی', paidAmount),
                  if (debtAmount > 0.0001)
                    pw.Container(
                      margin: const pw.EdgeInsets.only(top: 2),
                      padding: const pw.EdgeInsets.all(5),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.red50,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: PdfColors.red200, width: 0.7),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          _pdfText('${nf.format(debtAmount)} $currency', bold, size: 8.8, color: PdfColors.red800, align: pw.TextAlign.left),
                          _pdfText('مانده بدهی', bold, size: 7.8, color: PdfColors.red800),
                        ],
                      ),
                    ),
                  pw.SizedBox(height: 7),
                  line(color: PdfColors.grey500, width: 0.7),
                  _pdfText(
                    'با تشکر از اعتماد شما، از خریدتان سپاسگزاریم',
                    bold,
                    size: 8,
                    align: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 3),
                  _pdfText(
                    storeName.trim().isEmpty ? 'فروشگاه' : storeName.trim(),
                    regular,
                    size: 7,
                    color: PdfColors.grey600,
                    align: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      await file.writeAsBytes(await pdf.save(), flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  static Future<File?> exportExcel({
    required String filenamePrefix,
    required String sheetName,
    required List<String> headers,
    required List<List<dynamic>> rows,
    String? storeName,
    String? title,
  }) async {
    try {
      final dir = await _exportDir();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(p.join(
        dir.path,
        '${_sanitizeFileName(storeName ?? '')}_${_sanitizeFileName(filenamePrefix)}_$stamp.xlsx',
      ));

      final workbook = Excel.createExcel();
      final defaultSheet = workbook.getDefaultSheet();
      if (defaultSheet != null && defaultSheet != sheetName) {
        workbook.rename(defaultSheet, sheetName);
      }
      final sheet = workbook[sheetName];

      if (title != null && title.trim().isNotEmpty) {
        sheet.appendRow([TextCellValue(title)]);
      }
      if (storeName != null && storeName.trim().isNotEmpty) {
        sheet.appendRow([TextCellValue('فروشگاه: $storeName')]);
      }
      sheet.appendRow([
        TextCellValue('تاریخ ایجاد: ${faDateTime(DateTime.now())}'),
      ]);
      sheet.appendRow(headers.map((e) => TextCellValue(e)).toList());

      for (final row in rows) {
        sheet.appendRow(row.map<CellValue>((value) {
          if (value == null) return TextCellValue('');
          if (value is int) return IntCellValue(value);
          if (value is double) return DoubleCellValue(value);
          if (value is num) return DoubleCellValue(value.toDouble());
          return TextCellValue(value.toString());
        }).toList());
      }

      for (var i = 0; i < headers.length; i++) {
        sheet.setColumnAutoFit(i);
        final width = sheet.getColumnWidth(i);
        if (width < 12) sheet.setColumnWidth(i, 12);
        if (width > 38) sheet.setColumnWidth(i, 38);
      }

      final bytes = workbook.save();
      if (bytes == null || bytes.isEmpty) return null;
      await file.writeAsBytes(bytes, flush: true);
      // Opening the workbook is only a convenience. Do not let an OS-level
      // association/Explorer error turn a valid XLSX into a failed export.
      try {
        await openExportFile(file.path);
      } catch (_) {}
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Save HTML content to file (used as "print" substitute)
  static Future<File?> printHtmlReport(
      {required String jobName, required String htmlContent}) async {
    try {
      final dir = await _exportDir();
      final file = File(p.join(dir.path,
          '${_sanitizeFileName(jobName)}_${DateTime.now().millisecondsSinceEpoch}.html'));
      await file.writeAsString(htmlContent, encoding: utf8);
      return file;
    } catch (_) {
      return null;
    }
  }
}

/// Simple HTML escaper for basic safety
class HtmlEscaper {
  const HtmlEscaper();
  String convert(String? s) {
    if (s == null) return '';
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
