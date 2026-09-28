import '../../core/utils/logger.dart';
import '../../platform/payment/razorpay_checkout.dart';
import '../model/order.dart';
import '../model/user.dart';
import '../repository/order_repository.dart';

/// Takes a created order through the gateway and back.
///
/// The app never decides whether a payment succeeded: it opens Razorpay with
/// the parameters the backend minted, and hands the three identifiers Razorpay
/// returns to `POST /food/orders/verify-payment`, which re-checks the
/// signature, refetches the payment from Razorpay and compares the amount
/// before it will mark the order paid.
class VerifyPaymentUseCase {
  const VerifyPaymentUseCase(this._repository, this._gateway);

  final OrderRepository _repository;
  final PaymentGateway _gateway;

  Future<Order> call(PlacedOrder placed, {User? customer}) async {
    final gatewayOrderId = placed.gatewayOrderId;
    final key = placed.gatewayKey;

    if (gatewayOrderId == null || key == null) {
      // Cash and wallet orders are settled at creation; there is nothing to pay.
      if (!placed.order.paymentMethod.isOnline) {
        AppLogger.debug(
          'no gateway step needed: method=${placed.order.paymentMethod.wireValue} '
          'order=${placed.order.id}',
          scope: 'payment',
        );
        return placed.order;
      }
      // An online order without gateway parameters was never charged — the
      // backend has no Razorpay credentials configured. Completing it here
      // would hand the user a success screen for an unpaid order.
      AppLogger.error(
        'online order ${placed.order.id} has no Razorpay parameters — '
        'the backend did not mint a gateway order. Payment cannot start.',
      );
      throw const PaymentDeclined('Online payment is unavailable right now.');
    }

    final outcome = await _gateway.open(
      key: key,
      gatewayOrderId: gatewayOrderId,
      // The backend echoes Razorpay's own paise figure; falling back to the
      // cart total is only for an older response that omits it.
      amountPaise: placed.gatewayAmountPaise > 0
          ? placed.gatewayAmountPaise
          : (placed.order.pricing.total * 100).round(),
      currency: placed.gatewayCurrency,
      orderReference: placed.order.displayId,
      customerName: customer?.name ?? '',
      customerEmail: customer?.email ?? '',
      customerPhone: customer?.phone ?? '',
      preferredMethod: placed.order.paymentMethod.razorpayMethod,
    );

    return switch (outcome) {
      PaymentSucceeded(:final paymentId, :final signature) =>
        await _repository.verifyPayment(
          orderId: placed.order.id,
          gatewayOrderId: gatewayOrderId,
          gatewayPaymentId: paymentId,
          signature: signature,
        ),
      PaymentCancelled() => throw const PaymentCancelledByUser(),
      PaymentFailed(:final message) => throw PaymentDeclined(message),
    };
  }

  Future<void> abandon(PlacedOrder placed) =>
      _repository.abandonPendingPayment(placed.order.id);
}

/// The user closed the payment sheet. The order is still recoverable.
class PaymentCancelledByUser implements Exception {
  const PaymentCancelledByUser();

  @override
  String toString() => 'Payment was cancelled before it completed.';
}

/// The gateway refused the payment, with its own reason.
class PaymentDeclined implements Exception {
  const PaymentDeclined(this.message);

  final String message;

  @override
  String toString() => message;
}
