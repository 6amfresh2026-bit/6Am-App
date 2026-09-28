import 'address.dart';
import 'cart.dart';
import 'order_status.dart';
import 'payment_method.dart';

/// A line inside a placed order. Kept separate from [CartItem] because the
/// backend snapshots names/prices at order time and never re-resolves them.
class OrderLine {
  const OrderLine({
    required this.itemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.variantName = '',
    this.imageUrl = '',
    this.isVeg = true,
    this.addonNames = const [],
    this.orderedQuantity,
    this.wasShortPicked = false,
  });

  final String itemId;
  final String name;
  final double price;
  final int quantity;
  final String variantName;
  final String imageUrl;
  final bool isVeg;
  final List<String> addonNames;

  /// What the customer asked for, when the shop could not supply it all.
  ///
  /// `quantity` is **what is being delivered** — the figure the bill charges
  /// for and the rider collects. Rendering the ordered figure against a bill
  /// charging for fewer is how an invoice ends up showing 4 × ₹149 over a
  /// subtotal for two.
  final int? orderedQuantity;
  final bool wasShortPicked;

  double get lineTotal => price * quantity;

  /// `2 of 4` — only worth saying when the two differ.
  String? get shortPickLabel {
    final ordered = orderedQuantity;
    if (!wasShortPicked || ordered == null || ordered <= quantity) return null;
    return '$quantity of $ordered';
  }
}

/// The assigned rider, present once dispatch has accepted.
class DeliveryPartner {
  const DeliveryPartner({
    required this.name,
    this.phone = '',
    this.rating = 0,
    this.photoUrl = '',
    this.vehicleNumber = '',
  });

  final String name;
  final String phone;
  final double rating;
  final String photoUrl;
  final String vehicleNumber;
}

/// A geographic point used by the tracking screen.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  // Value equality so a `select` on the rider position only rebuilds the map
  // when the coordinates actually changed — not on every identical GPS ping.
  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Route between rider and target, from `GET /orders/:id/route`.
class OrderRoute {
  const OrderRoute({
    this.polyline = '',
    this.distanceKm,
    this.durationMins,
    this.origin,
    this.destination,
    this.target = '',
  });

  final String polyline;
  final double? distanceKm;
  final int? durationMins;
  final GeoPoint? origin;
  final GeoPoint? destination;
  final String target;

  static const empty = OrderRoute();
}

class Order {
  const Order({
    required this.id,
    required this.displayId,
    required this.status,
    required this.lines,
    required this.pricing,
    required this.placedAt,
    this.address,
    this.sellerId = '',
    this.sellerName = '',
    this.sellerImageUrl = '',
    this.paymentMethod = PaymentMethod.upi,
    this.paymentStatus = '',
    this.deliveryPartner,
    this.dropOtp = '',
    this.etaMinutes,
    this.scheduledAt,
    this.slotLabel = '',
    this.slotStartTime = '',
    this.slotEndTime = '',
    this.deliveredAt,
    this.cancelledAt,
    this.cancellationReason = '',
    this.instructions = '',
    this.restaurantRating,
    this.riderLocation,
    this.statusTimestamps = const {},
  });

  final String id;
  final String displayId;
  final OrderStatus status;
  final List<OrderLine> lines;
  final CartPricing pricing;
  final DateTime placedAt;
  final Address? address;
  final String sellerId;
  final String sellerName;
  final String sellerImageUrl;
  final PaymentMethod paymentMethod;
  final String paymentStatus;
  final DeliveryPartner? deliveryPartner;
  final String dropOtp;
  final int? etaMinutes;

  /// Set only on a booking — an order promised for a future window, which on
  /// this product comes from a subscription rather than the cart.
  final DateTime? scheduledAt;

  /// The window as the customer was told it, snapshotted on the order.
  final String slotLabel;
  final String slotStartTime;
  final String slotEndTime;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final String cancellationReason;
  final String instructions;
  final double? restaurantRating;
  final GeoPoint? riderLocation;

