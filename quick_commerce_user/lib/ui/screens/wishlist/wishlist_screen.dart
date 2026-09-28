import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../di/app_providers.dart';
import '../../../domain/model/product.dart';
import '../../../domain/model/seller.dart';
import '../../../domain/usecase/add_to_cart_usecase.dart';
import '../../../navigation/route_paths.dart';
import '../../common/widgets/buttons/secondary_button.dart';
import '../../common/widgets/cards/premium_seller_card.dart';
import '../../common/widgets/cards/product_card.dart';
import '../../common/widgets/feedback/app_toast.dart';
import '../../common/widgets/loaders/product_card_skeleton.dart';
import '../../common/widgets/misc/sound_refresh_indicator.dart';
import '../../common/widgets/misc/staggered_entrance.dart';
import '../../common/widgets/states/empty_state_widget.dart';
import '../../common/widgets/states/error_state_widget.dart';
import '../cart/widgets/cart_summary_bar.dart';
import '../product/product_listing/product_listing_args.dart';
import 'wishlist_provider.dart';

/// Saved products and saved stores — two views of one server-side list.
///
/// Both tabs read the single wishlist snapshot the app already holds, so
/// opening this screen costs no extra request.
class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    // Pull a fresh list on open. Hearts tapped elsewhere only added an id to
    // the cached snapshot — the product behind it arrives here, which is the
    // one place those objects are actually rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(authProvider).isSignedIn) return;
      ref.read(wishlistProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authProvider).isSignedIn;

    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wishlist')),
        bottomNavigationBar: const CartSummaryBar(),
        body: SafeArea(
          child: EmptyStateWidget(
            icon: Icons.favorite_border_rounded,
            title: 'Sign in to see your wishlist',
            message: 'Saved items follow you across every device.',
            actionLabel: 'Sign in',
            onAction: () => context.push(RoutePaths.login),
          ),
        ),
      );
    }

    final wishlist = ref.watch(wishlistProvider);
    final products = ref.watch(wishlistProductsProvider);
    final stores = ref.watch(wishlistStoresProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Wishlist'),
          bottom: TabBar(
            tabs: [
              // Counts come from the rendered lists, never the id sets — those
              // also hold products that quietly stopped being sold.
              Tab(text: 'Products (${products.length})'),
              Tab(text: 'Stores (${stores.length})'),
            ],
          ),
        ),
        bottomNavigationBar: const CartSummaryBar(),
        body: SafeArea(
          child: wishlist.when(
            loading: () =>
                ProductGridSkeleton(columns: context.productGridColumns),
            error: (error, _) => ErrorStateWidget(
              failure: ErrorMapper.toFailure(error),
              onRetry: () => ref.read(wishlistProvider.notifier).refresh(),
            ),
            data: (_) => TabBarView(
              children: [
                _ProductsTab(products: products),
                _StoresTab(stores: stores),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductsTab extends ConsumerWidget {
  const _ProductsTab({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.favorite_border_rounded,
        title: 'Nothing saved yet',
        message: 'Tap the heart on any product to keep it here for later.',
        actionLabel: 'Start shopping',
        onAction: () => context.go(RoutePaths.home),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: SecondaryButton(
            label: 'Add all in-stock items to cart',
            icon: Icons.add_shopping_cart_rounded,
            expand: true,
            onPressed: () => _addAll(context, ref, products),
          ),
        ),
        Expanded(
          child: SoundRefreshIndicator(
            onRefresh: () => ref.read(wishlistProvider.notifier).refresh(),
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: context.productGridColumns,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.52,
              ),
              itemBuilder: (context, index) {
                final product = products[index];
                return StaggeredEntrance(
                  index: index,
                  child: ProductCard(
                    product: product,
                    width: double.infinity,
                    heroTag: 'wishlist',
                    onTap: () => context.push(
                      RoutePaths.productDetailsOf(product.id),
                      extra: product,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addAll(
    BuildContext context,
    WidgetRef ref,
    List<Product> items,
  ) async {
    final available = items.where((p) => p.isPurchasable).toList();
    if (available.isEmpty) {
      AppToast.error(context, 'None of your saved items are in stock');
      return;
    }

    var added = 0;
    var skipped = 0;

    for (final product in available) {
      // Variant products need an explicit pack choice, so they are left alone.
      if (product.hasVariants) {
        skipped++;
        continue;
      }

      final outcome = await ref.read(cartProvider.notifier).add(
            product,
            skipVariantPrompt: true,
          );
      if (!context.mounted) return;

      if (outcome is CartUpdated) {
        added++;
      } else {
        // A different seller or a stock cap — reported, never silently dropped.
        skipped++;
      }
    }

    AppToast.success(
      context,
      skipped == 0
          ? '$added items added to your cart'
          : '$added added · $skipped need a choice or are unavailable',
    );
  }
}

class _StoresTab extends ConsumerWidget {
  const _StoresTab({required this.stores});

  final List<Seller> stores;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stores.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.storefront_outlined,
        title: 'No saved stores',
        message: 'Save a store to jump straight back to what it sells.',
        actionLabel: 'Browse stores',
        onAction: () => context.go(RoutePaths.home),
      );
    }

    return SoundRefreshIndicator(
      onRefresh: () => ref.read(wishlistProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: stores.length,
        itemBuilder: (context, index) {
          final store = stores[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: PremiumSellerCard(
              seller: store,
              index: index,
              // Always filled here — every card on this tab is saved by
              // definition, and tapping the heart removes it.
              isFavorite: true,
              onFavoriteTap: (_) => _unsave(context, ref, store),
              onTap: () => context.push(
                RoutePaths.productListing,
                extra: ProductListingArgs(
                  title: store.name,
                  sellerId: store.id,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _unsave(
    BuildContext context,
    WidgetRef ref,
    Seller store,
  ) async {
    try {
      await ref.read(wishlistProvider.notifier).toggleStore(store.id);
      if (context.mounted) {
        AppToast.show(context, 'Removed ${store.name}');
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.error(context, 'Could not update your saved stores');
      }
    }
  }
}
