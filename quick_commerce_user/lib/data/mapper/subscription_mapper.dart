import '../../domain/model/payment_method.dart';
import '../../domain/model/product_subscription.dart';
import '../dto/subscription_dto.dart';

abstract final class SubscriptionMapper {
  static SubscriptionOccurrence occurrenceToDomain(
    SubscriptionOccurrenceDto dto,
  ) =>
      SubscriptionOccurrence(
        id: dto.id,
        scheduledDate: dto.scheduledDate,
        deliveryTime: dto.deliveryTime,
        status: OccurrenceStatus.fromWire(dto.status),
        orderId: dto.orderId,
        cancelledAt: dto.cancelledAt,
        cancelReason: dto.cancelReason,
        failureReason: dto.failureReason,
      );

  /// Soonest first — the schedule is read as "what's coming next".
  static List<SubscriptionOccurrence> occurrencesToDomain(
    List<SubscriptionOccurrenceDto> dtos,
  ) {
    final list = dtos.map(occurrenceToDomain).toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    return list;
  }

  static ProductSubscription toDomain(SubscriptionDto dto) =>
      ProductSubscription(
        id: dto.id,
        restaurantId: dto.restaurantId,
        itemId: dto.itemId,
        itemName: dto.itemName,
        variantId: dto.variantId,
        quantity: dto.quantity,
        frequency: SubscriptionFrequency.fromWire(dto.frequency),
        daysOfWeek: dto.daysOfWeek,
        dayOfMonth: dto.dayOfMonth,
        deliveryTime: dto.deliveryTime,
        startDate: dto.startDate,
        addressId: dto.addressId,
        paymentMethod: PaymentMethod.fromWire(dto.paymentMethod),
        status: SubscriptionStatus.fromWire(dto.status),
        createdAt: dto.createdAt,
        occurrences: occurrencesToDomain(dto.occurrences),
      );

  static List<ProductSubscription> toDomainList(List<SubscriptionDto> dtos) =>
      dtos.map(toDomain).toList();

  /// Subscriptions accept only `cash | razorpay | wallet` — narrower than
  /// checkout, which also takes `card`. Anything card-like is sent as
  /// `razorpay`, the gateway that would have processed it anyway.
  static String paymentWireValue(PaymentMethod method) => switch (method) {
        PaymentMethod.cash => 'cash',
        PaymentMethod.wallet => 'wallet',
        PaymentMethod.upi ||
        PaymentMethod.qr ||
        PaymentMethod.card =>
          'razorpay',
      };

  /// `startDate` is date-only server-side. Sent as a plain `yyyy-MM-dd` so a
  /// UTC conversion can never roll it onto the previous day for users east of
  /// Greenwich — which is every user of this app.
  static String dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
