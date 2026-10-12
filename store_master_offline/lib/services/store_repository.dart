// ============================================================================
// StoreRepository - ترکیب تمام DAO ها و اکشن‌های تراکنشی
// ============================================================================
import 'package:sqflite/sqflite.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../database/database_helper.dart';
import '../models/store_config.dart';
import '../models/user.dart';
import '../models/product.dart';
import '../models/contact.dart';
import '../models/expense.dart';
import '../models/store_transaction.dart';
import '../models/transaction_item.dart';
import '../models/audit_log.dart';
import '../models/stock_movement.dart';
import '../models/attendance_record.dart';
import '../models/accounting_models.dart';
import '../models/commercial_models.dart';

class StoreRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ===== Config =====
  Future<StoreConfig?> getConfig() async {
    final db = await _db.database;
    final rows = await db.query('store_config', where: 'id = ?', whereArgs: [1], limit: 1);
    if (rows.isEmpty) return null;
    return StoreConfig.fromMap(rows.first);
  }

  Stream<StoreConfig?> get configStream async* {
    yield await getConfig();
  }

  Future<void> updateStoreConfig(StoreConfig c) async {
    final db = await _db.database;
    await db.insert('store_config', c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ===== Users =====
  Future<List<User>> getAllUsers() async {
    final db = await _db.database;
    final rows = await db.query('users', orderBy: 'role ASC, name ASC');
    return rows.map(User.fromMap).toList();
  }

  Future<User?> getUserById(int id) async {
    final db = await _db.database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<User?> getUserByPin(String pin) async {
    final db = await _db.database;
    final rows = await db.query(
      'users',
      where: 'pin = ? AND isActive = 1',
      whereArgs: [pin],
      limit: 1,
    );
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<User?> getUserByPinAndId(String pin, int userId) async {
    final db = await _db.database;
    final rows = await db.query(
      'users',
      where: 'pin = ? AND id = ? AND isActive = 1',
      whereArgs: [pin, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<bool> pinExists(String pin, {int? excludingUserId}) async {
    final db = await _db.database;
    final where = excludingUserId == null
        ? 'pin = ?'
        : 'pin = ? AND id != ?';
    final args = excludingUserId == null ? [pin] : [pin, excludingUserId];
    final rows = await db.query('users', where: where, whereArgs: args, limit: 1);
    return rows.isNotEmpty;
  }

  Future<int> getUserCount() async {
    final db = await _db.database;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM users');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<int> insertUser(User u) async {
    final db = await _db.database;
    return db.insert('users', u.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateUser(User u) async {
    final db = await _db.database;
    await db.insert('users', u.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteUser(User u) async {
    final db = await _db.database;
    await db.delete('users', where: 'id = ?', whereArgs: [u.id]);
  }

  // ===== Product Categories =====
  Future<List<ProductCategory>> getProductCategories() async {
    final db = await _db.database;
    final rows = await db.query('product_categories', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(ProductCategory.fromMap).toList();
  }

  Future<int> saveProductCategory(ProductCategory c) async {
    final db = await _db.database;
    return db.insert('product_categories', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteProductCategory(int id) async {
    final db = await _db.database;
    await db.delete('product_categories', where: 'id = ?', whereArgs: [id]);
  }

  // ===== Products =====
  Future<List<Product>> getAllProducts() async {
    final db = await _db.database;
    final rows = await db.query('products', orderBy: 'name ASC');
    return rows.map(Product.fromMap).toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await _db.database;
    final q = '%${query.trim()}%';
    final rows = await db.rawQuery(
      'SELECT * FROM products WHERE name LIKE ? OR barcode LIKE ? OR category LIKE ? ORDER BY name ASC',
      [q, q, q],
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<List<Product>> getLowStockProducts() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT * FROM products WHERE stockQuantity <= minStockAlert AND minStockAlert >= 0 ORDER BY stockQuantity ASC',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await _db.database;
    final rows = await db.query('products', where: 'barcode = ?', whereArgs: [barcode], limit: 1);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<Product?> getProductById(int id) async {
    final db = await _db.database;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<int> insertProduct(Product p) async {
    final db = await _db.database;
    return db.insert('products', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateProduct(Product p) async {
    final db = await _db.database;
    await db.insert('products', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteProduct(Product p) async {
    final db = await _db.database;
    await db.delete('products', where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> decreaseStock(int productId, double qty) async {
    final db = await _db.database;
    await db.rawUpdate(
        'UPDATE products SET stockQuantity = stockQuantity - ? WHERE id = ?', [qty, productId]);
  }

  Future<void> increaseStock(int productId, double qty) async {
    final db = await _db.database;
    await db.rawUpdate(
        'UPDATE products SET stockQuantity = stockQuantity + ? WHERE id = ?', [qty, productId]);
  }

  Future<void> deleteAllProducts() async {
    final db = await _db.database;
    await db.delete('products');
  }

  // ===== Contacts =====
  Future<List<Contact>> getAllContacts() async {
    final db = await _db.database;
    final rows = await db.query('contacts', orderBy: 'name ASC');
    return rows.map(Contact.fromMap).toList();
  }

  Future<List<Contact>> getDebtors() async {
    final db = await _db.database;
    final rows = await db.query('contacts', where: 'totalDebt > 0', orderBy: 'totalDebt DESC');
    return rows.map(Contact.fromMap).toList();
  }

  Future<List<Contact>> getCreditors() async {
    final db = await _db.database;
    final rows = await db.query('contacts', where: 'totalPayable > 0', orderBy: 'totalPayable DESC');
    return rows.map(Contact.fromMap).toList();
  }

  Future<int> insertContact(Contact c) async {
    final db = await _db.database;
    return db.insert('contacts', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateContact(Contact c) async {
    final db = await _db.database;
    if (c.id == 0) {
      await db.insert('contacts', c.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
      return;
    }
    final count = await db.update('contacts', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    if (count == 0) throw StateError('طرف حساب موردنظر پیدا نشد.');
  }

  Future<void> deleteContact(Contact c) async {
    final db = await _db.database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> addDebt(int contactId, double amount) async {
    final db = await _db.database;
    await db.rawUpdate('UPDATE contacts SET totalDebt = totalDebt + ? WHERE id = ?', [amount, contactId]);
  }

  Future<void> payDebt(int contactId, double amount) async {
    final db = await _db.database;
    await db.rawUpdate(
        'UPDATE contacts SET totalDebt = CASE WHEN (totalDebt - ?) < 0 THEN 0 ELSE (totalDebt - ?) END WHERE id = ?',
        [amount, amount, contactId]);
  }

  Future<void> addPayable(int contactId, double amount) async {
    final db = await _db.database;
    await db.rawUpdate('UPDATE contacts SET totalPayable = totalPayable + ? WHERE id = ?', [amount, contactId]);
  }

  Future<void> payPayable(int contactId, double amount) async {
    final db = await _db.database;
    await db.rawUpdate(
        'UPDATE contacts SET totalPayable = CASE WHEN (totalPayable - ?) < 0 THEN 0 ELSE (totalPayable - ?) END WHERE id = ?',
        [amount, amount, contactId]);
  }

  Future<void> deleteAllContacts() async {
    final db = await _db.database;
    await db.delete('contacts');
  }

  // ===== Expenses =====
  Future<List<Expense>> getAllExpenses() async {
    final db = await _db.database;
    final rows = await db.query('expenses', orderBy: 'dateMillis DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<Expense>> getExpensesByDateRange(int start, int end) async {
    final db = await _db.database;
    final rows = await db.query('expenses',
        where: 'dateMillis >= ? AND dateMillis <= ?',
        whereArgs: [start, end],
        orderBy: 'dateMillis DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future<double> getTotalExpensesByRange(int start, int end) async {
    final db = await _db.database;
    final r = await db.rawQuery(
        'SELECT SUM(amount) as s FROM expenses WHERE dateMillis >= ? AND dateMillis <= ?', [start, end]);
    return (r.first['s'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> insertExpense(Expense e) async {
    await ensureAccountingSeed();
    final db = await _db.database;
    return db.transaction<int>((txn) async {
      final id = await txn.insert('expenses', e.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      final a = await _accountIdsTxn(txn);
      await _insertJournalTxn(txn, sourceType: 'EXPENSE', sourceId: id, description: 'ثبت هزینه ${e.title}', userId: e.userId, userName: e.userName, dateMillis: e.dateMillis, lines: [
        {'accountId': a['5201'] ?? 0, 'accountCode': '5201', 'accountName': 'هزینه‌های عملیاتی', 'debit': e.amount, 'credit': 0.0},
        {'accountId': a['1101'] ?? 0, 'accountCode': '1101', 'accountName': 'صندوق', 'debit': 0.0, 'credit': e.amount},
      ]);
      return id;
    });
  }

  Future<void> deleteExpense(Expense e) async {
    final db = await _db.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> deleteAllExpenses() async {
    final db = await _db.database;
    await db.delete('expenses');
  }

  /// Update an existing expense without changing its primary key.
  /// Falls back to insert only when the incoming expense has no id.
  Future<void> updateExpense(Expense e) async {
    final db = await _db.database;
    if (e.id == 0) {
      await db.insert(
        'expenses',
        e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }

    await db.update(
      'expenses',
      e.toMap(),
      where: 'id = ?',
      whereArgs: [e.id],
    );
  }

  // ===== Transactions =====
  Future<List<StoreTransaction>> getAllTransactions() async {
    final db = await _db.database;
    final rows = await db.query('transactions', orderBy: 'dateMillis DESC');
    return rows.map(StoreTransaction.fromMap).toList();
  }

  Future<List<StoreTransaction>> getTransactionsByDateRange(int start, int end) async {
    final db = await _db.database;
    final rows = await db.query('transactions',
        where: 'dateMillis >= ? AND dateMillis <= ?',
        whereArgs: [start, end],
        orderBy: 'dateMillis DESC');
    return rows.map(StoreTransaction.fromMap).toList();
  }

  Future<List<TransactionItem>> getTransactionItems(int transactionId) async {
    final db = await _db.database;
    final rows = await db.query('transaction_items', where: 'transactionId = ?', whereArgs: [transactionId]);
    return rows.map(TransactionItem.fromMap).toList();
  }

  Future<int> insertTransaction(StoreTransaction t) async {
    final db = await _db.database;
    final id = await db.insert('transactions', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    if (t.invoiceNumber.trim().isEmpty) {
      await db.update('transactions', {'invoiceNumber': id.toString()},
          where: 'id = ?', whereArgs: [id]);
    }
    return id;
  }

  Future<StoreTransaction?> getTransactionById(int id) async {
    final db = await _db.database;
    final rows = await db.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : StoreTransaction.fromMap(rows.first);
  }

  Future<String> getAvailableInvoiceNumber({String preferred = ''}) async {
    final db = await _db.database;
    final candidate = preferred.trim();
    if (candidate.isNotEmpty) {
      final rows = await db.query('transactions', columns: ['id'], where: 'invoiceNumber = ?', whereArgs: [candidate], limit: 1);
      if (rows.isEmpty) return candidate;
      throw ArgumentError('شماره فاکتور «$candidate» قبلاً ثبت شده است.');
    }
    final max = Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COALESCE(MAX(CAST(invoiceNumber AS INTEGER)), 0) FROM transactions WHERE invoiceNumber GLOB '[0-9]*'",
        )) ?? 0;
    var next = max + 1;
    while (true) {
      final value = next.toString();
      final rows = await db.query('transactions', columns: ['id'], where: 'invoiceNumber = ?', whereArgs: [value], limit: 1);
      if (rows.isEmpty) return value;
      next++;
    }
  }

  Future<void> insertTransactionItems(List<TransactionItem> items) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final it in items) {
      batch.insert('transaction_items', it.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteTransaction(StoreTransaction t) async {
    final db = await _db.database;
    await db.delete('transaction_items', where: 'transactionId = ?', whereArgs: [t.id]);
    await db.delete('transactions', where: 'id = ?', whereArgs: [t.id]);
  }


  Future<void> deleteInvoice(StoreTransaction t) async {
    final db = await _db.database;
    await ensureAccountingSeed();
    await db.transaction((txn) async {
      final items = await txn.query('transaction_items',
          where: 'transactionId = ?', whereArgs: [t.id]);
      for (final raw in items) {
        final productId = (raw['productId'] as num?)?.toInt() ?? 0;
        final qty = (raw['quantity'] as num?)?.toDouble() ?? 0;
        if (productId <= 0 || qty == 0) continue;
        final productRows = await txn.query('products',
            columns: ['isService'], where: 'id = ?', whereArgs: [productId], limit: 1);
        final isService = productRows.isNotEmpty &&
            (productRows.first['isService'] as num?)?.toInt() == 1;
        if (isService) continue;
        if (t.type == 'SALE') {
          await txn.rawUpdate(
              'UPDATE products SET stockQuantity = stockQuantity + ? WHERE id = ?',
              [qty, productId]);
        } else if (t.type == 'PURCHASE') {
          await txn.rawUpdate(
              'UPDATE products SET stockQuantity = CASE WHEN stockQuantity - ? < 0 THEN 0 ELSE stockQuantity - ? END WHERE id = ?',
              [qty, qty, productId]);
        }
      }

      if (t.contactId != null && t.contactId! > 0) {
        if (t.type == 'SALE' && t.debtAmount > 0) {
          await txn.rawUpdate(
            'UPDATE contacts SET totalDebt = CASE WHEN totalDebt - ? < 0 THEN 0 ELSE totalDebt - ? END WHERE id = ?',
            [t.debtAmount, t.debtAmount, t.contactId],
          );
        } else if (t.type == 'PURCHASE' && t.debtAmount > 0) {
          await txn.rawUpdate(
            'UPDATE contacts SET totalPayable = CASE WHEN totalPayable - ? < 0 THEN 0 ELSE totalPayable - ? END WHERE id = ?',
            [t.debtAmount, t.debtAmount, t.contactId],
          );
        }
      }

      await txn.delete('installments', where: 'transactionId = ?', whereArgs: [t.id]);
      await txn.delete('invoice_payments', where: 'transactionId = ?', whereArgs: [t.id]);
      await txn.delete('stock_movements', where: 'refNumber = ?', whereArgs: ['#${t.id}']);

      final journalRows = await txn.query('journal_entries', columns: ['id'],
          where: 'sourceId = ? AND sourceType IN (?, ?)',
          whereArgs: [t.id, 'SALE', 'PURCHASE']);
      for (final row in journalRows) {
        final jid = (row['id'] as num?)?.toInt();
        if (jid != null) {
          await txn.delete('journal_lines', where: 'journalId = ?', whereArgs: [jid]);
          await txn.delete('journal_entries', where: 'id = ?', whereArgs: [jid]);
        }
      }

      await txn.delete('transaction_items', where: 'transactionId = ?', whereArgs: [t.id]);
      await txn.delete('transactions', where: 'id = ?', whereArgs: [t.id]);
      await txn.insert('audit_logs', AuditLog(
        userId: t.userId,
        userName: t.userName,
        userRole: '',
        action: 'حذف فاکتور',
        details: 'فاکتور ${t.invoiceNumber.isEmpty ? '#${t.id}' : 'شماره ${t.invoiceNumber}'} حذف و آثار مالی/موجودی آن برگشت داده شد',
      ).toMap());
    });
  }

  Future<int> replaceInvoice({
    required StoreTransaction oldTransaction,
    required StoreTransaction updatedTransaction,
    required List<TransactionItem> items,
  }) async {
    if (oldTransaction.type != 'SALE' && oldTransaction.type != 'PURCHASE') {
      throw ArgumentError('فقط فاکتور فروش یا خرید قابل ویرایش است.');
    }
    if (updatedTransaction.type != oldTransaction.type) {
      throw ArgumentError('نوع فاکتور در ویرایش قابل تغییر نیست.');
    }
    if (items.isEmpty) throw ArgumentError('فاکتور باید حداقل یک قلم داشته باشد.');
    await deleteInvoice(oldTransaction);
    final normalized = StoreTransaction(
      id: oldTransaction.id,
      invoiceNumber: updatedTransaction.invoiceNumber.trim().isEmpty
          ? oldTransaction.invoiceNumber.isEmpty ? oldTransaction.id.toString() : oldTransaction.invoiceNumber
          : updatedTransaction.invoiceNumber.trim(),
      type: updatedTransaction.type,
      totalAmount: updatedTransaction.totalAmount,
      discount: updatedTransaction.discount,
      finalAmount: updatedTransaction.finalAmount,
      paidAmount: updatedTransaction.paidAmount,
      debtAmount: updatedTransaction.debtAmount,
      paymentMethod: updatedTransaction.paymentMethod,
      contactId: updatedTransaction.contactId,
      contactName: updatedTransaction.contactName,
      userId: updatedTransaction.userId,
      userName: updatedTransaction.userName,
      dateMillis: updatedTransaction.dateMillis,
      note: updatedTransaction.note,
      taxBase: updatedTransaction.taxBase,
      taxAmount: updatedTransaction.taxAmount,
      priceListId: updatedTransaction.priceListId,
      warehouseId: updatedTransaction.warehouseId,
      returnOfId: updatedTransaction.returnOfId,
      returnType: updatedTransaction.returnType,
    );
    return normalized.type == 'SALE'
        ? recordSale(normalized, items)
        : recordPurchase(normalized, items);
  }

  Future<void> deleteAllTransactions() async {
    final db = await _db.database;
    await db.delete('transactions');
    await db.delete('transaction_items');
  }

  Future<double> getTotalSalesByRange(int start, int end) async {
    final db = await _db.database;
    final r = await db.rawQuery(
        "SELECT SUM(finalAmount) as s FROM transactions WHERE type = 'SALE' AND dateMillis >= ? AND dateMillis <= ?",
        [start, end]);
    return (r.first['s'] as num?)?.toDouble() ?? 0.0;
  }

  /// ثبت فاکتور خرید به‌صورت کاملاً تراکنشی:
  /// 1) فاکتور خرید
  /// 2) اقلام فاکتور
  /// 3) افزایش موجودی کالا
  /// 4) ثبت بدهی به تأمین‌کننده در صورت نسیه
  /// 5) ثبت گردش انبار برای هر قلم
  Future<int> recordPurchase(
    StoreTransaction t,
    List<TransactionItem> items,
  ) async {
    await ensureAccountingSeed();
    if (t.type != 'PURCHASE') {
      throw ArgumentError('نوع تراکنش خرید باید PURCHASE باشد.');
    }
    if (items.isEmpty) {
      throw ArgumentError('فاکتور خرید باید حداقل یک قلم داشته باشد.');
    }

    final db = await _db.database;

    return db.transaction<int>((txn) async {
      final transId = await txn.insert(
        'transactions',
        t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.update('transactions', {
        'invoiceNumber': t.invoiceNumber.trim().isEmpty ? transId.toString() : t.invoiceNumber.trim(),
      }, where: 'id = ?', whereArgs: [transId]);

      final contactId = t.contactId;
      if (t.debtAmount > 0 && contactId != null && contactId > 0) {
        await txn.rawUpdate(
          'UPDATE contacts SET totalPayable = totalPayable + ? WHERE id = ?',
          [t.debtAmount, contactId],
        );
        await txn.insert('installments', {
          'transactionId': transId,
          'contactId': contactId,
          'contactName': t.contactName,
          'dueDateMillis': t.dateMillis + const Duration(days: 30).inMilliseconds,
          'amount': t.debtAmount,
          'paidAmount': 0.0,
          'status': 'OPEN',
          'description': 'قسط اولیه فاکتور خرید #$transId',
        });
      }

      for (final item in items) {
        final fixedItem = item.copyWith(transactionId: transId, quantity: item.quantity);

        await txn.insert(
          'transaction_items',
          fixedItem.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (item.productId > 0 && item.quantity > 0) {
          await txn.rawUpdate(
            'UPDATE products SET stockQuantity = stockQuantity + ?, buyPrice = ? WHERE id = ?',
            [item.quantity, item.unitPrice, item.productId],
          );
          if (t.warehouseId != null && t.warehouseId! > 0) {
            final existing = await txn.query('warehouse_stock', where: 'warehouseId = ? AND productId = ?', whereArgs: [t.warehouseId, item.productId], limit: 1);
            if (existing.isEmpty) {
              await txn.insert('warehouse_stock', {'warehouseId': t.warehouseId, 'productId': item.productId, 'quantity': item.quantity});
            } else {
              await txn.rawUpdate('UPDATE warehouse_stock SET quantity = quantity + ? WHERE warehouseId = ? AND productId = ?', [item.quantity, t.warehouseId, item.productId]);
            }
          }

          final movement = StockMovement(
            productId: item.productId,
            productName: item.productName,
            type: 'IN',
            quantity: item.quantity,
            unit: 'عدد',
            pricePerUnit: item.unitPrice,
            totalPrice: item.totalPrice,
            partyName: t.contactName,
            refNumber: '#$transId',
            dateMillis: t.dateMillis,
            userId: t.userId,
            userName: t.userName,
            note: t.note,
          );

          await txn.insert(
            'stock_movements',
            movement.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      final a = await _accountIdsTxn(txn);
      final total = t.finalAmount;
      await _insertJournalTxn(txn, sourceType: 'PURCHASE', sourceId: transId, description: 'ثبت حسابداری فاکتور خرید #$transId', userId: t.userId, userName: t.userName, dateMillis: t.dateMillis, lines: [
        {'accountId': a['1301'] ?? 0, 'accountCode': '1301', 'accountName': 'موجودی کالا', 'debit': total, 'credit': 0.0},
        if (t.paidAmount > 0) {'accountId': a['1101'] ?? 0, 'accountCode': '1101', 'accountName': 'صندوق', 'debit': 0.0, 'credit': t.paidAmount},
        if (t.debtAmount > 0) {'accountId': a['2101'] ?? 0, 'accountCode': '2101', 'accountName': 'حساب‌های پرداختنی', 'debit': 0.0, 'credit': t.debtAmount},
      ]);
      return transId;
    });
  }

  // ===== Stock Movements =====
  Future<List<StockMovement>> getAllMovements() async {
    final db = await _db.database;
    final rows = await db.query('stock_movements', orderBy: 'dateMillis DESC');
    return rows.map(StockMovement.fromMap).toList();
  }

  Future<List<StockMovement>> getMovementsByType(String type) async {
    final db = await _db.database;
    final rows = await db.query('stock_movements',
        where: 'type = ?', whereArgs: [type], orderBy: 'dateMillis DESC');
    return rows.map(StockMovement.fromMap).toList();
  }

  Future<int> insertMovement(StockMovement m) async {
    final db = await _db.database;
    return db.insert('stock_movements', m.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateMovement(StockMovement m) async {
    final db = await _db.database;
    await db.insert('stock_movements', m.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteMovement(StockMovement m) async {
    final db = await _db.database;
    await db.delete('stock_movements', where: 'id = ?', whereArgs: [m.id]);
  }

  Future<void> deleteAllMovements() async {
    final db = await _db.database;
    await db.delete('stock_movements');
  }

  // ===== Audit Logs =====
  Future<List<AuditLog>> getRecentLogs() async {
    final db = await _db.database;
    final rows = await db.rawQuery('SELECT * FROM audit_logs ORDER BY timestamp DESC LIMIT 100');
    return rows.map(AuditLog.fromMap).toList();
  }

  Future<int> insertAuditLog(AuditLog l) async {
    final db = await _db.database;
    return db.insert('audit_logs', l.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// پاک‌سازی کامل لاگ‌های حسابرسی سیستم.
  /// این عملیات باید فقط از لایه ViewModel با کنترل نقش مدیر فراخوانی شود.
  Future<void> deleteAllLogs() async {
    final db = await _db.database;
    await db.delete('audit_logs');
  }

  // ===== Attendance =====
  Future<List<AttendanceRecord>> getAllAttendance() async {
    final db = await _db.database;
    final rows = await db.query('attendance_records', orderBy: 'clockInTime DESC');
    return rows.map(AttendanceRecord.fromMap).toList();
  }

  Future<List<AttendanceRecord>> getAttendanceByUser(int userId) async {
    final db = await _db.database;
    final rows = await db.query('attendance_records',
        where: 'userId = ?', whereArgs: [userId], orderBy: 'clockInTime DESC');
    return rows.map(AttendanceRecord.fromMap).toList();
  }

  Future<AttendanceRecord?> getActiveAttendance(int userId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
        'SELECT * FROM attendance_records WHERE userId = ? AND clockOutTime IS NULL ORDER BY clockInTime DESC LIMIT 1', [userId]);
    return rows.isEmpty ? null : AttendanceRecord.fromMap(rows.first);
  }

  Future<int> insertAttendance(AttendanceRecord r) async {
    final db = await _db.database;
    return db.insert('attendance_records', r.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateAttendance(AttendanceRecord r) async {
    final db = await _db.database;
    await db.insert('attendance_records', r.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteAttendance(AttendanceRecord r) async {
    final db = await _db.database;
    await db.delete('attendance_records', where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> deleteAllAttendance() async {
    final db = await _db.database;
    await db.delete('attendance_records');
  }

  // ===== عملیات ترکیبی =====
  Future<int> recordStockMovement(StockMovement movement) async {
    final id = await insertMovement(movement);
    if (movement.productId > 0) {
      if (movement.type == 'IN') {
        await increaseStock(movement.productId, movement.quantity);
      } else if (movement.type == 'OUT') {
        await decreaseStock(movement.productId, movement.quantity);
      }
    }
    await insertAuditLog(AuditLog(
      userId: movement.userId,
      userName: movement.userName,
      userRole: '',
      action: movement.type == 'IN' ? 'ورود کالا به انبار' : 'خروج کالا از انبار',
      details: '${movement.productName} به میزان ${movement.quantity} ${movement.unit} ثبت شد',
    ));
    return id;
  }

  Future<void> updateStockMovement(StockMovement oldM, StockMovement newM) async {
    if (oldM.productId > 0) {
      if (oldM.type == 'IN') await decreaseStock(oldM.productId, oldM.quantity);
      else if (oldM.type == 'OUT') await increaseStock(oldM.productId, oldM.quantity);
    }
    if (newM.productId > 0) {
      if (newM.type == 'IN') await increaseStock(newM.productId, newM.quantity);
      else if (newM.type == 'OUT') await decreaseStock(newM.productId, newM.quantity);
    }
    await updateMovement(newM);
  }

  Future<void> deleteStockMovement(StockMovement m) async {
    if (m.productId > 0) {
      if (m.type == 'IN') await decreaseStock(m.productId, m.quantity);
      else if (m.type == 'OUT') await increaseStock(m.productId, m.quantity);
    }
    await deleteMovement(m);
  }



  Future<void> _insertJournalTxn(
    dynamic txn, {
    required String sourceType,
    int? sourceId,
    required String description,
    required int userId,
    required String userName,
    required int dateMillis,
    required List<Map<String, dynamic>> lines,
  }) async {
    final debit = lines.fold<double>(0, (v, x) => v + ((x['debit'] as num?)?.toDouble() ?? 0));
    final credit = lines.fold<double>(0, (v, x) => v + ((x['credit'] as num?)?.toDouble() ?? 0));
    if ((debit - credit).abs() > 0.01) throw StateError('سند خودکار نامتوازن است.');
    final seq = Sqflite.firstIntValue(await txn.rawQuery('SELECT COALESCE(MAX(id),0)+1 FROM journal_entries')) ?? 1;
    final number = 'JE-${Jalali.now().year}-${seq.toString().padLeft(6, '0')}';
    final jid = await txn.insert('journal_entries', JournalEntry(
      number: number, dateMillis: dateMillis, description: description,
      sourceType: sourceType, sourceId: sourceId, userId: userId, userName: userName,
    ).toMap());
    for (final l in lines) {
      await txn.insert('journal_lines', JournalLine(
        journalId: jid,
        accountId: (l['accountId'] as int?) ?? 0,
        accountCode: l['accountCode'] as String,
        accountName: l['accountName'] as String,
        debit: (l['debit'] as num?)?.toDouble() ?? 0,
        credit: (l['credit'] as num?)?.toDouble() ?? 0,
        description: l['description'] as String? ?? '',
      ).toMap());
    }
  }

  Future<Map<String, int>> _accountIdsTxn(dynamic txn) async {
    final rows = await txn.query('chart_accounts', columns: ['id','code']);
    return {for (final r in rows) r['code'].toString(): (r['id'] as num).toInt()};
  }

  Future<int> recordSale(StoreTransaction t, List<TransactionItem> items) async {
    await ensureAccountingSeed();
    final db = await _db.database;
    return await db.transaction<int>((txn) async {
      final transId = await txn.insert('transactions', t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.update('transactions', {
        'invoiceNumber': t.invoiceNumber.trim().isEmpty ? transId.toString() : t.invoiceNumber.trim(),
      }, where: 'id = ?', whereArgs: [transId]);
      final withId = items.map((it) => it.copyWith(transactionId: transId, quantity: it.quantity)).toList();
      for (final it in withId) {
        await txn.insert('transaction_items', it.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final it in items) {
        if (it.productId > 0) {
          final productRows = await txn.query('products', columns: ['isService'], where: 'id = ?', whereArgs: [it.productId], limit: 1);
          final isService = productRows.isNotEmpty && (productRows.first['isService'] as num?)?.toInt() == 1;
          if (!isService) {
            await txn.rawUpdate(
                'UPDATE products SET stockQuantity = stockQuantity - ? WHERE id = ?', [it.quantity, it.productId]);
          }
        }
      }
      if (t.debtAmount > 0 && t.contactId != null && t.contactId! > 0) {
        await txn.rawUpdate('UPDATE contacts SET totalDebt = totalDebt + ? WHERE id = ?', [t.debtAmount, t.contactId]);
        await txn.insert('installments', {
          'transactionId': transId,
          'contactId': t.contactId,
          'contactName': t.contactName,
          'dueDateMillis': t.dateMillis + const Duration(days: 30).inMilliseconds,
          'amount': t.debtAmount,
          'paidAmount': 0.0,
          'status': 'OPEN',
          'description': 'قسط اولیه فاکتور فروش #$transId',
        });
      }
      await txn.insert('audit_logs', AuditLog(
        userId: t.userId, userName: t.userName, userRole: '',
        action: 'ثبت فاکتور فروش',
        details: 'فاکتور #$transId به مبلغ ${t.finalAmount} ثبت شد',
      ).toMap());

      final a = await _accountIdsTxn(txn);
      final cogs = items.fold<double>(0, (sum, it) => sum + (it.quantity * it.costPrice));
      final revenue = t.finalAmount;
      final lines = <Map<String, dynamic>>[];
      if (t.paidAmount > 0) {
        lines.add({'accountId': a['1101'] ?? 0, 'accountCode': '1101', 'accountName': 'صندوق', 'debit': t.paidAmount, 'credit': 0.0});
      }
      if (t.debtAmount > 0) {
        lines.add({'accountId': a['1201'] ?? 0, 'accountCode': '1201', 'accountName': 'حساب‌های دریافتنی', 'debit': t.debtAmount, 'credit': 0.0});
      }
      if (t.paidAmount <= 0 && t.debtAmount <= 0) {
        lines.add({'accountId': a['1101'] ?? 0, 'accountCode': '1101', 'accountName': 'صندوق', 'debit': revenue, 'credit': 0.0});
      }
      lines.add({'accountId': a['4101'] ?? 0, 'accountCode': '4101', 'accountName': 'فروش', 'debit': 0.0, 'credit': revenue});
      if (cogs > 0) {
        lines.add({'accountId': a['5101'] ?? 0, 'accountCode': '5101', 'accountName': 'بهای تمام‌شده فروش', 'debit': cogs, 'credit': 0.0});
        lines.add({'accountId': a['1301'] ?? 0, 'accountCode': '1301', 'accountName': 'موجودی کالا', 'debit': 0.0, 'credit': cogs});
      }
      await _insertJournalTxn(txn, sourceType: 'SALE', sourceId: transId, description: 'ثبت حسابداری فاکتور فروش #$transId', userId: t.userId, userName: t.userName, dateMillis: t.dateMillis, lines: lines);
      return transId;
    });
  }



  Future<int> recordReturn(StoreTransaction original, List<TransactionItem> items, {required bool saleReturn}) async {
    if (items.isEmpty) throw ArgumentError('برگشت باید حداقل یک قلم داشته باشد.');
    await ensureAccountingSeed();
    final db = await _db.database;
    return db.transaction<int>((txn) async {
      double total = 0;
      double cogs = 0;
      for (final item in items) {
        if (item.quantity <= 0) continue;
        total += item.quantity * item.unitPrice;
        cogs += item.quantity * item.costPrice;
      }
      if (total <= 0) throw StateError('مبلغ برگشت معتبر نیست.');

      final debtPortion = original.debtAmount <= 0 ? 0.0 : total.clamp(0.0, original.debtAmount).toDouble();
      final cashPortion = saleReturn ? (total - debtPortion) : 0.0;
      final payablePortion = !saleReturn && original.debtAmount > 0
          ? total.clamp(0.0, original.debtAmount).toDouble()
          : 0.0;
      final cashPurchaseRefund = !saleReturn ? (total - payablePortion) : 0.0;

      final t = StoreTransaction(
        type: saleReturn ? 'SALE_RETURN' : 'PURCHASE_RETURN',
        totalAmount: total,
        discount: 0,
        finalAmount: total,
        paidAmount: cashPortion > 0 ? cashPortion : (cashPurchaseRefund > 0 ? cashPurchaseRefund : 0),
        debtAmount: saleReturn ? debtPortion : payablePortion,
        paymentMethod: original.paymentMethod,
        contactId: original.contactId,
        contactName: original.contactName,
        userId: original.userId,
        userName: original.userName,
        dateMillis: DateTime.now().millisecondsSinceEpoch,
        note: 'برگشت از فاکتور #${original.id}',
        returnOfId: original.id,
        returnType: saleReturn ? 'SALE' : 'PURCHASE',
        warehouseId: original.warehouseId,
        taxBase: original.taxBase > 0 ? (original.taxBase * (total / (original.finalAmount <= 0 ? total : original.finalAmount))) : total,
        taxAmount: original.taxAmount > 0 ? (original.taxAmount * (total / (original.finalAmount <= 0 ? total : original.finalAmount))) : 0,
      );
      final id = await txn.insert('transactions', t.toMap());

      for (final item in items) {
        if (item.quantity <= 0) continue;
        final returnItem = TransactionItem(
          transactionId: id, productId: item.productId, productName: item.productName,
          quantity: item.quantity, unitPrice: item.unitPrice, costPrice: item.costPrice,
          totalPrice: item.quantity * item.unitPrice,
        );
        await txn.insert('transaction_items', returnItem.toMap());
        if (item.productId > 0) {
          final delta = saleReturn ? item.quantity : -item.quantity;
          await txn.rawUpdate(
            'UPDATE products SET stockQuantity = stockQuantity + ? WHERE id = ?',
            [delta, item.productId],
          );
          if (t.warehouseId != null && t.warehouseId! > 0) {
            final existing = await txn.query('warehouse_stock', where: 'warehouseId = ? AND productId = ?', whereArgs: [t.warehouseId, item.productId], limit: 1);
            if (existing.isEmpty) {
              await txn.insert('warehouse_stock', {'warehouseId': t.warehouseId, 'productId': item.productId, 'quantity': delta});
            } else {
              await txn.rawUpdate('UPDATE warehouse_stock SET quantity = quantity + ? WHERE warehouseId = ? AND productId = ?', [delta, t.warehouseId, item.productId]);
            }
          }
          await txn.insert('stock_movements', StockMovement(
            productId: item.productId,
            productName: item.productName,
            type: saleReturn ? 'IN' : 'OUT',
            quantity: item.quantity,
            pricePerUnit: item.unitPrice,
            totalPrice: item.quantity * item.unitPrice,
            partyName: original.contactName,
            refNumber: 'RET#$id',
            dateMillis: t.dateMillis,
            userId: t.userId,
            userName: t.userName,
            note: 'برگشت فاکتور #${original.id}',
          ).toMap());
        }
      }

      if (original.contactId != null && original.contactId! > 0) {
        if (saleReturn && debtPortion > 0) {
          await txn.rawUpdate(
            'UPDATE contacts SET totalDebt = CASE WHEN totalDebt - ? < 0 THEN 0 ELSE totalDebt - ? END WHERE id = ?',
            [debtPortion, debtPortion, original.contactId],
          );
        } else if (!saleReturn && payablePortion > 0) {
          await txn.rawUpdate(
            'UPDATE contacts SET totalPayable = CASE WHEN totalPayable - ? < 0 THEN 0 ELSE totalPayable - ? END WHERE id = ?',
            [payablePortion, payablePortion, original.contactId],
          );
        }
      }

      final a = await _accountIdsTxn(txn);
      if (saleReturn) {
        await _insertJournalTxn(txn,
          sourceType: 'SALE_RETURN',
          sourceId: id,
          description: 'برگشت فروش #${original.id}',
          userId: t.userId,
          userName: t.userName,
          dateMillis: t.dateMillis,
          lines: [
            {'accountId': a['4101'] ?? 0, 'accountCode': '4101', 'accountName': 'فروش', 'debit': total, 'credit': 0.0},
            if (debtPortion > 0) {'accountId': a['1201'] ?? 0, 'accountCode': '1201', 'accountName': 'حساب‌های دریافتنی', 'debit': 0.0, 'credit': debtPortion},
            if (cashPortion > 0) {'accountId': a['1101'] ?? 0, 'accountCode': '1101', 'accountName': 'صندوق', 'debit': 0.0, 'credit': cashPortion},
            if (t.taxAmount > 0) {'accountId': a['2201'] ?? 0, 'accountCode': '2201', 'accountName': 'مالیات پرداختنی', 'debit': t.taxAmount, 'credit': 0.0},
            if (cogs > 0) {'accountId': a['1301'] ?? 0, 'accountCode': '1301', 'accountName': 'موجودی کالا', 'debit': cogs, 'credit': 0.0},
            if (cogs > 0) {'accountId': a['5101'] ?? 0, 'accountCode': '5101', 'accountName': 'بهای تمام‌شده فروش', 'debit': 0.0, 'credit': cogs},
          ],
        );
      } else {
        await _insertJournalTxn(txn,
          sourceType: 'PURCHASE_RETURN',
          sourceId: id,
          description: 'برگشت خرید #${original.id}',
          userId: t.userId,
          userName: t.userName,
          dateMillis: t.dateMillis,
          lines: [
            if (payablePortion > 0) {'accountId': a['2101'] ?? 0, 'accountCode': '2101', 'accountName': 'حساب‌های پرداختنی', 'debit': payablePortion, 'credit': 0.0},
            if (cashPurchaseRefund > 0) {'accountId': a['1101'] ?? 0, 'accountCode': '1101', 'accountName': 'صندوق', 'debit': cashPurchaseRefund, 'credit': 0.0},
            {'accountId': a['1301'] ?? 0, 'accountCode': '1301', 'accountName': 'موجودی کالا', 'debit': 0.0, 'credit': total},
            if (t.taxAmount > 0) {'accountId': a['2201'] ?? 0, 'accountCode': '2201', 'accountName': 'مالیات پرداختنی', 'debit': 0.0, 'credit': t.taxAmount},
          ],
        );
      }
      return id;
    });
  }

  Future<void> deleteSale(StoreTransaction t) async {
    await deleteInvoice(t);
  }

  // ========================================================================
  // حسابداری تجاری
  // ========================================================================

  Future<void> ensureAccountingSeed() async {
    final db = await _db.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM chart_accounts')) ?? 0;
    if (count > 0) return;
    const accounts = <ChartAccount>[
      ChartAccount(code: '1101', name: 'صندوق', type: 'ASSET', isCashOrBank: true),
      ChartAccount(code: '1102', name: 'بانک', type: 'ASSET', isCashOrBank: true),
      ChartAccount(code: '1201', name: 'حساب‌های دریافتنی', type: 'ASSET'),
      ChartAccount(code: '1301', name: 'موجودی کالا', type: 'ASSET'),
      ChartAccount(code: '2101', name: 'حساب‌های پرداختنی', type: 'LIABILITY'),
      ChartAccount(code: '2201', name: 'مالیات پرداختنی', type: 'LIABILITY'),
      ChartAccount(code: '3101', name: 'سرمایه', type: 'EQUITY'),
      ChartAccount(code: '4101', name: 'فروش', type: 'REVENUE'),
      ChartAccount(code: '4201', name: 'تخفیفات فروش', type: 'REVENUE'),
      ChartAccount(code: '5101', name: 'بهای تمام‌شده فروش', type: 'EXPENSE'),
      ChartAccount(code: '5201', name: 'هزینه‌های عملیاتی', type: 'EXPENSE'),
      ChartAccount(code: '5301', name: 'حقوق و دستمزد', type: 'EXPENSE'),
    ];
    for (final a in accounts) {
      await db.insert('chart_accounts', a.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<ChartAccount>> getChartAccounts({bool activeOnly = false}) async {
    await ensureAccountingSeed();
    final db = await _db.database;
    final rows = await db.query('chart_accounts', where: activeOnly ? 'isActive = 1' : null, orderBy: 'code ASC');
    return rows.map(ChartAccount.fromMap).toList();
  }

  Future<int> saveChartAccount(ChartAccount account) async {
    await ensureAccountingSeed();
    final db = await _db.database;
    if (account.id == 0) return db.insert('chart_accounts', account.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
    await db.update('chart_accounts', account.toMap(), where: 'id = ?', whereArgs: [account.id]);
    return account.id;
  }

  Future<List<JournalEntry>> getJournalEntries({int limit = 500, int? startMillis, int? endMillis}) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <dynamic>[];
    if (startMillis != null) { where.add('dateMillis >= ?'); args.add(startMillis); }
    if (endMillis != null) { where.add('dateMillis <= ?'); args.add(endMillis); }
    final rows = await db.query('journal_entries', where: where.isEmpty ? null : where.join(' AND '), whereArgs: args.isEmpty ? null : args, orderBy: 'dateMillis DESC, id DESC', limit: limit);
    return rows.map(JournalEntry.fromMap).toList();
  }

  Future<List<JournalLine>> getJournalLines(int journalId) async {
    final db = await _db.database;
    final rows = await db.query('journal_lines', where: 'journalId = ?', whereArgs: [journalId], orderBy: 'id ASC');
    return rows.map(JournalLine.fromMap).toList();
  }

  Future<int> createJournalEntry({
    required String description,
    required List<JournalLine> lines,
    String sourceType = 'MANUAL',
    int? sourceId,
    int userId = 0,
    String userName = '',
    int? dateMillis,
  }) async {
    if (lines.isEmpty) throw ArgumentError('سند باید حداقل یک ردیف داشته باشد.');
    final debit = lines.fold<double>(0, (s, l) => s + l.debit);
    final credit = lines.fold<double>(0, (s, l) => s + l.credit);
    if ((debit - credit).abs() > 0.01) throw StateError('جمع بدهکار و بستانکار سند برابر نیست.');
    if (debit <= 0) throw StateError('مبلغ سند باید بیشتر از صفر باشد.');
    final db = await _db.database;
    return db.transaction<int>((txn) async {
      final stamp = dateMillis ?? DateTime.now().millisecondsSinceEpoch;
      final seq = Sqflite.firstIntValue(await txn.rawQuery('SELECT COALESCE(MAX(id),0)+1 FROM journal_entries')) ?? 1;
      final number = 'JE-${Jalali.now().year}-${seq.toString().padLeft(6, '0')}';
      final journalId = await txn.insert('journal_entries', JournalEntry(
        number: number, dateMillis: stamp, description: description.trim(), sourceType: sourceType,
        sourceId: sourceId, userId: userId, userName: userName,
      ).toMap());
      for (final line in lines) {
        await txn.insert('journal_lines', line.copyWithJournalId(journalId).toMap());
      }
      return journalId;
    });
  }

  Future<List<Map<String, dynamic>>> getGeneralLedger({int? accountId, int? startMillis, int? endMillis}) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <dynamic>[];
    if (accountId != null) { where.add('jl.accountId = ?'); args.add(accountId); }
    if (startMillis != null) { where.add('je.dateMillis >= ?'); args.add(startMillis); }
    if (endMillis != null) { where.add('je.dateMillis <= ?'); args.add(endMillis); }
    return db.rawQuery('''SELECT je.id journalId, je.number, je.dateMillis, je.description journalDescription,
      jl.id lineId, jl.accountId, jl.accountCode, jl.accountName, jl.debit, jl.credit, jl.description lineDescription
      FROM journal_entries je JOIN journal_lines jl ON jl.journalId = je.id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} ORDER BY je.dateMillis DESC, je.id DESC, jl.id ASC''', args);
  }

  Future<Map<String, double>> getProfitLoss(int startMillis, int endMillis) async {
    final rows = await getGeneralLedger(startMillis: startMillis, endMillis: endMillis);
    double revenue = 0, expense = 0;
    for (final r in rows) {
      final code = r['accountCode']?.toString() ?? '';
      final d = (r['debit'] as num?)?.toDouble() ?? 0;
      final c = (r['credit'] as num?)?.toDouble() ?? 0;
      if (code.startsWith('4')) revenue += c - d;
      if (code.startsWith('5')) expense += d - c;
    }
    return {'revenue': revenue, 'expense': expense, 'netProfit': revenue - expense};
  }

  Future<Map<String, double>> getBalanceSheet(int millis) async {
    final rows = await getGeneralLedger(endMillis: millis);
    double assets = 0, liabilities = 0, equity = 0;
    final types = <String, String>{for (final a in await getChartAccounts()) a.code: a.type};
    for (final r in rows) {
      final type = types[r['accountCode']?.toString()];
      final d = (r['debit'] as num?)?.toDouble() ?? 0;
      final c = (r['credit'] as num?)?.toDouble() ?? 0;
      if (type == 'ASSET') assets += d - c;
      if (type == 'LIABILITY') liabilities += c - d;
      if (type == 'EQUITY') equity += c - d;
    }
    return {'assets': assets, 'liabilities': liabilities, 'equity': equity};
  }

  Future<List<CashBankAccount>> getCashBankAccounts() async {
    await ensureAccountingSeed();
    final db = await _db.database;
    // بانک‌ها باید سرفصل مستقل داشته باشند؛ نسخه‌های قبلی ممکن است همه را به 1101 وصل کرده باشند.
    final all = await db.query('cash_bank_accounts', where: 'isActive = 1', orderBy: 'name ASC');
    final usedCodes = (await db.query('chart_accounts', columns: ['code']))
        .map((r) => r['code'].toString()).toSet();
    var nextCode = 1110;
    for (final row in all.where((r) => (r['type']?.toString() ?? '') == 'BANK')) {
      final accountId = (row['id'] as num?)?.toInt() ?? 0;
      final ledgerId = (row['ledgerAccountId'] as num?)?.toInt() ?? 0;
      final ledgerRows = ledgerId > 0
          ? await db.query('chart_accounts', where: 'id = ?', whereArgs: [ledgerId], limit: 1)
          : <Map<String, dynamic>>[];
      final existingCode = ledgerRows.isEmpty ? '' : ledgerRows.first['code']?.toString() ?? '';
      final isSharedDefault = existingCode == '1101' || existingCode.isEmpty ||
          all.where((other) => other['id'] != accountId && other['ledgerAccountId'] == ledgerId).isNotEmpty;
      if (!isSharedDefault) continue;
      while (usedCodes.contains(nextCode.toString())) nextCode++;
      final code = nextCode.toString();
      nextCode++;
      final newLedgerId = await db.insert('chart_accounts', ChartAccount(
        code: code,
        name: row['name']?.toString() ?? 'حساب بانکی',
        type: 'ASSET',
        isCashOrBank: true,
      ).toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
      if (newLedgerId > 0) {
        usedCodes.add(code);
        await db.update('cash_bank_accounts', {'ledgerAccountId': newLedgerId}, where: 'id = ?', whereArgs: [accountId]);
      }
    }
    final rows = await db.query('cash_bank_accounts', where: 'isActive = 1', orderBy: 'name ASC');
    return rows.map(CashBankAccount.fromMap).toList();
  }

  Future<int> saveCashBankAccount(CashBankAccount account) async {
    final db = await _db.database;
    if (account.id == 0) return db.insert('cash_bank_accounts', account.toMap());
    await db.update('cash_bank_accounts', account.toMap(), where: 'id = ?', whereArgs: [account.id]);
    return account.id;
  }

  Future<double> getCashBankBalance(CashBankAccount account) async {
    final rows = await getGeneralLedger(accountId: account.ledgerAccountId);
    double balance = account.openingBalance;
    for (final r in rows) {
      balance += ((r['debit'] as num?)?.toDouble() ?? 0) - ((r['credit'] as num?)?.toDouble() ?? 0);
    }
    return balance;
  }

  Future<int> createSettlement(SettlementRecord settlement) async {
    if (settlement.amount <= 0) throw ArgumentError('مبلغ تسویه باید بیشتر از صفر باشد.');
    await ensureAccountingSeed();
    final db = await _db.database;
    return db.transaction<int>((txn) async {
      final id = await txn.insert('settlements', settlement.toMap());
      if (settlement.contactId > 0) {
        final field = settlement.type == 'RECEIPT' ? 'totalDebt' : 'totalPayable';
        await txn.rawUpdate('UPDATE contacts SET $field = CASE WHEN $field - ? < 0 THEN 0 ELSE $field - ? END WHERE id = ?', [settlement.amount, settlement.amount, settlement.contactId]);
      }
      final a = await _accountIdsTxn(txn);
      int cashAccountId = a['1101'] ?? 0;
      String cashCode = '1101';
      String cashName = settlement.cashBankName.isEmpty ? 'صندوق' : settlement.cashBankName;
      if (settlement.cashBankId > 0) {
        final cb = await txn.query('cash_bank_accounts', where: 'id = ?', whereArgs: [settlement.cashBankId], limit: 1);
        if (cb.isNotEmpty) {
          cashAccountId = (cb.first['ledgerAccountId'] as num?)?.toInt() ?? cashAccountId;
          cashName = cb.first['name']?.toString() ?? cashName;
          final meta = await txn.query('chart_accounts', where: 'id = ?', whereArgs: [cashAccountId], limit: 1);
          if (meta.isNotEmpty) cashCode = meta.first['code']?.toString() ?? cashCode;
        }
      }
      await _insertJournalTxn(txn, sourceType: 'SETTLEMENT', sourceId: id, description: settlement.description.isEmpty ? 'تسویه ${settlement.contactName}' : settlement.description, userId: settlement.userId, userName: settlement.userName, dateMillis: settlement.dateMillis, lines: settlement.type == 'RECEIPT' ? [
        {'accountId': cashAccountId, 'accountCode': cashCode, 'accountName': cashName, 'debit': settlement.amount, 'credit': 0.0},
        {'accountId': a['1201'] ?? 0, 'accountCode': '1201', 'accountName': 'حساب‌های دریافتنی', 'debit': 0.0, 'credit': settlement.amount},
      ] : [
        {'accountId': a['2101'] ?? 0, 'accountCode': '2101', 'accountName': 'حساب‌های پرداختنی', 'debit': settlement.amount, 'credit': 0.0},
        {'accountId': cashAccountId, 'accountCode': cashCode, 'accountName': cashName, 'debit': 0.0, 'credit': settlement.amount},
      ]);
      return id;
    });
  }


  Future<int> transferCashBank({
    required CashBankAccount from,
    required CashBankAccount to,
    required double amount,
    String description = '',
    int userId = 0,
    String userName = '',
  }) async {
    if (amount <= 0) throw ArgumentError('مبلغ انتقال باید بیشتر از صفر باشد.');
    if (from.id == to.id) throw ArgumentError('مبدأ و مقصد انتقال نباید یکسان باشد.');
    await ensureAccountingSeed();
    final db = await _db.database;
    return db.transaction<int>((txn) async {
      Future<Map<String, dynamic>> accountMeta(int id, String fallback) async {
        final rows = await txn.query('chart_accounts', where: 'id = ?', whereArgs: [id], limit: 1);
        if (rows.isEmpty) return {'code': '', 'name': fallback};
        return {'code': rows.first['code']?.toString() ?? '', 'name': rows.first['name']?.toString() ?? fallback};
      }
      final toMeta = await accountMeta(to.ledgerAccountId, to.name);
      final fromMeta = await accountMeta(from.ledgerAccountId, from.name);
      await _insertJournalTxn(
        txn,
        sourceType: 'CASH_BANK_TRANSFER',
        description: description.trim().isEmpty
            ? 'انتقال وجه از ${from.name} به ${to.name}'
            : description.trim(),
        userId: userId,
        userName: userName,
        dateMillis: DateTime.now().millisecondsSinceEpoch,
        lines: [
          {'accountId': to.ledgerAccountId, 'accountCode': toMeta['code'], 'accountName': toMeta['name'], 'debit': amount, 'credit': 0.0},
          {'accountId': from.ledgerAccountId, 'accountCode': fromMeta['code'], 'accountName': fromMeta['name'], 'debit': 0.0, 'credit': amount},
        ],
      );
      return 0;
    });
  }

  Future<void> markPayrollPaid(PayrollRecord payroll, {
    int userId = 0,
    String userName = '',
    int? cashBankId,
    String cashBankName = 'صندوق',
  }) async {
    if (payroll.paid) return;
    await ensureAccountingSeed();
    final db = await _db.database;
    await db.transaction((txn) async {
      final a = await _accountIdsTxn(txn);
      final paidAt = DateTime.now().millisecondsSinceEpoch;
      await txn.update('payroll_records', {'paid': 1, 'paidDateMillis': paidAt}, where: 'id = ?', whereArgs: [payroll.id]);
      int cashAccountId = a['1101'] ?? 0;
      if (cashBankId != null) {
        final rows = await txn.query('cash_bank_accounts', where: 'id = ?', whereArgs: [cashBankId], limit: 1);
        if (rows.isNotEmpty) cashAccountId = (rows.first['ledgerAccountId'] as num?)?.toInt() ?? cashAccountId;
      }
      await _insertJournalTxn(
        txn,
        sourceType: 'PAYROLL_PAYMENT',
        sourceId: payroll.id,
        description: 'پرداخت حقوق ${payroll.userName}',
        userId: userId,
        userName: userName,
        dateMillis: paidAt,
        lines: [
          {'accountId': a['5301'] ?? 0, 'accountCode': '5301', 'accountName': 'حقوق و دستمزد', 'debit': payroll.netSalary, 'credit': 0.0},
          {'accountId': cashAccountId, 'accountCode': '', 'accountName': cashBankName, 'debit': 0.0, 'credit': payroll.netSalary},
        ],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getTrialBalance({int? startMillis, int? endMillis}) async {
    final rows = await getGeneralLedger(startMillis: startMillis, endMillis: endMillis);
    final map = <int, Map<String, dynamic>>{};
    for (final r in rows) {
      final id = (r['accountId'] as num).toInt();
      final e = map.putIfAbsent(id, () => {'accountId': id, 'accountCode': r['accountCode'], 'accountName': r['accountName'], 'debit': 0.0, 'credit': 0.0});
      e['debit'] = (e['debit'] as double) + ((r['debit'] as num?)?.toDouble() ?? 0);
      e['credit'] = (e['credit'] as double) + ((r['credit'] as num?)?.toDouble() ?? 0);
    }
    return map.values.toList()..sort((a,b) => (a['accountCode'] as String).compareTo(b['accountCode'] as String));
  }

  Future<List<Map<String, dynamic>>> getAgingDetails() async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.rawQuery("SELECT t.id, t.contactId, t.contactName, t.debtAmount, t.dateMillis, t.userName, t.note FROM transactions t WHERE t.type = 'SALE' AND t.debtAmount > 0 ORDER BY t.dateMillis ASC");
    return rows.map((r) {
      final dateMillis = (r['dateMillis'] as num?)?.toInt() ?? now;
      final age = ((now - dateMillis) / Duration.millisecondsPerDay).floor();
      final bucket = age <= 30 ? '0_30' : age <= 60 ? '31_60' : age <= 90 ? '61_90' : '90_plus';
      return <String, dynamic>{...r, 'ageDays': age, 'bucket': bucket};
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getTaxAnnualReport(int year, double taxRate) async {
    final result = <Map<String, dynamic>>[];
    for (int month = 1; month <= 12; month++) {
      final r = await getTaxReport(year, month, taxRate);
      result.add({'month': month, ...r});
    }
    return result;
  }

  Future<List<SettlementRecord>> getSettlements({int limit = 300}) async {
    final db = await _db.database;
    final rows = await db.query('settlements', orderBy: 'dateMillis DESC, id DESC', limit: limit);
    return rows.map(SettlementRecord.fromMap).toList();
  }

  Future<int> savePayroll(PayrollRecord payroll) async {
    final db = await _db.database;
    if (payroll.id == 0) return db.insert('payroll_records', payroll.toMap());
    await db.update('payroll_records', payroll.toMap(), where: 'id = ?', whereArgs: [payroll.id]);
    return payroll.id;
  }

  Future<List<PayrollRecord>> getPayroll({int? year, int? month}) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <dynamic>[];
    if (year != null) { where.add('periodYear = ?'); args.add(year); }
    if (month != null) { where.add('periodMonth = ?'); args.add(month); }
    final rows = await db.query('payroll_records', where: where.isEmpty ? null : where.join(' AND '), whereArgs: args.isEmpty ? null : args, orderBy: 'periodYear DESC, periodMonth DESC, userName ASC');
    return rows.map(PayrollRecord.fromMap).toList();
  }

  Future<Map<String, double>> getTaxReport(int year, int month, double taxRate) async {
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch - 1;
    final sales = await getTotalSalesByRange(start, end);
    final purchases = await dbTotal('transactions', 'finalAmount', "type = 'PURCHASE'", start, end);
    final expenses = await getTotalExpensesByRange(start, end);
    final taxable = (sales - purchases - expenses).clamp(0.0, double.infinity).toDouble();
    return {'sales': sales, 'purchases': purchases, 'expenses': expenses, 'taxable': taxable, 'tax': taxable * taxRate};
  }

  Future<double> dbTotal(String table, String column, String extraWhere, int start, int end) async {
    final db = await _db.database;
    final r = await db.rawQuery('SELECT COALESCE(SUM($column),0) s FROM $table WHERE dateMillis >= ? AND dateMillis <= ? AND $extraWhere', [start, end]);
    return (r.first['s'] as num?)?.toDouble() ?? 0;
  }

  Future<Map<String, double>> getAgingSummary() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = {'0_30': 0.0, '31_60': 0.0, '61_90': 0.0, '90_plus': 0.0};
    for (final c in await getDebtors()) {
      final ageDays = ((now - c.updatedAt) / Duration.millisecondsPerDay).floor();
      final key = ageDays <= 30 ? '0_30' : ageDays <= 60 ? '31_60' : ageDays <= 90 ? '61_90' : '90_plus';
      result[key] = (result[key] ?? 0) + c.totalDebt;
    }
    return result;
  }

  // ========================================================================
  // امکانات تجاری پیشرفته: دوره مالی، چک، اقساط، تطبیق بانکی، چندانباره، قیمت‌ها، سریال، مالیات و مرکز هزینه
  // ========================================================================

  Future<List<FiscalYear>> getFiscalYears() async {
    final db = await _db.database;
    final rows = await db.query('fiscal_years', orderBy: 'year DESC');
    return rows.map(FiscalYear.fromMap).toList();
  }

  Future<int> saveFiscalYear(FiscalYear item) async {
    final db = await _db.database;
    if (item.id == 0) return db.insert('fiscal_years', item.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
    await db.update('fiscal_years', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item.id;
  }

  Future<void> closeFiscalYear(int id) async {
    final db = await _db.database;
    await db.update('fiscal_years', {'isClosed': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // ---- افزودنی: ویرایش/حذف سال مالی، حذف قسط، حذف تطبیق بانکی ----
  Future<void> deleteFiscalYear(int id) async {
    final db = await _db.database;
    await db.delete('fiscal_years', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteInstallment(int id) async {
    final db = await _db.database;
    await db.delete('installments', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBankReconciliation(int id) async {
    final db = await _db.database;
    await db.delete('bank_reconciliations', where: 'id = ?', whereArgs: [id]);
  }

  // ---- CRUD کامل امکانات حسابداری تجاری پیشرفته ----
  Future<void> deleteCheck(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final rows = await txn.query('checks', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;
      final settlementId = (rows.first['settlementId'] as num?)?.toInt();
      if (settlementId != null && settlementId > 0) {
        final jr = await txn.query('journal_entries', where: 'sourceType = ? AND sourceId = ?', whereArgs: ['SETTLEMENT', settlementId], limit: 1);
        for (final j in jr) {
          final jid = (j['id'] as num).toInt();
          await txn.delete('journal_lines', where: 'journalId = ?', whereArgs: [jid]);
          await txn.delete('journal_entries', where: 'id = ?', whereArgs: [jid]);
        }
        await txn.delete('settlements', where: 'id = ?', whereArgs: [settlementId]);
      }
      await txn.delete('checks', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteAllChecks() async {
    final db = await _db.database;
    await db.delete('checks');
  }

  Future<void> deleteSettlement(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final rows = await txn.query('settlements', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;
      final r = rows.first;
      final contactId = (r['contactId'] as num?)?.toInt() ?? 0;
      final amount = (r['amount'] as num?)?.toDouble() ?? 0;
      final type = r['type']?.toString() ?? 'RECEIPT';
      if (contactId > 0 && amount > 0) {
        final field = type == 'RECEIPT' ? 'totalDebt' : 'totalPayable';
        await txn.rawUpdate('UPDATE contacts SET $field = $field + ?, updatedAt = ? WHERE id = ?', [amount, DateTime.now().millisecondsSinceEpoch, contactId]);
      }
      final jr = await txn.query('journal_entries', where: 'sourceType = ? AND sourceId = ?', whereArgs: ['SETTLEMENT', id]);
      for (final j in jr) {
        final jid = (j['id'] as num).toInt();
        await txn.delete('journal_lines', where: 'journalId = ?', whereArgs: [jid]);
        await txn.delete('journal_entries', where: 'id = ?', whereArgs: [jid]);
      }
      await txn.delete('settlements', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> updateJournalEntry({
    required int id,
    required String description,
    required List<JournalLine> lines,
    int? dateMillis,
  }) async {
    if (lines.isEmpty) throw ArgumentError('سند باید حداقل یک ردیف داشته باشد.');
    final debit = lines.fold<double>(0, (sum, l) => sum + l.debit);
    final credit = lines.fold<double>(0, (sum, l) => sum + l.credit);
    if (debit <= 0 || (debit - credit).abs() > .01) throw StateError('جمع بدهکار و بستانکار سند برابر نیست.');
    final db=await _db.database;
    await db.transaction((txn) async {
      final rows=await txn.query('journal_entries',where:'id = ?',whereArgs:[id],limit:1);
      if(rows.isEmpty) throw StateError('سند پیدا نشد.');
      if((rows.first['sourceType']?.toString() ?? 'MANUAL')!='MANUAL') throw StateError('سندهای سیستمی باید از عملیات اصلی اصلاح شوند.');
      await txn.update('journal_entries', {'description':description.trim(), 'dateMillis':dateMillis ?? rows.first['dateMillis']}, where:'id = ?', whereArgs:[id]);
      await txn.delete('journal_lines', where:'journalId = ?', whereArgs:[id]);
      for(final l in lines) await txn.insert('journal_lines', l.copyWithJournalId(id).toMap());
    });
  }

  Future<void> updateSettlement(SettlementRecord settlement) async {
    // تسویه قبلی را از مانده طرف حساب و سند حسابداری برمی‌گردانیم، سپس همان رکورد را بازسازی می‌کنیم.
    final db=await _db.database;
    await db.transaction((txn) async {
      final rows=await txn.query('settlements',where:'id = ?',whereArgs:[settlement.id],limit:1);
      if(rows.isEmpty) throw StateError('تسویه پیدا نشد.');
      final old=rows.first;
      final oldContact=(old['contactId'] as num?)?.toInt()??0;
      final oldAmount=(old['amount'] as num?)?.toDouble()??0;
      final oldType=old['type']?.toString()??'RECEIPT';
      if(oldContact>0&&oldAmount>0){ final f=oldType=='RECEIPT'?'totalDebt':'totalPayable'; await txn.rawUpdate('UPDATE contacts SET $f=$f+?, updatedAt=? WHERE id=?',[oldAmount,DateTime.now().millisecondsSinceEpoch,oldContact]); }
      final jr=await txn.query('journal_entries',where:'sourceType=? AND sourceId=?',whereArgs:['SETTLEMENT',settlement.id]);
      for(final j in jr){final jid=(j['id'] as num).toInt();await txn.delete('journal_lines',where:'journalId=?',whereArgs:[jid]);await txn.delete('journal_entries',where:'id=?',whereArgs:[jid]);}
      await txn.update('settlements',settlement.toMap(),where:'id=?',whereArgs:[settlement.id]);
      final field=settlement.type=='RECEIPT'?'totalDebt':'totalPayable';
      await txn.rawUpdate('UPDATE contacts SET $field=CASE WHEN $field-? < 0 THEN 0 ELSE $field-? END, updatedAt=? WHERE id=?',[settlement.amount,settlement.amount,DateTime.now().millisecondsSinceEpoch,settlement.contactId]);
      final a=await _accountIdsTxn(txn);
      int cashAccountId=a['1101']??0; String cashCode='1101'; String cashName=settlement.cashBankName.isEmpty?'صندوق':settlement.cashBankName;
      final cb=await txn.query('cash_bank_accounts',where:'id=?',whereArgs:[settlement.cashBankId],limit:1);
      if(cb.isNotEmpty){cashAccountId=(cb.first['ledgerAccountId'] as num?)?.toInt()??cashAccountId;cashName=cb.first['name']?.toString()??cashName;final m=await txn.query('chart_accounts',where:'id=?',whereArgs:[cashAccountId],limit:1);if(m.isNotEmpty)cashCode=m.first['code']?.toString()??cashCode;}
      await _insertJournalTxn(txn,sourceType:'SETTLEMENT',sourceId:settlement.id,description:settlement.description.isEmpty?'تسویه ${settlement.contactName}':settlement.description,userId:settlement.userId,userName:settlement.userName,dateMillis:settlement.dateMillis,lines:settlement.type=='RECEIPT'?[{'accountId':cashAccountId,'accountCode':cashCode,'accountName':cashName,'debit':settlement.amount,'credit':0.0},{'accountId':a['1201']??0,'accountCode':'1201','accountName':'حساب‌های دریافتنی','debit':0.0,'credit':settlement.amount}]:[{'accountId':a['2101']??0,'accountCode':'2101','accountName':'حساب‌های پرداختنی','debit':settlement.amount,'credit':0.0},{'accountId':cashAccountId,'accountCode':cashCode,'accountName':cashName,'debit':0.0,'credit':settlement.amount}]);
    });
  }

  Future<void> deleteJournalEntry(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final rows = await txn.query('journal_entries', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;
      final sourceType = rows.first['sourceType']?.toString() ?? 'MANUAL';
      if (sourceType != 'MANUAL') {
        throw StateError('این سند از عملیات اصلی برنامه ایجاد شده است؛ برای حفظ تراز، آن را از همان عملیات اصلی حذف یا اصلاح کنید.');
      }
      await txn.delete('journal_lines', where: 'journalId = ?', whereArgs: [id]);
      await txn.delete('journal_entries', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteAllJournalEntries({bool manualOnly = false}) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final rows = await txn.query('journal_entries', columns: ['id','sourceType'], where: manualOnly ? 'sourceType = ?' : null, whereArgs: manualOnly ? ['MANUAL'] : null);
      for (final r in rows) {
        final id = (r['id'] as num).toInt();
        await txn.delete('journal_lines', where: 'journalId = ?', whereArgs: [id]);
      }
      await txn.delete('journal_entries', where: manualOnly ? 'sourceType = ?' : null, whereArgs: manualOnly ? ['MANUAL'] : null);
    });
  }

  Future<void> deleteCashBankAccount(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final rows = await txn.query('cash_bank_accounts', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;
      final ledgerId = (rows.first['ledgerAccountId'] as num?)?.toInt() ?? 0;
      final refs = await txn.query('settlements', where: 'cashBankId = ?', whereArgs: [id], limit: 1);
      final checks = await txn.query('checks', where: 'cashBankId = ?', whereArgs: [id], limit: 1);
      final recon = await txn.query('bank_reconciliations', where: 'cashBankId = ?', whereArgs: [id], limit: 1);
      if (refs.isNotEmpty || checks.isNotEmpty || recon.isNotEmpty) throw StateError('این حساب در سوابق مالی استفاده شده است؛ ابتدا سوابق وابسته را حذف کنید.');
      await txn.delete('cash_bank_accounts', where: 'id = ?', whereArgs: [id]);
      if (ledgerId > 0) {
        final used = await txn.query('journal_lines', where: 'accountId = ?', whereArgs: [ledgerId], limit: 1);
        if (used.isEmpty) await txn.delete('chart_accounts', where: 'id = ?', whereArgs: [ledgerId]);
      }
    });
  }

  Future<void> deleteChartAccount(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final used = await txn.query('journal_lines', where: 'accountId = ?', whereArgs: [id], limit: 1);
      if (used.isNotEmpty) throw StateError('این حساب در سندهای حسابداری استفاده شده و قابل حذف نیست.');
      final linked = await txn.query('cash_bank_accounts', where: 'ledgerAccountId = ?', whereArgs: [id], limit: 1);
      if (linked.isNotEmpty) throw StateError('ابتدا حساب صندوق/بانک مرتبط را حذف کنید.');
      await txn.delete('chart_accounts', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deletePayroll(int id) async {
    final db = await _db.database;
    final rows = await db.query('payroll_records', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    if ((rows.first['paid'] as num? ?? 0) == 1) throw StateError('حقوق پرداخت‌شده را از اینجا نمی‌توان حذف کرد؛ ابتدا سند پرداخت را اصلاح کنید.');
    await db.delete('payroll_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllPayroll() async {
    final db = await _db.database;
    await db.delete('payroll_records', where: 'paid = 0');
  }

  Future<void> deleteWarehouse(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final stock = await txn.query('warehouse_stock', where: 'warehouseId = ?', whereArgs: [id], limit: 1);
      if (stock.isNotEmpty) throw StateError('این انبار دارای موجودی ثبت‌شده است.');
      await txn.delete('warehouses', where: 'id = ?', whereArgs: [id]);
    });
  }
  Future<void> deletePriceList(int id) async { final db=await _db.database; await db.delete('product_prices', where:'priceListId = ?', whereArgs:[id]); await db.delete('price_lists', where:'id = ?', whereArgs:[id]); }
  Future<void> deleteSerial(int id) async { final db=await _db.database; await db.delete('serial_numbers', where:'id = ?', whereArgs:[id]); }
  Future<void> deleteTaxRule(int id) async { final db=await _db.database; await db.delete('tax_rules', where:'id = ?', whereArgs:[id]); }
  Future<void> deleteCostCenter(int id) async { final db=await _db.database; await db.delete('cost_centers', where:'id = ?', whereArgs:[id]); }
  Future<void> deleteAllBankReconciliations() async { final db=await _db.database; await db.delete('bank_reconciliations'); }
  Future<void> deleteAllInstallments() async { final db=await _db.database; await db.delete('installments'); }
  Future<void> deleteAllWarehouses() async { final db=await _db.database; await db.delete('warehouses'); }
  Future<void> deleteAllPriceLists() async { final db=await _db.database; await db.delete('product_prices'); await db.delete('price_lists'); }
  Future<void> deleteAllSerials() async { final db=await _db.database; await db.delete('serial_numbers'); }
  Future<void> deleteAllTaxRules() async { final db=await _db.database; await db.delete('tax_rules'); }
  Future<void> deleteAllCostCenters() async { final db=await _db.database; await db.delete('cost_centers'); }

  Future<List<CheckRecord>> getChecks({String? type, String? status}) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <dynamic>[];
    if (type != null) { where.add('type = ?'); args.add(type); }
    if (status != null) { where.add('status = ?'); args.add(status); }
    final rows = await db.query('checks', where: where.isEmpty ? null : where.join(' AND '), whereArgs: args.isEmpty ? null : args, orderBy: 'dueDateMillis ASC, id DESC');
    return rows.map(CheckRecord.fromMap).toList();
  }

  Future<int> saveCheck(CheckRecord item) async {
    final db = await _db.database;
    if (item.id == 0) return db.insert('checks', item.toMap());
    await db.update('checks', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item.id;
  }

  Future<void> updateCheckStatus(int id, String status, {int? clearedDateMillis, int? settlementId}) async {
    final db = await _db.database;
    await db.update('checks', {
      'status': status,
      'clearedDateMillis': clearedDateMillis,
      'settlementId': settlementId,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<InstallmentRecord>> getInstallments({String? status}) async {
    final db = await _db.database;
    final rows = await db.query('installments', where: status == null ? null : 'status = ?', whereArgs: status == null ? null : [status], orderBy: 'dueDateMillis ASC');
    return rows.map(InstallmentRecord.fromMap).toList();
  }

  Future<int> saveInstallment(InstallmentRecord item) async {
    final db = await _db.database;
    if (item.id == 0) return db.insert('installments', item.toMap());
    await db.update('installments', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item.id;
  }

  Future<void> applyInstallmentPayment(int installmentId, double amount) async {
    if (amount <= 0) throw ArgumentError('مبلغ قسط باید بیشتر از صفر باشد.');
    final db = await _db.database;
    await db.transaction((txn) async {
      final rows = await txn.query('installments', where: 'id = ?', whereArgs: [installmentId], limit: 1);
      if (rows.isEmpty) throw StateError('قسط پیدا نشد.');
      final r = rows.first;
      final total = (r['amount'] as num?)?.toDouble() ?? 0;
      final paid = (r['paidAmount'] as num?)?.toDouble() ?? 0;
      final next = (paid + amount).clamp(0.0, total).toDouble();
      await txn.update('installments', {'paidAmount': next, 'status': next >= total ? 'PAID' : 'PARTIAL'}, where: 'id = ?', whereArgs: [installmentId]);
    });
  }

  Future<List<BankReconciliation>> getBankReconciliations({int? cashBankId}) async {
    final db = await _db.database;
    final rows = await db.query('bank_reconciliations', where: cashBankId == null ? null : 'cashBankId = ?', whereArgs: cashBankId == null ? null : [cashBankId], orderBy: 'statementDateMillis DESC');
    return rows.map(BankReconciliation.fromMap).toList();
  }

  Future<int> saveBankReconciliation(BankReconciliation item) async {
    final db = await _db.database;
    if (item.id == 0) return db.insert('bank_reconciliations', item.toMap());
    await db.update('bank_reconciliations', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item.id;
  }

  Future<List<Map<String, dynamic>>> getBankStatementLines(int cashBankId) async {
    final db = await _db.database;
    return db.query('bank_statement_lines', where: 'cashBankId = ?', whereArgs: [cashBankId], orderBy: 'statementDateMillis DESC, id DESC');
  }

  Future<int> addBankStatementLine({required int cashBankId, required int statementDateMillis, required double amount, String description = '', String reference = ''}) async {
    final db = await _db.database;
    return db.insert('bank_statement_lines', {
      'cashBankId': cashBankId,
      'statementDateMillis': statementDateMillis,
      'amount': amount,
      'description': description,
      'reference': reference,
      'matched': 0,
    });
  }

  Future<void> matchBankStatementLine(int id, {int? journalLineId}) async {
    final db = await _db.database;
    await db.update('bank_statement_lines', {'matched': 1, 'journalLineId': journalLineId}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WarehouseRecord>> getWarehouses() async {
    final db = await _db.database;
    final rows = await db.query('warehouses', where: 'isActive = 1', orderBy: 'isDefault DESC, name ASC');
    return rows.map(WarehouseRecord.fromMap).toList();
  }

  Future<int> saveWarehouse(WarehouseRecord item) async {
    final db = await _db.database;
    return db.transaction<int>((txn) async {
      if (item.isDefault) {
        await txn.update('warehouses', {'isDefault': 0});
      }
      if (item.id == 0) return txn.insert('warehouses', item.toMap());
      await txn.update('warehouses', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
      return item.id;
    });
  }

  Future<List<WarehouseStock>> getWarehouseStock(int warehouseId) async {
    final db = await _db.database;
    final rows = await db.query('warehouse_stock', where: 'warehouseId = ?', whereArgs: [warehouseId]);
    return rows.map(WarehouseStock.fromMap).toList();
  }

  Future<void> setWarehouseStock({required int warehouseId, required int productId, required double quantity}) async {
    final db = await _db.database;
    await db.insert('warehouse_stock', {'warehouseId': warehouseId, 'productId': productId, 'quantity': quantity}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PriceListRecord>> getPriceLists() async {
    final db = await _db.database;
    final rows = await db.query('price_lists', where: 'isActive = 1', orderBy: 'isDefault DESC, name ASC');
    return rows.map(PriceListRecord.fromMap).toList();
  }

  Future<int> savePriceList(PriceListRecord item) async {
    final db = await _db.database;
    return db.transaction<int>((txn) async {
      if (item.isDefault) await txn.update('price_lists', {'isDefault': 0});
      if (item.id == 0) return txn.insert('price_lists', item.toMap());
      await txn.update('price_lists', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
      return item.id;
    });
  }

  Future<List<ProductPriceRecord>> getProductPrices(int priceListId) async {
    final db = await _db.database;
    final rows = await db.query('product_prices', where: 'priceListId = ?', whereArgs: [priceListId]);
    return rows.map(ProductPriceRecord.fromMap).toList();
  }

  Future<int> saveProductPrice(ProductPriceRecord item) async {
    final db = await _db.database;
    return db.insert('product_prices', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SerialNumberRecord>> getSerials({int? productId, String? status}) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <dynamic>[];
    if (productId != null) { where.add('productId = ?'); args.add(productId); }
    if (status != null) { where.add('status = ?'); args.add(status); }
    final rows = await db.query('serial_numbers', where: where.isEmpty ? null : where.join(' AND '), whereArgs: args.isEmpty ? null : args, orderBy: 'id DESC');
    return rows.map(SerialNumberRecord.fromMap).toList();
  }

  Future<int> saveSerial(SerialNumberRecord item) async {
    final db = await _db.database;
    if (item.id == 0) return db.insert('serial_numbers', item.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
    await db.update('serial_numbers', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item.id;
  }

  Future<List<TaxRuleRecord>> getTaxRules() async {
    final db = await _db.database;
    final rows = await db.query('tax_rules', where: 'isActive = 1', orderBy: 'code ASC');
    return rows.map(TaxRuleRecord.fromMap).toList();
  }

  Future<int> saveTaxRule(TaxRuleRecord item) async {
    final db = await _db.database;
    if (item.id == 0) return db.insert('tax_rules', item.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
    await db.update('tax_rules', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item.id;
  }

  Future<List<CostCenterRecord>> getCostCenters() async {
    final db = await _db.database;
    final rows = await db.query('cost_centers', where: 'isActive = 1', orderBy: 'code ASC');
    return rows.map(CostCenterRecord.fromMap).toList();
  }

  Future<int> saveCostCenter(CostCenterRecord item) async {
    final db = await _db.database;
    if (item.id == 0) return db.insert('cost_centers', item.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
    await db.update('cost_centers', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item.id;
  }

  Future<Map<String, double>> getAccountBalance(int accountId, {int? startMillis, int? endMillis}) async {
    final rows = await getGeneralLedger(accountId: accountId, startMillis: startMillis, endMillis: endMillis);
    double debit = 0, credit = 0;
    for (final r in rows) {
      debit += (r['debit'] as num?)?.toDouble() ?? 0;
      credit += (r['credit'] as num?)?.toDouble() ?? 0;
    }
    return {'debit': debit, 'credit': credit, 'balance': debit - credit};
  }

  Future<List<Map<String, dynamic>>> getReceivableAgingByInvoice() async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.rawQuery("""
      SELECT t.id invoiceId, t.contactId, t.contactName, t.finalAmount, t.debtAmount, t.dateMillis
      FROM transactions t
      WHERE t.type = 'SALE' AND t.debtAmount > 0
      ORDER BY t.dateMillis ASC
    """);
    return rows.map((r) {
      final age = ((now - ((r['dateMillis'] as num?)?.toInt() ?? now)) / Duration.millisecondsPerDay).floor();
      final bucket = age <= 30 ? '0-30' : age <= 60 ? '31-60' : age <= 90 ? '61-90' : '90+';
      return {...r, 'ageDays': age, 'bucket': bucket};
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getPayableAgingByInvoice() async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.rawQuery("""
      SELECT t.id invoiceId, t.contactId, t.contactName, t.finalAmount, t.debtAmount, t.dateMillis
      FROM transactions t
      WHERE t.type = 'PURCHASE' AND t.debtAmount > 0
      ORDER BY t.dateMillis ASC
    """);
    return rows.map((r) {
      final age = ((now - ((r['dateMillis'] as num?)?.toInt() ?? now)) / Duration.millisecondsPerDay).floor();
      final bucket = age <= 30 ? '0-30' : age <= 60 ? '31-60' : age <= 90 ? '61-90' : '90+';
      return {...r, 'ageDays': age, 'bucket': bucket};
    }).toList();
  }


  // ========================================================================
  // عملیات تجاری تکمیلی - آفلاین
  // ========================================================================
  Future<List<Map<String, dynamic>>> getInvoicePayments(int transactionId) async {
    final db = await _db.database;
    return db.query('invoice_payments', where: 'transactionId = ?', whereArgs: [transactionId], orderBy: 'dateMillis DESC');
  }

  Future<int> allocateInvoicePayment({required int transactionId, int? settlementId, required double amount, String note = ''}) async {
    if (amount <= 0) throw ArgumentError('مبلغ پرداخت باید بیشتر از صفر باشد.');
    final db = await _db.database;
    return db.transaction<int>((txn) async {
      final inv = await txn.query('transactions', where: 'id = ?', whereArgs: [transactionId], limit: 1);
      if (inv.isEmpty) throw StateError('فاکتور پیدا نشد.');
      final total = (inv.first['finalAmount'] as num?)?.toDouble() ?? 0;
      final paid = (inv.first['paidAmount'] as num?)?.toDouble() ?? 0;
      final debt = (inv.first['debtAmount'] as num?)?.toDouble() ?? 0;
      if (amount > debt + 0.01) throw StateError('مبلغ تسویه بیشتر از مانده فاکتور است.');
      final id = await txn.insert('invoice_payments', {'transactionId':transactionId,'settlementId':settlementId,'amount':amount,'dateMillis':DateTime.now().millisecondsSinceEpoch,'note':note});
      final nextPaid = (paid + amount).clamp(0.0, total).toDouble();
      final nextDebt = (debt - amount).clamp(0.0, double.infinity).toDouble();
      await txn.update('transactions', {'paidAmount': nextPaid, 'debtAmount': nextDebt}, where: 'id = ?', whereArgs: [transactionId]);
      return id;
    });
  }

  Future<List<Map<String, dynamic>>> getServiceItems({
    String? businessCode,
  }) async {
    final db = await _db.database;
    final code = businessCode?.trim();

    if (code == null || code.isEmpty) {
      return db.query(
        'service_items',
        where: 'isActive = 1',
        orderBy: 'businessCode ASC, category ASC, name ASC',
      );
    }

    return db.query(
      'service_items',
      where: 'isActive = 1 AND businessCode = ?',
      whereArgs: <dynamic>[code],
      orderBy: 'category ASC, name ASC',
    );
  }

  Future<int> saveServiceItem(Map<String, dynamic> item) async {
    final db = await _db.database;
    final copy = Map<String, dynamic>.from(item);
    final id = (copy['id'] as num?)?.toInt() ?? 0;

    final businessCode = copy['businessCode']?.toString().trim() ?? '';
    final name = copy['name']?.toString().trim() ?? '';
    final category = copy['category']?.toString().trim() ?? '';
    final unitValue = copy['unit']?.toString().trim() ?? '';
    final note = copy['note']?.toString().trim() ?? '';
    final sellPrice = (copy['sellPrice'] as num?)?.toDouble() ?? 0.0;
    final costPrice = (copy['costPrice'] as num?)?.toDouble() ?? 0.0;
    final taxRate = (copy['taxRate'] as num?)?.toDouble() ?? 0.0;
    final isActive = (copy['isActive'] as num?)?.toInt() ?? 1;

    if (name.isEmpty) {
      throw ArgumentError('نام خدمت نمی‌تواند خالی باشد.');
    }
    if (!sellPrice.isFinite || sellPrice < 0) {
      throw ArgumentError('قیمت فروش معتبر نیست.');
    }
    if (!costPrice.isFinite || costPrice < 0) {
      throw ArgumentError('قیمت تمام‌شده معتبر نیست.');
    }
    if (!taxRate.isFinite || taxRate < 0) {
      throw ArgumentError('مالیات معتبر نیست.');
    }

    final values = <String, dynamic>{
      'businessCode': businessCode.isEmpty ? 'GENERAL' : businessCode,
      'name': name,
      'category': category,
      'sellPrice': sellPrice,
      'costPrice': costPrice,
      'unit': unitValue.isEmpty ? 'خدمت' : unitValue,
      'taxRate': taxRate,
      'isActive': isActive,
      'note': note,
    };

    if (id == 0) {
      return db.insert(
        'service_items',
        values,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }

    await db.update(
      'service_items',
      values,
      where: 'id = ?',
      whereArgs: <dynamic>[id],
    );
    return id;
  }
  Future<List<Map<String,dynamic>>> getInventoryBatches({int? productId,int? warehouseId}) async { final db=await _db.database; final w=<String>[]; final a=<dynamic>[]; if(productId!=null){w.add('productId = ?');a.add(productId);} if(warehouseId!=null){w.add('warehouseId = ?');a.add(warehouseId);} return db.query('inventory_batches', where:w.isEmpty?null:w.join(' AND '), whereArgs:a.isEmpty?null:a, orderBy:'expiryMillis ASC, id DESC'); }
  Future<int> saveInventoryBatch(Map<String,dynamic> item) async { final db=await _db.database; return db.insert('inventory_batches', item, conflictAlgorithm:ConflictAlgorithm.replace); }
  Future<List<Map<String,dynamic>>> getSalesOrders({String? status}) async { final db=await _db.database; return db.query('sales_orders', where:status==null?null:'status = ?', whereArgs:status==null?null:[status], orderBy:'dateMillis DESC'); }
  Future<int> saveSalesOrder(Map<String,dynamic> order,List<Map<String,dynamic>> items) async { final db=await _db.database; return db.transaction<int>((txn) async { final id=await txn.insert('sales_orders',order,conflictAlgorithm:ConflictAlgorithm.replace); for(final it in items){await txn.insert('order_items',{...it,'orderType':'SALE_ORDER','orderId':id});} return id; }); }
  Future<List<Map<String,dynamic>>> getPurchaseOrders({String? status}) async { final db=await _db.database; return db.query('purchase_orders', where:status==null?null:'status = ?', whereArgs:status==null?null:[status], orderBy:'dateMillis DESC'); }
  Future<int> savePurchaseOrder(Map<String,dynamic> order,List<Map<String,dynamic>> items) async { final db=await _db.database; return db.transaction<int>((txn) async { final id=await txn.insert('purchase_orders',order,conflictAlgorithm:ConflictAlgorithm.replace); for(final it in items){await txn.insert('order_items',{...it,'orderType':'PURCHASE_ORDER','orderId':id});} return id; }); }
  Future<List<Map<String,dynamic>>> getRecurringExpenses() async { final db=await _db.database; return db.query('recurring_expenses', where:'isActive = 1', orderBy:'nextDueMillis ASC'); }
  Future<int> saveRecurringExpense(Map<String,dynamic> item) async { final db=await _db.database; return db.insert('recurring_expenses',item,conflictAlgorithm:ConflictAlgorithm.replace); }
  Future<int> saveCashCount({required int cashBankId,required double countedAmount,required double bookAmount,String note='',int userId=0,String userName=''}) async { final db=await _db.database; final diff=countedAmount-bookAmount; return db.insert('cash_counts',{'cashBankId':cashBankId,'countedAmount':countedAmount,'bookAmount':bookAmount,'difference':diff,'dateMillis':DateTime.now().millisecondsSinceEpoch,'userId':userId,'userName':userName,'note':note}); }
  Future<List<Map<String,dynamic>>> getCashCounts(int cashBankId) async { final db=await _db.database; return db.query('cash_counts',where:'cashBankId = ?',whereArgs:[cashBankId],orderBy:'dateMillis DESC'); }
  Future<int> saveOpeningBalance({required int fiscalYearId,required int accountId,double debit=0,double credit=0,String description=''}) async { if(debit<0||credit<0||(debit==0&&credit==0)) throw StateError('مانده افتتاحیه نامعتبر است.'); final db=await _db.database; return db.insert('opening_balances',{'fiscalYearId':fiscalYearId,'accountId':accountId,'debit':debit,'credit':credit,'description':description,'createdAt':DateTime.now().millisecondsSinceEpoch}); }
  Future<Map<String,double>> getCurrentBalances() async { final db=await _db.database; final rows=await db.rawQuery("SELECT ca.type, SUM(jl.debit-jl.credit) balance FROM chart_accounts ca JOIN journal_lines jl ON jl.accountId=ca.id JOIN journal_entries je ON je.id=jl.journalId WHERE je.posted=1 GROUP BY ca.type"); final out=<String,double>{}; for(final r in rows){out[r['type'].toString()]=(r['balance'] as num?)?.toDouble()??0;} return out; }
  Future<void> setSetting(String key,String value) async { final db=await _db.database; await db.insert('app_settings',{'key':key,'value':value},conflictAlgorithm:ConflictAlgorithm.replace); }
  Future<String?> getSetting(String key) async { final db=await _db.database; final r=await db.query('app_settings',where:'key = ?',whereArgs:[key],limit:1); return r.isEmpty?null:r.first['value'] as String?; }

}

extension JournalLineCopy on JournalLine {
  JournalLine copyWithJournalId(int journalId) => JournalLine(
    id: id, journalId: journalId, accountId: accountId, accountCode: accountCode,
    accountName: accountName, debit: debit, credit: credit, description: description,
  );
}
