import '../model/payment_method.dart';
import '../model/product_subscription.dart';

abstract interface class SubscriptionRepository {
  /// The live subscription-discount rate (%) by frequency, e.g.
  /// `{daily: 0, weekly: 5, monthly: 12}`. Read before showing frequency
  /// choices — never hardcode these numbers, the backend owns them.
  Future<Map<SubscriptionFrequency, int>> discountConfig();

  Future<List<ProductSubscription>> list();

  /// Includes the pre-generated [SubscriptionOccurrence] schedule.
  Future<ProductSubscription> getById(String subscriptionId);

  Future<ProductSubscription> create({
    required String restaurantId,
    required String itemId,
    required int quantity,
    required SubscriptionFrequency frequency,
    required String deliveryTime,
    required DateTime startDate,
    required String addressId,
    String? variantId,
    List<int> daysOfWeek = const [],
    int? dayOfMonth,
    PaymentMethod method = PaymentMethod.cash,
  });

  /// Pause, resume, cancel, or edit the parts the backend allows to change.
  /// At least one field must be supplied.
  Future<ProductSubscription> update(
    String subscriptionId, {
    SubscriptionStatus? status,
    int? quantity,
    String? deliveryTime,
    String? addressId,
  });

  Future<void> cancel(String subscriptionId);

  Future<List<SubscriptionOccurrence>> occurrences(String subscriptionId);

  /// Calls off one upcoming delivery. The backend refuses once the delivery
  /// day has begun — see [SubscriptionOccurrence.canCancelAt].
  Future<SubscriptionOccurrence> cancelOccurrence(
    String subscriptionId,
    String occurrenceId, {
    String? reason,
  });
}
