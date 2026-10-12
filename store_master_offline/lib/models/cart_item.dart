// ============================================================================
// CartItem - آیتم سبد خرید (همان CartItem در Kotlin)
// ============================================================================
import 'product.dart';

class CartItem {
  final Product product;
  double quantity;
  double? customPrice;

  CartItem({required this.product, this.quantity = 1.0, this.customPrice});

  double get unitPrice => customPrice ?? product.sellPrice;
  double get totalPrice => unitPrice * quantity;
}
