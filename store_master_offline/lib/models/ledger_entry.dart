// مدل سند حسابداری دوطرفه
class LedgerEntry {
  final int id;
  final int dateMillis;
  final String account;
  final double debit;
  final double credit;
  final String description;
  final String refType;
  final int? refId;
  final int userId;
  final String userName;

  LedgerEntry({
    this.id = 0,
    int? dateMillis,
    required this.account,
    this.debit = 0,
    this.credit = 0,
    this.description = '',
    this.refType = 'MANUAL',
    this.refId,
    this.userId = 0,
    this.userName = '',
  }) : dateMillis = dateMillis ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'dateMillis': dateMillis,
        'account': account,
        'debit': debit,
        'credit': credit,
        'description': description,
        'refType': refType,
        'refId': refId,
        'userId': userId,
        'userName': userName,
      };

  factory LedgerEntry.fromMap(Map<String, dynamic> m) => LedgerEntry(
        id: (m['id'] as num?)?.toInt() ?? 0,
        dateMillis: (m['dateMillis'] as num?)?.toInt(),
        account: (m['account'] as String?) ?? 'سایر',
        debit: (m['debit'] as num?)?.toDouble() ?? 0,
        credit: (m['credit'] as num?)?.toDouble() ?? 0,
        description: (m['description'] as String?) ?? '',
        refType: (m['refType'] as String?) ?? 'MANUAL',
        refId: (m['refId'] as num?)?.toInt(),
        userId: (m['userId'] as num?)?.toInt() ?? 0,
        userName: (m['userName'] as String?) ?? '',
      );
}
