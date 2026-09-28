import 'package:flutter/material.dart';

import '../../../../domain/model/product.dart';
import '../../../common/widgets/cards/product_card.dart';
import '../../../common/widgets/loaders/shimmer_box.dart';
import '../../../common/widgets/misc/section_header.dart';

/// Bestsellers strip. Products are ranked from the live catalog by
/// `CatalogGroupingService`; ids are real, so the tap-through resolves.
class BestsellersRow extends StatelessWidget {
  const BestsellersRow({
    super.key,
    this.products = const [],
    this.isLoading = false,
    this.title = 'Best Selling',
    this.onProductTap,
    this.onSeeAll,
    this.onAddTap,
  });

  final List<Product> products;
  final bool isLoading;
  final String title;
  final ValueChanged<String>? onProductTap;
  final VoidCallback? onSeeAll;
  final ValueChanged<Product>? onAddTap;

  @override
  Widget build(BuildContext context) {
    if (!isLoading && products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, onSeeAll: onSeeAll),
        SizedBox(
          height: 240,
          child: products.isEmpty
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 4,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, _) => const ShimmerBox(width: 135, height: 220),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ProductCard(
                      product: product,
                      width: 135,
                      heroTag: 'bestseller-${product.id}',
                      onTap: () => onProductTap?.call(product.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
