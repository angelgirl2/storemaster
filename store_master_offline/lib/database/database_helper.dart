// ============================================================================
// DatabaseHelper - معادل AppDatabase با تمام Migrations 1→7
// ============================================================================
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/local_device_identity.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  DatabaseHelper._();

  Database? _db;
  static const int _version = 26;
  static const String _dbName = 'storemaster_database.db';

  Future<String> get databasePath async => await _resolvePath();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<String> _resolvePath() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      final dir = await getApplicationDocumentsDirectory();
      return p.join(dir.path, _dbName);
    }
    final dir = await getDatabasesPath();
    return p.join(dir, _dbName);
  }

  Future<Database> _init() async {
    final path = await _resolvePath();
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: _version,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    }
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''CREATE TABLE store_config (
      id INTEGER PRIMARY KEY, storeName TEXT, storeType TEXT, businessTitle TEXT DEFAULT 'فروشگاه', logoBase64 TEXT DEFAULT '', colorTheme TEXT,
      currency TEXT, taxPercentage REAL DEFAULT 0.0, isConfigured INTEGER DEFAULT 0,
      autoBackupEnabled INTEGER DEFAULT 1, layoutStyle TEXT DEFAULT 'GRID',
      lastBackupTimestamp INTEGER, morningStartHour INTEGER DEFAULT 6,
      morningEndHour INTEGER DEFAULT 15, eveningStartHour INTEGER DEFAULT 15,
      eveningEndHour INTEGER DEFAULT 24, isDarkMode INTEGER DEFAULT 0,
      storePhone TEXT DEFAULT '', profitCoefficient REAL DEFAULT 0.22,
      endShiftAlertTime TEXT DEFAULT '21:00',
      printPaperSize TEXT DEFAULT 'A4',
      printOrientation TEXT DEFAULT 'PORTRAIT',
      printMarginMm REAL DEFAULT 8.0,
      customPaperWidthMm REAL DEFAULT 210.0,
      customPaperHeightMm REAL DEFAULT 297.0
    )''');

    await db.execute('''CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, pin TEXT, role TEXT,
      phone TEXT DEFAULT '', isActive INTEGER DEFAULT 1, createdAt INTEGER,
      baseSalary REAL DEFAULT 0.0, commissionPercent REAL DEFAULT 0.0,
      totalSalesAmount REAL DEFAULT 0.0, totalCommission REAL DEFAULT 0.0,
      storeId INTEGER DEFAULT 0, serverUserId INTEGER DEFAULT 0, permissions TEXT DEFAULT ''
    )''');

    await db.execute('''CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, barcode TEXT DEFAULT '',
      category TEXT, buyPrice REAL, sellPrice REAL, stockQuantity REAL,
      unit TEXT DEFAULT 'عدد', isService INTEGER DEFAULT 0, minStockAlert REAL DEFAULT 5.0, note TEXT DEFAULT '',
      updatedAt INTEGER
    )''');

    await db.execute('''CREATE TABLE product_categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL DEFAULT '',
      createdAt INTEGER NOT NULL
    )''');

    await db.execute('''CREATE TABLE contacts (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, phone TEXT DEFAULT '',
      address TEXT DEFAULT '', type TEXT DEFAULT 'CUSTOMER',
      totalDebt REAL DEFAULT 0.0, totalPayable REAL DEFAULT 0.0,
      note TEXT DEFAULT '', updatedAt INTEGER
    )''');

    await db.execute('''CREATE TABLE expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL,
      category TEXT, dateMillis INTEGER, userId INTEGER, userName TEXT,
      note TEXT DEFAULT ''
    )''');

    await db.execute('''CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT, invoiceNumber TEXT NOT NULL DEFAULT '', type TEXT, totalAmount REAL,
      discount REAL DEFAULT 0.0, finalAmount REAL, paidAmount REAL,
      debtAmount REAL DEFAULT 0.0, paymentMethod TEXT DEFAULT 'CASH',
      contactId INTEGER, contactName TEXT DEFAULT '', taxBase REAL DEFAULT 0, taxAmount REAL DEFAULT 0, priceListId INTEGER, warehouseId INTEGER, returnOfId INTEGER, returnType TEXT DEFAULT '',
      userId INTEGER, userName TEXT, dateMillis INTEGER, note TEXT DEFAULT ''
    )''');

    await db.execute('''CREATE TABLE transaction_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT, transactionId INTEGER,
      productId INTEGER, productName TEXT, quantity REAL,
      unitPrice REAL, costPrice REAL, totalPrice REAL
    )''');

    await db.execute('''CREATE TABLE audit_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT, userId INTEGER, userName TEXT,
      userRole TEXT, action TEXT, details TEXT, timestamp INTEGER
    )''');

    await db.execute('''CREATE TABLE stock_movements (
      id INTEGER PRIMARY KEY AUTOINCREMENT, productId INTEGER, productName TEXT,
      type TEXT, quantity REAL, unit TEXT DEFAULT 'عدد',
      pricePerUnit REAL DEFAULT 0.0, totalPrice REAL DEFAULT 0.0,
      partyName TEXT DEFAULT '', refNumber TEXT DEFAULT '',
      dateMillis INTEGER, userId INTEGER, userName TEXT, note TEXT DEFAULT ''
    )''');

    await db.execute('''CREATE TABLE attendance_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT, userId INTEGER, userName TEXT,
      dateMillis INTEGER, clockInTime INTEGER, clockOutTime INTEGER,
      shiftType TEXT DEFAULT 'MORNING', status TEXT DEFAULT 'PRESENT',
      note TEXT DEFAULT '', overtimeMinutes INTEGER DEFAULT 0
    )''');

    await db.execute('''CREATE TABLE chart_accounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL, type TEXT NOT NULL, parentId INTEGER,
      isCashOrBank INTEGER DEFAULT 0, isActive INTEGER DEFAULT 1
    )''');
    await db.execute('''CREATE TABLE journal_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT, number TEXT NOT NULL UNIQUE,
      dateMillis INTEGER NOT NULL, description TEXT DEFAULT '',
      sourceType TEXT DEFAULT 'MANUAL', sourceId INTEGER,
      userId INTEGER DEFAULT 0, userName TEXT DEFAULT '', posted INTEGER DEFAULT 1
    )''');
    await db.execute('''CREATE TABLE journal_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT, journalId INTEGER NOT NULL,
      accountId INTEGER NOT NULL, accountCode TEXT, accountName TEXT,
      debit REAL DEFAULT 0, credit REAL DEFAULT 0, description TEXT DEFAULT ''
    )''');
    await db.execute('''CREATE TABLE cash_bank_accounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      type TEXT NOT NULL, bankName TEXT DEFAULT '', accountNumber TEXT DEFAULT '',
      openingBalance REAL DEFAULT 0, ledgerAccountId INTEGER NOT NULL,
      isActive INTEGER DEFAULT 1
    )''');
    await db.execute('''CREATE TABLE settlements (
      id INTEGER PRIMARY KEY AUTOINCREMENT, contactId INTEGER, contactName TEXT,
      type TEXT NOT NULL, amount REAL NOT NULL, cashBankId INTEGER,
      cashBankName TEXT, dateMillis INTEGER NOT NULL, description TEXT DEFAULT '',
      userId INTEGER DEFAULT 0, userName TEXT DEFAULT ''
    )''');
    await db.execute('''CREATE TABLE payroll_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT, userId INTEGER NOT NULL,
      userName TEXT NOT NULL, periodYear INTEGER NOT NULL, periodMonth INTEGER NOT NULL,
      baseSalary REAL DEFAULT 0, commission REAL DEFAULT 0, overtime REAL DEFAULT 0,
      deductions REAL DEFAULT 0, netSalary REAL DEFAULT 0, paid INTEGER DEFAULT 0,
      paidDateMillis INTEGER
    )''');
    await db.execute('''CREATE TABLE tax_reports (
      id INTEGER PRIMARY KEY AUTOINCREMENT, year INTEGER NOT NULL,
      month INTEGER NOT NULL, sales REAL DEFAULT 0, purchases REAL DEFAULT 0,
      expenses REAL DEFAULT 0, taxRate REAL DEFAULT 0, taxAmount REAL DEFAULT 0,
      createdAt INTEGER NOT NULL
    )''');

    await db.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_invoice_number ON transactions(invoiceNumber) WHERE TRIM(invoiceNumber) <> ''");

    await _createCommercialTables(db);
    await _createEnterpriseTables(db);
    await _createSyncInfrastructure(db);
  }

  Future<void> _createCommercialTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS fiscal_years (
      id INTEGER PRIMARY KEY AUTOINCREMENT, year INTEGER NOT NULL UNIQUE,
      startMillis INTEGER NOT NULL, endMillis INTEGER NOT NULL,
      isClosed INTEGER DEFAULT 0
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS checks (
      id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, contactId INTEGER,
      contactName TEXT DEFAULT '', number TEXT NOT NULL, amount REAL NOT NULL,
      dueDateMillis INTEGER NOT NULL, bankName TEXT DEFAULT '', status TEXT DEFAULT 'PENDING',
      cashBankId INTEGER, settlementId INTEGER, clearedDateMillis INTEGER,
      description TEXT DEFAULT '', userId INTEGER DEFAULT 0, userName TEXT DEFAULT ''
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS installments (
      id INTEGER PRIMARY KEY AUTOINCREMENT, transactionId INTEGER NOT NULL, contactId INTEGER,
      contactName TEXT DEFAULT '', dueDateMillis INTEGER NOT NULL, amount REAL NOT NULL,
      paidAmount REAL DEFAULT 0, status TEXT DEFAULT 'OPEN', description TEXT DEFAULT ''
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS bank_reconciliations (
      id INTEGER PRIMARY KEY AUTOINCREMENT, cashBankId INTEGER NOT NULL,
      statementDateMillis INTEGER NOT NULL, statementBalance REAL NOT NULL,
      bookBalance REAL NOT NULL, difference REAL NOT NULL, status TEXT DEFAULT 'OPEN',
      notes TEXT DEFAULT '', userId INTEGER DEFAULT 0, userName TEXT DEFAULT ''
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS warehouses (
      id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL UNIQUE, name TEXT NOT NULL,
      location TEXT DEFAULT '', isDefault INTEGER DEFAULT 0, isActive INTEGER DEFAULT 1
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS warehouse_stock (
      id INTEGER PRIMARY KEY AUTOINCREMENT, warehouseId INTEGER NOT NULL,
      productId INTEGER NOT NULL, quantity REAL DEFAULT 0,
      UNIQUE(warehouseId, productId)
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS price_lists (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      isDefault INTEGER DEFAULT 0, isActive INTEGER DEFAULT 1
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS product_prices (
      id INTEGER PRIMARY KEY AUTOINCREMENT, priceListId INTEGER NOT NULL,
      productId INTEGER NOT NULL, price REAL NOT NULL,
      UNIQUE(priceListId, productId)
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS serial_numbers (
      id INTEGER PRIMARY KEY AUTOINCREMENT, productId INTEGER NOT NULL, serial TEXT NOT NULL UNIQUE,
      status TEXT DEFAULT 'AVAILABLE', warehouseId INTEGER, transactionId INTEGER
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS tax_rules (
      id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL UNIQUE, name TEXT NOT NULL,
      rate REAL NOT NULL, type TEXT DEFAULT 'VAT', isActive INTEGER DEFAULT 1
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS cost_centers (
      id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL UNIQUE, name TEXT NOT NULL,
      isActive INTEGER DEFAULT 1
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS fiscal_closing_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT, fiscalYearId INTEGER NOT NULL,
      journalId INTEGER NOT NULL, createdAt INTEGER NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS bank_statement_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT, cashBankId INTEGER NOT NULL,
      statementDateMillis INTEGER NOT NULL, amount REAL NOT NULL, description TEXT DEFAULT '',
      reference TEXT DEFAULT '', matched INTEGER DEFAULT 0, journalLineId INTEGER
    )''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_checks_due ON checks(dueDateMillis, status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_installments_due ON installments(dueDateMillis, status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_serial_product ON serial_numbers(productId, status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wh_stock ON warehouse_stock(warehouseId, productId)');
  }

  Future<void> _createEnterpriseTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS app_settings (
      key TEXT PRIMARY KEY, value TEXT NOT NULL DEFAULT ''
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS invoice_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT, transactionId INTEGER NOT NULL,
      settlementId INTEGER, amount REAL NOT NULL, dateMillis INTEGER NOT NULL,
      note TEXT DEFAULT ''
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS inventory_batches (
      id INTEGER PRIMARY KEY AUTOINCREMENT, productId INTEGER NOT NULL,
      warehouseId INTEGER, batchNumber TEXT DEFAULT '', expiryMillis INTEGER,
      quantity REAL DEFAULT 0, unitCost REAL DEFAULT 0, createdAt INTEGER NOT NULL,
      isActive INTEGER DEFAULT 1
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS service_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  businessCode TEXT NOT NULL DEFAULT 'GENERAL',
  name TEXT NOT NULL,
  category TEXT DEFAULT '',
  sellPrice REAL DEFAULT 0,
  costPrice REAL DEFAULT 0,
  unit TEXT DEFAULT 'خدمت',
  taxRate REAL DEFAULT 0,
  isActive INTEGER DEFAULT 1,
  note TEXT DEFAULT ''
)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS sales_orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT, number TEXT NOT NULL UNIQUE,
      customerId INTEGER, customerName TEXT DEFAULT '', status TEXT DEFAULT 'DRAFT',
      totalAmount REAL DEFAULT 0, discount REAL DEFAULT 0, taxAmount REAL DEFAULT 0,
      finalAmount REAL DEFAULT 0, dateMillis INTEGER NOT NULL, dueDateMillis INTEGER,
      userId INTEGER DEFAULT 0, userName TEXT DEFAULT '', note TEXT DEFAULT ''
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS purchase_orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT, number TEXT NOT NULL UNIQUE,
      supplierId INTEGER, supplierName TEXT DEFAULT '', status TEXT DEFAULT 'DRAFT',
      totalAmount REAL DEFAULT 0, discount REAL DEFAULT 0, taxAmount REAL DEFAULT 0,
      finalAmount REAL DEFAULT 0, dateMillis INTEGER NOT NULL, dueDateMillis INTEGER,
      userId INTEGER DEFAULT 0, userName TEXT DEFAULT '', note TEXT DEFAULT ''
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS order_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT, orderType TEXT NOT NULL,
      orderId INTEGER NOT NULL, productId INTEGER, serviceId INTEGER,
      name TEXT DEFAULT '', quantity REAL DEFAULT 0, unitPrice REAL DEFAULT 0,
      totalPrice REAL DEFAULT 0
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS recurring_expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
      amount REAL NOT NULL, category TEXT DEFAULT '', frequency TEXT DEFAULT 'MONTHLY',
      nextDueMillis INTEGER NOT NULL, accountId INTEGER, isActive INTEGER DEFAULT 1,
      note TEXT DEFAULT ''
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS cash_counts (
      id INTEGER PRIMARY KEY AUTOINCREMENT, cashBankId INTEGER NOT NULL,
      countedAmount REAL NOT NULL, bookAmount REAL NOT NULL, difference REAL NOT NULL,
      dateMillis INTEGER NOT NULL, userId INTEGER DEFAULT 0, userName TEXT DEFAULT '',
      note TEXT DEFAULT ''
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS opening_balances (
      id INTEGER PRIMARY KEY AUTOINCREMENT, fiscalYearId INTEGER NOT NULL,
      accountId INTEGER NOT NULL, debit REAL DEFAULT 0, credit REAL DEFAULT 0,
      description TEXT DEFAULT '', createdAt INTEGER NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS account_parties (
      id INTEGER PRIMARY KEY AUTOINCREMENT, accountId INTEGER NOT NULL,
      partyType TEXT NOT NULL, partyId INTEGER NOT NULL,
      UNIQUE(accountId, partyType, partyId)
    )''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoice_payments_transaction ON invoice_payments(transactionId, dateMillis)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_batches_product ON inventory_batches(productId, warehouseId, expiryMillis)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_orders_date ON sales_orders(dateMillis, status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_purchase_orders_date ON purchase_orders(dateMillis, status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_recurring_due ON recurring_expenses(nextDueMillis, isActive)');
  }

  Future<void> _createSyncInfrastructure(Database db) async {
    await db.execute(
        "CREATE TABLE IF NOT EXISTS sync_flags (flag TEXT PRIMARY KEY, value TEXT NOT NULL DEFAULT '1')");
    await db.execute(
        "CREATE TABLE IF NOT EXISTS sync_outbox (id INTEGER PRIMARY KEY AUTOINCREMENT, entity TEXT NOT NULL, operation TEXT NOT NULL, entityId TEXT NOT NULL, payloadJson TEXT NOT NULL, sourceVersion INTEGER NOT NULL DEFAULT 0, createdAt INTEGER NOT NULL)");
    await db.execute("CREATE TABLE IF NOT EXISTS local_sync_log (id INTEGER PRIMARY KEY AUTOINCREMENT, originDeviceId TEXT NOT NULL, originSeq INTEGER NOT NULL, entity TEXT NOT NULL, operation TEXT NOT NULL, entityId TEXT NOT NULL, payloadJson TEXT NOT NULL, sourceVersion INTEGER NOT NULL DEFAULT 0, createdAt INTEGER NOT NULL, UNIQUE(originDeviceId, originSeq))");
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
    for (final row in tables) {
      final table = '${row['name']}';
      if ({'sync_flags', 'sync_outbox', 'local_sync_log'}.contains(table)) continue;
      final cols = await db.rawQuery('PRAGMA table_info("$table")');
      if (cols.isEmpty) continue;
      final names = cols.map((x) => '${x['name']}').toList();
      final pk = names.contains('id')
          ? 'id'
          : (cols.firstWhere((x) => (x['pk'] as num? ?? 0) > 0,
              orElse: () => cols.first)['name'] as String);
      // Version sync changes by the local mutation time, not the business date.
      // Otherwise editing a back-dated invoice could be ignored by the server.
      final versionParts = <String>["CAST(strftime('%s','now') AS INTEGER)*1000"];
      for (final candidate in ['updatedAt', 'createdAt', 'dateMillis', 'timestamp']) {
        if (names.contains(candidate)) {
          versionParts.add('COALESCE(NEW."$candidate", 0)');
        }
      }
      final ver = versionParts.length == 1
          ? versionParts.single
          : 'MAX(${versionParts.join(',')})';
      final jnew = names.map((n) => "'$n', NEW.\"$n\"").join(',');
      final settingGuard = table == 'app_settings'
          ? " AND COALESCE(NEW.key, '') NOT IN ('local_sync_device_id','license_payload','license_signature','license_last_clock','license_expired_latched','local_trial_payload')"
          : '';
      final deleteSettingGuard = table == 'app_settings'
          ? " AND COALESCE(OLD.key, '') NOT IN ('local_sync_device_id','license_payload','license_signature','license_last_clock','license_expired_latched','local_trial_payload')"
          : '';
      await db.execute('DROP TRIGGER IF EXISTS sync_${table}_insert');
      await db.execute('DROP TRIGGER IF EXISTS sync_${table}_update');
      await db.execute('DROP TRIGGER IF EXISTS sync_${table}_delete');
      await db.execute(
          "CREATE TRIGGER sync_${table}_insert AFTER INSERT ON \"$table\" WHEN NOT EXISTS(SELECT 1 FROM sync_flags WHERE flag='applying')$settingGuard BEGIN INSERT INTO sync_outbox(entity,operation,entityId,payloadJson,sourceVersion,createdAt) VALUES('$table','UPSERT',CAST(NEW.\"$pk\" AS TEXT),json_object($jnew),$ver,strftime('%s','now')*1000); INSERT INTO local_sync_log(originDeviceId,originSeq,entity,operation,entityId,payloadJson,sourceVersion,createdAt) VALUES((SELECT value FROM app_settings WHERE key='local_sync_device_id'),COALESCE((SELECT MAX(originSeq) FROM local_sync_log WHERE originDeviceId=(SELECT value FROM app_settings WHERE key='local_sync_device_id')),0)+1,'$table','UPSERT',CAST(NEW.\"$pk\" AS TEXT),json_object($jnew),$ver,strftime('%s','now')*1000); END");
      await db.execute(
          "CREATE TRIGGER sync_${table}_update AFTER UPDATE ON \"$table\" WHEN NOT EXISTS(SELECT 1 FROM sync_flags WHERE flag='applying')$settingGuard BEGIN INSERT INTO sync_outbox(entity,operation,entityId,payloadJson,sourceVersion,createdAt) VALUES('$table','UPSERT',CAST(NEW.\"$pk\" AS TEXT),json_object($jnew),$ver,strftime('%s','now')*1000); INSERT INTO local_sync_log(originDeviceId,originSeq,entity,operation,entityId,payloadJson,sourceVersion,createdAt) VALUES((SELECT value FROM app_settings WHERE key='local_sync_device_id'),COALESCE((SELECT MAX(originSeq) FROM local_sync_log WHERE originDeviceId=(SELECT value FROM app_settings WHERE key='local_sync_device_id')),0)+1,'$table','UPSERT',CAST(NEW.\"$pk\" AS TEXT),json_object($jnew),$ver,strftime('%s','now')*1000); END");
      await db.execute(
          "CREATE TRIGGER sync_${table}_delete AFTER DELETE ON \"$table\" WHEN NOT EXISTS(SELECT 1 FROM sync_flags WHERE flag='applying')$deleteSettingGuard BEGIN INSERT INTO sync_outbox(entity,operation,entityId,payloadJson,sourceVersion,createdAt) VALUES('$table','DELETE',CAST(OLD.\"$pk\" AS TEXT),'{}',strftime('%s','now')*1000,strftime('%s','now')*1000); INSERT INTO local_sync_log(originDeviceId,originSeq,entity,operation,entityId,payloadJson,sourceVersion,createdAt) VALUES((SELECT value FROM app_settings WHERE key='local_sync_device_id'),COALESCE((SELECT MAX(originSeq) FROM local_sync_log WHERE originDeviceId=(SELECT value FROM app_settings WHERE key='local_sync_device_id')),0)+1,'$table','DELETE',CAST(OLD.\"$pk\" AS TEXT),'{}',strftime('%s','now')*1000,strftime('%s','now')*1000); END");
    }
    final seeded = await db.query('sync_flags',
        where: 'flag=?', whereArgs: ['seeded'], limit: 1);
    if (seeded.isEmpty) {
      for (final row in tables) {
        final table = '${row['name']}';
        if ({'sync_flags', 'sync_outbox', 'local_sync_log', 'app_settings'}
            .contains(table)) continue;
        final cols = await db.rawQuery('PRAGMA table_info(\"$table\")');
        if (cols.isEmpty) continue;
        final names = cols.map((x) => '${x['name']}').toList();
        final pk = names.contains('id')
            ? 'id'
            : (cols.firstWhere((x) => (x['pk'] as num? ?? 0) > 0,
                orElse: () => cols.first)['name'] as String);
        final rows = await db.query(table);
        for (final r in rows) {
          final dynamic v = r['updatedAt'] ??
              r['createdAt'] ??
              r['dateMillis'] ??
              r['timestamp'] ??
              DateTime.now().millisecondsSinceEpoch;
          await db.insert('sync_outbox', {
            'entity': table,
            'operation': 'UPSERT',
            'entityId': '${r[pk]}',
            'payloadJson': jsonEncode(r),
            'sourceVersion': v is num
                ? v.toInt()
                : int.tryParse('$v') ?? DateTime.now().millisecondsSinceEpoch,
            'createdAt': DateTime.now().millisecondsSinceEpoch
          });
        }
      }
      await db.insert('sync_flags', {'flag': 'seeded', 'value': '1'},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await LocalDeviceIdentity.instance.reserveIdRange(db);
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 22) {
      try {
        await db.execute("UPDATE users SET permissions = permissions || CASE WHEN permissions IS NULL OR TRIM(permissions) = '' THEN '' ELSE '|' END || 'invoices_edit|invoices_delete' WHERE role IN ('SELLER','CASHIER') AND (permissions IS NULL OR permissions NOT LIKE '%invoices_edit%')");
      } catch (_) {}
    }
    if (oldV < 23) {
      try {
        await db.execute("UPDATE users SET permissions = CASE WHEN role IN ('SELLER','CASHIER') AND (permissions IS NULL OR TRIM(permissions)='') THEN 'dashboard_view|sales_create|customers_view|products_view|invoices_edit|invoices_delete|invoices_return' ELSE permissions END");
      } catch (_) {}
    }
    if (oldV < 21) {
      // تثبیت ساختار طرف‌حساب‌ها و نقش‌ها در نسخه‌های قدیمی.
      await db.execute('''CREATE TABLE IF NOT EXISTS contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, phone TEXT DEFAULT '',
        address TEXT DEFAULT '', type TEXT DEFAULT 'CUSTOMER',
        totalDebt REAL DEFAULT 0.0, totalPayable REAL DEFAULT 0.0,
        note TEXT DEFAULT '', updatedAt INTEGER
      )''');
      try { await db.execute("UPDATE contacts SET type='CUSTOMER' WHERE type IS NULL OR TRIM(type)=''"); } catch (_) {}
      try { await db.execute("CREATE INDEX IF NOT EXISTS idx_contacts_type ON contacts(type)"); } catch (_) {}
      try { await db.execute("UPDATE users SET role='CASHIER' WHERE role='POS_CASHIER'"); } catch (_) {}
      try { await db.execute("UPDATE users SET permissions='' WHERE permissions IS NULL"); } catch (_) {}
    }

    if (oldV < 16) {
      await db.execute(
          '''CREATE TABLE IF NOT EXISTS app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL DEFAULT '')''');
      try {
        await db
            .execute('ALTER TABLE users ADD COLUMN storeId INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE users ADD COLUMN serverUserId INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            "ALTER TABLE users ADD COLUMN permissions TEXT DEFAULT ''");
      } catch (_) {}
      await db.execute(
          "INSERT OR REPLACE INTO app_settings(key,value) VALUES('online_required','1')");
    }

    // MIGRATION_14_15: لایسنس آفلاین امضاشده و ضد تغییر
    if (oldV < 15) {
      await db.execute('''CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY, value TEXT NOT NULL DEFAULT ''
      )''');
    }

    // MIGRATION_1_2: افزودن ستون‌های جدید به store_config
    if (oldV < 2) {
      try {
        await db.execute(
            "ALTER TABLE store_config ADD COLUMN layoutStyle TEXT NOT NULL DEFAULT 'GRID'");
        await db.execute(
            "ALTER TABLE store_config ADD COLUMN morningStartHour INTEGER NOT NULL DEFAULT 6");
        await db.execute(
            "ALTER TABLE store_config ADD COLUMN morningEndHour INTEGER NOT NULL DEFAULT 15");
        await db.execute(
            "ALTER TABLE store_config ADD COLUMN eveningStartHour INTEGER NOT NULL DEFAULT 15");
        await db.execute(
            "ALTER TABLE store_config ADD COLUMN eveningEndHour INTEGER NOT NULL DEFAULT 24");
      } catch (_) {}
    }

    // MIGRATION_2_3: ایجاد جدول stock_movements
    if (oldV < 3) {
      try {
        await db.execute('''CREATE TABLE IF NOT EXISTS stock_movements (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          productId INTEGER NOT NULL, productName TEXT NOT NULL,
          type TEXT NOT NULL, quantity REAL NOT NULL,
          unit TEXT NOT NULL DEFAULT 'عدد',
          pricePerUnit REAL NOT NULL DEFAULT 0.0,
          totalPrice REAL NOT NULL DEFAULT 0.0,
          partyName TEXT NOT NULL DEFAULT '',
          refNumber TEXT NOT NULL DEFAULT '',
          dateMillis INTEGER NOT NULL,
          userId INTEGER NOT NULL, userName TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT '', overtimeMinutes INTEGER DEFAULT 0
        )''');
      } catch (_) {}
    }

    // MIGRATION_3_4: ایجاد جدول attendance_records
    if (oldV < 4) {
      try {
        await db.execute('''CREATE TABLE IF NOT EXISTS attendance_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          userId INTEGER NOT NULL, userName TEXT NOT NULL,
          dateMillis INTEGER NOT NULL, clockInTime INTEGER NOT NULL,
          clockOutTime INTEGER,
          shiftType TEXT NOT NULL DEFAULT 'MORNING',
          status TEXT NOT NULL DEFAULT 'PRESENT',
          note TEXT NOT NULL DEFAULT '', overtimeMinutes INTEGER DEFAULT 0
        )''');
      } catch (_) {}
    }

    // MIGRATION_4_5: افزودن isDarkMode به store_config
    if (oldV < 5) {
      try {
        await db.execute(
            "ALTER TABLE store_config ADD COLUMN isDarkMode INTEGER NOT NULL DEFAULT 0");
      } catch (_) {}
    }

    // MIGRATION_5_6: حذف ایندکس‌های قدیمی در صورت وجود
    if (oldV < 6) {
      try {
        await db.execute('DROP INDEX IF EXISTS idx_products_barcode');
        await db.execute('DROP INDEX IF EXISTS idx_products_category');
        await db.execute('DROP INDEX IF EXISTS idx_transactions_date');
        await db.execute('DROP INDEX IF EXISTS idx_stock_movements_productId');
        await db.execute('DROP INDEX IF EXISTS idx_contacts_type');
      } catch (_) {}
    }

    // MIGRATION_6_7: افزودن فیلدهای مالی به users
    if (oldV < 7) {
      for (final column in [
        'baseSalary REAL NOT NULL DEFAULT 0.0',
        'commissionPercent REAL NOT NULL DEFAULT 0.0',
        'totalSalesAmount REAL NOT NULL DEFAULT 0.0',
        'totalCommission REAL NOT NULL DEFAULT 0.0',
      ]) {
        try {
          await db.execute('ALTER TABLE users ADD COLUMN $column');
        } catch (_) {}
      }
    }

    // MIGRATION_7_8: فیلدهای تکمیلی تنظیمات که توسط تنظیمات/گزارش/چاپ استفاده می‌شوند
    if (oldV < 8) {
      for (final column in [
        "storePhone TEXT NOT NULL DEFAULT ''",
        "profitCoefficient REAL NOT NULL DEFAULT 0.22",
        "endShiftAlertTime TEXT NOT NULL DEFAULT '21:00'",
      ]) {
        try {
          await db.execute('ALTER TABLE store_config ADD COLUMN $column');
        } catch (_) {}
      }
    }

    // MIGRATION_8_9: هسته حسابداری تجاری
    if (oldV < 9) {
      await db.execute('''CREATE TABLE IF NOT EXISTS chart_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL, type TEXT NOT NULL, parentId INTEGER,
        isCashOrBank INTEGER DEFAULT 0, isActive INTEGER DEFAULT 1
      )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS journal_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT, number TEXT NOT NULL UNIQUE,
        dateMillis INTEGER NOT NULL, description TEXT DEFAULT '',
        sourceType TEXT DEFAULT 'MANUAL', sourceId INTEGER,
        userId INTEGER DEFAULT 0, userName TEXT DEFAULT '', posted INTEGER DEFAULT 1
      )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS journal_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT, journalId INTEGER NOT NULL,
        accountId INTEGER NOT NULL, accountCode TEXT, accountName TEXT,
        debit REAL DEFAULT 0, credit REAL DEFAULT 0, description TEXT DEFAULT ''
      )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS cash_bank_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
        type TEXT NOT NULL, bankName TEXT DEFAULT '', accountNumber TEXT DEFAULT '',
        openingBalance REAL DEFAULT 0, ledgerAccountId INTEGER NOT NULL,
        isActive INTEGER DEFAULT 1
      )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS settlements (
        id INTEGER PRIMARY KEY AUTOINCREMENT, contactId INTEGER, contactName TEXT,
        type TEXT NOT NULL, amount REAL NOT NULL, cashBankId INTEGER,
        cashBankName TEXT, dateMillis INTEGER NOT NULL, description TEXT DEFAULT '',
        userId INTEGER DEFAULT 0, userName TEXT DEFAULT ''
      )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS payroll_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT, userId INTEGER NOT NULL,
        userName TEXT NOT NULL, periodYear INTEGER NOT NULL, periodMonth INTEGER NOT NULL,
        baseSalary REAL DEFAULT 0, commission REAL DEFAULT 0, overtime REAL DEFAULT 0,
        deductions REAL DEFAULT 0, netSalary REAL DEFAULT 0, paid INTEGER DEFAULT 0,
        paidDateMillis INTEGER
      )''');
      await db.execute('''CREATE TABLE IF NOT EXISTS tax_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT, year INTEGER NOT NULL,
        month INTEGER NOT NULL, sales REAL DEFAULT 0, purchases REAL DEFAULT 0,
        expenses REAL DEFAULT 0, taxRate REAL DEFAULT 0, taxAmount REAL DEFAULT 0,
        createdAt INTEGER NOT NULL
      )''');
    }

    // MIGRATION_9_10: امکانات تجاری پیشرفته
    if (oldV < 10) {
      await _createCommercialTables(db);
      for (final sql in [
        "ALTER TABLE transactions ADD COLUMN taxBase REAL DEFAULT 0",
        "ALTER TABLE transactions ADD COLUMN taxAmount REAL DEFAULT 0",
        "ALTER TABLE transactions ADD COLUMN priceListId INTEGER",
        "ALTER TABLE transactions ADD COLUMN warehouseId INTEGER",
        "ALTER TABLE transactions ADD COLUMN returnOfId INTEGER",
        "ALTER TABLE transactions ADD COLUMN returnType TEXT DEFAULT ''",
      ]) {
        try {
          await db.execute(sql);
        } catch (_) {}
      }
      try {
        final now = DateTime.now();
        await db.insert(
            'fiscal_years',
            {
              'year': now.year,
              'startMillis': DateTime(now.year, 1, 1).millisecondsSinceEpoch,
              'endMillis':
                  DateTime(now.year + 1, 1, 1).millisecondsSinceEpoch - 1,
              'isClosed': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (_) {}
    }

    // MIGRATION_10_11: عملیات تجاری تکمیلی آفلاین
    if (oldV < 11) {
      await _createEnterpriseTables(db);
      try {
        await db.insert(
            'app_settings', {'key': 'schema_feature_level', 'value': '11'},
            conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}
    }

    // MIGRATION_11_12: تنظیمات چاپ و اندازه کاغذ
    if (oldV < 12) {
      for (final column in [
        "printPaperSize TEXT NOT NULL DEFAULT 'A4'",
        "printOrientation TEXT NOT NULL DEFAULT 'PORTRAIT'",
        "printMarginMm REAL NOT NULL DEFAULT 8.0",
        "customPaperWidthMm REAL NOT NULL DEFAULT 210.0",
        "customPaperHeightMm REAL NOT NULL DEFAULT 297.0",
      ]) {
        try {
          await db.execute('ALTER TABLE store_config ADD COLUMN $column');
        } catch (_) {}
      }
    }

    // MIGRATION_13_14: کالا/خدمت مستقل و دسته‌بندی‌های قابل توضیح
    if (oldV < 14) {
      try {
        await db.execute(
            "ALTER TABLE products ADD COLUMN isService INTEGER NOT NULL DEFAULT 0");
      } catch (_) {}
      await db.execute('''CREATE TABLE IF NOT EXISTS product_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT NOT NULL DEFAULT '',
        createdAt INTEGER NOT NULL
      )''');
    }

    // MIGRATION_12_13: عنوان کسب‌وکار و لوگوی فروشگاه
    if (oldV < 13) {
      for (final column in [
        "businessTitle TEXT NOT NULL DEFAULT 'فروشگاه'",
        "logoBase64 TEXT NOT NULL DEFAULT ''",
      ]) {
        try {
          await db.execute('ALTER TABLE store_config ADD COLUMN $column');
        } catch (_) {}
      }
    }

    // MIGRATION_19_20: شماره فاکتور مستقل از شناسه داخلی + ایندکس یکتا
    if (oldV < 20) {
      try {
        await db.execute(
          "ALTER TABLE transactions ADD COLUMN invoiceNumber TEXT NOT NULL DEFAULT ''",
        );
      } catch (_) {}
      try {
        await db.execute(
          "UPDATE transactions SET invoiceNumber = CAST(id AS TEXT) WHERE TRIM(COALESCE(invoiceNumber,'')) = ''",
        );
      } catch (_) {}
      try {
        await db.execute(
          "CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_invoice_number ON transactions(invoiceNumber) WHERE TRIM(invoiceNumber) <> ''",
        );
      } catch (_) {}
    }

    // MIGRATION_17_18: بازسازی Triggerهای Sync با سینتکس صحیح SQLite.
    // این کار Triggerهای قدیمی حاوی strftime("%s","now") را حذف و دوباره ایجاد می‌کند.
    // MIGRATION_18_19: تفکیک فهرست خدمات بر اساس نوع کسب‌وکار
    if (oldV < 19) {
      try {
        await db.execute(
          "ALTER TABLE service_items ADD COLUMN businessCode TEXT NOT NULL DEFAULT 'GENERAL'",
        );
      } catch (_) {}

      try {
        await db.execute(
          "UPDATE service_items SET businessCode = 'GENERAL' "
          "WHERE businessCode IS NULL OR TRIM(businessCode) = ''",
        );
      } catch (_) {}

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_service_items_business '
        'ON service_items(businessCode, isActive, name)',
      );
    }
    await _createSyncInfrastructure(db);
    if (oldV < 24) {
      try { await db.execute("CREATE TABLE IF NOT EXISTS local_sync_log (id INTEGER PRIMARY KEY AUTOINCREMENT, originDeviceId TEXT NOT NULL, originSeq INTEGER NOT NULL, entity TEXT NOT NULL, operation TEXT NOT NULL, entityId TEXT NOT NULL, payloadJson TEXT NOT NULL, sourceVersion INTEGER NOT NULL DEFAULT 0, createdAt INTEGER NOT NULL, UNIQUE(originDeviceId, originSeq))"); } catch (_) {}
      try { await LocalDeviceIdentity.instance.reserveIdRange(db); } catch (_) {}
    }
    if (oldV < 23) {
      try {
        await db.execute("ALTER TABLE attendance_records ADD COLUMN overtimeMinutes INTEGER DEFAULT 0");
      } catch (_) {}
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
