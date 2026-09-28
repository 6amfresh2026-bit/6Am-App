import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/data/dto/json_reader.dart';
import 'package:quick_commerce_user/data/dto/product_dto.dart';
import 'package:quick_commerce_user/data/mapper/product_mapper.dart';
import 'package:quick_commerce_user/data/mapper/seller_mapper.dart';
import 'package:quick_commerce_user/domain/model/wishlist.dart';

/// The wishlist's one genuine trap: `foodIds` and `foods` are different
/// lengths on purpose. Hearts read the ids, cards read the objects — get that
/// backwards and a customer's heart un-fills on its own.
void main() {
  /// The payload shape the favourites endpoint returns, with one wishlisted
  /// product that has since been delisted — present in `foodIds`, absent from
  /// `foods`.
  Map<String, dynamic> payload() => {
        'foodIds': ['f1', 'f2-delisted'],
        'restaurantIds': ['r1'],
        'foods': [
          {
            '_id': 'f1',
            'name': 'Chocolate Brownie',
            'price': 149,
            'otherPrice': 0,
            'foodType': 'Veg',
            'isAvailable': true,
            'restaurantId': 'r1',
            'restaurantName': 'Demo Test Store',
          },
        ],
        'restaurants': [
          {
            '_id': 'r1',
            'restaurantName': 'Demo Test Store',
            'coverImage': '',
            'coverImages': <String>[],
            'rating': 4.2,
            'totalRatings': 18,
            'isAcceptingOrders': true,
          },
        ],
      };

  Wishlist parse(Map<String, dynamic> json) => Wishlist(
        productIds: json.strings('foodIds').toSet(),
        storeIds: json.strings('restaurantIds').toSet(),
        products: ProductMapper.toDomainList(
          json.objects('foods').map(ProductDto.fromJson).toList(),
        ),
        stores: SellerMapper.toDomainList(
          json.objects('restaurants').map(SellerDto.fromJson).toList(),
        ),
      );

  group('ids versus objects', () {
    test('a delisted product keeps its heart but loses its card', () {
      final wishlist = parse(payload());

      expect(wishlist.productIds, {'f1', 'f2-delisted'});
      expect(wishlist.products.map((p) => p.id), ['f1']);

      // The whole point: the heart the customer tapped stays filled.
      expect(wishlist.hasProduct('f2-delisted'), isTrue);
    });

    test('counts come from the rendered lists, not the id sets', () {
      final wishlist = parse(payload());
      // "2 saved" over a screen showing 1 card would read as a bug.
      expect(wishlist.productCount, 1);
      expect(wishlist.productIds.length, 2);
      expect(wishlist.storeCount, 1);
    });
  });

  group('local toggles', () {
    const base = Wishlist(
      productIds: {'f1', 'f2'},
      storeIds: {'r1'},
      products: [],
      stores: [],
    );

    test('unsaving a product drops it from ids and cards together', () {
      final wishlist = parse(payload()).withProduct('f1', saved: false);
      expect(wishlist.hasProduct('f1'), isFalse);
      expect(wishlist.products, isEmpty);
    });

    test('saving adds the id but does not invent a card', () {
      // The toggle response carries no catalogue fields, so the card can only
      // appear on the next load. Faking one would render an empty tile.
      final wishlist = base.withProduct('f3', saved: true);
      expect(wishlist.hasProduct('f3'), isTrue);
      expect(wishlist.products, isEmpty);
    });

    test('toggling a product leaves stores untouched', () {
      final wishlist = base.withProduct('f1', saved: false);
      expect(wishlist.storeIds, {'r1'});
    });

    test('stores toggle independently of products', () {
      final saved = base.withStore('r2', saved: true);
      expect(saved.hasStore('r2'), isTrue);
      expect(saved.productIds, {'f1', 'f2'});

      final removed = parse(payload()).withStore('r1', saved: false);
      expect(removed.hasStore('r1'), isFalse);
      expect(removed.stores, isEmpty);
    });

    test('unsaving something that was never saved is harmless', () {
      // Mirrors the API: removing a non-member succeeds rather than erroring.
      final wishlist = base.withProduct('never-there', saved: false);
      expect(wishlist.productIds, {'f1', 'f2'});
    });

    test('saving twice does not duplicate', () {
      final once = base.withProduct('f3', saved: true);
      final twice = once.withProduct('f3', saved: true);
      expect(twice.productIds.length, 3);
    });
  });

  group('store payload', () {
    test('restaurantName and ratings map onto the store', () {
      final store = parse(payload()).stores.single;
      expect(store.id, 'r1');
      expect(store.name, 'Demo Test Store');
      expect(store.rating, 4.2);
      expect(store.ratingCount, 18);
      expect(store.acceptingOrders, isTrue);
      // No products come back on this endpoint, so the card must not claim one.
      expect(store.productCount, 0);
    });

    test('a cover image is used when there is no catalogue image', () {
      final store = SellerMapper.toDomain(
        SellerDto.fromJson({
          '_id': 'r9',
          'restaurantName': 'Cover Store',
          'coverImage': 'https://cdn.example.com/cover.webp',
        }),
      );
      expect(store.imageUrl, 'https://cdn.example.com/cover.webp');
    });

    test('coverImages is the last resort', () {
      final store = SellerMapper.toDomain(
        SellerDto.fromJson({
          '_id': 'r9',
          'restaurantName': 'Cover Store',
          'coverImages': ['https://cdn.example.com/first.webp'],
        }),
      );
      expect(store.imageUrl, 'https://cdn.example.com/first.webp');
    });
  });

  test('an empty wishlist reports itself empty', () {
    expect(Wishlist.empty.isEmpty, isTrue);
    expect(Wishlist.empty.hasProduct('anything'), isFalse);
    expect(Wishlist.empty.hasStore('anything'), isFalse);
  });
}
