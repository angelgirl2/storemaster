// مدل TransactionItem - آیتم‌های فاکتور
class TransactionItem {
  final int id;
  final int transactionId;
  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double costPrice;
  final double totalPrice;

  TransactionItem({
    this.id = 0,
    required this.transactionId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'transactionId': transactionId,
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'costPrice': costPrice,
        'totalPrice': totalPrice,
      };

  factory TransactionItem.fromMap(Map<String, dynamic> m) => TransactionItem(
        id: (m['id'] as num?)?.toInt() ?? 0,
        transactionId: (m['transactionId'] as num?)?.toInt() ?? 0,
        productId: (m['productId'] as num?)?.toInt() ?? 0,
        productName: (m['productName'] as String?) ?? '',
        quantity: (m['quantity'] as num?)?.toDouble() ?? 0.0,
        unitPrice: (m['unitPrice'] as num?)?.toDouble() ?? 0.0,
        costPrice: (m['costPrice'] as num?)?.toDouble() ?? 0.0,
        totalPrice: (m['totalPrice'] as num?)?.toDouble() ?? 0.0,
      );

  TransactionItem copyWith({int? transactionId, required double quantity}) =>
      TransactionItem(
        id: id,
        transactionId: transactionId ?? this.transactionId,
        productId: productId,
        productName: productName,
        quantity: quantity,
        unitPrice: unitPrice,
        costPrice: costPrice,
        totalPrice: totalPrice,
      );
}
