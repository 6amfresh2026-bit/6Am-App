import '../model/address.dart';
import '../model/cart.dart';
import '../model/coupon.dart';
import '../service/coupon_eligibility_service.dart';
import 'price_cart_usecase.dart';

/// Result of applying a coupon — the server may still reject it, in which case
/// the cart comes back unchanged with a reason.
sealed class CouponOutcome {
  const CouponOutcome();
}

class CouponApplied extends CouponOutcome {
  const CouponApplied(this.cart, this.savings);
  final Cart cart;
  final double savings;
}

class CouponRejected extends CouponOutcome {
  const CouponRejected(this.reason);
  final String reason;
}

/// Applies (or removes) a coupon and re-prices the cart on the server.
class ApplyCouponUseCase {
  const ApplyCouponUseCase({
    required PriceCartUseCase priceCart,
    required CouponEligibilityService eligibility,
  })  : _priceCart = priceCart,
        _eligibility = eligibility;

  final PriceCartUseCase _priceCart;
  final CouponEligibilityService _eligibility;

  Future<CouponOutcome> call(Cart cart, Coupon coupon, {Address? address}) async {
    final verdict = _eligibility.evaluate(coupon, cart);
    if (!verdict.isEligible) return CouponRejected(verdict.reason);

    final priced = await _priceCart(
      cart.copyWith(appliedCoupon: coupon),
      address: address,
      couponCode: coupon.code,
    );

    // The server is the arbiter: no discount means it did not honour the code.
    if (priced.pricing.discount <= 0) {
      return const CouponRejected('This coupon could not be applied to your order');
    }

    return CouponApplied(priced, priced.pricing.discount);
  }

  Future<Cart> remove(Cart cart, {Address? address}) async {
    final cleared = cart.copyWith(clearCoupon: true);
    return _priceCart(cleared, address: address, couponCode: '');
  }
}
