// فروش و مدیریت لایسنس محصول/ماژول
class LicenseSale {
  final int id;
  final String customerName;
  final String phone;
  final String plan;
  final String licenseKey;
  final double amount;
  final int durationDays;
  final int issuedAt;
  final int expiresAt;
  final String status;
  final String note;

  LicenseSale({
    this.id = 0,
    required this.customerName,
    this.phone = '',
    required this.plan,
    required this.licenseKey,
    required this.amount,
    required this.durationDays,
    int? issuedAt,
    required this.expiresAt,
    this.status = 'ACTIVE',
    this.note = '',
  }) : issuedAt = issuedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'customerName': customerName,
        'phone': phone,
        'plan': plan,
        'licenseKey': licenseKey,
        'amount': amount,
        'durationDays': durationDays,
        'issuedAt': issuedAt,
        'expiresAt': expiresAt,
        'status': status,
        'note': note,
      };

  factory LicenseSale.fromMap(Map<String, dynamic> m) => LicenseSale(
        id: (m['id'] as num?)?.toInt() ?? 0,
        customerName: (m['customerName'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        plan: (m['plan'] as String?) ?? 'PRO',
        licenseKey: (m['licenseKey'] as String?) ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        durationDays: (m['durationDays'] as num?)?.toInt() ?? 30,
        issuedAt: (m['issuedAt'] as num?)?.toInt(),
        expiresAt: (m['expiresAt'] as num?)?.toInt() ?? 0,
        status: (m['status'] as String?) ?? 'ACTIVE',
        note: (m['note'] as String?) ?? '',
      );
}
