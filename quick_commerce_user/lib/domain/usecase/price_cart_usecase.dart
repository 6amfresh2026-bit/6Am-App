import '../model/address.dart';
import '../model/cart.dart';
import '../repository/cart_repository.dart';

/// Asks the server for the authoritative bill and folds it back into the cart.
///
/// This is the *only* path by which a `CartPricing` ever gets populated.
class PriceCartUseCase {
  const PriceCartUseCase(this._repository);

  final CartRepository _repository;

  Future<Cart> call(
    Cart cart, {
    Address? address,
    String? couponCode,
    DateTime? scheduledAt,
  }) async {
    if (cart.isEmpty) return Cart.empty;

    final result = await _repository.price(
      cart: cart,
      address: address,
      couponCode: couponCode ?? cart.appliedCoupon?.code,
      deliveryMode: cart.deliveryMode,
      scheduledAt: scheduledAt,
    );

    return cart.copyWith(
      pricing: result.pricing,
      priceChanges: result.changes,
    );
  }
}
