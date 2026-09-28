import '../model/address.dart';
import '../model/cart.dart';
import '../model/payment_method.dart';
import 'stock_service.dart';

/// What is blocking checkout, if anything.
sealed class CheckoutIssue {
  const CheckoutIssue(this.message);

  final String message;
}

class MissingAddress extends CheckoutIssue {
  const MissingAddress() : super('Choose a delivery address to continue');
}

class AddressMissingCoordinates extends CheckoutIssue {
  const AddressMissingCoordinates()
      : super('We need this address pinned on the map to price delivery');
}

class EmptyCart extends CheckoutIssue {
  const EmptyCart() : super('Your cart is empty');
}

class ItemsUnavailable extends CheckoutIssue {
  const ItemsUnavailable(this.itemNames)
      : super('Some items are no longer available');

  final List<String> itemNames;
}

class BillNotPriced extends CheckoutIssue {
  const BillNotPriced() : super('Fetching the latest bill — one moment');
}

class MissingPaymentMethod extends CheckoutIssue {
  const MissingPaymentMethod() : super('Select a payment method');
}

class CheckoutValidationService {
  const CheckoutValidationService({this.stockService = const StockService()});

  final StockService stockService;

  /// All blocking issues, in the order the user should resolve them.
  List<CheckoutIssue> validate({
    required Cart cart,
    required Address? address,
    PaymentMethod? method,
    bool requirePayment = false,
  }) {
    final issues = <CheckoutIssue>[];

    if (cart.isEmpty) {
      issues.add(const EmptyCart());
      return issues;
    }

    final unavailable = stockService.unavailableLines(cart);
    if (unavailable.isNotEmpty) {
      issues.add(ItemsUnavailable(unavailable.map((l) => l.product.name).toList()));
    }

    if (address == null) {
      issues.add(const MissingAddress());
    } else if (!address.hasCoordinates) {
      issues.add(const AddressMissingCoordinates());
    }

    if (cart.effectiveTotal <= 0) issues.add(const BillNotPriced());

    if (requirePayment && method == null) issues.add(const MissingPaymentMethod());

    return issues;
  }

  bool canPlaceOrder({
    required Cart cart,
    required Address? address,
    required PaymentMethod? method,
  }) =>
      validate(
        cart: cart,
        address: address,
        method: method,
        requirePayment: true,
      ).isEmpty;
}
