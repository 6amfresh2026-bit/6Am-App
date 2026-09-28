import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/utils/logger.dart';

/// What the user came back from the Razorpay sheet with.
sealed class PaymentOutcome {
  const PaymentOutcome();
}

/// Razorpay captured the payment. The three identifiers are what the backend
/// re-signs and re-fetches before it will mark the order paid.
class PaymentSucceeded extends PaymentOutcome {
  const PaymentSucceeded({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });

  final String orderId;
  final String paymentId;
  final String signature;
}

/// The gateway rejected the payment, or the network dropped mid-flow.
class PaymentFailed extends PaymentOutcome {
  const PaymentFailed(this.message, {this.code});

  final String message;
  final int? code;
}

/// The user dismissed the sheet without paying. Not an error — the order stays
/// in `pending_payment` and can be retried or abandoned.
class PaymentCancelled extends PaymentOutcome {
  const PaymentCancelled();
}

/// Opens the Razorpay checkout sheet.
///
/// Everything that decides whether money moved lives on the backend: it creates
/// the Razorpay order, and `verify-payment` re-checks the signature, refetches
/// the payment and compares the amount in paise. This class only carries the
/// user to the sheet and the result back.
abstract interface class PaymentGateway {
  Future<PaymentOutcome> open({
    required String key,
    required String gatewayOrderId,
    required int amountPaise,
    required String currency,
    required String orderReference,
    String customerName,
    String customerEmail,
    String customerPhone,
    String preferredMethod,
  });

  void dispose();
}

class RazorpayCheckout implements PaymentGateway {
  RazorpayCheckout();

  Razorpay? _razorpay;
  Completer<PaymentOutcome>? _pending;

  @override
  Future<PaymentOutcome> open({
    required String key,
    required String gatewayOrderId,
    required int amountPaise,
    required String currency,
    required String orderReference,
    String customerName = '',
    String customerEmail = '',
    String customerPhone = '',
    String preferredMethod = '',
  }) {
    // A sheet is already up: never open a second one, or the first completer
    // leaks and the user can pay twice.
    final inFlight = _pending;
    if (inFlight != null && !inFlight.isCompleted) return inFlight.future;

    final completer = Completer<PaymentOutcome>();
    _pending = completer;

    final razorpay = _razorpay ??= Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    AppLogger.debug(
      'opening Razorpay checkout: key=$key order_id=$gatewayOrderId '
      'amount=$amountPaise $currency reference=$orderReference '
      'method=${preferredMethod.isEmpty ? 'any' : preferredMethod}',
      scope: 'payment',
    );

    try {
      razorpay.open({
        'key': key,
        'order_id': gatewayOrderId,
        'amount': amountPaise,
        'currency': currency,
        'name': 'Suvio Quick',
        'description': 'Order $orderReference',
        // Razorpay times the sheet out on its own; without this a backgrounded
        // sheet can sit open past the order's pending-payment window.
        'timeout': 300,
        'retry': {'enabled': true, 'max_count': 1},
        'prefill': {
          if (customerName.isNotEmpty) 'name': customerName,
          if (customerEmail.isNotEmpty) 'email': customerEmail,
          if (customerPhone.isNotEmpty) 'contact': customerPhone,
          if (preferredMethod.isNotEmpty) 'method': preferredMethod,
        },
      });
    } catch (e, stack) {
      AppLogger.error('Razorpay sheet failed to open', error: e, stackTrace: stack);
      _finish(const PaymentFailed('Could not open the payment screen.'));
    }

    return completer.future;
  }

  void _onSuccess(PaymentSuccessResponse response) {
    final paymentId = response.paymentId ?? '';
    final signature = response.signature ?? '';
    AppLogger.debug(
      'Razorpay success callback: order_id=${response.orderId} '
      'payment_id=$paymentId signature=${signature.isEmpty ? 'MISSING' : 'present'}',
      scope: 'payment',
    );
    // Razorpay only omits these on a flow the backend cannot verify anyway —
    // treating it as success would strand a paid order as unpaid.
    if (paymentId.isEmpty || signature.isEmpty) {
      AppLogger.error('Razorpay success without payment id/signature');
      _finish(const PaymentFailed('Payment could not be confirmed.'));
      return;
    }
    _finish(
      PaymentSucceeded(
        orderId: response.orderId ?? '',
        paymentId: paymentId,
        signature: signature,
      ),
    );
  }

  void _onError(PaymentFailureResponse response) {
    AppLogger.debug(
      'Razorpay error callback: code=${response.code} message=${response.message}',
      scope: 'payment',
    );
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      AppLogger.debug('Razorpay sheet dismissed by user', scope: 'payment');
      _finish(const PaymentCancelled());
      return;
    }
    _finish(
      PaymentFailed(
        _readableMessage(response.message),
        code: response.code,
      ),
    );
  }

  /// Paytm and the like hand off to their own app; nothing is captured yet, so
  /// the order is left pending and the user can retry.
  void _onExternalWallet(ExternalWalletResponse response) {
    _finish(const PaymentCancelled());
  }

  void _finish(PaymentOutcome outcome) {
    final completer = _pending;
    _pending = null;
    if (completer != null && !completer.isCompleted) completer.complete(outcome);
  }

  /// Razorpay wraps its reason in a JSON blob; show the sentence, not the blob.
  static String _readableMessage(String? raw) {
    final message = (raw ?? '').trim();
    if (message.isEmpty) return 'The payment could not be completed.';
    final match = RegExp(r'"description"\s*:\s*"([^"]+)"').firstMatch(message);
    return match?.group(1) ?? message;
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
    _finish(const PaymentCancelled());
  }
}
