// backup_manager_fixed.dart
// BackupManager — پشتیبان‌گیری SQL و JSON (نسخه اصلاح‌شده)

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/store_config.dart';
import '../models/user.dart';
import '../models/product.dart';
import '../models/contact.dart';
import '../models/expense.dart';
import '../models/store_transaction.dart';
import '../models/transaction_item.dart';
import '../models/stock_movement.dart';
import '../models/audit_log.dart';

class BackupManager {
  static Future<Directory> _backupDir() async {
    Directory d;
    if (Platform.isWindows) {
      d = Directory(p.join(
          Platform.environment['USERPROFILE'] ?? '.', 'storemaster_backups'));
    } else {
      d = Directory(p.join((await getApplicationDocumentsDirectory()).path,
          'storemaster_backups'));
    }
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static String _escapeSql(String s) => s.replaceAll("'", "''");

  static String _cleanName(String s) {
    // نگه داشتن حروف، اعداد و حروف فارسی و جایگزینی بقیه با underscore، سپس کوتاه‌سازی
    final cleaned = s.replaceAll(RegExp(r'[^a-zA-Z0-9آ-ی_]'), '_');
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }


  static Future<File?> createFullDatabaseBackup() async {
    try {
      final dbPath = await DatabaseHelper.instance.databasePath;
      final src = File(dbPath);
      if (!await src.exists()) return null;
      final dir = await _backupDir();
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('store_config', where:'id = ?', whereArgs:[1], limit:1);
      final store = rows.isNotEmpty ? _cleanName((rows.first['storeName'] as String?) ?? 'فروشگاه') : 'فروشگاه';
      final file = File(p.join(dir.path,'${store}_FULL_${DateTime.now().millisecondsSinceEpoch}.db'));
      await src.copy(file.path);
      return file;
    } catch (_) { return null; }
  }

  static Future<File?> createBackupSql() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final sb = StringBuffer();
      sb.writeln('-- StoreMaster SQL Database Backup Dump');
      sb.writeln('-- Exported At: ${DateTime.now().toIso8601String()}\n');

      final cfgRows = await db.query('store_config',
          where: 'id = ?', whereArgs: [1], limit: 1);
      if (cfgRows.isNotEmpty) {
        final c = StoreConfig.fromMap(cfgRows.first);
        sb.writeln(
            "INSERT OR REPLACE INTO store_config (id, storeName, storeType, colorTheme, currency, taxPercentage, isConfigured, autoBackupEnabled, layoutStyle, lastBackupTimestamp, morningStartHour, morningEndHour, eveningStartHour, eveningEndHour, isDarkMode, storePhone, profitCoefficient, endShiftAlertTime) VALUES (${c.id}, '${_escapeSql(c.storeName)}', '${_escapeSql(c.storeType)}', '${_escapeSql(c.colorTheme)}', '${_escapeSql(c.currency)}', ${c.taxPercentage}, ${c.isConfigured ? 1 : 0}, ${c.autoBackupEnabled ? 1 : 0}, '${_escapeSql(c.layoutStyle)}', ${c.lastBackupTimestamp}, ${c.morningStartHour}, ${c.morningEndHour}, ${c.eveningStartHour}, ${c.eveningEndHour}, ${c.isDarkMode ? 1 : 0}, '${_escapeSql(c.storePhone)}', ${c.profitCoefficient}, '${_escapeSql(c.endShiftAlertTime)}');\n");
      }

      final usersRows = await db.query('users', orderBy: 'role ASC, name ASC');
      final users = usersRows.map((r) => User.fromMap(r)).toList();
      for (final u in users) {
        sb.writeln(
            "INSERT OR REPLACE INTO users (id, name, pin, role, phone, isActive, createdAt) VALUES (${u.id}, '${_escapeSql(u.name)}', '${_escapeSql(u.pin)}', '${_escapeSql(u.role)}', '${_escapeSql(u.phone)}', ${u.isActive ? 1 : 0}, ${u.createdAt});");
      }
      if (users.isNotEmpty) sb.writeln();

      final productsRows = await db.query('products', orderBy: 'name ASC');
      final products = productsRows.map((r) => Product.fromMap(r)).toList();
      for (final p_ in products) {
        sb.writeln(
            "INSERT OR REPLACE INTO products (id, name, barcode, category, buyPrice, sellPrice, stockQuantity, unit, minStockAlert, note, updatedAt) VALUES (${p_.id}, '${_escapeSql(p_.name)}', '${_escapeSql(p_.barcode)}', '${_escapeSql(p_.category)}', ${p_.buyPrice}, ${p_.sellPrice}, ${p_.stockQuantity}, '${_escapeSql(p_.unit)}', ${p_.minStockAlert}, '${_escapeSql(p_.note)}', ${p_.updatedAt});");
      }
      if (products.isNotEmpty) sb.writeln();

      final contactsRows = await db.query('contacts', orderBy: 'name ASC');
      final contacts = contactsRows.map((r) => Contact.fromMap(r)).toList();
      for (final c in contacts) {
        sb.writeln(
            "INSERT OR REPLACE INTO contacts (id, name, phone, address, type, totalDebt, totalPayable, note, updatedAt) VALUES (${c.id}, '${_escapeSql(c.name)}', '${_escapeSql(c.phone)}', '${_escapeSql(c.address)}', '${_escapeSql(c.type)}', ${c.totalDebt}, ${c.totalPayable}, '${_escapeSql(c.note)}', ${c.updatedAt});");
      }
      if (contacts.isNotEmpty) sb.writeln();

      final expensesRows =
          await db.query('expenses', orderBy: 'dateMillis DESC');
      final expenses = expensesRows.map((r) => Expense.fromMap(r)).toList();
      for (final e in expenses) {
        sb.writeln(
            "INSERT OR REPLACE INTO expenses (id, title, amount, category, dateMillis, userId, userName, note) VALUES (${e.id}, '${_escapeSql(e.title)}', ${e.amount}, '${_escapeSql(e.category)}', ${e.dateMillis}, ${e.userId}, '${_escapeSql(e.userName)}', '${_escapeSql(e.note)}');");
      }
      if (expenses.isNotEmpty) sb.writeln();

      final txnsRows =
          await db.query('transactions', orderBy: 'dateMillis DESC');
      final txns = txnsRows.map((r) => StoreTransaction.fromMap(r)).toList();
      for (final t in txns) {
        sb.writeln(
            "INSERT OR REPLACE INTO transactions (id, type, totalAmount, discount, finalAmount, paidAmount, debtAmount, paymentMethod, contactId, contactName, userId, userName, dateMillis, note) VALUES (${t.id}, '${_escapeSql(t.type)}', ${t.totalAmount}, ${t.discount}, ${t.finalAmount}, ${t.paidAmount}, ${t.debtAmount}, '${_escapeSql(t.paymentMethod)}', ${t.contactId ?? "NULL"}, '${_escapeSql(t.contactName)}', ${t.userId}, '${_escapeSql(t.userName)}', ${t.dateMillis}, '${_escapeSql(t.note)}');");
        final itemsRows = await db.query('transaction_items',
            where: 'transactionId = ?', whereArgs: [t.id]);
        final items = itemsRows.map((r) => TransactionItem.fromMap(r)).toList();
        for (final item in items) {
          sb.writeln(
              "INSERT OR REPLACE INTO transaction_items (id, transactionId, productId, productName, quantity, unitPrice, costPrice, totalPrice) VALUES (${item.id}, ${item.transactionId}, ${item.productId}, '${_escapeSql(item.productName)}', ${item.quantity}, ${item.unitPrice}, ${item.costPrice}, ${item.totalPrice});");
        }
      }
      if (txns.isNotEmpty) sb.writeln();

      final movementsRows =
          await db.query('stock_movements', orderBy: 'dateMillis DESC');
      final movements =
          movementsRows.map((r) => StockMovement.fromMap(r)).toList();
      for (final m in movements) {
        sb.writeln(
            "INSERT OR REPLACE INTO stock_movements (id, productId, productName, type, quantity, unit, pricePerUnit, totalPrice, partyName, refNumber, dateMillis, userId, userName, note) VALUES (${m.id}, ${m.productId}, '${_escapeSql(m.productName)}', '${_escapeSql(m.type)}', ${m.quantity}, '${_escapeSql(m.unit)}', ${m.pricePerUnit}, ${m.totalPrice}, '${_escapeSql(m.partyName)}', '${_escapeSql(m.refNumber)}', ${m.dateMillis}, ${m.userId}, '${_escapeSql(m.userName)}', '${_escapeSql(m.note)}');");
      }

      final dir = await _backupDir();
      final storeNameForFile = cfgRows.isNotEmpty
          ? _cleanName(StoreConfig.fromMap(cfgRows.first).storeName)
          : "فروشگاه";
      final fileName =
          '${storeNameForFile}_دیتابیس_${DateTime.now().millisecondsSinceEpoch}.sql';
      final file = File(p.join(dir.path, fileName));
      await file.writeAsString(sb.toString(), encoding: utf8);
      return file;
    } catch (e) {
      // در صورت خطا، null بازگردانده می‌شود؛ می‌توانید لاگ‌گیری اضافه کنید
      return null;
    }
  }

  static Future<File?> createBackupJson() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final root = <String, dynamic>{
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'version': 1,
      };

      final cfgRows = await db.query('store_config',
          where: 'id = ?', whereArgs: [1], limit: 1);
      if (cfgRows.isNotEmpty) {
        final c = StoreConfig.fromMap(cfgRows.first);
        root['config'] = {
          'storeName': c.storeName,
          'storeType': c.storeType,
          'colorTheme': c.colorTheme,
          'currency': c.currency,
          'taxPercentage': c.taxPercentage,
          'layoutStyle': c.layoutStyle,
          'isDarkMode': c.isDarkMode,
          'morningStartHour': c.morningStartHour,
          'morningEndHour': c.morningEndHour,
          'eveningStartHour': c.eveningStartHour,
          'eveningEndHour': c.eveningEndHour,
          'storePhone': c.storePhone,
          'profitCoefficient': c.profitCoefficient,
          'endShiftAlertTime': c.endShiftAlertTime,
          'autoBackupEnabled': c.autoBackupEnabled,
        };
      }

      final usersRows = await db.query('users', orderBy: 'role ASC, name ASC');
      root['users'] = usersRows
          .map((r) => User.fromMap(r))
          .map((u) => {
                'name': u.name,
                'pin': u.pin,
                'role': u.role,
                'phone': u.phone,
              })
          .toList();

      final productsRows = await db.query('products', orderBy: 'name ASC');
      root['products'] = productsRows
          .map((r) => Product.fromMap(r))
          .map((p) => {
                'name': p.name,
                'barcode': p.barcode,
                'category': p.category,
                'buyPrice': p.buyPrice,
                'sellPrice': p.sellPrice,
                'stockQuantity': p.stockQuantity,
                'unit': p.unit,
                'minStockAlert': p.minStockAlert,
                'note': p.note,
              })
          .toList();

      final contactsRows = await db.query('contacts', orderBy: 'name ASC');
      root['contacts'] = contactsRows
          .map((r) => Contact.fromMap(r))
          .map((c) => {
                'name': c.name,
                'phone': c.phone,
                'address': c.address,
                'type': c.type,
                'totalDebt': c.totalDebt,
                'totalPayable': c.totalPayable,
                'note': c.note,
              })
          .toList();

      final expensesRows =
          await db.query('expenses', orderBy: 'dateMillis DESC');
      root['expenses'] = expensesRows
          .map((r) => Expense.fromMap(r))
          .map((e) => {
                'title': e.title,
                'amount': e.amount,
                'category': e.category,
                'dateMillis': e.dateMillis,
                'userId': e.userId,
                'userName': e.userName,
                'note': e.note,
              })
          .toList();

      final txnsRows =
          await db.query('transactions', orderBy: 'dateMillis DESC');
      final txns = txnsRows.map((r) => StoreTransaction.fromMap(r)).toList();
      root['transactions'] = await Future.wait(txns.map((t) async {
        final itemsRows = await db.query('transaction_items',
            where: 'transactionId = ?', whereArgs: [t.id]);
        return {
          'type': t.type,
          'contactName': t.contactName,
          'totalAmount': t.totalAmount,
          'discount': t.discount,
          'finalAmount': t.finalAmount,
          'paidAmount': t.paidAmount,
          'debtAmount': t.debtAmount,
          'paymentMethod': t.paymentMethod,
          'userId': t.userId,
          'userName': t.userName,
          'dateMillis': t.dateMillis,
          'items': itemsRows
              .map((item) => {
                    'productId': item['productId'],
                    'productName': item['productName'],
                    'quantity': item['quantity'],
                    'unitPrice': item['unitPrice'],
                    'costPrice': item['costPrice'],
                    'totalPrice': item['totalPrice'],
                  })
              .toList(),
        };
      }));

      final movementsRows =
          await db.query('stock_movements', orderBy: 'dateMillis DESC');
      root['stockMovements'] = movementsRows
          .map((r) => StockMovement.fromMap(r))
          .map((m) => {
                'productId': m.productId,
                'productName': m.productName,
                'type': m.type,
                'quantity': m.quantity,
                'unit': m.unit,
                'pricePerUnit': m.pricePerUnit,
                'totalPrice': m.totalPrice,
                'partyName': m.partyName,
                'refNumber': m.refNumber,
                'dateMillis': m.dateMillis,
                'userId': m.userId,
                'userName': m.userName,
                'note': m.note,
              })
          .toList();

      final dir = await _backupDir();
      final storeNameForFile = cfgRows.isNotEmpty
          ? _cleanName(StoreConfig.fromMap(cfgRows.first).storeName)
          : "فروشگاه";
      final fileName =
          '${storeNameForFile}_پشتیبان_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(p.join(dir.path, fileName));
      final encoder = const JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(root), encoding: utf8);
      return file;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> restoreFromJson(String jsonContent) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final root = json.decode(jsonContent) as Map<String, dynamic>;

      if (root['config'] != null) {
        final cObj = root['config'] as Map<String, dynamic>;
        final config = StoreConfig(
          id: 1,
          storeName: cObj['storeName'] as String? ?? 'فروشگاه من',
          storeType: cObj['storeType'] as String? ?? 'GENERAL',
          colorTheme: (cObj['colorTheme'] as String?)?.isNotBlank == true
              ? cObj['colorTheme'] as String
              : 'EMERALD',
          currency: cObj['currency'] as String? ?? 'تومان',
          taxPercentage: (cObj['taxPercentage'] as num?)?.toDouble() ?? 0.0,
          isConfigured: true,
          layoutStyle: cObj['layoutStyle'] as String? ?? 'GRID',
          isDarkMode: cObj['isDarkMode'] as bool? ?? false,
          morningStartHour: cObj['morningStartHour'] as int? ?? 6,
          morningEndHour: cObj['morningEndHour'] as int? ?? 15,
          eveningStartHour: cObj['eveningStartHour'] as int? ?? 15,
          eveningEndHour: cObj['eveningEndHour'] as int? ?? 24,
          storePhone: cObj['storePhone'] as String? ?? '',
          profitCoefficient: (cObj['profitCoefficient'] as num?)?.toDouble() ?? 0.22,
          endShiftAlertTime: cObj['endShiftAlertTime'] as String? ?? '21:00',
          autoBackupEnabled: cObj['autoBackupEnabled'] as bool? ?? true,
        );
        await db.insert('store_config', config.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      if (root['products'] != null) {
        for (final p_ in (root['products'] as List)) {
          final pObj = p_ as Map<String, dynamic>;
          final product = Product(
            name: pObj['name'] as String,
            barcode: pObj['barcode'] as String? ?? '',
            category: pObj['category'] as String? ?? 'عمومی',
            buyPrice: (pObj['buyPrice'] as num?)?.toDouble() ?? 0.0,
            sellPrice: (pObj['sellPrice'] as num?)?.toDouble() ?? 0.0,
            stockQuantity: (pObj['stockQuantity'] as num?)?.toDouble() ?? 0.0,
            unit: pObj['unit'] as String? ?? 'عدد',
            minStockAlert: (pObj['minStockAlert'] as num?)?.toDouble() ?? 5.0,
            note: pObj['note'] as String? ?? '',
          );
          await db.insert('products', product.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      if (root['contacts'] != null) {
        for (final c_ in (root['contacts'] as List)) {
          final cObj = c_ as Map<String, dynamic>;
          final c = Contact(
            name: cObj['name'] as String,
            phone: cObj['phone'] as String? ?? '',
            address: cObj['address'] as String? ?? '',
            type: cObj['type'] as String? ?? 'CUSTOMER',
            totalDebt: (cObj['totalDebt'] as num?)?.toDouble() ?? 0.0,
            totalPayable: (cObj['totalPayable'] as num?)?.toDouble() ?? 0.0,
            note: cObj['note'] as String? ?? '',
            notes: '',
          );
          await db.insert('contacts', c.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      if (root['expenses'] != null) {
        for (final e_ in (root['expenses'] as List)) {
          final eObj = e_ as Map<String, dynamic>;
          final e = Expense(
            title: eObj['title'] as String,
            amount: (eObj['amount'] as num?)?.toDouble() ?? 0.0,
            category: eObj['category'] as String? ?? 'سایر',
            dateMillis: (eObj['dateMillis'] as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch,
            userId: (eObj['userId'] as num?)?.toInt() ?? 1,
            userName: eObj['userName'] as String? ?? 'مدیر',
            note: eObj['note'] as String? ?? '',
          );
          await db.insert('expenses', e.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      if (root['transactions'] != null) {
        for (final t_ in (root['transactions'] as List)) {
          final tObj = t_ as Map<String, dynamic>;
          final trans = StoreTransaction(
            type: tObj['type'] as String? ?? 'SALE',
            contactName: tObj['contactName'] as String? ?? 'مشتری عمومی',
            totalAmount: (tObj['totalAmount'] as num?)?.toDouble() ?? 0.0,
            discount: (tObj['discount'] as num?)?.toDouble() ?? 0.0,
            finalAmount: (tObj['finalAmount'] as num?)?.toDouble() ?? 0.0,
            paidAmount: (tObj['paidAmount'] as num?)?.toDouble() ?? 0.0,
            debtAmount: (tObj['debtAmount'] as num?)?.toDouble() ?? 0.0,
            paymentMethod: tObj['paymentMethod'] as String? ?? 'CASH',
            userId: (tObj['userId'] as num?)?.toInt() ?? 1,
            userName: tObj['userName'] as String? ?? 'فروشنده',
            dateMillis: (tObj['dateMillis'] as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch,
          );
          final transId = await db.insert('transactions', trans.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
          final items = (tObj['items'] as List?) ?? [];
          for (final it_ in items) {
            final itObj = it_ as Map<String, dynamic>;
            final qty = (itObj['quantity'] as num?)?.toDouble() ?? 1.0;
            final uPrice = (itObj['unitPrice'] as num?)?.toDouble() ?? 0.0;
            await db.insert(
                'transaction_items',
                TransactionItem(
                  transactionId: transId,
                  productId: (itObj['productId'] as num?)?.toInt() ?? 0,
                  productName: itObj['productName'] as String? ?? '',
                  quantity: qty,
                  unitPrice: uPrice,
                  costPrice: (itObj['costPrice'] as num?)?.toDouble() ?? 0.0,
                  totalPrice:
                      (itObj['totalPrice'] as num?)?.toDouble() ?? qty * uPrice,
                ).toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      if (root['stockMovements'] != null) {
        for (final s_ in (root['stockMovements'] as List)) {
          final sObj = s_ as Map<String, dynamic>;
          final m = StockMovement(
            productId: (sObj['productId'] as num?)?.toInt() ?? 0,
            productName: sObj['productName'] as String? ?? '',
            type: sObj['type'] as String? ?? 'IN',
            quantity: (sObj['quantity'] as num?)?.toDouble() ?? 1.0,
            unit: sObj['unit'] as String? ?? 'عدد',
            pricePerUnit: (sObj['pricePerUnit'] as num?)?.toDouble() ?? 0.0,
            totalPrice: (sObj['totalPrice'] as num?)?.toDouble() ?? 0.0,
            partyName: sObj['partyName'] as String? ?? '',
            refNumber: sObj['refNumber'] as String? ?? '',
            dateMillis: (sObj['dateMillis'] as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch,
            userId: (sObj['userId'] as num?)?.toInt() ?? 1,
            userName: sObj['userName'] as String? ?? 'کاربر',
            note: sObj['note'] as String? ?? '',
          );
          await db.insert('stock_movements', m.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      await db.insert(
          'audit_logs',
          AuditLog(
            userId: 1,
            userName: 'سیستم',
            userRole: 'ADMIN',
            action: 'بازیابی پشتیبان',
            details: 'اطلاعات از فایل پشتیبان جایگذاری شدند',
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      return true;
    } catch (e) {
      return false;
    }
  }
}

extension on String? {
  bool get isNotBlank => (this ?? '').trim().isNotEmpty;
}
