import 'json_reader.dart';

class SubscriptionOccurrenceDto {
  const SubscriptionOccurrenceDto({
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
  final String status;
  final String orderId;
  final DateTime? cancelledAt;
  final String cancelReason;
  final String failureReason;

  factory SubscriptionOccurrenceDto.fromJson(Map<String, dynamic> json) =>
      SubscriptionOccurrenceDto(
        id: json.id(),
        // Stored as local midnight server-side and serialised as UTC; `date`
        // converts back to local so the calendar day matches what was chosen.
        scheduledDate: json.date('scheduledDate'),
        deliveryTime: json.str('deliveryTime'),
        status: json.str('status', 'scheduled'),
        orderId: json.id(const ['orderId']),
        cancelledAt: json.dateOrNull('cancelledAt'),
        cancelReason: json.str('cancelReason'),
        failureReason: json.str('failureReason'),
      );
}

class SubscriptionDto {
  const SubscriptionDto({
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
    this.paymentMethod = 'cash',
    this.createdAt,
    this.occurrences = const [],
  });

  final String id;
  final String restaurantId;
  final String itemId;
  final String itemName;
  final String variantId;
  final int quantity;
  final String frequency;
  final List<int> daysOfWeek;
  final int? dayOfMonth;
  final String deliveryTime;
  final DateTime startDate;
  final String addressId;
  final String paymentMethod;
  final String status;
  final DateTime? createdAt;
  final List<SubscriptionOccurrenceDto> occurrences;

  factory SubscriptionDto.fromJson(
    Map<String, dynamic> json, {
    List<SubscriptionOccurrenceDto> occurrences = const [],
  }) =>
      SubscriptionDto(
        id: json.id(),
        restaurantId: json.id(const ['restaurantId']),
        itemId: json.id(const ['itemId']),
        itemName: json.str('itemName'),
        variantId: json.str('variantId'),
        quantity: json.integer('quantity', 1),
        frequency: json.str('frequency', 'daily'),
        daysOfWeek: _ints(json['daysOfWeek']),
        dayOfMonth: json.intOrNull('dayOfMonth'),
        deliveryTime: json.str('deliveryTime'),
        startDate: json.date('startDate'),
        addressId: json.id(const ['addressId']),
        paymentMethod: json.str('paymentMethod', 'cash'),
        status: json.str('status', 'active'),
        createdAt: json.dateOrNull('createdAt'),
        occurrences: occurrences,
      );

  static List<int> _ints(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e is num ? e.toInt() : int.tryParse(e.toString()))
        .whereType<int>()
        .toList();
  }
}
