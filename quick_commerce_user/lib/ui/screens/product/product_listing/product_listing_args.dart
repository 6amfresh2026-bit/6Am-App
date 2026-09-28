import '../../../../domain/model/brand.dart';
import '../../../../domain/model/category.dart';
import '../../../../domain/model/product.dart';
import '../../../../domain/repository/product_repository.dart';

/// Everything the listing screen needs to know about its context.
///
/// One screen serves category, sub-category, brand, search-refinement and
/// "see all" entry points, so the differences live here rather than in five
/// near-identical screens.
class ProductListingArgs {
  const ProductListingArgs({
    required this.title,
    this.categoryId,
    this.brandName,
    this.query,
    this.sellerId,
    this.seedProducts = const [],
    this.initialSort = ProductSort.relevance,
  });

  final String title;
  final String? categoryId;
  final String? brandName;
  final String? query;

  /// Set when the screen is a seller's store, which is loaded from that
  /// seller's menu rather than the catalog search.
  final String? sellerId;

  /// Pre-fetched products for "see all" on a derived home row, where there is
  /// no server-side filter that reproduces the section.
  final List<Product> seedProducts;
  final ProductSort initialSort;

  factory ProductListingArgs.forCategory(Category category) =>
      ProductListingArgs(title: category.name, categoryId: category.id);

  factory ProductListingArgs.forBrand(Brand brand) =>
      ProductListingArgs(title: brand.name, brandName: brand.name);

  ProductFilters get initialFilters =>
      ProductFilters(categoryId: categoryId, brand: brandName);

  /// True when the list is fixed client-side and cannot paginate.
  bool get isSeeded => seedProducts.isNotEmpty;

  bool get isSellerStore => (sellerId ?? '').isNotEmpty;

  // Value identity: this type is a Riverpod family key, so two structurally
  // identical arguments must resolve to the same provider instance.
  @override
  bool operator ==(Object other) =>
      other is ProductListingArgs &&
      other.title == title &&
      other.categoryId == categoryId &&
      other.brandName == brandName &&
      other.query == query &&
      other.sellerId == sellerId &&
      other.seedProducts.length == seedProducts.length &&
      other.initialSort == initialSort;

  @override
  int get hashCode => Object.hash(
        title,
        categoryId,
        brandName,
        query,
        sellerId,
        seedProducts.length,
        initialSort,
      );
}
