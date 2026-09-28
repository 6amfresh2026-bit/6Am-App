import '../../../core/errors/failure.dart';
import '../../../domain/model/product.dart';

class SearchState {
  const SearchState({
    this.query = '',
    this.results = const [],
    this.grouped = const {},
    this.recentSearches = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.page = 1,
    this.failure,
    this.hasSearched = false,
  });

  final String query;
  final List<Product> results;

  /// Results bucketed by category, so the list reads as sections rather than
  /// one undifferentiated wall.
  final Map<String, List<Product>> grouped;
  final List<String> recentSearches;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final Failure? failure;
  final bool hasSearched;

  bool get isEmpty =>
      hasSearched && !isLoading && results.isEmpty && failure == null;

  bool get showIdleState => query.trim().length < 2 && !hasSearched;

  SearchState copyWith({
    String? query,
    List<Product>? results,
    Map<String, List<Product>>? grouped,
    List<String>? recentSearches,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    Failure? failure,
    bool? hasSearched,
    bool clearFailure = false,
  }) =>
      SearchState(
        query: query ?? this.query,
        results: results ?? this.results,
        grouped: grouped ?? this.grouped,
        recentSearches: recentSearches ?? this.recentSearches,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        failure: clearFailure ? null : (failure ?? this.failure),
        hasSearched: hasSearched ?? this.hasSearched,
      );
}
