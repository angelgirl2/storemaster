// مدل Contact - طرف‌حساب‌ها (مشتری/تامین‌کننده)
class Contact {
  final int id;
  final String name;
  final String phone;
  final String address;
  final String type; // CUSTOMER, SUPPLIER, BOTH
  final double totalDebt; // طلب ما از مشتری
  final double totalPayable; // بدهی ما به تامین کننده
  final String note;
  final int updatedAt;

  Contact({
    this.id = 0,
    required this.name,
    this.phone = '',
    this.address = '',
    this.type = 'CUSTOMER',
    this.totalDebt = 0.0,
    this.totalPayable = 0.0,
    this.note = '',
    int? updatedAt,
    required String notes,
  }) : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'name': name,
        'phone': phone,
        'address': address,
        'type': type,
        'totalDebt': totalDebt,
        'totalPayable': totalPayable,
        'note': note,
        'updatedAt': updatedAt,
      };

  factory Contact.fromMap(Map<String, dynamic> m) => Contact(
        id: (m['id'] as num?)?.toInt() ?? 0,
        name: (m['name'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
        type: (m['type'] as String?) ?? 'CUSTOMER',
        totalDebt: (m['totalDebt'] as num?)?.toDouble() ?? 0.0,
        totalPayable: (m['totalPayable'] as num?)?.toDouble() ?? 0.0,
        note: (m['note'] as String?) ?? '',
        updatedAt: (m['updatedAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        notes: '',
      );
}
