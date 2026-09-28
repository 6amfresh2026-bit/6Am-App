import 'package:flutter/material.dart';

import '../../../../domain/model/product.dart';
import '../../../common/widgets/cards/product_card.dart';
import '../../../common/widgets/misc/staggered_entrance.dart';

/// Horizontal strip of product cards used by every home section.
class ProductRow extends StatelessWidget {
  const ProductRow({
    super.key,
    required this.products,
    required this.onProductTap,
    required this.heroTag,
    this.showRanks = false,
    this.height = 258,
  });

  final List<Product> products;
  final void Function(Product product) onProductTap;

  /// Namespaces Hero tags so the same product in two rows does not collide.
  final String heroTag;
  final bool showRanks;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final product = products[index];
          return StaggeredEntrance(
            index: index,
            horizontal: true,
            child: ProductCard(
              product: product,
              heroTag: heroTag,
              width: 135,
              rank: showRanks ? index + 1 : null,
              onTap: () => onProductTap(product),
            ),
          );
        },
      ),
    );
  }
}
