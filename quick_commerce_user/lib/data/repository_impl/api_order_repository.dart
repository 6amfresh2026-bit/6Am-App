import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../../domain/model/address.dart';
import '../../domain/model/cart.dart';
import '../../domain/model/order.dart';
import '../../domain/model/paged_result.dart';
import '../../domain/model/payment_method.dart';
import '../../domain/repository/order_repository.dart';
import '../dto/json_reader.dart';
import '../dto/order_dto.dart';
import '../mapper/address_mapper.dart';
import '../mapper/order_mapper.dart';
import '../mapper/pricing_mapper.dart';
import 'api_paths.dart';

class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository(this._client);

  final ApiClient _client;

  @override
  Future<PlacedOrder> place({
    required Cart cart,
    required Address address,
    required PaymentMethod method,
    String? customerName,
    String? customerPhone,
    String? instructions,
    bool sendCutlery = false,
    bool allowSubstitutes = false,
    String deliveryMode = 'basic',
    DateTime? scheduledAt,
  }) async {
    final json = await _client.post(
      ApiPaths.orders,
      body: {
        'items': cart.items.map(OrderMapper.lineToJson).toList(),
        // The create endpoint's field is `address`, not `deliveryAddress`.
        'address': AddressMapper.toOrderJson(address, customerName: customerName),
        'restaurantId': cart.sellerId,
        if (cart.sellerName.isNotEmpty) 'restaurantName': cart.sellerName,
        if (customerName != null && customerName.isNotEmpty)
          'customerName': customerName,
        if (customerPhone != null && customerPhone.isNotEmpty)
          'customerPhone': customerPhone,
        // The server recomputes every figure; only `couponCode` is honoured.
        'pricing': PricingMapper.toDto(cart.pricing).toJson(),
        if (instructions != null && instructions.trim().isNotEmpty)
          'deliveryInstructions': instructions.trim(),
        'deliveryMode': deliveryMode,
        'sendCutlery': sendCutlery,
        // Defaults to 'refund': a swap spends the customer's money on
        // something they did not choose, so it needs saying yes to.
        'substitutionPreference': allowSubstitutes ? 'allow' : 'refund',
        'paymentMethod': method.orderWireValue,
        if (scheduledAt != null) 'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      },
      requiresAuth: true,
    );

    if (json is! Map<String, dynamic>) {
      throw const ParseException('Unexpected order response.');
    }

    final razorpay = json.mapOrNull('razorpay');
    final placed = OrderMapper.placedFromJson(json);

    AppLogger.debug(
      'order created: id=${placed.order.id} method=${method.orderWireValue} '
      'status=${placed.order.status} | gateway block: '
      '${razorpay == null ? 'ABSENT (no Razorpay order was minted)' : 'rzOrderId=${placed.gatewayOrderId} '
          'key=${placed.gatewayKey} amountPaise=${placed.gatewayAmountPaise} '
          'currency=${placed.gatewayCurrency}'}',
      scope: 'payment',
    );

    return placed;
  }

  @override
  Future<Order> verifyPayment({
    required String orderId,
    required String gatewayOrderId,
    required String gatewayPaymentId,
    required String signature,
  }) async {
    AppLogger.debug(
      'verify-payment → POST ${ApiPaths.verifyPayment} '
      'orderId=$orderId rzOrderId=$gatewayOrderId '
      'rzPaymentId=$gatewayPaymentId signature=${signature.length} chars',
      scope: 'payment',
    );
    try {
      final json = await _client.post(
        ApiPaths.verifyPayment,
        body: {
          'orderId': orderId,
          'razorpayOrderId': gatewayOrderId,
          'razorpayPaymentId': gatewayPaymentId,
          'razorpaySignature': signature,
        },
        requiresAuth: true,
      );
      final order = _single(json);
      AppLogger.debug(
        'verify-payment OK: order=${order.id} status=${order.status} '
        'paymentStatus=${order.paymentStatus}',
        scope: 'payment',
      );
      return order;
    } catch (e) {
      // The order may well be paid at Razorpay even though this call failed;
      // never let this line be the only record of it.
      AppLogger.error('verify-payment FAILED for order $orderId', error: e);
      rethrow;
    }
  }

  @override
  Future<void> abandonPendingPayment(String orderId) =>
      _client.delete(ApiPaths.orderPendingPayment(orderId), requiresAuth: true);

  @override
  Future<PagedResult<Order>> list({int page = 1, int pageSize = 20}) async {
    final json = await _client.get(
      ApiPaths.orders,
      query: {'page': page, 'limit': pageSize},
      requiresAuth: true,
    );
    if (json is! Map<String, dynamic>) return PagedResult.empty<Order>();

    final dtos = json.objects('data').map(OrderDto.fromJson).toList();
    final meta = PageMeta.from(json, fallbackCount: dtos.length);

    return PagedResult(
      items: dtos.map(OrderMapper.toDomain).toList(),
      total: meta.total,
      page: meta.page,
      pageSize: meta.pageSize,
    );
  }

  @override
  Future<Order> getById(String orderId) async {
    final json = await _client.get(ApiPaths.order(orderId), requiresAuth: true);
    return _single(json);
  }

  @override
  Future<OrderRoute> routeFor(String orderId) async {
    final json = await _client.get(ApiPaths.orderRoute(orderId), requiresAuth: true);
    if (json is! Map<String, dynamic>) return OrderRoute.empty;
    return OrderMapper.routeToDomain(OrderRouteDto.fromJson(json));
  }

  @override
  Future<String> dropOtp(String orderId) async {
    try {
      final json =
          await _client.get(ApiPaths.orderDropOtp(orderId), requiresAuth: true);
      if (json is! Map<String, dynamic>) return '';
      return json.str('otp');
    } on AppException {
      // The endpoint 400s until the rider is at the drop — not an error here.
      return '';
    }
  }

  @override
  Future<Order> cancel(String orderId, {String? reason}) async {
    final json = await _client.patch(
      ApiPaths.orderCancel(orderId),
      body: {'reason': ?reason?.nullIfEmpty},
      requiresAuth: true,
    );
    return _single(json);
  }

  @override
  Future<Order> rate({
    required String orderId,
    required int sellerRating,
    int? riderRating,
    String? comment,
  }) async {
    final json = await _client.patch(
      ApiPaths.orderRatings(orderId),
      body: {
        'restaurantRating': sellerRating,
        'deliveryPartnerRating': ?riderRating,
        if (comment != null && comment.trim().isNotEmpty)
          'restaurantComment': comment.trim(),
      },
      requiresAuth: true,
    );
    return _single(json);
  }

  @override
  Future<Order> updateInstructions(String orderId, String instructions) async {
    final json = await _client.patch(
      ApiPaths.orderInstructions(orderId),
      body: {'instructions': instructions},
      requiresAuth: true,
    );
    return _single(json);
  }

  Order _single(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const ParseException('Unexpected order response.');
    }
    return OrderMapper.toDomain(OrderDto.fromJson(json.mapAt('order')));
  }
}
