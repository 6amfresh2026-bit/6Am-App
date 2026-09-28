import '../model/address.dart';
import '../model/cart.dart';
import '../model/cart_item.dart';

/// Persists the cart locally and mirrors it to the backend, and asks the
/// server to price it. Pricing is never computed on the client.
abstract interface class CartRepository {
  /// Cart cached on this device, restored at app start.
  Future<Cart> loadCached();

  Future<void> cache(Cart cart);

  /// Mirrors the cart to `PUT /food/user/cart` so it survives a reinstall.
  /// Best-effort: a failure here must never block the UI.
  Future<void> sync(Cart cart);

  /// `POST /food/orders/calculate` — the single source of truth for the bill.
  Future<({CartPricing pricing, List<PriceChange> changes, List<CartItem> items})>
      price({
    required Cart cart,
    Address? address,
    String? couponCode,
    String deliveryMode,
    DateTime? scheduledAt,
  });
}
