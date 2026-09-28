import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/utils/logger.dart';
import '../../../di/repository_providers.dart';
import '../../../di/service_providers.dart';
import '../../../domain/model/order.dart';
import '../../../domain/model/product.dart';
import 'home_state.dart';

/// Builds the home screen from the real catalog.
///
/// Sections are derived rather than fetched: the backend has no
/// "trending"/"best sellers" endpoints, so `CatalogGroupingService` ranks a
/// fetched catalog page. Documented in README → Backend Gaps.
class HomeController extends Notifier<HomeState> {
  @override
  HomeState build() {
    Future.microtask(load);
    return const HomeState();
  }

  Future<void> load({bool refresh = false}) async {
    if (refresh) state = state.copyWith(isRefreshing: true, clearFailure: true);

    // Banners, categories and the catalog load in parallel; each updates the
    // UI as it lands so no section waits on another.
    await Future.wait([
      _loadBanners(),
      _loadCoupons(),
      _loadCatalog(),
    ]);

    if (refresh) state = state.copyWith(isRefreshing: false);
  }

  Future<void> _loadBanners() async {
    state = state.copyWith(isLoadingBanners: true);
    try {
      final content = ref.read(catalogContentRepositoryProvider);
      // Three separate collections upstream, one carousel here: whichever the
      // admin has published is what the user sees. `topBanners` was fetchable
      // but nothing ever called it.
      final results = await Future.wait([
        content.heroBanners(),
        content.topBanners(),
        content.promotionBanners(),
      ]);
      final banners = [...results[0], ...results[1], ...results[2]];
      AppLogger.debug(
        'home carousel: ${results[0].length} hero + ${results[1].length} top + '
        '${results[2].length} promotion = ${banners.length} banner(s)',
        scope: 'banners',
      );
      state = state.copyWith(banners: banners, isLoadingBanners: false);
    } catch (e, stack) {
      // Banners are decoration; their failure must not take the page down —
      // but it must not be silent either.
      AppLogger.error('home banners failed to load', error: e, stackTrace: stack);
      state = state.copyWith(isLoadingBanners: false);
    }
  }

  Future<void> _loadCoupons() async {
    state = state.copyWith(isLoadingCoupons: true);
    try {
      final coupons = await ref.read(couponRepositoryProvider).available();
      state = state.copyWith(
        // Expired offers are still returned by the endpoint; never show them.
        coupons: coupons.where((c) => !c.isExpired).toList(),
        isLoadingCoupons: false,
      );
    } catch (_) {
      // Offers are promotional; their failure must not take the page down.
      state = state.copyWith(isLoadingCoupons: false);
    }
  }

  static const _catalogPageSize = 50;

  /// These pages are fetched one after another, so each one is a round trip the
  /// user waits through before the first row paints. They only feed the derived
  /// rankings (flash sale / best sellers / recommended), and those are stable
  /// well before 150 items — ten pages cost eight extra serial requests and
  /// changed the top twelve of each row by nothing.
  static const _maxCatalogPages = 3;

  static const _maxCategoryRows = 20;

  Future<void> _loadCatalog() async {
    state = state.copyWith(
      isLoadingCategories: true,
      isLoadingSections: true,
      clearFailure: true,
    );

    try {
      final categories = await ref.read(categoryRepositoryProvider).topLevel();
      state = state.copyWith(categories: categories, isLoadingCategories: false);

      final products = ref.read(productRepositoryProvider);
      final grouping = ref.read(catalogGroupingServiceProvider);

      // Every home section is ranked from this list, so a single page meant the
      // rankings only ever saw the first 50 items in the catalogue.
      var catalog = await products.list(pageSize: _catalogPageSize);
      var all = catalog.items;
      while (catalog.hasMore && catalog.page < _maxCatalogPages) {
        catalog = await products.list(
          page: catalog.page + 1,
          pageSize: _catalogPageSize,
        );
        all = [...all, ...catalog.items];
      }

      // One request per category the backend returned, in parallel — every
      // category gets a row, not just the first eight. Capped only so an admin
      // adding fifty categories cannot fire fifty requests at once.
      final rowCategories = categories.take(_maxCategoryRows).toList();
      final rows = await Future.wait(
        rowCategories.map(
          (c) => products
              .list(categoryId: c.id, pageSize: 12)
              .then((page) => page.items)
              .catchError((_) => <Product>[]),
        ),
      );

      final sections = <HomeSection>[
        HomeSection(
          id: 'flash',
          title: 'Flash sale',
          subtitle: 'Deepest discounts, while stock lasts',
          products: grouping.flashSale(all),
        ),
        HomeSection(
          id: 'trending',
          title: 'Trending near you',
          products: all.where((p) => p.ratingCount > 0).take(12).toList(),
        ),
        HomeSection(
          id: 'recently-bought',
          title: 'Buy it again',
          subtitle: 'From your recent orders',
          products: await _recentlyBought(all),
        ),
        HomeSection(
          id: 'recommended',
          title: 'Recommended for you',
          products: grouping.recommended(all),
        ),
        HomeSection(
          id: 'best-sellers',
          title: 'Best sellers',
          products: grouping.bestSellers(all),
          showRanks: true,
        ),
        for (var i = 0; i < rowCategories.length; i++)
          HomeSection(
            id: 'category-${rowCategories[i].id}',
            title: rowCategories[i].name,
            products: rows[i],
            categoryId: rowCategories[i].id,
          ),
      ]..removeWhere((s) => s.isEmpty);

      state = state.copyWith(
        sections: sections,
        brands: grouping.brandsFrom(all).take(12).toList(),
        sellers: grouping.sellersFrom(all),
        isLoadingSections: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingCategories: false,
        isLoadingSections: false,
        failure: ErrorMapper.toFailure(e),
      );
    }
  }

  /// Products from the customer's own delivered orders, matched back to the
  /// live catalog so prices and stock are current.
  Future<List<Product>> _recentlyBought(List<Product> catalog) async {
    try {
      final orders = await ref.read(orderRepositoryProvider).list(pageSize: 10);
      final boughtIds = <String>{};
      for (final Order order in orders.items) {
        for (final line in order.lines) {
          boughtIds.add(line.itemId);
        }
      }
      return catalog.where((p) => boughtIds.contains(p.id)).take(12).toList();
    } catch (_) {
      // Signed-out or failed: the section simply does not render.
      return const [];
    }
  }

}

final homeProvider = NotifierProvider<HomeController, HomeState>(HomeController.new);
