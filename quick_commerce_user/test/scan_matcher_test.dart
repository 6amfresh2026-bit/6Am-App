import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/domain/model/addon.dart';
import 'package:quick_commerce_user/domain/model/brand.dart';
import 'package:quick_commerce_user/domain/model/paged_result.dart';
import 'package:quick_commerce_user/domain/model/product.dart';
import 'package:quick_commerce_user/domain/repository/product_repository.dart';
import 'package:quick_commerce_user/ui/screens/scanner/scan_matcher.dart';

/// Fake catalogue: a query returns the products whose name contains it.
class _FakeRepo implements ProductRepository {
  _FakeRepo(this.catalogue);
  final List<Product> catalogue;

  @override
  Future<PagedResult<Product>> search({
    required String query,
    ProductFilters filters = const ProductFilters(),
    int page = 1,
    int pageSize = 20,
  }) async {
    final q = query.toLowerCase();
    final hits =
        catalogue.where((p) => p.name.toLowerCase().contains(q)).toList();
    return PagedResult(
      items: hits,
      total: hits.length,
      page: 1,
      pageSize: pageSize,
    );
  }

  @override
  Future<PagedResult<Product>> list({
    String? query,
    String? categoryId,
    bool vegOnly = false,
    bool inStockOnly = false,
    int page = 1,
    int pageSize = 20,
  }) =>
      throw UnimplementedError();
  @override
  Future<Product> getById(String id, {String? sellerId}) =>
      throw UnimplementedError();
  @override
  Future<List<Product>> bySeller(String sellerId) => throw UnimplementedError();
  @override
  Future<List<AddonGroup>> addonsFor({
    required String sellerId,
    String? productId,
  }) =>
      throw UnimplementedError();
  @override
  Future<List<Brand>> brands({String? categoryId}) => throw UnimplementedError();
}

Product _p(String id, String name) =>
    Product(id: id, name: name, price: 40, sellerId: 's1');

void main() {
  group('ScanMatcher.matchDetections', () {
    test('drops candidates with no catalogue hit', () async {
      final matcher = ScanMatcher(_FakeRepo([_p('1', 'Banana Robusta')]));
      final out = await matcher.matchDetections([
        const ScanCandidate('banana', 0.9),
        const ScanCandidate('spaceship', 0.9),
      ]);
      expect(out.map((d) => d.product.name), ['Banana Robusta']);
    });

    test('same product from two signals collapses to the higher confidence',
        () async {
      final matcher = ScanMatcher(_FakeRepo([_p('1', 'Banana Robusta')]));
      final out = await matcher.matchDetections([
        const ScanCandidate('banana', 0.7),
        const ScanCandidate('banana', 0.95),
      ]);
      expect(out.length, 1);
      expect(out.first.confidence, 0.95);
    });

    test('an unrelated name match is dialled down below the confident bar',
        () async {
      // Label "bottle" matches "Cola Bottle" (shares the word "bottle") → stays
      // confident; but a term sharing no word is discounted.
      final matcher = ScanMatcher(_FakeRepo([_p('1', 'Cola Bottle')]));
      final related = await matcher.matchDetections(
        [const ScanCandidate('bottle', 0.8)],
      );
      expect(related.first.needsConfirmation, isFalse);

      final loose = await matcher.matchDetections(
        // 'col' is a substring of 'Cola' but < 3 meaningful overlap after split;
        // use a term that hits via search yet shares no >=3-char word.
        [const ScanCandidate('co', 0.8)],
      );
      // 'co' has length < 3 so relatedness fails → confidence * 0.6 = 0.48.
      expect(loose.first.needsConfirmation, isTrue);
      expect(loose.first.confidence, closeTo(0.48, 0.001));
    });

    test('results are sorted most-confident first', () async {
      final matcher = ScanMatcher(_FakeRepo([
        _p('1', 'Banana Robusta'),
        _p('2', 'Tomato Local'),
      ]));
      final out = await matcher.matchDetections([
        const ScanCandidate('tomato', 0.7),
        const ScanCandidate('banana', 0.95),
      ]);
      expect(out.first.product.name, 'Banana Robusta');
      expect(out.last.product.name, 'Tomato Local');
    });
  });
}
