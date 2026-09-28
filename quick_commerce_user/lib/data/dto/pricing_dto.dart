import 'json_reader.dart';

/// The `pricing` object returned by `POST /food/orders/calculate` and
/// persisted on every order. Field names mirror the backend exactly.
class PricingDto {
  const PricingDto({
    this.subtotal = 0,
    this.tax = 0,
    this.packagingFee = 0,
    this.deliveryFee = 0,
    this.deliveryFeeGst = 0,
    this.platformFee = 0,
    this.quickDeliveryFee = 0,
    this.discount = 0,
    this.total = 0,
    this.currency = 'INR',
    this.couponCode,
    this.deliveryMode = 'basic',
    this.distanceKm,
    this.deliveryPromiseMinutes,
    this.deliveryPromiseMinutesBasic,
    this.deliveryPromiseMinutesQuick,
    this.deliveryFeeMessage = '',
    this.appliedCouponCode,
    this.appliedCouponDiscount = 0,
    this.couponRejectedReason = '',
    this.nextSlabMinOrderValue,
    this.nextSlabSpendMore,
    this.nextSlabDiscount,
    this.smallCartFee = 0,
    this.smallCartThreshold = 0,
    this.deliveryIsFree = false,
    this.freeDeliveryAbove = 0,
    this.spendMoreForFreeDelivery = 0,
  });

  final double subtotal;
  final double tax;
  final double packagingFee;
  final double deliveryFee;
  final double deliveryFeeGst;
  final double platformFee;
  final double quickDeliveryFee;
  final double discount;
  final double total;
  final String currency;
  final String? couponCode;
  final String deliveryMode;
  final double? distanceKm;
  final int? deliveryPromiseMinutes;

  /// What each mode would promise, so both options can be labelled from the
  /// server's own figures instead of a printed band.
  final int? deliveryPromiseMinutesBasic;
  final int? deliveryPromiseMinutesQuick;
  final String deliveryFeeMessage;

  /// Non-null **only** when the coupon was actually honoured. `couponCode` is
  /// echoed back on refusal too, so it can never stand in for this.
  final String? appliedCouponCode;
  final double appliedCouponDiscount;

  /// Why a coupon was refused, already worded for the customer.
  final String couponRejectedReason;

  /// The spend rung above the one reached, on an applied slab coupon.
  final double? nextSlabMinOrderValue;
  final double? nextSlabSpendMore;
  final double? nextSlabDiscount;

  final double smallCartFee;
  final double smallCartThreshold;
  final bool deliveryIsFree;
  final double freeDeliveryAbove;
  final double spendMoreForFreeDelivery;

  factory PricingDto.fromJson(Map<String, dynamic> json) {
    final applied = json.mapOrNull('appliedCoupon');
    final nextSlab = json.mapOrNull('couponNextSlab');
    return PricingDto(
      subtotal: json.dbl('subtotal'),
      tax: json.dbl('tax'),
      packagingFee: json.dbl('packagingFee'),
      deliveryFee: json.dbl('deliveryFee'),
      deliveryFeeGst: json.dbl('deliveryFeeGst'),
      platformFee: json.dbl('platformFee'),
      quickDeliveryFee: json.dbl('quickDeliveryFee'),
      discount: json.dbl('discount'),
      total: json.dbl('total'),
      currency: json.str('currency', 'INR'),
      // Echoed back whether or not it was honoured — never a success signal.
      couponCode: json.str('couponCode').nullIfEmpty,
      deliveryMode: json.str('deliveryMode', 'basic'),
      distanceKm: json.doubleOrNull('distanceKm'),
      deliveryPromiseMinutes: json.intOrNull('deliveryPromiseMinutes'),
      deliveryPromiseMinutesBasic:
          json.intOrNull('deliveryPromiseMinutesBasic'),
      deliveryPromiseMinutesQuick:
          json.intOrNull('deliveryPromiseMinutesQuick'),
      deliveryFeeMessage: json.mapAt('deliveryFeeBreakdown').str('message'),
      appliedCouponCode: applied?.str('code').nullIfEmpty,
      appliedCouponDiscount: applied?.dbl('discount') ?? 0,
      couponRejectedReason: json.str('couponRejectedReason'),
      nextSlabMinOrderValue: nextSlab?.doubleOrNull('minOrderValue'),
      nextSlabSpendMore: nextSlab?.doubleOrNull('spendMore'),
      nextSlabDiscount: nextSlab?.doubleOrNull('discount'),
      smallCartFee: json.dbl('smallCartFee'),
      smallCartThreshold: json.dbl('smallCartThreshold'),
      deliveryIsFree: json.boolean('deliveryIsFree'),
      freeDeliveryAbove: json.dbl('freeDeliveryAbove'),
      spendMoreForFreeDelivery: json.dbl('spendMoreForFreeDelivery'),
    );
  }

  /// Echoed back on `POST /orders`. The server recomputes everything and only
  /// reads `couponCode`, but we send the full object as the contract expects.
  Map<String, dynamic> toJson() => {
        'subtotal': subtotal,
        'tax': tax,
        'packagingFee': packagingFee,
        'deliveryFee': deliveryFee,
        'platformFee': platformFee,
        'discount': discount,
        'total': total,
        'currency': currency,
        'couponCode': couponCode,
      };
}

class PriceChangeDto {
  const PriceChangeDto({
    required this.itemId,
    required this.name,
    required this.previousPrice,
    required this.price,
  });

  final String itemId;
  final String name;
  final double previousPrice;
  final double price;

  factory PriceChangeDto.fromJson(Map<String, dynamic> json) => PriceChangeDto(
        itemId: json.str('itemId'),
        name: json.str('name'),
        previousPrice: json.dbl('previousPrice'),
        price: json.dbl('price'),
      );
}
