// مدل Product - کالاهای انبار
class Product {
  final int id;
  final String name;
  final String barcode;
  final String category;
  final double buyPrice;
  final double sellPrice;
  final double stockQuantity;
  final String unit; // واحد دلخواه: عدد، کیلو، ساعت، برگ، متر و...
  final bool isService;
  final double minStockAlert;
  final String note;
  final int updatedAt;

  Product({
    this.id = 0,
    required this.name,
    this.barcode = '',
    required this.category,
    required this.buyPrice,
    required this.sellPrice,
    required this.stockQuantity,
    this.unit = 'عدد',
    this.isService = false,
    this.minStockAlert = 5.0,
    this.note = '',
    int? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'name': name,
        'barcode': barcode,
        'category': category,
        'buyPrice': buyPrice,
        'sellPrice': sellPrice,
        'stockQuantity': stockQuantity,
        'unit': unit,
        'isService': isService ? 1 : 0,
        'minStockAlert': minStockAlert,
        'note': note,
        'updatedAt': updatedAt,
      };

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: (m['id'] as num?)?.toInt() ?? 0,
        name: (m['name'] as String?) ?? '',
        barcode: (m['barcode'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'عمومی',
        buyPrice: (m['buyPrice'] as num?)?.toDouble() ?? 0.0,
        sellPrice: (m['sellPrice'] as num?)?.toDouble() ?? 0.0,
        stockQuantity: (m['stockQuantity'] as num?)?.toDouble() ?? 0.0,
        unit: (m['unit'] as String?) ?? 'عدد',
        isService: (m['isService'] as num?)?.toInt() == 1,
        minStockAlert: (m['minStockAlert'] as num?)?.toDouble() ?? 5.0,
        note: (m['note'] as String?) ?? '',
        updatedAt: (m['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      );
}


class ProductCategory {
  final int id;
  final String name;
  final String description;
  final int createdAt;

  ProductCategory({
    this.id = 0,
    required this.name,
    this.description = '',
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'name': name,
        'description': description,
        'createdAt': createdAt,
      };

  factory ProductCategory.fromMap(Map<String, dynamic> m) => ProductCategory(
        id: (m['id'] as num?)?.toInt() ?? 0,
        name: (m['name'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        createdAt: (m['createdAt'] as num?)?.toInt(),
      );
}
