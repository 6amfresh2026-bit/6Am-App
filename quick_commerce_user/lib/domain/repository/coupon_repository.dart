import '../model/coupon.dart';

abstract interface class CouponRepository {
  /// `GET /food/restaurant/offers`. Passing the subtotal lets the backend
  /// pre-filter by minimum order value; we still show the rest greyed out.
  Future<List<Coupon>> available({double? subtotal, String? sellerId});
}
