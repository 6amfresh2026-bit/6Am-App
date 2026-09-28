import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/usecase/add_to_cart_usecase.dart';
import '../domain/usecase/apply_coupon_usecase.dart';
import '../domain/usecase/place_order_usecase.dart';
import '../domain/usecase/price_cart_usecase.dart';
import '../domain/usecase/verify_payment_usecase.dart';
import 'repository_providers.dart';
import 'service_providers.dart';

final addToCartUseCaseProvider = Provider<AddToCartUseCase>(
  (ref) => AddToCartUseCase(
    repository: ref.watch(cartRepositoryProvider),
    pricingService: ref.watch(cartPricingServiceProvider),
    stockService: ref.watch(stockServiceProvider),
  ),
);

final priceCartUseCaseProvider = Provider<PriceCartUseCase>(
  (ref) => PriceCartUseCase(ref.watch(cartRepositoryProvider)),
);

final applyCouponUseCaseProvider = Provider<ApplyCouponUseCase>(
  (ref) => ApplyCouponUseCase(
    priceCart: ref.watch(priceCartUseCaseProvider),
    eligibility: ref.watch(couponEligibilityServiceProvider),
  ),
);

final placeOrderUseCaseProvider = Provider<PlaceOrderUseCase>(
  (ref) => PlaceOrderUseCase(
    repository: ref.watch(orderRepositoryProvider),
    validation: ref.watch(checkoutValidationServiceProvider),
  ),
);


final verifyPaymentUseCaseProvider = Provider<VerifyPaymentUseCase>(
  (ref) => VerifyPaymentUseCase(
    ref.watch(orderRepositoryProvider),
    ref.watch(paymentGatewayProvider),
  ),
);
