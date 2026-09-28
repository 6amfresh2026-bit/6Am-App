import '../model/cart.dart';
import '../model/coupon.dart';
import '../../core/utils/currency_formatter.dart';

/// Decides which coupons a cart can use, and why the others cannot.
///
/// The authoritative discount still comes from the server's pricing call —
/// this only drives the coupon list's enabled/greyed presentation.
class CouponEligibilityService {
  const CouponEligibilityService();

  CouponEligibility evaluate(Coupon coupon, Cart cart) {
    if (cart.isEmpty) {
      return const CouponEligibility(
        isEligible: false,
        reason: 'Add items to your cart first',
      );
    }
    if (coupon.isExpired) {
      return const CouponEligibility(isEligible: false, reason: 'This offer has ended');
    }

    final subtotal = cart.pricing.subtotal > 0
        ? cart.pricing.subtotal
        : cart.provisionalSubtotal;

    if (subtotal < coupon.minOrderValue) {
      final gap = coupon.minOrderValue - subtotal;
      return CouponEligibility(
        isEligible: false,
        reason: 'Add ${CurrencyFormatter.format(gap)} more to unlock',
      );
    }

    if (coupon.sellerId.isNotEmpty &&
        cart.sellerId.isNotEmpty &&
        coupon.sellerId != cart.sellerId) {
      return CouponEligibility(
        isEligible: false,
        reason: 'Valid only at ${coupon.sellerName}',
      );
    }

    return CouponEligibility.eligible;
  }

  /// Eligible coupons first, then by the biggest estimated saving.
  List<Coupon> rank(List<Coupon> coupons, Cart cart) {
    final subtotal = cart.pricing.subtotal > 0
        ? cart.pricing.subtotal
        : cart.provisionalSubtotal;
    final sorted = [...coupons];
    sorted.sort((a, b) {
      final aOk = evaluate(a, cart).isEligible;
      final bOk = evaluate(b, cart).isEligible;
      if (aOk != bOk) return aOk ? -1 : 1;
      return b.estimatedDiscountOn(subtotal).compareTo(a.estimatedDiscountOn(subtotal));
    });
    return sorted;
  }

  /// The coupon that saves the most right now, for the "best offer" nudge.
  Coupon? bestFor(List<Coupon> coupons, Cart cart) {
    final eligible = coupons.where((c) => evaluate(c, cart).isEligible).toList();
    if (eligible.isEmpty) return null;
    return rank(eligible, cart).first;
  }
}
