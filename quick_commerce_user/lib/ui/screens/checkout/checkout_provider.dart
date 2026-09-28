import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/utils/logger.dart';
import '../../../di/app_providers.dart';
import '../../../di/service_providers.dart';
import '../../../di/usecase_providers.dart';
import '../../../domain/model/order.dart';
import '../../../domain/model/payment_method.dart';
import '../../../domain/service/checkout_validation_service.dart';
import '../../../domain/usecase/place_order_usecase.dart';
import 'checkout_state.dart';

class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() {
    // Re-price whenever the chosen address changes: delivery fee is
    // distance-based, so a new address means a new bill.
    ref.listen(selectedAddressProvider, (previous, next) {
      if (previous?.id != next?.id) ref.read(cartProvider.notifier).priceNow();
    });
    Future.microtask(() => ref.read(cartProvider.notifier).priceNow());
    return const CheckoutState();
  }

  void setPaymentMethod(PaymentMethod method) =>
      state = state.copyWith(paymentMethod: method);

  void setInstructions(String value) =>
      state = state.copyWith(instructions: value);

  void setSendCutlery(bool value) => state = state.copyWith(sendCutlery: value);

  void setAllowSubstitutes(bool value) =>
      state = state.copyWith(allowSubstitutes: value);

  void toggleSummary() =>
      state = state.copyWith(expandedSummary: !state.expandedSummary);

  void consumeShake() => state = state.copyWith(shakeAddressCard: false);

  /// Validates without placing, so the CTA can reflect readiness live.
  List<CheckoutIssue> currentIssues() =>
      ref.read(checkoutValidationServiceProvider).validate(
            cart: ref.read(cartProvider).cart,
            address: ref.read(selectedAddressProvider),
            method: state.paymentMethod,
            requirePayment: true,
          );

  /// Creates the order server-side. Returns null when blocked or on failure.
  Future<PlacedOrder?> placeOrder({required String? name, required String? phone}) async {
    final issues = currentIssues();
    if (issues.isNotEmpty) {
      state = state.copyWith(
        issues: issues,
        shakeAddressCard: issues.any((i) => i is MissingAddress),
      );
      return null;
    }

    state = state.copyWith(isPlacing: true, issues: const [], clearFailure: true);
    final cart = ref.read(cartProvider).cart;
    AppLogger.debug(
      'placing order: method=${state.paymentMethod.orderWireValue} '
      'seller=${cart.sellerId} items=${cart.items.length} '
      'total=${cart.pricing.total}',
      scope: 'payment',
    );
    try {
      final outcome = await ref.read(placeOrderUseCaseProvider)(
        cart: cart,
        address: ref.read(selectedAddressProvider),
        method: state.paymentMethod,
        customerName: name,
        customerPhone: phone,
        instructions: state.instructions,
        sendCutlery: state.sendCutlery,
        allowSubstitutes: state.allowSubstitutes,
      );

      state = state.copyWith(isPlacing: false);
      return switch (outcome) {
        OrderPlaced(:final placedOrder) => placedOrder,
        OrderBlocked(:final issues) => () {
            state = state.copyWith(issues: issues);
            return null;
          }(),
      };
    } catch (e) {
      state = state.copyWith(
        isPlacing: false,
        failure: ErrorMapper.toFailure(e),
      );
      return null;
    }
  }
}

final checkoutProvider =
    NotifierProvider<CheckoutController, CheckoutState>(CheckoutController.new);
