import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/data/dto/order_dto.dart';
import 'package:quick_commerce_user/data/mapper/order_mapper.dart';
import 'package:quick_commerce_user/domain/model/cart.dart';
import 'package:quick_commerce_user/domain/model/order.dart';
import 'package:quick_commerce_user/domain/model/order_status.dart';
import 'package:quick_commerce_user/ui/common/delivery_promise.dart';

/// A booking is a live order that is simply not in progress yet. Describing it
/// with instant-order vocabulary is the failure mode: counting from
/// `placedAt + eta` reads as arriving in minutes and then as permanently
/// overdue, and "looking for a rider" is noise on something due tomorrow.
void main() {
  final now = DateTime(2026, 9, 12, 15);

  Order order({
    DateTime? scheduledAt,
    String slotLabel = '',
    String start = '',
    String end = '',
    int? etaMinutes,
    OrderStatus status = OrderStatus.confirmed,
    DeliveryPartner? partner,
  }) =>
      Order(
        id: 'o1',
        displayId: 'A1',
        status: status,
        lines: const [],
        pricing: const CartPricing(),
        placedAt: now,
        scheduledAt: scheduledAt,
        slotLabel: slotLabel,
        slotStartTime: start,
        slotEndTime: end,
        etaMinutes: etaMinutes,
        deliveryPartner: partner,
      );

  group('what counts as a booking', () {
    test('a future scheduledAt is a booking', () {
      expect(
        order(scheduledAt: DateTime(2026, 9, 13, 7)).isBookingAt(now),
        isTrue,
      );
    });

    test('no scheduledAt is an instant order', () {
      expect(order().isBookingAt(now), isFalse);
    });

    test('a window already past is no longer a booking', () {
      // Once its moment arrives it behaves like any other live order, so the
      // normal ETA wording takes over rather than a stale "arriving tomorrow".
      expect(
        order(scheduledAt: DateTime(2026, 9, 12, 14)).isBookingAt(now),
        isFalse,
      );
    });
  });

  group('how it is worded', () {
    test('tomorrow morning reads as a window, not a countdown', () {
      final label = DeliveryPromise.forOrder(
        order(
          scheduledAt: DateTime(2026, 9, 13, 7),
          start: '07:00',
          end: '08:00',
        ),
        now: now,
      );
      expect(label, 'Arriving tomorrow, 07:00 – 08:00');
    });

    test('the slot label is kept alongside the times', () {
      final label = DeliveryPromise.forOrder(
        order(
          scheduledAt: DateTime(2026, 9, 13, 18),
          slotLabel: 'Evening',
          start: '18:00',
          end: '20:00',
        ),
        now: now,
      );
      expect(label, 'Arriving tomorrow, Evening · 18:00 – 20:00');
    });

    test('a booking with no window falls back to its time', () {
      final label = DeliveryPromise.forOrder(
        order(scheduledAt: DateTime(2026, 9, 12, 19, 30)),
        now: now,
      );
      expect(label, 'Arriving today, 7:30 PM');
    });

    test('a booking never quotes the instant ETA', () {
      // The whole point: hundreds of minutes must not render as a minute count.
      final label = DeliveryPromise.forOrder(
        order(scheduledAt: DateTime(2026, 9, 13, 7), etaMinutes: 12),
        now: now,
      );
      expect(label, isNot(contains('12')));
      expect(label, startsWith('Arriving tomorrow'));
    });

    test('an instant order still quotes its ETA', () {
      expect(
        DeliveryPromise.forOrder(order(etaMinutes: 12), now: now),
        'Arriving in about 12 mins',
      );
    });

    test('no quote yet is vague rather than wrong', () {
      expect(DeliveryPromise.forOrder(order(), now: now), 'Calculating…');
    });
  });

  group('rider search', () {
    test('is not mentioned on a booking', () {
      // dispatch stays unassigned for hours, and the backend will not even
      // offer it to riders until the window is close.
      expect(
        order(scheduledAt: DateTime(2026, 9, 13, 7)).showsRiderSearch(now),
        isFalse,
      );
    });

    test('is mentioned on an unassigned instant order', () {
      expect(order().showsRiderSearch(now), isTrue);
    });

    test('stops once a rider is assigned', () {
      expect(
        order(partner: const DeliveryPartner(name: 'Ravi'))
            .showsRiderSearch(now),
        isFalse,
      );
    });

    test('is not mentioned on a cancelled order', () {
      expect(
        order(status: OrderStatus.cancelledByUser).showsRiderSearch(now),
        isFalse,
      );
    });
  });

  test('booking fields are read off the wire', () {
    final parsed = OrderMapper.toDomain(
      OrderDto.fromJson({
        '_id': 'o1',
        'orderStatus': 'confirmed',
        'createdAt': '2026-09-12T09:30:00.000Z',
        'scheduledAt': '2026-09-13T01:30:00.000Z',
        'deliverySlot': {
          'label': 'Morning',
          'startTime': '07:00',
          'endTime': '08:00',
        },
      }),
    );

    expect(parsed.scheduledAt, isNotNull);
    expect(parsed.hasSlot, isTrue);
    expect(parsed.slotWindow, 'Morning · 07:00 – 08:00');
  });

  test('an instant order carries no booking fields', () {
    final parsed = OrderMapper.toDomain(
      OrderDto.fromJson({
        '_id': 'o2',
        'orderStatus': 'confirmed',
        'createdAt': '2026-09-12T09:30:00.000Z',
      }),
    );

    expect(parsed.scheduledAt, isNull);
    expect(parsed.hasSlot, isFalse);
    expect(parsed.isBookingAt(now), isFalse);
  });
}
