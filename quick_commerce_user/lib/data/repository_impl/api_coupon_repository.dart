import '../../core/network/api_client.dart';
import '../../domain/model/coupon.dart';
import '../../domain/repository/coupon_repository.dart';
import '../dto/coupon_dto.dart';
import '../dto/json_reader.dart';
import '../mapper/coupon_mapper.dart';
import 'api_paths.dart';

class ApiCouponRepository implements CouponRepository {
  ApiCouponRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<Coupon>> available({double? subtotal, String? sellerId}) async {
    // Sent without `subtotal` on purpose: the endpoint would drop coupons the
    // cart has not yet unlocked, and the UI wants to show those greyed out
    // with an "add ₹X more" nudge.
    final json = await _client.get(
      ApiPaths.offers,
      query: {if (sellerId != null && sellerId.isNotEmpty) 'restaurantId': sellerId},
      // Personalises the list (drops used/first-order-only coupons) when signed in.
      requiresAuth: true,
    );
    if (json is! Map<String, dynamic>) return const [];
    return CouponMapper.toDomainList(
      json.objects('allOffers').map(CouponDto.fromJson).toList(),
    );
  }
}
