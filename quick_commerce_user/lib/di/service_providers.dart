import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/service/cart_pricing_service.dart';
import '../domain/service/catalog_grouping_service.dart';
import '../domain/service/checkout_validation_service.dart';
import '../domain/service/coupon_eligibility_service.dart';
import '../domain/service/search_ranking_service.dart';
import '../domain/service/stock_service.dart';
import '../domain/service/subscription_schedule_service.dart';
import 'repository_providers.dart';

/// Free-delivery threshold, read once from the backend's public fee settings.
/// Falls back to the service default while the call is in flight or if it
/// fails — the cart nudge is cosmetic, the real fee always comes from pricing.
final feeSettingsProvider =
    FutureProvider<({double freeDeliveryThreshold, double baseDeliveryFee})>(
  (ref) => ref.watch(catalogContentRepositoryProvider).feeSettings(),
);

final cartPricingServiceProvider = Provider<CartPricingService>((ref) {
  final settings = ref.watch(feeSettingsProvider).valueOrNull;
  return CartPricingService(
    freeDeliveryThreshold: settings?.freeDeliveryThreshold ?? 199,
  );
});

final stockServiceProvider = Provider<StockService>((ref) => const StockService());

final couponEligibilityServiceProvider =
    Provider<CouponEligibilityService>((ref) => const CouponEligibilityService());

final searchRankingServiceProvider =
    Provider<SearchRankingService>((ref) => const SearchRankingService());

final catalogGroupingServiceProvider =
    Provider<CatalogGroupingService>((ref) => const CatalogGroupingService());

final checkoutValidationServiceProvider = Provider<CheckoutValidationService>(
  (ref) => CheckoutValidationService(stockService: ref.watch(stockServiceProvider)),
);

final subscriptionScheduleServiceProvider = Provider<SubscriptionScheduleService>(
  (ref) => const SubscriptionScheduleService(),
);
