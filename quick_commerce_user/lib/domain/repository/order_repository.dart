import '../model/address.dart';
import '../model/cart.dart';
import '../model/order.dart';
import '../model/paged_result.dart';
import '../model/payment_method.dart';

abstract interface class OrderRepository {
  Future<PlacedOrder> place({
    required Cart cart,
    required Address address,
    required PaymentMethod method,
    String? customerName,
    String? customerPhone,
    String? instructions,
    bool sendCutlery,
    bool allowSubstitutes,
    String deliveryMode,
    DateTime? scheduledAt,
  });

  /// Confirms a gateway payment with the three identifiers Razorpay returned.
  /// The backend re-verifies the signature and the captured amount; a mismatch
  /// throws rather than marking the order paid.
  Future<Order> verifyPayment({
    required String orderId,
    required String gatewayOrderId,
    required String gatewayPaymentId,
    required String signature,
  });

  Future<void> abandonPendingPayment(String orderId);

  Future<PagedResult<Order>> list({int page, int pageSize});

  Future<Order> getById(String orderId);

  Future<OrderRoute> routeFor(String orderId);

  Future<String> dropOtp(String orderId);

  Future<Order> cancel(String orderId, {String? reason});

  Future<Order> rate({
    required String orderId,
    required int sellerRating,
    int? riderRating,
    String? comment,
  });

  Future<Order> updateInstructions(String orderId, String instructions);
}
