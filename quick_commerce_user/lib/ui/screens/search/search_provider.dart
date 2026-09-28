import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/local_storage/local_storage.dart';
import '../../../core/utils/debouncer.dart';
import '../../../di/repository_providers.dart';
import '../../../di/service_providers.dart';
import '../../../domain/model/product.dart';
import '../../../domain/repository/product_repository.dart';
import 'search_state.dart';

class SearchController extends Notifier<SearchState> {
  static const _pageSize = 20;
  static const _maxRecent = 8;

  final _debouncer = Debouncer(AppDurations.searchDebounce);
  final List<Product> _raw = [];

  @override
  SearchState build() {
    ref.onDispose(_debouncer.dispose);
    return SearchState(
      recentSearches:
          ref.read(localStorageProvider).getStringList(StorageKeys.recentSearches),
    );
  }

  /// Called on every keystroke; the actual request is debounced.
  void onQueryChanged(String query) {
    state = state.copyWith(query: query, clearFailure: true);

    if (query.trim().length < 2) {
      _debouncer.cancel();
      _raw.clear();
      state = state.copyWith(
        results: const [],
        grouped: const {},
        hasSearched: false,
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(isLoading: true);
    _debouncer.run(() => search(query));
  }

  Future<void> search(String query, {bool reset = true}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;

    if (reset) {
      _raw.clear();
      state = state.copyWith(
        isLoading: true,
        page: 1,
        hasSearched: true,
        clearFailure: true,
      );
    }

    try {
      final page = await ref.read(productRepositoryProvider).list(
            query: trimmed,
            page: reset ? 1 : state.page,
            pageSize: _pageSize,
          );

      _raw.addAll(page.items);

      final ranking = ref.read(searchRankingServiceProvider);
      final ranked = ranking.apply(
        _raw,
        filters: const ProductFilters(),
        sort: ProductSort.relevance,
        query: trimmed,
      );

      state = state.copyWith(
        results: ranked,
        grouped: ranking.groupByCategory(ranked),
        isLoading: false,
        isLoadingMore: false,
        hasMore: page.hasMore,
        page: page.page,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        failure: ErrorMapper.toFailure(e),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, page: state.page + 1);
    await search(state.query, reset: false);
  }

  /// Records the term once the user commits to it (submit or tapping a result).
  Future<void> commitSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;

    final recent = [trimmed, ...state.recentSearches.where((r) => r != trimmed)]
        .take(_maxRecent)
        .toList();

    state = state.copyWith(recentSearches: recent);
    await ref
        .read(localStorageProvider)
        .setStringList(StorageKeys.recentSearches, recent);
  }

  Future<void> clearRecent() async {
    state = state.copyWith(recentSearches: const []);
    await ref.read(localStorageProvider).remove(StorageKeys.recentSearches);
  }
}

final searchProvider =
    NotifierProvider<SearchController, SearchState>(SearchController.new);
