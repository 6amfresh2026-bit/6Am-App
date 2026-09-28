import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/data/dto/json_reader.dart';
import 'package:quick_commerce_user/data/dto/product_dto.dart';
import 'package:quick_commerce_user/data/mapper/product_mapper.dart';
import 'package:quick_commerce_user/domain/model/addon.dart';
import 'package:quick_commerce_user/domain/model/cart.dart';
import 'package:quick_commerce_user/domain/model/coupon.dart';
import 'package:quick_commerce_user/domain/model/product.dart';
import 'package:quick_commerce_user/domain/model/product_variant.dart';
import 'package:quick_commerce_user/domain/service/cart_pricing_service.dart';
import 'package:quick_commerce_user/domain/service/coupon_eligibility_service.dart';
import 'package:quick_commerce_user/domain/service/search_ranking_service.dart';
import 'package:quick_commerce_user/domain/repository/product_repository.dart';
import 'package:quick_commerce_user/core/utils/currency_formatter.dart';

/// Covers the logic that would silently corrupt a bill or a cart if it broke:
/// cart merging and caps, savings, coupon eligibility, ranking, the backend's
/// awkward JSON shapes, and Indian currency grouping.
void main() {
  Product product({
    String id = 'p1',
    double price = 100,
    double? mrp = 125,
    String seller = 's1',
    int? stock,
    int? maxPerOrder,
    List<ProductVariant> variants = const [],
    String brand = 'Amul',
    bool available = true,
  }) =>
      Product(
        id: id,
        name: 'Product $id',
        price: price,
        mrp: mrp,
        sellerId: seller,
        sellerName: 'Store $seller',
        stockQty: stock,
        maxQtyPerOrder: maxPerOrder,
        variants: variants,
        brand: brand,
        isAvailable: available,
      );

  group('CartPricingService', () {
    const service = CartPricingService(freeDeliveryThreshold: 199);

    test('adding the same line merges instead of duplicating', () {
      var cart = service.addItem(Cart.empty, product: product());
      cart = service.addItem(cart, product: product());

      expect(cart.lineCount, 1);
      expect(cart.itemCount, 2);
    });

    test('a different variant creates a separate line', () {
      const small = ProductVariant(id: 'v1', name: '500 g', price: 100);
      const large = ProductVariant(id: 'v2', name: '1 kg', price: 180);
      final p = product(variants: const [small, large]);

      var cart = service.addItem(Cart.empty, product: p, variant: small);
      cart = service.addItem(cart, product: p, variant: large);

      expect(cart.lineCount, 2);
      expect(cart.itemCount, 2);
    });

    test('a different add-on set creates a separate line', () {
      const addon = Addon(id: 'a1', name: 'Cutlery', price: 5);
      var cart = service.addItem(Cart.empty, product: product());
      cart = service.addItem(cart, product: product(), addons: const [addon]);

      expect(cart.lineCount, 2);
    });

    test('quantity is capped by the per-order limit', () {
      final p = product(maxPerOrder: 3);
      var cart = service.addItem(Cart.empty, product: p, quantity: 10);

      expect(cart.itemCount, 3);

      cart = service.setQuantity(cart, cart.items.first.lineId, 99);
      expect(cart.itemCount, 3);
    });

    test('quantity is capped by remaining stock', () {
      final cart = service.addItem(Cart.empty, product: product(stock: 2), quantity: 5);
      expect(cart.itemCount, 2);
    });

    test('out-of-stock products are never added', () {
      final cart = service.addItem(Cart.empty, product: product(available: false));
      expect(cart.isEmpty, isTrue);
    });

    test('mixing sellers is refused unless the caller opts in', () {
      final cart = service.addItem(Cart.empty, product: product(seller: 's1'));

      final refused = service.addItem(cart, product: product(id: 'p2', seller: 's2'));
      expect(refused.lineCount, 1);
      expect(refused.sellerId, 's1');

      final replaced = service.addItem(
        cart,
        product: product(id: 'p2', seller: 's2'),
        replaceSeller: true,
      );
      expect(replaced.lineCount, 1);
      expect(replaced.sellerId, 's2');
    });

    test('removing the last line empties the cart entirely', () {
      final cart = service.addItem(Cart.empty, product: product());
      final emptied = service.removeLine(cart, cart.items.first.lineId);

      expect(emptied.isEmpty, isTrue);
      expect(emptied.sellerId, isEmpty);
    });

    test('editing the cart invalidates the server pricing', () {
      final priced = service
          .addItem(Cart.empty, product: product())
          .copyWith(pricing: const CartPricing(subtotal: 100, total: 130));

      final edited = service.addItem(priced, product: product());
      expect(edited.pricing.total, 0);
    });

    test('savings are MRP minus selling price, never negative', () {
      final cart = service.addItem(
        Cart.empty,
        product: product(price: 100, mrp: 125),
        quantity: 2,
      );
      expect(cart.provisionalSavings, 50);

      final noDiscount =
          service.addItem(Cart.empty, product: product(price: 100, mrp: null));
      expect(noDiscount.provisionalSavings, 0);
    });

    test('free-delivery gap closes at the threshold', () {
      final small = service.addItem(Cart.empty, product: product(price: 50));
      expect(service.amountToFreeDelivery(small), 149);

      final large = service.addItem(Cart.empty, product: product(price: 250));
      expect(service.amountToFreeDelivery(large), 0);
    });

    test('the bill renders exactly what the server priced', () {
      final cart = service.addItem(Cart.empty, product: product()).copyWith(
            pricing: const CartPricing(
              subtotal: 100,
              deliveryFee: 0,
              platformFee: 5,
              tax: 9,
              discount: 20,
              total: 94,
            ),
          );

      final lines = service.billLines(cart);
      final total = lines.firstWhere((l) => l.isTotal);
      expect(total.amount, 94);
      expect(lines.any((l) => l.isFree), isTrue);
      expect(lines.any((l) => l.isDiscount && l.amount == 20), isTrue);
    });
  });

  group('CouponEligibilityService', () {
    const service = CouponEligibilityService();
    const pricing = CartPricingService();

    const coupon = Coupon(
      id: 'c1',
      code: 'SUVIO50',
      title: 'Flat ₹50 off',
      discountType: DiscountType.flat,
      discountValue: 50,
      minOrderValue: 200,
    );

    test('is blocked below the minimum order value, with the shortfall named', () {
      final cart = pricing.addItem(Cart.empty, product: product(price: 150));
      final verdict = service.evaluate(coupon, cart);

      expect(verdict.isEligible, isFalse);
      expect(verdict.reason, contains('50'));
    });

    test('is eligible once the minimum is met', () {
      final cart = pricing.addItem(Cart.empty, product: product(price: 250));
      expect(service.evaluate(coupon, cart).isEligible, isTrue);
    });

    test('percentage discounts respect their cap', () {
      const percentage = Coupon(
        id: 'c2',
        code: 'SAVE20',
        title: '20% off',
        discountType: DiscountType.percentage,
        discountValue: 20,
        maxDiscount: 40,
      );
      expect(percentage.estimatedDiscountOn(1000), 40);
      expect(percentage.estimatedDiscountOn(100), 20);
    });

    test('a coupon from another seller is refused', () {
      final cart = pricing.addItem(Cart.empty, product: product(price: 500));
      const foreign = Coupon(
        id: 'c3',
        code: 'OTHER',
        title: 'Flat ₹10',
        discountType: DiscountType.flat,
        discountValue: 10,
        sellerId: 'other-store',
        sellerName: 'Other Store',
      );

      expect(service.evaluate(foreign, cart).isEligible, isFalse);
    });

    test('eligible coupons rank ahead of ineligible ones', () {
      final cart = pricing.addItem(Cart.empty, product: product(price: 100));
      const cheap = Coupon(
        id: 'c4',
        code: 'SMALL',
        title: 'Flat ₹10',
        discountType: DiscountType.flat,
        discountValue: 10,
      );

      final ranked = service.rank([coupon, cheap], cart);
      expect(ranked.first.code, 'SMALL');
    });
  });

  group('SearchRankingService', () {
    const service = SearchRankingService();

    test('filters by price range and brand', () {
      final products = [
        product(id: 'a', price: 50, brand: 'Amul'),
        product(id: 'b', price: 500, brand: 'Nestle'),
      ];

      final byPrice = service.apply(
        products,
        filters: const ProductFilters(maxPrice: 100),
        sort: ProductSort.relevance,
      );
      expect(byPrice.map((p) => p.id), ['a']);

      final byBrand = service.apply(
        products,
        filters: const ProductFilters(brand: 'nestle'),
        sort: ProductSort.relevance,
      );
      expect(byBrand.map((p) => p.id), ['b']);
    });

    test('sorts by price in both directions', () {
      final products = [
        product(id: 'a', price: 300),
        product(id: 'b', price: 100),
      ];

      expect(
        service
            .apply(
              products,
              filters: const ProductFilters(),
              sort: ProductSort.priceLowToHigh,
            )
            .map((p) => p.id),
        ['b', 'a'],
      );
      expect(
        service
            .apply(
              products,
              filters: const ProductFilters(),
              sort: ProductSort.priceHighToLow,
            )
            .map((p) => p.id),
        ['a', 'b'],
      );
    });

    test('relevance prefers an exact name match over a substring', () {
      final products = [
        const Product(id: 'x', name: 'Almond Milk', price: 10, sellerId: 's'),
        const Product(id: 'y', name: 'Milk', price: 10, sellerId: 's'),
      ];

      final ranked = service.apply(
        products,
        filters: const ProductFilters(),
        sort: ProductSort.relevance,
        query: 'milk',
      );
      expect(ranked.first.id, 'y');
    });

    test('in-stock items outrank out-of-stock ones', () {
      final products = [
        product(id: 'out', available: false),
        product(id: 'in'),
      ];

      final ranked = service.apply(
        products,
        filters: const ProductFilters(),
        sort: ProductSort.relevance,
      );
      expect(ranked.first.id, 'in');
    });
  });

  group('ProductMapper', () {
    test('reads the catalog shape the backend actually returns', () {
      final dto = ProductDto.fromJson({
        '_id': 'f1',
        'name': 'Toned Milk',
        'price': 27,
        'otherPrice': 30,
        'mrp': 32,
        'foodType': 'Veg',
        'packSize': '500 ml',
        'brand': 'Amul',
        'stockQty': 3,
        'restaurantId': 'r1',
        'images': ['https://example.com/a.jpg'],
        'variants': [
          {'_id': 'v1', 'name': '500 ml', 'price': 27, 'otherPrice': 32},
          {'_id': 'v2', 'name': '', 'price': 40},
          {'_id': 'v3', 'name': 'Free', 'price': 0},
        ],
        'seller': {'_id': 'r1', 'name': 'Fresh Mart', 'estimatedDeliveryTimeMinutes': 9},
      });

      final product = ProductMapper.toDomain(dto);

      expect(product.isVeg, isTrue);
      expect(product.sellerId, 'r1');
      expect(product.deliveryMinutes, 9);
      // The highest strike price wins, and the discount follows from it.
      expect(product.strikePrice, 32);
      expect(product.discountPercent, 16);
      // Blank-named and zero-priced variants are dropped by the backend's own
      // serializer, so the client must not surface them either.
      expect(product.variants.length, 1);
      expect(product.stockStatus, StockStatus.limited);
    });

    test('an unavailable item is not purchasable even with stock on hand', () {
      final dto = ProductDto.fromJson({
        '_id': 'f2',
        'name': 'Bread',
        'price': 40,
        'isAvailable': false,
        'stockQty': 12,
      });
      expect(ProductMapper.toDomain(dto).isPurchasable, isFalse);
    });
  });

  group('JsonReader', () {
    test('coerces the loose types the API mixes in', () {
      final json = <String, dynamic>{
        'price': '42.5',
        'count': '7',
        'flag': 'true',
        'image': {'url': 'https://example.com/x.png'},
        'images': [
          'https://example.com/a.png',
          {'url': 'https://example.com/b.png'},
          '',
        ],
      };

      expect(json.dbl('price'), 42.5);
      expect(json.integer('count'), 7);
      expect(json.boolean('flag'), isTrue);
      expect(json.imageUrl('image'), 'https://example.com/x.png');
      expect(json.strings('images').length, 2);
      expect(json.dbl('missing', 1), 1);
    });

    test('normalises all three pagination envelopes the backend uses', () {
      final flat = PageMeta.from({'total': 90, 'page': 2, 'limit': 20});
      expect(flat.total, 90);
      expect(flat.page, 2);

      final nested = PageMeta.from({
        'pagination': {'total': 90, 'page': 3, 'limit': 15},
      });
      expect(nested.pageSize, 15);
      expect(nested.page, 3);

      final meta = PageMeta.from({
        'meta': {'total': 4, 'page': 1, 'limit': 20},
      });
      expect(meta.total, 4);
    });
  });

  group('CurrencyFormatter', () {
    test('groups in the Indian lakh/crore style', () {
      expect(CurrencyFormatter.format(999), '₹999');
      expect(CurrencyFormatter.format(1234), '₹1,234');
      expect(CurrencyFormatter.format(123456), '₹1,23,456');
      expect(CurrencyFormatter.format(12345678), '₹1,23,45,678');
      expect(CurrencyFormatter.format(-500), '-₹500');
      expect(CurrencyFormatter.format(99.5, decimals: true), '₹99.50');
    });
  });
}
