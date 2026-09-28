import 'json_reader.dart';

/// From `GET /food/restaurant/offers`.
class CouponDto {
  const CouponDto({
    required this.id,
    required this.code,
    required this.title,
    required this.discountType,
    required this.discountValue,
    this.minOrderValue = 0,
    this.maxDiscount,
    this.restaurantId = '',
    this.restaurantName = '',
    this.isFirstOrderOnly = false,
    this.endDate,
  });

  final String id;
  final String code;
  final String title;
  final String discountType;
  final double discountValue;
  final double minOrderValue;
  final double? maxDiscount;
  final String restaurantId;
  final String restaurantName;
  final bool isFirstOrderOnly;
  final DateTime? endDate;

  factory CouponDto.fromJson(Map<String, dynamic> json) => CouponDto(
        id: json.id(const ['id', 'offerId', '_id']),
        code: json.str('couponCode'),
        title: json.str('title'),
        discountType: json.str('discountType'),
        discountValue: json.dbl('discountValue'),
        minOrderValue: json.dbl('minOrderValue'),
        maxDiscount: json.doubleOrNull('maxDiscount'),
        restaurantId: json.id(const ['restaurantId']),
        restaurantName: json.str('restaurantName'),
        isFirstOrderOnly: json.boolean('isFirstOrderOnly'),
        endDate: json.dateOrNull('endDate'),
      );
}
