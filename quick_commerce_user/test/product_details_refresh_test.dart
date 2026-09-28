import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/di/repository_providers.dart';
import 'package:quick_commerce_user/domain/model/addon.dart';
import 'package:quick_commerce_user/domain/model/brand.dart';
import 'package:quick_commerce_user/domain/model/paged_result.dart';
import 'package:quick_commerce_user/domain/model/product.dart';
import 'package:quick_commerce_user/domain/model/review.dart';
import 'package:quick_commerce_user/domain/repository/product_repository.dart';
import 'package:quick_commerce_user/domain/repository/review_repository.dart';
import 'package:quick_commerce_user/ui/screens/product/product_details/product_details_provider.dart';

/// A product handed to the details screen from a card comes from
/// `/search/products`, which omits every field only the seller's menu carries —
/// `subscriptionEnabled` among them. The screen used to keep that seed forever,
/// so "Subscribe" never appeared on an item the seller had enabled.
class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository(this._full);

  final Product _full;
  int getByIdCalls = 0;
  String? lastSellerId;

  @override
  Future<Product> getById(String id, {String? sellerId}) async {
    getByIdCalls++;
    lastSellerId = sellerId;
    return _full;
  }

  @override
  Future<List<AddonGroup>> addonsFor({
    required String sellerId,
    String? productId,
  }) async =>
      const [];

  @override
  Future<List<Product>> bySeller(String sellerId) async => const [];

  @override
  Future<List<Brand>> brands({String? categoryId}) async => const [];

  @override
  Future<PagedResult<Product>> list({
    String? query,
    String? categoryId,
    bool vegOnly = false,
    bool inStockOnly = false,
    int page = 1,
    int pageSize = 20,
  }) async =>
      const PagedResult(items: [], total: 0, page: 1, pageSize: 20);

  @override
  Future<PagedResult<Product>> search({
    required String query,
    ProductFilters filters = const ProductFilters(),
    int page = 1,
    int pageSize = 20,
  }) async =>
      const PagedResult(items: [], total: 0, page: 1, pageSize: 20);
}

/// The details screen also loads reviews; stubbed so the test exercises the
/// product refresh rather than the network stack behind everything else.
class _FakeReviewRepository implements ReviewRepository {
  @override
  Future<({RatingSummary summary, List<Review> reviews})> forProduct(
    String productId,
  ) async =>
      (summary: RatingSummary.empty, reviews: const <Review>[]);

  @override
  Future<Review> submit({
    required String orderId,
    required String productId,
    required int rating,
    String? comment,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<({String orderId, String displayId, DateTime placedAt})>>
      rateableOrders(String productId) async => const [];
}

void main() {
  Product product({required bool subscribable}) => Product(
        id: 'p1',
        name: 'Chocolate Brownie',
        price: 149,
        sellerId: 'r1',
        subscriptionEnabled: subscribable,
      );

  /// Pumps until the controller's background work has settled.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  test('a seeded product is refreshed so menu-only fields arrive', () async {
    final repository = _FakeProductRepository(product(subscribable: true));
    final container = ProviderContainer(
      overrides: [
        productRepositoryProvider.overrideWithValue(repository),
        reviewRepositoryProvider.overrideWithValue(_FakeReviewRepository()),
      ],
    );
    addTearDown(container.dispose);

    // The seed is what a card hands over: no subscriptionEnabled.
    final args = ProductDetailsArgs(
      productId: 'p1',
      product: product(subscribable: false),
    );

    final provider = productDetailsProvider(args);
    expect(
      container.read(provider).product?.subscriptionEnabled,
      isFalse,
      reason: 'the seed paints first, without menu-only fields',
    );

    await settle();

    expect(
      container.read(provider).product?.subscriptionEnabled,
      isTrue,
      reason: 'the refresh replaces the seed with the full record',
    );
    expect(repository.getByIdCalls, 1);
    // Fetched via the seller's menu rather than a catalogue scan — one call,
    // and the only source that carries the flag.
    expect(repository.lastSellerId, 'r1');
  });

  test('a failed refresh keeps the seeded product on screen', () async {
    final container = ProviderContainer(
      overrides: [
        productRepositoryProvider.overrideWithValue(_ThrowingRepository()),
        reviewRepositoryProvider.overrideWithValue(_FakeReviewRepository()),
      ],
    );
    addTearDown(container.dispose);

    final args = ProductDetailsArgs(
      productId: 'p1',
      product: product(subscribable: false),
    );
    final provider = productDetailsProvider(args);
    // Read once so the controller is built and its refresh actually starts.
    expect(container.read(provider).product?.name, 'Chocolate Brownie');

    await settle();

    // Still rendering, not blanked — a background failure must not destroy a
    // page the customer is already looking at.
    expect(container.read(provider).product?.name, 'Chocolate Brownie');
    expect(container.read(provider).isLoading, isFalse);
  });
}

class _ThrowingRepository extends _FakeProductRepository {
  _ThrowingRepository() : super(_unused);

  static const _unused =
      Product(id: 'x', name: 'x', price: 0, sellerId: 'x');

  @override
  Future<Product> getById(String id, {String? sellerId}) async =>
      throw Exception('network down');
}
