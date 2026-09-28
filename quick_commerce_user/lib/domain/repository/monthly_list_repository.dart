import '../model/address.dart';
import '../model/monthly_list.dart';
import '../model/order.dart';
import '../model/payment_method.dart';

abstract interface class MonthlyListRepository {
  Future<List<MonthlyList>> list();

  Future<MonthlyList> getById(String listId);

  /// Every item must belong to [restaurantId] — a list is single-restaurant.
  Future<MonthlyList> create({
    required String restaurantId,
    required List<MonthlyListItem> items,
    String? name,
  });

  /// At least one field must be supplied; the backend rejects an empty patch.
  Future<MonthlyList> update(
    String listId, {
    String? name,
    bool? isActive,
    List<MonthlyListItem>? items,
  });

  Future<void> delete(String listId);

  /// Places this month's order from the saved list. Exactly one of [addressId]
  /// or [address] is required. Returns the same payload as normal checkout, so
  /// an online-payment order still hands back the gateway block to complete.
  Future<PlacedOrder> placeOrder(
    String listId, {
    String? addressId,
    Address? address,
    PaymentMethod method = PaymentMethod.cash,
    String deliveryMode = 'basic',
    String? couponCode,
  });
}
