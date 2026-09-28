import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../di/repository_providers.dart';
import '../../../domain/model/brand.dart';
import '../../../navigation/route_paths.dart';
import '../../common/widgets/cards/brand_card.dart';
import '../../common/widgets/loaders/list_skeleton.dart';
import '../../common/widgets/misc/staggered_entrance.dart';
import '../../common/widgets/states/empty_state_widget.dart';
import '../../common/widgets/states/error_state_widget.dart';
import '../cart/widgets/cart_summary_bar.dart';
import '../product/product_listing/product_listing_args.dart';

/// Brands present in the catalog. Derived from item `brand` values — the
/// backend has no brand resource (README → Backend Gaps).
final brandsProvider = FutureProvider<List<Brand>>(
  (ref) => ref.watch(productRepositoryProvider).brands(),
);

class BrandListingScreen extends ConsumerWidget {
  const BrandListingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brands = ref.watch(brandsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Brands')),
      bottomNavigationBar: const CartSummaryBar(),
      body: SafeArea(
        child: brands.when(
          loading: () => const CategoryGridSkeleton(count: 9, columns: 3),
          error: (error, _) => ErrorStateWidget(
            failure: ErrorMapper.toFailure(error),
            onRetry: () => ref.invalidate(brandsProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.storefront_outlined,
                title: 'No brands to show',
                message:
                    'Brands appear here once sellers tag their products with one.',
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.86,
              ),
              itemBuilder: (context, index) => StaggeredEntrance(
                index: index,
                child: BrandCard(
                  brand: items[index],
                  width: double.infinity,
                  onTap: () => context.push(
                    RoutePaths.productListing,
                    extra: ProductListingArgs.forBrand(items[index]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
