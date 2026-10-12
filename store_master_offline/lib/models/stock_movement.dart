// مدل StockMovement - گردش انبار (ورودی/خروجی)
class StockMovement {
  final int id;
  final int productId;
  final String productName;
  final String type; // "IN" یا "OUT"
  final double quantity;
  final String unit;
  final double pricePerUnit;
  final double totalPrice;
  final String partyName;
  final String refNumber;
  final int dateMillis;
  final int userId;
  final String userName;
  final String note;

  StockMovement({
    this.id = 0,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    this.unit = 'عدد',
    this.pricePerUnit = 0.0,
    this.totalPrice = 0.0,
    this.partyName = '',
    this.refNumber = '',
    int? dateMillis,
    required this.userId,
    required this.userName,
    this.note = '',
  }) : dateMillis = dateMillis ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'productId': productId,
        'productName': productName,
        'type': type,
        'quantity': quantity,
        'unit': unit,
        'pricePerUnit': pricePerUnit,
        'totalPrice': totalPrice,
        'partyName': partyName,
        'refNumber': refNumber,
        'dateMillis': dateMillis,
        'userId': userId,
        'userName': userName,
        'note': note,
      };

  factory StockMovement.fromMap(Map<String, dynamic> m) => StockMovement(
        id: (m['id'] as num?)?.toInt() ?? 0,
        productId: (m['productId'] as num?)?.toInt() ?? 0,
        productName: (m['productName'] as String?) ?? '',
        type: (m['type'] as String?) ?? 'IN',
        quantity: (m['quantity'] as num?)?.toDouble() ?? 0.0,
        unit: (m['unit'] as String?) ?? 'عدد',
        pricePerUnit: (m['pricePerUnit'] as num?)?.toDouble() ?? 0.0,
        totalPrice: (m['totalPrice'] as num?)?.toDouble() ?? 0.0,
        partyName: (m['partyName'] as String?) ?? '',
        refNumber: (m['refNumber'] as String?) ?? '',
        dateMillis: (m['dateMillis'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        userId: (m['userId'] as num?)?.toInt() ?? 0,
        userName: (m['userName'] as String?) ?? '',
        note: (m['note'] as String?) ?? '',
      );
}
