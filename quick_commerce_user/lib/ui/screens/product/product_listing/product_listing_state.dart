import '../../../../core/errors/failure.dart';
import '../../../../domain/model/product.dart';
import '../../../../domain/repository/product_repository.dart';

class ProductListingState {
  const ProductListingState({
    this.products = const [],
    this.filters = const ProductFilters(),
    this.sort = ProductSort.relevance,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.page = 1,
    this.failure,
  });

  /// Already filtered and sorted by `SearchRankingService`.
  final List<Product> products;
  final ProductFilters filters;
  final ProductSort sort;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final Failure? failure;

  bool get isEmpty => !isLoading && products.isEmpty && failure == null;

  ProductListingState copyWith({
    List<Product>? products,
    ProductFilters? filters,
    ProductSort? sort,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      ProductListingState(
        products: products ?? this.products,
        filters: filters ?? this.filters,
        sort: sort ?? this.sort,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}
