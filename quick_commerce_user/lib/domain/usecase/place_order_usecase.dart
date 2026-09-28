import '../model/address.dart';
import '../model/cart.dart';
import '../model/order.dart';
import '../model/payment_method.dart';
import '../repository/order_repository.dart';
import '../service/checkout_validation_service.dart';

sealed class PlaceOrderOutcome {
  const PlaceOrderOutcome();
}

class OrderPlaced extends PlaceOrderOutcome {
  const OrderPlaced(this.placedOrder);
  final PlacedOrder placedOrder;
}

class OrderBlocked extends PlaceOrderOutcome {
  const OrderBlocked(this.issues);
  final List<CheckoutIssue> issues;
}

/// Validates the cart, then creates the order server-side.
class PlaceOrderUseCase {
  const PlaceOrderUseCase({
    required OrderRepository repository,
    required CheckoutValidationService validation,
  })  : _repository = repository,
        _validation = validation;

  final OrderRepository _repository;
  final CheckoutValidationService _validation;

  Future<PlaceOrderOutcome> call({
    required Cart cart,
    required Address? address,
    required PaymentMethod method,
    String? customerName,
    String? customerPhone,
    String? instructions,
    bool sendCutlery = false,
    bool allowSubstitutes = false,
    DateTime? scheduledAt,
  }) async {
    final issues = _validation.validate(
      cart: cart,
      address: address,
      method: method,
      requirePayment: true,
    );
    if (issues.isNotEmpty) return OrderBlocked(issues);

    final placed = await _repository.place(
      cart: cart,
      address: address!,
      method: method,
      customerName: customerName,
      customerPhone: customerPhone,
      instructions: instructions,
      sendCutlery: sendCutlery,
      allowSubstitutes: allowSubstitutes,
      deliveryMode: cart.deliveryMode,
      scheduledAt: scheduledAt,
    );
    return OrderPlaced(placed);
  }
}
