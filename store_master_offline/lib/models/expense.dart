// مدل Expense - هزینه‌ها
class Expense {
  final int id;
  final String title;
  final double amount;
  final String category; // اجاره, قبوض, حقوق پرسنل, حمل و نقل, سایر
  final int dateMillis;
  final int userId;
  final String userName;
  final String note;

  Expense({
    this.id = 0,
    required this.title,
    required this.amount,
    required this.category,
    int? dateMillis,
    required this.userId,
    required this.userName,
    this.note = '',
  }) : dateMillis = dateMillis ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'title': title,
        'amount': amount,
        'category': category,
        'dateMillis': dateMillis,
        'userId': userId,
        'userName': userName,
        'note': note,
      };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: (m['id'] as num?)?.toInt() ?? 0,
        title: (m['title'] as String?) ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
        category: (m['category'] as String?) ?? 'سایر',
        dateMillis: (m['dateMillis'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        userId: (m['userId'] as num?)?.toInt() ?? 0,
        userName: (m['userName'] as String?) ?? '',
        note: (m['note'] as String?) ?? '',
      );
}