  /// Milestone → when it was reached, derived from the backend status history.
  final Map<TrackingStep, DateTime> statusTimestamps;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);

  /// A booking is a live order that is simply not in progress yet.
  ///
  /// It must not be described with the instant-order vocabulary: counting from
  /// `placedAt + eta` reads as "arriving in minutes" and then as permanently
  /// overdue, and "Preparing your order" is wrong for something due tomorrow.
  bool isBookingAt(DateTime now) =>
      scheduledAt != null && scheduledAt!.isAfter(now);

  bool get hasSlot => slotStartTime.isNotEmpty && slotEndTime.isNotEmpty;

  /// `07:00 – 08:00`, or the slot's own label when it carries one.
  String get slotWindow {
    if (!hasSlot) return slotLabel;
    final window = '$slotStartTime – $slotEndTime';
    return slotLabel.isEmpty ? window : '$slotLabel · $window';
  }

  /// Whether a rider is worth mentioning yet.
  ///
  /// `dispatch.status` stays unassigned for hours on a booking, and the backend
  /// does not even offer it to riders until its window is close — so "looking
  /// for a rider" on an order due tomorrow is noise, not progress.
  bool showsRiderSearch(DateTime now) =>
      !isBookingAt(now) && deliveryPartner == null && !status.isCancelled;

  bool get isRated => restaurantRating != null && restaurantRating! > 0;

  TrackingStep get currentStep => TrackingStep.forStatus(status);

  bool isStepReached(TrackingStep step) {
    if (status.isCancelled) return step == TrackingStep.placed;
    return step.index <= currentStep.index;
  }

  bool get awaitsPayment => status == OrderStatus.pendingPayment;

  Order copyWith({
    OrderStatus? status,
    String? dropOtp,
    GeoPoint? riderLocation,
    DeliveryPartner? deliveryPartner,
    int? etaMinutes,
  }) =>
      Order(
        id: id,
        displayId: displayId,
        status: status ?? this.status,
        lines: lines,
        pricing: pricing,
        placedAt: placedAt,
        address: address,
        sellerId: sellerId,
        sellerName: sellerName,
        sellerImageUrl: sellerImageUrl,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
        deliveryPartner: deliveryPartner ?? this.deliveryPartner,
        dropOtp: dropOtp ?? this.dropOtp,
        etaMinutes: etaMinutes ?? this.etaMinutes,
        scheduledAt: scheduledAt,
        slotLabel: slotLabel,
        slotStartTime: slotStartTime,
        slotEndTime: slotEndTime,
        deliveredAt: deliveredAt,
        cancelledAt: cancelledAt,
        cancellationReason: cancellationReason,
        instructions: instructions,
        restaurantRating: restaurantRating,
        riderLocation: riderLocation ?? this.riderLocation,
        statusTimestamps: statusTimestamps,
      );

  @override
  bool operator ==(Object other) => other is Order && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Payload returned by order creation: the order plus any gateway handoff.
/// An order the backend has created. When it is an online-payment order the
/// backend has also created the matching Razorpay order and handed back the
/// checkout parameters — `POST /food/orders` → `razorpay: {key, orderId,
/// amount, currency}`.
class PlacedOrder {
  const PlacedOrder({
    required this.order,
    this.gatewayOrderId,
    this.gatewayKey,
    this.gatewayAmountPaise = 0,
    this.gatewayCurrency = 'INR',
  });

  final Order order;
  final String? gatewayOrderId;
  final String? gatewayKey;

  /// Amount in the smallest currency unit, exactly as Razorpay recorded it.
  /// Never recomputed here — the backend compares this against the captured
  /// payment paise-for-paise.
  final int gatewayAmountPaise;
  final String gatewayCurrency;

  bool get needsGatewayPayment =>
      gatewayOrderId != null && gatewayOrderId!.isNotEmpty;
}
