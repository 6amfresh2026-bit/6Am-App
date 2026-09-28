import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/domain/model/cart.dart';
import 'package:quick_commerce_user/domain/model/order.dart';
import 'package:quick_commerce_user/domain/model/order_status.dart';
import 'package:quick_commerce_user/domain/model/payment_method.dart';
import 'package:quick_commerce_user/domain/repository/order_repository.dart';
import 'package:quick_commerce_user/domain/usecase/verify_payment_usecase.dart';
import 'package:quick_commerce_user/platform/payment/razorpay_checkout.dart';

class _FakeGateway implements PaymentGateway {
  _FakeGateway(this.outcome);

  final PaymentOutcome outcome;
  Map<String, Object?>? opened;

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
  }) async {
    opened = {
      'key': key,
      'order_id': gatewayOrderId,
      'amount': amountPaise,
      'currency': currency,
      'method': preferredMethod,
    };
    return outcome;
  }

  @override
  void dispose() {}
}

class _FakeOrders implements OrderRepository {
  Map<String, String>? verified;

  @override
  Future<Order> verifyPayment({
    required String orderId,
    required String gatewayOrderId,
    required String gatewayPaymentId,
    required String signature,
  }) async {
    verified = {
      'orderId': orderId,
      'razorpayOrderId': gatewayOrderId,
      'razorpayPaymentId': gatewayPaymentId,
      'razorpaySignature': signature,
    };
    return _order.copyWith(status: OrderStatus.created);
  }

  @override
  Future<void> abandonPendingPayment(String orderId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

final _order = Order(
  id: 'ord_1',
  displayId: '#1042',
  status: OrderStatus.pendingPayment,
  paymentMethod: PaymentMethod.upi,
  pricing: const CartPricing(subtotal: 480, total: 512.5),
  lines: const [],
  placedAt: DateTime(2026, 8, 7),
);

final _cashOrder = Order(
  id: 'ord_1',
  displayId: '#1043',
  status: OrderStatus.created,
  paymentMethod: PaymentMethod.cash,
  pricing: const CartPricing(subtotal: 480, total: 512.5),
  lines: const [],
  placedAt: DateTime(2026, 8, 7),
);

PlacedOrder _placed({int amountPaise = 51250, String? gatewayOrderId = 'order_rz1'}) =>
    PlacedOrder(
      order: _order,
      gatewayOrderId: gatewayOrderId,
      gatewayKey: gatewayOrderId == null ? null : 'rzp_test_key',
      gatewayAmountPaise: amountPaise,
    );

void main() {
  test('a captured payment is verified with the gateway identifiers', () async {
    final gateway = _FakeGateway(
      const PaymentSucceeded(
        orderId: 'order_rz1',
        paymentId: 'pay_abc',
        signature: 'sig_abc',
      ),
    );
    final orders = _FakeOrders();

    await VerifyPaymentUseCase(orders, gateway)(_placed());

    // The sheet gets the backend's paise figure verbatim — never a recomputed one.
    expect(gateway.opened!['amount'], 51250);
    expect(gateway.opened!['order_id'], 'order_rz1');
    expect(orders.verified, {
      'orderId': 'ord_1',
      'razorpayOrderId': 'order_rz1',
      'razorpayPaymentId': 'pay_abc',
      'razorpaySignature': 'sig_abc',
    });
  });

  test('a dismissed sheet never reaches verify-payment', () async {
    final orders = _FakeOrders();

    await expectLater(
      VerifyPaymentUseCase(orders, _FakeGateway(const PaymentCancelled()))(_placed()),
      throwsA(isA<PaymentCancelledByUser>()),
    );
    expect(orders.verified, isNull);
  });

  test('a declined payment surfaces the gateway reason', () async {
    final orders = _FakeOrders();

    await expectLater(
      VerifyPaymentUseCase(
        orders,
        _FakeGateway(const PaymentFailed('Your bank declined the payment')),
      )(_placed()),
      throwsA(
        isA<PaymentDeclined>().having(
          (e) => e.message,
          'message',
          'Your bank declined the payment',
        ),
      ),
    );
    expect(orders.verified, isNull);
  });

  test('cash and wallet orders skip the gateway entirely', () async {
    final gateway = _FakeGateway(const PaymentCancelled());

    final order = await VerifyPaymentUseCase(_FakeOrders(), gateway)(
      PlacedOrder(order: _cashOrder),
    );

    expect(gateway.opened, isNull);
    expect(order.id, 'ord_1');
  });

  test('an online order with no gateway params is never treated as paid', () {
    // Razorpay credentials missing on the backend: the order exists but was
    // never charged.
    expect(
      VerifyPaymentUseCase(_FakeOrders(), _FakeGateway(const PaymentCancelled()))(
        _placed(gatewayOrderId: null),
      ),
      throwsA(isA<PaymentDeclined>()),
    );
  });

  test('scan-and-pay is sent as razorpay so an order is actually charged', () {
    expect(PaymentMethod.qr.orderWireValue, 'razorpay');
    expect(PaymentMethod.qr.razorpayMethod, 'upi');
    expect(PaymentMethod.cash.orderWireValue, 'cash');
  });
}
