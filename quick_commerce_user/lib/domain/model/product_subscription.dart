import 'payment_method.dart';

/// How often a subscribed product is delivered.
enum SubscriptionFrequency {
  daily('daily', 'Daily'),
  weekly('weekly', 'Weekly'),
  monthly('monthly', 'Monthly');

  const SubscriptionFrequency(this.wireValue, this.label);

  final String wireValue;
  final String label;

  bool get needsDaysOfWeek => this == SubscriptionFrequency.weekly;

  bool get needsDayOfMonth => this == SubscriptionFrequency.monthly;

  static SubscriptionFrequency fromWire(String? value) =>
      SubscriptionFrequency.values.firstWhere(
        (f) => f.wireValue == value,
        orElse: () => SubscriptionFrequency.daily,
      );
}

enum SubscriptionStatus {
  active('active', 'Active'),
  paused('paused', 'Paused'),
  cancelled('cancelled', 'Cancelled');

  const SubscriptionStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  bool get isActive => this == SubscriptionStatus.active;

  /// A cancelled subscription is terminal — the backend will not reactivate it,
  /// so the UI offers "subscribe again" rather than a resume toggle.
  bool get isCancelled => this == SubscriptionStatus.cancelled;

  static SubscriptionStatus fromWire(String? value) =>
      SubscriptionStatus.values.firstWhere(
        (s) => s.wireValue == value,
        orElse: () => SubscriptionStatus.active,
      );
}

/// State of one scheduled delivery in the series.
enum OccurrenceStatus {
  scheduled('scheduled', 'Scheduled'),
  cancelled('cancelled', 'Cancelled'),
  orderPlaced('order_placed', 'Order placed'),
  failed('failed', 'Failed');

  const OccurrenceStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static OccurrenceStatus fromWire(String? value) =>
      OccurrenceStatus.values.firstWhere(
        (s) => s.wireValue == value,
        orElse: () => OccurrenceStatus.scheduled,
      );
}

/// One dated delivery generated from a subscription's recurrence rule.
class SubscriptionOccurrence {
  const SubscriptionOccurrence({
    required this.id,
    required this.scheduledDate,
    required this.deliveryTime,
    required this.status,
    this.orderId = '',
    this.cancelledAt,
    this.cancelReason = '',
    this.failureReason = '',
  });

  final String id;
  final DateTime scheduledDate;
  final String deliveryTime;
  final OccurrenceStatus status;
  final String orderId;
  final DateTime? cancelledAt;
  final String cancelReason;
  final String failureReason;

  bool get isScheduled => status == OccurrenceStatus.scheduled;

  bool get hasOrder => orderId.isNotEmpty;

  /// Midnight starting the delivery day — the moment cancellation closes.
  ///
  /// The backend places the order as soon as the day begins, so "the night
  /// before" is the whole cancellation window, exactly as specified.
  DateTime get cancellationCutoff =>
      DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);

  /// Whether this delivery can still be called off. Mirrors the server rule so
  /// the UI never offers a cancel the backend would reject with a 400.
  bool canCancelAt(DateTime now) =>
      isScheduled && now.isBefore(cancellationCutoff);
}

class ProductSubscription {
  const ProductSubscription({
    required this.id,
    required this.restaurantId,
    required this.itemId,
    required this.quantity,
    required this.frequency,
    required this.deliveryTime,
    required this.startDate,
    required this.addressId,
    required this.status,
    this.itemName = '',
    this.variantId = '',
    this.daysOfWeek = const [],
    this.dayOfMonth,
    this.paymentMethod = PaymentMethod.cash,
    this.createdAt,
    this.occurrences = const [],
  });

  final String id;
  final String restaurantId;
  final String itemId;
  final String itemName;
  final String variantId;
  final int quantity;
  final SubscriptionFrequency frequency;

  /// `0` = Sunday … `6` = Saturday. Only meaningful when [frequency] is weekly.
  final List<int> daysOfWeek;

  /// `1`–`28`. Only meaningful when [frequency] is monthly.
  final int? dayOfMonth;

  /// `HH:mm`, 24-hour — the customer's chosen delivery time.
  final String deliveryTime;
  final DateTime startDate;
  final String addressId;
  final PaymentMethod paymentMethod;
  final SubscriptionStatus status;
  final DateTime? createdAt;

  /// Pre-generated deliveries. Populated by `GET /subscriptions/:id`; empty on
  /// the list endpoint, which returns subscriptions only.
  final List<SubscriptionOccurrence> occurrences;

  bool get isActive => status.isActive;

  bool get canPause => status == SubscriptionStatus.active;

  bool get canResume => status == SubscriptionStatus.paused;

  List<SubscriptionOccurrence> get upcoming =>
      occurrences.where((o) => o.isScheduled).toList();

  ProductSubscription copyWith({
    int? quantity,
    String? deliveryTime,
    String? addressId,
    SubscriptionStatus? status,
    List<SubscriptionOccurrence>? occurrences,
  }) =>
      ProductSubscription(
        id: id,
        restaurantId: restaurantId,
        itemId: itemId,
        itemName: itemName,
        variantId: variantId,
        quantity: quantity ?? this.quantity,
        frequency: frequency,
        daysOfWeek: daysOfWeek,
        dayOfMonth: dayOfMonth,
        deliveryTime: deliveryTime ?? this.deliveryTime,
        startDate: startDate,
        addressId: addressId ?? this.addressId,
        paymentMethod: paymentMethod,
        status: status ?? this.status,
        createdAt: createdAt,
        occurrences: occurrences ?? this.occurrences,
      );

  @override
  bool operator ==(Object other) =>
      other is ProductSubscription && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
