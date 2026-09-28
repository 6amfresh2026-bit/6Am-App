import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/cards/product_card.dart';
import '../../../common/widgets/loaders/product_card_skeleton.dart';
import '../../../common/widgets/misc/staggered_entrance.dart';
import '../../../common/widgets/states/empty_state_widget.dart';
import '../../../common/widgets/states/error_state_widget.dart';
import '../../cart/widgets/cart_summary_bar.dart';
import 'product_listing_args.dart';
import 'product_listing_provider.dart';
import 'widgets/sort_filter_sheet.dart';
import '../../../common/widgets/misc/sound_refresh_indicator.dart';

/// Grid listing for category, sub-category, brand and "see all" contexts.
class ProductListingScreen extends ConsumerStatefulWidget {
  const ProductListingScreen({super.key, required this.args});

  final ProductListingArgs args;

  @override
  ConsumerState<ProductListingScreen> createState() =>
      _ProductListingScreenState();
}

class _ProductListingScreenState extends ConsumerState<ProductListingScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Infinite scroll: fetch the next page once 80% of the list is behind us.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent * 0.8) {
      ref.read(productListingProvider(widget.args).notifier).loadMore();
    }
  }

  Future<void> _openSortFilter() async {
    final controller = ref.read(productListingProvider(widget.args).notifier);
    final state = ref.read(productListingProvider(widget.args));

    final result = await SortFilterSheet.show(
      context,
      sort: state.sort,
      filters: state.filters,
      brands: controller.availableBrands,
      priceBounds: controller.priceBounds,
    );
    if (result == null) return;

    controller
      ..applySort(result.sort)
      ..applyFilters(result.filters);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productListingProvider(widget.args));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.title),
        actions: [
          IconButton(
            onPressed: () => context.push(RoutePaths.search),
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
          ),
        ],
      ),
      bottomNavigationBar: const CartSummaryBar(),
      body: Column(
        children: [
          _FilterBar(
            activeCount: state.filters.activeCount,
            resultCount: state.products.length,
            onTap: _openSortFilter,
          ),
          Expanded(child: _body(context, state)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, state) {
    if (state.isLoading && state.products.isEmpty) {
      return ProductGridSkeleton(columns: context.productGridColumns);
    }
    if (state.failure != null && state.products.isEmpty) {
      return ErrorStateWidget(
        failure: state.failure!,
        onRetry: () => ref
            .read(productListingProvider(widget.args).notifier)
            .load(reset: true),
      );
    }
    if (state.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.filter_alt_off_rounded,
        title: 'Nothing matches those filters',
        message:
            'Try widening your price range or clearing a filter to see more.',
        actionLabel: 'Clear filters',
        onAction: () =>
            ref.read(productListingProvider(widget.args).notifier).clearFilters(),
      );
    }

    return SoundRefreshIndicator(
      onRefresh: () =>
          ref.read(productListingProvider(widget.args).notifier).load(reset: true),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: state.products.length + (state.isLoadingMore ? 2 : 0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: context.productGridColumns,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.58,
        ),
        itemBuilder: (context, index) {
          if (index >= state.products.length) {
            return const ProductCardSkeleton(width: double.infinity);
          }
          final product = state.products[index];
          return StaggeredEntrance(
            index: index,
            child: ProductCard(
              product: product,
              width: double.infinity,
              heroTag: 'listing-${widget.args.title}',
              onTap: () => context.push(
                RoutePaths.productDetailsOf(product.id),
                extra: product,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.activeCount,
    required this.resultCount,
    required this.onTap,
  });

  final int activeCount;
  final int resultCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.semantic.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$resultCount ${resultCount == 1 ? 'item' : 'items'}',
              style: context.text.bodyMedium,
            ),
          ),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: activeCount > 0
                    ? context.colors.primary.withValues(alpha: 0.10)
                    : context.semantic.surfaceAlt,
                borderRadius: AppRadii.rPill,
                border: Border.all(
                  color: activeCount > 0
                      ? context.colors.primary
                      : context.semantic.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 15,
                    color: activeCount > 0
                        ? context.colors.primary
                        : context.colors.onSurface,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    activeCount > 0 ? 'Sort & filter ($activeCount)' : 'Sort & filter',
                    style: context.text.labelMedium!.copyWith(
                      color: activeCount > 0
                          ? context.colors.primary
                          : context.colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
