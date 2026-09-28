import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/app_providers.dart';
import '../../../di/repository_providers.dart';
import '../../../di/service_providers.dart';
import '../../../domain/model/coupon.dart';

/// Offers available to the current cart, ranked eligible-first.
final couponsProvider = FutureProvider<List<Coupon>>((ref) async {
  final cart = ref.watch(cartProvider).cart;
  final coupons = await ref.watch(couponRepositoryProvider).available(
        sellerId: cart.sellerId.isEmpty ? null : cart.sellerId,
      );
  return ref.read(couponEligibilityServiceProvider).rank(coupons, cart);
});
