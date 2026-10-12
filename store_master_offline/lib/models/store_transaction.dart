// مدل StoreTransaction - فاکتورهای فروش
class StoreTransaction {
  final int id;
  final String invoiceNumber;
  final String type; // SALE, PURCHASE, DEBT_PAYMENT, PAYABLE_PAYMENT
  final double totalAmount;
  final double discount;
  final double finalAmount;
  final double paidAmount;
  final double debtAmount;
  final String paymentMethod; // CASH, CARD, CREDIT
  final int? contactId;
  final String contactName;
  final int userId;
  final String userName;
  final int dateMillis;
  final String note;
  final double taxBase;
  final double taxAmount;
  final int? priceListId;
  final int? warehouseId;
  final int? returnOfId;
  final String returnType;

  StoreTransaction({
    this.id = 0,
    this.invoiceNumber = '',
    required this.type,
    required this.totalAmount,
    this.discount = 0.0,
    required this.finalAmount,
    required this.paidAmount,
    this.debtAmount = 0.0,
    this.paymentMethod = 'CASH',
    this.contactId,
    this.contactName = '',
    required this.userId,
    required this.userName,
    int? dateMillis,
    this.note = '',
    this.taxBase = 0.0,
    this.taxAmount = 0.0,
    this.priceListId,
    this.warehouseId,
    this.returnOfId,
    this.returnType = '',
  }) : dateMillis = dateMillis ?? DateTime.now().millisecondsSinceEpoch;

  StoreTransaction copyWith({
    int? id,
    String? invoiceNumber,
    String? type,
    double? totalAmount,
    double? discount,
    double? finalAmount,
    double? paidAmount,
    double? debtAmount,
    String? paymentMethod,
    int? contactId,
    String? contactName,
    int? userId,
    String? userName,
    int? dateMillis,
    String? note,
    double? taxBase,
    double? taxAmount,
    int? priceListId,
    int? warehouseId,
    int? returnOfId,
    String? returnType,
  }) => StoreTransaction(
    id: id ?? this.id,
    invoiceNumber: invoiceNumber ?? this.invoiceNumber,
    type: type ?? this.type,
    totalAmount: totalAmount ?? this.totalAmount,
    discount: discount ?? this.discount,
    finalAmount: finalAmount ?? this.finalAmount,
    paidAmount: paidAmount ?? this.paidAmount,
    debtAmount: debtAmount ?? this.debtAmount,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    contactId: contactId ?? this.contactId,
    contactName: contactName ?? this.contactName,
    userId: userId ?? this.userId,
    userName: userName ?? this.userName,
    dateMillis: dateMillis ?? this.dateMillis,
    note: note ?? this.note,
    taxBase: taxBase ?? this.taxBase,
    taxAmount: taxAmount ?? this.taxAmount,
    priceListId: priceListId ?? this.priceListId,
    warehouseId: warehouseId ?? this.warehouseId,
    returnOfId: returnOfId ?? this.returnOfId,
    returnType: returnType ?? this.returnType,
  );

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'invoiceNumber': invoiceNumber,
        'type': type,
        'totalAmount': totalAmount,
        'discount': discount,
        'finalAmount': finalAmount,
        'paidAmount': paidAmount,
        'debtAmount': debtAmount,
        'paymentMethod': paymentMethod,
        'contactId': contactId,
        'contactName': contactName,
        'userId': userId,
        'userName': userName,
        'dateMillis': dateMillis,
        'note': note,
        'taxBase': taxBase,
        'taxAmount': taxAmount,
        'priceListId': priceListId,
        'warehouseId': warehouseId,
        'returnOfId': returnOfId,
        'returnType': returnType,
      };

  factory StoreTransaction.fromMap(Map<String, dynamic> m) => StoreTransaction(
        id: (m['id'] as num?)?.toInt() ?? 0,
        invoiceNumber: (m['invoiceNumber'] as String?) ?? '',
        type: (m['type'] as String?) ?? 'SALE',
        totalAmount: (m['totalAmount'] as num?)?.toDouble() ?? 0.0,
        discount: (m['discount'] as num?)?.toDouble() ?? 0.0,
        finalAmount: (m['finalAmount'] as num?)?.toDouble() ?? 0.0,
        paidAmount: (m['paidAmount'] as num?)?.toDouble() ?? 0.0,
        debtAmount: (m['debtAmount'] as num?)?.toDouble() ?? 0.0,
        paymentMethod: (m['paymentMethod'] as String?) ?? 'CASH',
        contactId: (m['contactId'] as num?)?.toInt(),
        contactName: (m['contactName'] as String?) ?? '',
        userId: (m['userId'] as num?)?.toInt() ?? 0,
        userName: (m['userName'] as String?) ?? '',
        dateMillis: (m['dateMillis'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        note: (m['note'] as String?) ?? '',
        taxBase: (m['taxBase'] as num?)?.toDouble() ?? 0.0,
        taxAmount: (m['taxAmount'] as num?)?.toDouble() ?? 0.0,
        priceListId: (m['priceListId'] as num?)?.toInt(),
        warehouseId: (m['warehouseId'] as num?)?.toInt(),
        returnOfId: (m['returnOfId'] as num?)?.toInt(),
        returnType: (m['returnType'] as String?) ?? '',
      );
}
