import '../model/addon.dart';
import '../model/brand.dart';
import '../model/paged_result.dart';
import '../model/product.dart';

/// Sort options exposed by the listing screen. Only `relevance` is honoured
/// server-side (`/search/products` has no sort param), so the rest are applied
/// by `SearchRankingService` over the fetched page.
enum ProductSort { relevance, priceLowToHigh, priceHighToLow, rating, discount }

/// Filters the listing sheet can apply.
class ProductFilters {
  const ProductFilters({
    this.categoryId,
    this.brand,
    this.minPrice,
    this.maxPrice,
    this.vegOnly = false,
    this.inStockOnly = false,
    this.minDiscountPercent,
  });

  final String? categoryId;
  final String? brand;
  final double? minPrice;
  final double? maxPrice;
  final bool vegOnly;
  final bool inStockOnly;
  final int? minDiscountPercent;

  bool get isEmpty =>
      brand == null &&
      minPrice == null &&
      maxPrice == null &&
      !vegOnly &&
      !inStockOnly &&
      minDiscountPercent == null;

  int get activeCount => [
        brand != null,
        minPrice != null || maxPrice != null,
        vegOnly,
        inStockOnly,
        minDiscountPercent != null,
      ].where((f) => f).length;

  ProductFilters copyWith({
    String? categoryId,
    String? brand,
    double? minPrice,
    double? maxPrice,
    bool? vegOnly,
    bool? inStockOnly,
    int? minDiscountPercent,
    bool clearBrand = false,
    bool clearPrice = false,
    bool clearDiscount = false,
  }) =>
      ProductFilters(
        categoryId: categoryId ?? this.categoryId,
        brand: clearBrand ? null : (brand ?? this.brand),
        minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
        maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
        vegOnly: vegOnly ?? this.vegOnly,
        inStockOnly: inStockOnly ?? this.inStockOnly,
        minDiscountPercent:
            clearDiscount ? null : (minDiscountPercent ?? this.minDiscountPercent),
      );
}

abstract interface class ProductRepository {
  /// Backed by `GET /food/search/products` — the only catalog endpoint that
  /// paginates and returns MRP/stock/brand.
  Future<PagedResult<Product>> list({
    String? query,
    String? categoryId,
    bool vegOnly,
    bool inStockOnly,
    int page,
    int pageSize,
  });

  Future<Product> getById(String id, {String? sellerId});

  /// Cross-entity search used by the search screen.
  Future<PagedResult<Product>> search({
    required String query,
    ProductFilters filters,
    int page,
    int pageSize,
  });

  /// Everything one seller carries, from `GET /food/restaurant/restaurants/
  /// :id/menu`. Backs the "Explore all products" store view; unpaginated
  /// because the menu endpoint returns the whole catalogue in one response.
  Future<List<Product>> bySeller(String sellerId);

  /// Add-on groups a seller offers for an item.
  Future<List<AddonGroup>> addonsFor({required String sellerId, String? productId});

  /// Brands present in the catalog. Derived from item `brand` values because
  /// the backend has no brand resource.
  Future<List<Brand>> brands({String? categoryId});
}
