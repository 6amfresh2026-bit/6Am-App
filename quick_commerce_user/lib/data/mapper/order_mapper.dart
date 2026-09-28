import '../../domain/model/cart.dart';
import '../../domain/model/cart_item.dart';
import '../../domain/model/order.dart';
import '../../domain/model/order_status.dart';
import '../../domain/model/payment_method.dart';
import '../dto/json_reader.dart';
import '../dto/order_dto.dart';
import 'address_mapper.dart';
import 'pricing_mapper.dart';

abstract final class OrderMapper {
  /// Order-creation payload → [PlacedOrder]. Every endpoint that creates an
  /// order returns the same `{order, razorpay?}` envelope — the normal
  /// checkout and "order this monthly list now" alike — so both parse here.
  static PlacedOrder placedFromJson(Map<String, dynamic> json) {
    final razorpay = json.mapOrNull('razorpay');
    return PlacedOrder(
      order: toDomain(OrderDto.fromJson(json.mapAt('order'))),
      gatewayOrderId: razorpay?.str('orderId').nullIfEmpty,
      gatewayKey: razorpay?.str('key').nullIfEmpty,
      gatewayAmountPaise: razorpay?.integer('amount') ?? 0,
      gatewayCurrency: razorpay?.str('currency', 'INR') ?? 'INR',
    );
  }

  static Order toDomain(OrderDto dto) {
    final status = OrderStatus.fromWire(dto.status);
    return Order(
      id: dto.id,
      displayId: dto.displayId,
      status: status,
      lines: dto.items
          .map((i) => OrderLine(
                itemId: i.itemId,
                name: i.name,
                price: i.price,
                quantity: i.quantity,
                variantName: i.variantName,
                imageUrl: i.image,
                isVeg: i.isVeg,
                addonNames: i.addonNames,
                orderedQuantity: i.orderedQuantity,
                wasShortPicked: i.wasShortPicked,
              ))
          .toList(),
      pricing: PricingMapper.toDomain(dto.pricing),
      placedAt: dto.createdAt,
      address: dto.address == null ? null : AddressMapper.toDomain(dto.address!),
      sellerId: dto.restaurantId,
      sellerName: dto.restaurantName,
      sellerImageUrl: dto.restaurantImage,
      paymentMethod: PaymentMethod.fromWire(dto.paymentMethod),
      paymentStatus: dto.paymentStatus,
      deliveryPartner: dto.deliveryPartner == null
          ? null
          : DeliveryPartner(
              name: dto.deliveryPartner!.name,
              phone: dto.deliveryPartner!.phone,
              rating: dto.deliveryPartner!.rating,
              photoUrl: dto.deliveryPartner!.photo,
              vehicleNumber: dto.deliveryPartner!.vehicleNumber,
            ),
      dropOtp: dto.handoverOtp,
      etaMinutes: dto.etaMinutes,
      scheduledAt: dto.scheduledAt,
      slotLabel: dto.slotLabel,
      slotStartTime: dto.slotStartTime,
      slotEndTime: dto.slotEndTime,
      deliveredAt: dto.deliveredAt,
      cancelledAt: dto.cancelledAt,
      cancellationReason: dto.cancellationReason,
      instructions: dto.deliveryInstructions,
      restaurantRating: dto.restaurantRating,
      riderLocation: dto.riderLat != null && dto.riderLng != null
          ? GeoPoint(dto.riderLat!, dto.riderLng!)
          : null,
      statusTimestamps: _timestamps(dto, status, dto.createdAt),
    );
  }

  /// Collapses the backend's status history into the five UI milestones,
  /// keeping the earliest time each milestone was reached.
  static Map<TrackingStep, DateTime> _timestamps(
    OrderDto dto,
    OrderStatus status,
    DateTime placedAt,
  ) {
    final stamps = <TrackingStep, DateTime>{TrackingStep.placed: placedAt};
    for (final entry in dto.statusHistory) {
      final step = TrackingStep.forStatus(OrderStatus.fromWire(entry.to));
      final existing = stamps[step];
      if (existing == null || entry.at.isBefore(existing)) stamps[step] = entry.at;
    }
    if (dto.deliveredAt != null) stamps[TrackingStep.delivered] = dto.deliveredAt!;
    return stamps;
  }

  static OrderRoute routeToDomain(OrderRouteDto dto) => OrderRoute(
        polyline: dto.polyline,
        distanceKm: dto.distanceKm,
        durationMins: dto.durationMins,
        origin: dto.originLat != null && dto.originLng != null
            ? GeoPoint(dto.originLat!, dto.originLng!)
            : null,
        destination: dto.destinationLat != null && dto.destinationLng != null
            ? GeoPoint(dto.destinationLat!, dto.destinationLng!)
            : null,
        target: dto.target,
      );

  /// Cart line → the `items[]` entry both `/orders/calculate` and `/orders`
  /// expect. Identical on both endpoints, so it lives in one place.
  static Map<String, dynamic> lineToJson(CartItem item) => {
        'itemId': item.product.id,
        'name': item.product.name,
        if (item.variant != null) ...{
          'variantId': item.variant!.id,
          'variantName': item.variant!.name,
          'variantPrice': item.variant!.price,
        },
        'price': item.unitPrice,
        'otherPrice': item.product.comparePrice ?? 0,
        'quantity': item.quantity,
        'isVeg': item.product.isVeg,
        'image': item.product.imageUrl,
        if (item.note.trim().isNotEmpty) 'notes': item.note,
        if (item.addons.isNotEmpty)
          'addons': item.addons
              .map((a) => {'addonId': a.id, 'id': a.id, 'name': a.name})
              .toList(),
      };

  /// Cart line → the shape `PUT /food/user/cart` reads.
  static Map<String, dynamic> lineToSyncJson(CartItem item) => {
        'lineItemId': item.lineId,
        'itemId': item.product.id,
        'name': item.product.name,
        'price': item.unitPrice,
        'otherPrice': item.product.comparePrice ?? 0,
        'quantity': item.quantity,
        if (item.variant != null) ...{
          'variantId': item.variant!.id,
          'variantName': item.variant!.name,
          'variantPrice': item.variant!.price,
        },
        'image': item.product.imageUrl,
        'foodType': item.product.isVeg ? 'Veg' : 'Non-Veg',
        'isVeg': item.product.isVeg,
        'restaurantId': item.product.sellerId,
      };

  static Map<String, dynamic> pricingToSyncJson(Cart cart) => {
        'subtotal': cart.pricing.subtotal,
        'tax': cart.pricing.tax,
        'deliveryFee': cart.pricing.deliveryFee,
        'platformFee': cart.pricing.platformFee,
        'discount': cart.pricing.discount,
        'total': cart.pricing.total,
        'savings': cart.provisionalSavings,
        'deliveryMode': cart.deliveryMode,
        if (cart.appliedCoupon != null) 'couponCode': cart.appliedCoupon!.code,
      };
}
