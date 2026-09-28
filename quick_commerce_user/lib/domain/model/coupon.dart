/// How a coupon reduces the bill.
enum DiscountType { percentage, flat }

/// A promotional offer. Eligibility is evaluated in `CouponEligibilityService`,
/// but the *applied* discount always comes back from the server's pricing call.
class Coupon {
  const Coupon({
    required this.id,
    required this.code,
    required this.title,
    required this.discountType,
    required this.discountValue,
    this.minOrderValue = 0,
    this.maxDiscount,
    this.sellerId = '',
    this.sellerName = '',
    this.isFirstOrderOnly = false,
    this.expiresAt,
  });

  final String id;
  final String code;
  final String title;
  final DiscountType discountType;
  final double discountValue;
  final double minOrderValue;
  final double? maxDiscount;
  final String sellerId;
  final String sellerName;
  final bool isFirstOrderOnly;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// Indicative saving shown in the coupon list before the server prices it.
  double estimatedDiscountOn(double subtotal) {
    if (subtotal < minOrderValue) return 0;
    final raw = switch (discountType) {
      DiscountType.percentage => subtotal * discountValue / 100,
      DiscountType.flat => discountValue,
    };
    final cap = maxDiscount;
    final capped = cap != null && cap > 0 && raw > cap ? cap : raw;
    return capped > subtotal ? subtotal : capped;
  }

  @override
  bool operator ==(Object other) => other is Coupon && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Why a coupon cannot be used right now, for the greyed-out list rows.
class CouponEligibility {
  const CouponEligibility({required this.isEligible, this.reason = ''});

  final bool isEligible;
  final String reason;

  static const eligible = CouponEligibility(isEligible: true);
}
