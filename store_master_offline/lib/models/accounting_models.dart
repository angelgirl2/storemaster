// ============================================================================
// Accounting models - سرفصل‌ها، اسناد، صندوق/بانک، تسویه، حقوق و برگشت‌ها
// ============================================================================

class ChartAccount {
  final int id;
  final String code;
  final String name;
  final String type; // ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE
  final int? parentId;
  final bool isCashOrBank;
  final bool isActive;

  const ChartAccount({
    this.id = 0,
    required this.code,
    required this.name,
    required this.type,
    this.parentId,
    this.isCashOrBank = false,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'code': code,
        'name': name,
        'type': type,
        'parentId': parentId,
        'isCashOrBank': isCashOrBank ? 1 : 0,
        'isActive': isActive ? 1 : 0,
      };

  factory ChartAccount.fromMap(Map<String, dynamic> m) => ChartAccount(
        id: (m['id'] as num?)?.toInt() ?? 0,
        code: (m['code'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        type: (m['type'] as String?) ?? 'ASSET',
        parentId: (m['parentId'] as num?)?.toInt(),
        isCashOrBank: (m['isCashOrBank'] as num? ?? 0) == 1,
        isActive: (m['isActive'] as num? ?? 1) == 1,
      );
}

class JournalEntry {
  final int id;
  final String number;
  final int dateMillis;
  final String description;
  final String sourceType;
  final int? sourceId;
  final int userId;
  final String userName;
  final bool posted;

  const JournalEntry({
    this.id = 0,
    required this.number,
    required this.dateMillis,
    this.description = '',
    this.sourceType = 'MANUAL',
    this.sourceId,
    this.userId = 0,
    this.userName = '',
    this.posted = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'number': number,
        'dateMillis': dateMillis,
        'description': description,
        'sourceType': sourceType,
        'sourceId': sourceId,
        'userId': userId,
        'userName': userName,
        'posted': posted ? 1 : 0,
      };

  factory JournalEntry.fromMap(Map<String, dynamic> m) => JournalEntry(
        id: (m['id'] as num?)?.toInt() ?? 0,
        number: (m['number'] as String?) ?? '',
        dateMillis: (m['dateMillis'] as num?)?.toInt() ?? 0,
        description: (m['description'] as String?) ?? '',
        sourceType: (m['sourceType'] as String?) ?? 'MANUAL',
        sourceId: (m['sourceId'] as num?)?.toInt(),
        userId: (m['userId'] as num?)?.toInt() ?? 0,
        userName: (m['userName'] as String?) ?? '',
        posted: (m['posted'] as num? ?? 1) == 1,
      );
}

class JournalLine {
  final int id;
  final int journalId;
  final int accountId;
  final String accountCode;
  final String accountName;
  final double debit;
  final double credit;
  final String description;

  const JournalLine({
    this.id = 0,
    required this.journalId,
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    this.debit = 0,
    this.credit = 0,
    this.description = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'journalId': journalId,
        'accountId': accountId,
        'accountCode': accountCode,
        'accountName': accountName,
        'debit': debit,
        'credit': credit,
        'description': description,
      };

  factory JournalLine.fromMap(Map<String, dynamic> m) => JournalLine(
        id: (m['id'] as num?)?.toInt() ?? 0,
        journalId: (m['journalId'] as num?)?.toInt() ?? 0,
        accountId: (m['accountId'] as num?)?.toInt() ?? 0,
        accountCode: (m['accountCode'] as String?) ?? '',
        accountName: (m['accountName'] as String?) ?? '',
        debit: (m['debit'] as num?)?.toDouble() ?? 0,
        credit: (m['credit'] as num?)?.toDouble() ?? 0,
        description: (m['description'] as String?) ?? '',
      );
}

class CashBankAccount {
  final int id;
  final String name;
  final String type; // CASH / BANK
  final String bankName;
  final String accountNumber;
  final double openingBalance;
  final int ledgerAccountId;
  final bool isActive;

  const CashBankAccount({
    this.id = 0,
    required this.name,
    required this.type,
    this.bankName = '',
    this.accountNumber = '',
    this.openingBalance = 0,
    required this.ledgerAccountId,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'name': name,
        'type': type,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'openingBalance': openingBalance,
        'ledgerAccountId': ledgerAccountId,
        'isActive': isActive ? 1 : 0,
      };

  factory CashBankAccount.fromMap(Map<String, dynamic> m) => CashBankAccount(
        id: (m['id'] as num?)?.toInt() ?? 0,
        name: (m['name'] as String?) ?? '',
        type: (m['type'] as String?) ?? 'CASH',
        bankName: (m['bankName'] as String?) ?? '',
        accountNumber: (m['accountNumber'] as String?) ?? '',
        openingBalance: (m['openingBalance'] as num?)?.toDouble() ?? 0,
        ledgerAccountId: (m['ledgerAccountId'] as num?)?.toInt() ?? 0,
        isActive: (m['isActive'] as num? ?? 1) == 1,
      );
}

class SettlementRecord {
  final int id;
  final int contactId;
  final String contactName;
  final String type; // RECEIPT / PAYMENT
  final double amount;
  final int cashBankId;
  final String cashBankName;
  final int dateMillis;
  final String description;
  final int userId;
  final String userName;

  const SettlementRecord({
    this.id = 0,
    required this.contactId,
    required this.contactName,
    required this.type,
    required this.amount,
    required this.cashBankId,
    required this.cashBankName,
    required this.dateMillis,
    this.description = '',
    this.userId = 0,
    this.userName = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'contactId': contactId,
        'contactName': contactName,
        'type': type,
        'amount': amount,
        'cashBankId': cashBankId,
        'cashBankName': cashBankName,
        'dateMillis': dateMillis,
        'description': description,
        'userId': userId,
        'userName': userName,
      };

  factory SettlementRecord.fromMap(Map<String, dynamic> m) => SettlementRecord(
        id: (m['id'] as num?)?.toInt() ?? 0,
        contactId: (m['contactId'] as num?)?.toInt() ?? 0,
        contactName: (m['contactName'] as String?) ?? '',
        type: (m['type'] as String?) ?? 'RECEIPT',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        cashBankId: (m['cashBankId'] as num?)?.toInt() ?? 0,
        cashBankName: (m['cashBankName'] as String?) ?? '',
        dateMillis: (m['dateMillis'] as num?)?.toInt() ?? 0,
        description: (m['description'] as String?) ?? '',
        userId: (m['userId'] as num?)?.toInt() ?? 0,
        userName: (m['userName'] as String?) ?? '',
      );
}

class PayrollRecord {
  final int id;
  final int userId;
  final String userName;
  final int periodYear;
  final int periodMonth;
  final double baseSalary;
  final double commission;
  final double overtime;
  final double deductions;
  final double netSalary;
  final bool paid;
  final int? paidDateMillis;

  const PayrollRecord({
    this.id = 0,
    required this.userId,
    required this.userName,
    required this.periodYear,
    required this.periodMonth,
    required this.baseSalary,
    required this.commission,
    required this.overtime,
    required this.deductions,
    required this.netSalary,
    this.paid = false,
    this.paidDateMillis,
  });

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'userId': userId,
        'userName': userName,
        'periodYear': periodYear,
        'periodMonth': periodMonth,
        'baseSalary': baseSalary,
        'commission': commission,
        'overtime': overtime,
        'deductions': deductions,
        'netSalary': netSalary,
        'paid': paid ? 1 : 0,
        'paidDateMillis': paidDateMillis,
      };

  factory PayrollRecord.fromMap(Map<String, dynamic> m) => PayrollRecord(
        id: (m['id'] as num?)?.toInt() ?? 0,
        userId: (m['userId'] as num?)?.toInt() ?? 0,
        userName: (m['userName'] as String?) ?? '',
        periodYear: (m['periodYear'] as num?)?.toInt() ?? 0,
        periodMonth: (m['periodMonth'] as num?)?.toInt() ?? 0,
        baseSalary: (m['baseSalary'] as num?)?.toDouble() ?? 0,
        commission: (m['commission'] as num?)?.toDouble() ?? 0,
        overtime: (m['overtime'] as num?)?.toDouble() ?? 0,
        deductions: (m['deductions'] as num?)?.toDouble() ?? 0,
        netSalary: (m['netSalary'] as num?)?.toDouble() ?? 0,
        paid: (m['paid'] as num? ?? 0) == 1,
        paidDateMillis: (m['paidDateMillis'] as num?)?.toInt(),
      );
}
