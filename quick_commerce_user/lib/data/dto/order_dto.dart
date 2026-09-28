import 'json_reader.dart';
import 'address_dto.dart';
import 'pricing_dto.dart';

/// A normalised order (`normalizeOrderForClient` on the backend).
class OrderDto {
  const OrderDto({
    required this.id,
    required this.displayId,
    required this.status,
    required this.items,
    required this.pricing,
    required this.createdAt,
    this.address,
    this.restaurantId = '',
    this.restaurantName = '',
    this.restaurantImage = '',
    this.paymentMethod = '',
    this.paymentStatus = '',
    this.deliveryPartner,
    this.handoverOtp = '',
    this.etaMinutes,
    this.scheduledAt,
    this.slotLabel = '',
    this.slotStartTime = '',
    this.slotEndTime = '',
    this.deliveredAt,
    this.cancelledAt,
    this.cancellationReason = '',
    this.deliveryInstructions = '',
    this.restaurantRating,
    this.riderLat,
    this.riderLng,
    this.statusHistory = const [],
  });

  final String id;
  final String displayId;
  final String status;
  final List<OrderItemDto> items;
  final PricingDto pricing;
  final DateTime createdAt;
  final AddressDto? address;
  final String restaurantId;
  final String restaurantName;
  final String restaurantImage;
  final String paymentMethod;
  final String paymentStatus;
  final DeliveryPartnerDto? deliveryPartner;
  final String handoverOtp;
  final int? etaMinutes;

  /// When the customer is promised this order, for a booking. Null on an
  /// instant order, which is everything placed from the cart.
  final DateTime? scheduledAt;

  /// Snapshot of the window, kept on the order so it still reads "7 – 8 AM"
  /// after the slot is renamed or retired.
  final String slotLabel;
  final String slotStartTime;
  final String slotEndTime;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final String cancellationReason;
  final String deliveryInstructions;
  final double? restaurantRating;
  final double? riderLat;
  final double? riderLng;
  final List<StatusHistoryDto> statusHistory;

  factory OrderDto.fromJson(Map<String, dynamic> json) {
    final restaurant = json.mapOrNull('restaurantId');
    final payment = json.mapAt('payment');
    final deliveryState = json.mapAt('deliveryState');
    final currentLocation = deliveryState.mapAt('currentLocation');
    final partner = json.mapAt('dispatch').mapOrNull('deliveryPartnerId');
    final ratings = json.mapAt('ratings').mapAt('restaurant');
    final address = json.mapOrNull('deliveryAddress');

    return OrderDto(
      id: json.firstStr(['orderMongoId', '_id'], json.id()),
      displayId: json.firstStr(['orderId', 'order_id'], json.id()),
      status: json.firstStr(['orderStatus', 'status'], 'created'),
      items: json.objects('items').map(OrderItemDto.fromJson).toList(),
      pricing: PricingDto.fromJson(json.mapAt('pricing')),
      createdAt: json.date('createdAt'),
      address: address == null ? null : AddressDto.fromJson(address),
      restaurantId: restaurant?.id() ?? json.str('restaurantId'),
      restaurantName: restaurant?.str('restaurantName') ?? '',
      restaurantImage: restaurant == null ? '' : restaurant.imageUrl('profileImage'),
      paymentMethod: payment.str('method'),
      paymentStatus: payment.str('status'),
      deliveryPartner:
          partner == null ? null : DeliveryPartnerDto.fromJson(partner),
      handoverOtp: json.str('handoverOtp'),
      etaMinutes: json.mapAt('eta').intOrNull('minutes'),
      scheduledAt: json.dateOrNull('scheduledAt'),
      slotLabel: json.mapAt('deliverySlot').str('label'),
      slotStartTime: json.mapAt('deliverySlot').str('startTime'),
      slotEndTime: json.mapAt('deliverySlot').str('endTime'),
      deliveredAt: json.dateOrNull('deliveredAt'),
      cancelledAt: json.dateOrNull('cancelledAt'),
      cancellationReason: json.str('cancellationReason'),
      deliveryInstructions: json.str('deliveryInstructions'),
      restaurantRating: ratings.doubleOrNull('rating') ?? json.doubleOrNull('rating'),
      riderLat: currentLocation.doubleOrNull('lat'),
      riderLng: currentLocation.doubleOrNull('lng'),
      statusHistory:
          json.objects('statusHistory').map(StatusHistoryDto.fromJson).toList(),
    );
  }
}

class OrderItemDto {
  const OrderItemDto({
    required this.itemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.variantName = '',
    this.image = '',
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
  final String image;
  final bool isVeg;
  final List<String> addonNames;

  /// What the customer asked for. Only sent when the line was adjusted at the
  /// shelf; `quantity` is what is actually coming.
  final int? orderedQuantity;
  final bool wasShortPicked;

  factory OrderItemDto.fromJson(Map<String, dynamic> json) => OrderItemDto(
        itemId: json.str('itemId'),
        name: json.str('name'),
        price: json.dbl('variantPrice') > 0 ? json.dbl('variantPrice') : json.dbl('price'),
        quantity: json.integer('quantity', 1),
        variantName: json.str('variantName'),
        image: json.imageUrl('image'),
        isVeg: json.boolean('isVeg', true),
        addonNames:
            json.objects('addons').map((a) => a.str('name')).where((n) => n.isNotEmpty).toList(),
        orderedQuantity: json.intOrNull('orderedQuantity'),
        wasShortPicked: json.boolean('wasShortPicked'),
      );
}

class DeliveryPartnerDto {
  const DeliveryPartnerDto({
    required this.name,
    this.phone = '',
    this.rating = 0,
    this.photo = '',
    this.vehicleNumber = '',
  });

  final String name;
  final String phone;
  final double rating;
  final String photo;
  final String vehicleNumber;

  factory DeliveryPartnerDto.fromJson(Map<String, dynamic> json) =>
      DeliveryPartnerDto(
        name: json.firstStr(['name', 'fullName'], 'Your rider'),
        phone: json.firstStr(['phone', 'phoneNumber']),
        rating: json.dbl('rating'),
        photo: json.imageUrl('profilePhoto'),
        vehicleNumber: json.str('vehicleNumber'),
      );
}

class StatusHistoryDto {
  const StatusHistoryDto({required this.to, required this.at});

  final String to;
  final DateTime at;

  factory StatusHistoryDto.fromJson(Map<String, dynamic> json) => StatusHistoryDto(
        to: json.str('to'),
        at: json.date('at'),
      );
}

class OrderRouteDto {
  const OrderRouteDto({
    this.polyline = '',
    this.distanceKm,
    this.durationMins,
    this.originLat,
    this.originLng,
    this.destinationLat,
    this.destinationLng,
    this.target = '',
  });

  final String polyline;
  final double? distanceKm;
  final int? durationMins;
  final double? originLat;
  final double? originLng;
  final double? destinationLat;
  final double? destinationLng;
  final String target;

  factory OrderRouteDto.fromJson(Map<String, dynamic> json) {
    final origin = json.mapAt('origin');
    final destination = json.mapAt('destination');
    return OrderRouteDto(
      polyline: json.str('polyline'),
      distanceKm: json.doubleOrNull('distanceKm'),
      durationMins: json.intOrNull('durationMins'),
      originLat: origin.doubleOrNull('lat'),
      originLng: origin.doubleOrNull('lng'),
      destinationLat: destination.doubleOrNull('lat'),
      destinationLng: destination.doubleOrNull('lng'),
      target: json.str('target'),
    );
  }
}
