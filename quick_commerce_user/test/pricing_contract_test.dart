import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/data/dto/order_dto.dart';
import 'package:quick_commerce_user/data/dto/pricing_dto.dart';
import 'package:quick_commerce_user/data/mapper/order_mapper.dart';
import 'package:quick_commerce_user/data/dto/product_dto.dart';
import 'package:quick_commerce_user/data/mapper/pricing_mapper.dart';
import 'package:quick_commerce_user/data/mapper/product_mapper.dart';
import 'package:quick_commerce_user/domain/model/product.dart';

/// The pricing response has one trap that has already shipped a wrong number
/// once: `couponCode` is echoed back even when the coupon was refused, so
/// reading it as success prints "SAVE50 applied · You saved ₹0" over a bill
/// that refused it outright.
void main() {
  Map<String, dynamic> pricing(Map<String, dynamic> extra) => {
        'subtotal': 298.0,
        'total': 298.0,
        ...extra,
      };

  group('coupon applied versus attempted', () {
    test('a refused coupon is not applied, however loudly it is echoed', () {
      final p = PricingMapper.toDomain(
        PricingDto.fromJson(pricing({
          'couponCode': 'SAVE50',
          'discount': 0,
          'couponRejectedReason': 'Needs ₹300 minimum — ₹2 more',
        })),
      );

      expect(p.couponCode, 'SAVE50', reason: 'still echoed back');
      expect(p.isCouponApplied, isFalse);
      expect(p.hasCouponError, isTrue);
      expect(p.couponRejectedReason, 'Needs ₹300 minimum — ₹2 more');
    });

    test('an applied coupon carries appliedCoupon', () {
      final p = PricingMapper.toDomain(
        PricingDto.fromJson(pricing({
          'couponCode': 'SAVE50',
          'discount': 50.0,
          'appliedCoupon': {'code': 'SAVE50', 'discount': 50.0},
          'couponRejectedReason': '',
        })),
      );

      expect(p.isCouponApplied, isTrue);
      expect(p.appliedCouponCode, 'SAVE50');
      expect(p.hasCouponError, isFalse);
    });

    test('no coupon at all is neither applied nor an error', () {
      final p = PricingMapper.toDomain(PricingDto.fromJson(pricing({})));
      expect(p.isCouponApplied, isFalse);
      expect(p.hasCouponError, isFalse);
    });
  });

  group('spend slabs', () {
    test('the next rung is read when there is one', () {
      final p = PricingMapper.toDomain(
        PricingDto.fromJson(pricing({
          'appliedCoupon': {'code': 'LADDER', 'discount': 50.0},
          'discount': 50.0,
          'couponNextSlab': {
            'minOrderValue': 600.0,
            'spendMore': 153.0,
            'discount': 120.0,
          },
        })),
      );

      expect(p.nextSlab, isNotNull);
      expect(p.nextSlab!.spendMore, 153.0);
      // What the rung pays at its own threshold — not extrapolated upward.
      expect(p.nextSlab!.discount, 120.0);
    });

    test('no next rung on the top of the ladder', () {
      final p = PricingMapper.toDomain(
        PricingDto.fromJson(pricing({
          'appliedCoupon': {'code': 'LADDER', 'discount': 300.0},
        })),
      );
      expect(p.nextSlab, isNull);
    });
  });

  group('small cart and free delivery', () {
    test('an unconfigured install surcharges nothing', () {
      final p = PricingMapper.toDomain(PricingDto.fromJson(pricing({})));
      expect(p.hasSmallCartFee, isFalse);
      expect(p.canReachFreeDelivery, isFalse);
    });

    test('the surcharge and its threshold are both read', () {
      final p = PricingMapper.toDomain(
        PricingDto.fromJson(pricing({
          'smallCartFee': 20.0,
          'smallCartThreshold': 200.0,
        })),
      );
      expect(p.hasSmallCartFee, isTrue);
      expect(p.smallCartThreshold, 200.0);
    });

    test('the shortfall to free delivery is the server figure', () {
      final p = PricingMapper.toDomain(
        PricingDto.fromJson(pricing({
          'freeDeliveryAbove': 500.0,
          'spendMoreForFreeDelivery': 351.0,
        })),
      );
      expect(p.canReachFreeDelivery, isTrue);
      expect(p.spendMoreForFreeDelivery, 351.0);
    });

    test('already past the threshold is not a nudge', () {
      final p = PricingMapper.toDomain(
        PricingDto.fromJson(pricing({
          'freeDeliveryAbove': 500.0,
          'spendMoreForFreeDelivery': 0.0,
          'deliveryIsFree': true,
        })),
      );
      expect(p.canReachFreeDelivery, isFalse);
      expect(p.deliveryWaived, isTrue);
    });
  });

  group('both delivery modes are quoted', () {
    test('basic and quick figures are read separately', () {
      final p = PricingMapper.toDomain(
        PricingDto.fromJson(pricing({
          'deliveryPromiseMinutes': 14,
          'deliveryPromiseMinutesBasic': 14,
          'deliveryPromiseMinutesQuick': 6,
        })),
      );
      expect(p.deliveryPromiseMinutes, 14);
      expect(p.deliveryPromiseMinutesBasic, 14);
      // The gap is the queue Priority skips by riding unbatched.
      expect(p.deliveryPromiseMinutesQuick, 6);
    });
  });

  group('short picks', () {
    test('quantity is what is arriving, orderedQuantity what was asked', () {
      final order = OrderMapper.toDomain(
        OrderDto.fromJson({
          '_id': 'o1',
          'orderStatus': 'confirmed',
          'createdAt': '2026-09-14T06:50:13.000Z',
          'items': [
            {
              'itemId': 'i1',
              'name': 'Chocolate Brownie',
              'price': 149.0,
              'quantity': 2,
              'orderedQuantity': 4,
              'wasShortPicked': true,
            },
          ],
        }),
      );

      final line = order.lines.single;
      expect(line.quantity, 2, reason: 'what is being delivered');
      expect(line.orderedQuantity, 4);
      // ₹149 × 2, not × 4 — the mismatch that printed ₹596 against ₹298.
      expect(line.lineTotal, 298.0);
      expect(line.shortPickLabel, '2 of 4');
    });

    test('an untouched line says nothing about short picking', () {
      final order = OrderMapper.toDomain(
        OrderDto.fromJson({
          '_id': 'o2',
          'orderStatus': 'confirmed',
          'createdAt': '2026-09-14T06:50:13.000Z',
          'items': [
            {'itemId': 'i1', 'name': 'Milk', 'price': 50.0, 'quantity': 2},
          ],
        }),
      );

      final line = order.lines.single;
      expect(line.wasShortPicked, isFalse);
      expect(line.orderedQuantity, isNull);
      expect(line.shortPickLabel, isNull);
    });
  });

  group('expiry dates', () {
    final now = DateTime(2026, 9, 15, 10);

    Product product(Object? expiry) => ProductMapper.toDomain(
          ProductDto.fromJson({
            '_id': 'p1',
            'name': 'Amul Milk 1L',
            'price': 62,
            'restaurantId': 'r1',
            'expiryDate': ?expiry,
          }),
        );

    test('most of a catalogue never expires', () {
      final p = product(null);
      expect(p.expiryDate, isNull);
      expect(p.isExpiredAt(now), isFalse);
      expect(p.daysUntilExpiry(now), isNull);
    });

    test('a future date counts down by calendar day', () {
      final p = product('2026-09-18T00:00:00.000Z');
      expect(p.isExpiredAt(now), isFalse);
      expect(p.daysUntilExpiry(now), 3);
    });

    test('a past date reads as expired', () {
      // The hourly sweep normally delists these first; this is the gap before
      // it runs, where the order would be refused outright.
      final p = product('2026-09-14T00:00:00.000Z');
      expect(p.isExpiredAt(now), isTrue);
    });

    test('the time of day does not shift the day count', () {
      // 10am today vs a date later today is still "0 days left", not -1.
      final p = product('2026-09-15T02:00:00.000Z');
      expect(p.daysUntilExpiry(now), 0);
    });
  });
}
