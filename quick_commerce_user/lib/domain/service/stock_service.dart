import '../model/cart.dart';
import '../model/cart_item.dart';
import '../model/product.dart';

/// Stock rules shared by cards, details and checkout.
class StockService {
  const StockService({this.lowStockThreshold = 5});

  final int lowStockThreshold;

  bool canAdd(Product product, {int currentQuantity = 0, int adding = 1}) {
    if (!product.isPurchasable) return false;
    if (!product.sellerAcceptingOrders) return false;
    return currentQuantity + adding <= product.maxOrderableQty;
  }

  /// Short label under the price, e.g. "Only 3 left". Empty when unremarkable.
  String stockLabel(Product product) => switch (product.stockStatus) {
        StockStatus.outOfStock => 'Out of stock',
        StockStatus.limited => 'Only ${product.stockQty} left',
        StockStatus.inStock => '',
      };

  /// Why the stepper stopped growing, for the toast.
  String? capReason(Product product, int currentQuantity) {
    if (currentQuantity < product.maxOrderableQty) return null;
    final perOrder = product.maxQtyPerOrder;
    if (perOrder != null && perOrder > 0 && currentQuantity >= perOrder) {
      return 'Limit of $perOrder per order';
    }
    return 'That is all we have in stock';
  }

  /// Cart lines that can no longer be fulfilled, checked before checkout.
  List<CartItem> unavailableLines(Cart cart) =>
      cart.items.where((i) => !i.product.isPurchasable).toList();
}
