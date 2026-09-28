import '../../../../core/errors/failure.dart';
import '../../../../domain/model/product.dart';
import '../../../../domain/model/sub_category.dart';

/// Ordering offered by the "Sort" chip. Applied over the page already loaded,
/// so it costs nothing and works offline.
enum ProductSort {
  relevance('Relevance'),
  priceLowToHigh('Price: low to high'),
  priceHighToLow('Price: high to low'),
  discount('Discount'),
  rating('Customer rating');

  const ProductSort(this.label);

  final String label;
}

/// "Diet Preference" chip.
enum DietFilter {
  any('All'),
  veg('Vegetarian'),
  nonVeg('Non-vegetarian');

  const DietFilter(this.label);

  final String label;
}

/// "Price" chip. Bounds are inclusive; `null` means unbounded.
enum PriceBand {
  any('Any price', null, null),
  under100('Under ₹100', null, 100),
  from100to300('₹100 – ₹300', 100, 300),
  from300to600('₹300 – ₹600', 300, 600),
  above600('Above ₹600', 600, null);

  const PriceBand(this.label, this.min, this.max);

  final String label;
  final double? min;
  final double? max;

  bool contains(double price) =>
      (min == null || price >= min!) && (max == null || price <= max!);
}

class SubCategoryState {
  const SubCategoryState({
    this.subCategories = const [],
    this.allProducts = const [],
    this.visibleProducts = const [],
    this.selectedId = 'all',
    this.isLoading = true,
    this.failure,
    this.sort = ProductSort.relevance,
    this.diet = DietFilter.any,
    this.brand = '',
    this.priceBand = PriceBand.any,
  });

  final List<SubCategory> subCategories;
  final List<Product> allProducts;
  final List<Product> visibleProducts;
  final String selectedId;
  final bool isLoading;
  final Failure? failure;

  final ProductSort sort;
  final DietFilter diet;

  /// Empty means "every brand".
  final String brand;
  final PriceBand priceBand;

  bool get isEmpty => !isLoading && allProducts.isEmpty && failure == null;

  /// True when a filter — not just a sub-category — is hiding products. Drives
  /// the "no matches" state, which offers to clear rather than to browse away.
  bool get hasActiveFilters =>
      diet != DietFilter.any || brand.isNotEmpty || priceBand != PriceBand.any;

  int get activeFilterCount =>
      (diet != DietFilter.any ? 1 : 0) +
      (brand.isNotEmpty ? 1 : 0) +
      (priceBand != PriceBand.any ? 1 : 0);

  /// Brands present in this category, for the "Brand" chip.
  List<String> get brands {
    final names = allProducts
        .map((p) => p.brand.trim())
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return names;
  }

  SubCategoryState copyWith({
    List<SubCategory>? subCategories,
    List<Product>? allProducts,
    List<Product>? visibleProducts,
    String? selectedId,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
    ProductSort? sort,
    DietFilter? diet,
    String? brand,
    PriceBand? priceBand,
  }) =>
      SubCategoryState(
        subCategories: subCategories ?? this.subCategories,
        allProducts: allProducts ?? this.allProducts,
        visibleProducts: visibleProducts ?? this.visibleProducts,
        selectedId: selectedId ?? this.selectedId,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : (failure ?? this.failure),
        sort: sort ?? this.sort,
        diet: diet ?? this.diet,
        brand: brand ?? this.brand,
        priceBand: priceBand ?? this.priceBand,
      );
}
