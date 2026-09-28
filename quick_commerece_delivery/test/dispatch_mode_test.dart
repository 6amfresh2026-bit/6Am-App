import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';

/// A fleet order is *given* to one named rider — no competitor, nothing to
/// win. Rendering it with the pool's offer countdown implies it can be lost to
/// someone else, which is not what is happening.
void main() {
  DeliveryOrder fromOrder(Map<String, dynamic> dispatch) =>
      DeliveryOrder.fromJson({
        '_id': 'o1',
        'order_id': 'FOD-7441949850',
        'orderStatus': 'confirmed',
        if (dispatch.isNotEmpty) 'dispatch': dispatch,
      });

  group('how the order reached this rider', () {
    test('a pool broadcast is a race', () {
      final order = fromOrder({'assignmentMode': 'auto'});
      expect(order.assignmentMode, 'auto');
      expect(order.isPooledOffer, isTrue);
    });

    test('a fleet handover is not', () {
      final order = fromOrder({'assignmentMode': 'fleet'});
      expect(order.isPooledOffer, isFalse);
    });

    test('a manual assignment is not, and records who did it', () {
      final order = fromOrder({
        'assignmentMode': 'manual',
        'assignedByRole': 'RESTAURANT',
      });
      expect(order.isPooledOffer, isFalse);
      expect(order.assignedByRole, 'RESTAURANT');
    });

    test('an older payload with no dispatch falls back to the race path', () {
      // Safer direction: an offer shown with a countdown that did not need one
      // is a cosmetic problem; one silently dropped is a missed order.
      final order = fromOrder({});
      expect(order.assignmentMode, isNull);
      expect(order.isPooledOffer, isTrue);
    });
  });

  group('dispatch pushes flatten the fields', () {
    test('a fleet push is recognised from the flattened payload', () {
      final order = DeliveryOrder.fromRealtimePayload({
        'orderMongoId': 'o1',
        'order_id': 'FOD-7441949850',
        'assignmentMode': 'fleet',
      });
      expect(order.isPooledOffer, isFalse);
    });

    test('an ordinary offer push still races', () {
      final order = DeliveryOrder.fromRealtimePayload({
        'orderMongoId': 'o1',
        'order_id': 'FOD-7441949850',
      });
      expect(order.isPooledOffer, isTrue);
    });
  });
}
