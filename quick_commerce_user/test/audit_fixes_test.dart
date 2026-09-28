import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/core/errors/error_mapper.dart';
import 'package:quick_commerce_user/core/extensions/num_extensions.dart';
import 'package:quick_commerce_user/core/network/media_url.dart';
import 'package:quick_commerce_user/core/network/share_links.dart';
import 'package:quick_commerce_user/domain/model/product.dart';
import 'package:quick_commerce_user/domain/service/catalog_grouping_service.dart';

void main() {
  group('seller derivation carries no invented data', () {
    const grouping = CatalogGroupingService();

    test('an unrated seller has rating 0 and no delivery estimate — never 4.8/25', () {
      final sellers = grouping.sellersFrom([
        const Product(
          id: 'p1',
          name: 'Milk',
          price: 30,
          sellerId: 's1',
          sellerName: 'Fresh Mart',
          // no rating, no deliveryMinutes
        ),
      ]);
      expect(sellers, hasLength(1));
      expect(sellers.first.rating, 0);
      expect(sellers.first.hasRating, isFalse);
      expect(sellers.first.deliveryMinutes, isNull);
      expect(sellers.first.name, 'Fresh Mart');
    });

    test('real ratings are averaged; a nameless seller is dropped, not faked', () {
      final sellers = grouping.sellersFrom([
        const Product(
            id: 'a', name: 'A', price: 1, sellerId: 's1', sellerName: 'Store One', rating: 4),
        const Product(
            id: 'b', name: 'B', price: 1, sellerId: 's1', sellerName: 'Store One', rating: 5),
        // A seller with no name on any product must not surface as "Seller #id".
        const Product(id: 'c', name: 'C', price: 1, sellerId: 's2'),
      ]);
      expect(sellers.map((s) => s.name), ['Store One']);
      expect(sellers.first.rating, 4.5);
    });
  });

  group('backend message branding (Restaurant → Store)', () {
    Response<dynamic> resp(String message) => Response<dynamic>(
          requestOptions: RequestOptions(path: '/food/orders/calculate'),
          statusCode: 400,
          data: {'success': false, 'message': message},
        );

    test('the closed-store message reads "Store", not "Restaurant"', () {
      final failure = ErrorMapper.toFailure(
        ErrorMapper.fromResponse(
          resp('Restaurant is currently closed. Please try again later.'),
        ),
      );
      expect(failure.message, 'Store is currently closed. Please try again later.');
    });

    test('the offline sibling and plurals are rewritten too', () {
      expect(
        ErrorMapper.fromResponse(resp('Restaurant is currently offline.')).message,
        'Store is currently offline.',
      );
      expect(
        ErrorMapper.fromResponse(resp('No restaurants deliver here yet.')).message,
        'No stores deliver here yet.',
      );
    });
  });

  group('delivery promise formatting', () {
    test('sub-hour promises stay in minutes', () {
      expect(12.asDurationLabel, '12 mins');
      expect(59.asDurationLabel, '59 mins');
    });

    test('an hour or more reads as hours', () {
      expect(60.asDurationLabel, '1 hr');
      expect(95.asDurationLabel, '1 hr 35 mins');
    });

    // The case that started this: a drop far outside the serving area priced at
    // 3712 minutes, which rendered as "Arrives in 3712 mins".
    test('multi-day promises read as days, not thousands of minutes', () {
      expect(3712.asDurationLabel, '2 days 13 hr');
      expect(2880.asDurationLabel, '2 days');
    });
  });

  group('share links', () {
    setUp(() => MediaUrl.configure('https://quick.appzeto.com/api/v1'));

    test('product links are https to the backend OG page, not a custom scheme', () {
      final url = ShareLinks.product(productId: 'abc123', sellerId: 'seller1');
      expect(url, startsWith('https://quick.appzeto.com/food-detail?'));
      expect(url, contains('id=abc123'));
      expect(url, contains('restaurantId=seller1'));
      expect(url, isNot(contains('://product/')));
    });

    test('a product with no seller still yields a usable link', () {
      final url = ShareLinks.product(productId: 'abc123');
      expect(url, 'https://quick.appzeto.com/food-detail?id=abc123');
    });

    test('seller links point at the restaurant page', () {
      expect(
        ShareLinks.seller('s99'),
        'https://quick.appzeto.com/restaurant-detail/s99',
      );
    });
  });
}
