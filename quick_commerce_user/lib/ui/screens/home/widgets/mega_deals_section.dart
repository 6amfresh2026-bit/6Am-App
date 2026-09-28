import 'package:flutter/material.dart';

import '../../../../core/extensions/num_extensions.dart';
import '../../../../domain/model/product.dart';
import '../../../common/widgets/loaders/shimmer_box.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import '../../../../core/theme/app_theme.dart';

/// The deepest-discount products from the live catalog, in the promo card.
class MegaDealsSection extends StatelessWidget {
  const MegaDealsSection({
    super.key,
    this.deals = const [],
    this.isLoading = false,
    this.onShopNowTap,
    this.onItemTap,
  });

  final List<Product> deals;
  final bool isLoading;
  final VoidCallback? onShopNowTap;
  final ValueChanged<Product>? onItemTap;

  @override
  Widget build(BuildContext context) {
    if (!isLoading && deals.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.semantic.brandSurfaceSoft, context.semantic.brandSurfaceSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.semantic.brandSurfaceSoft, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left promo callout.
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MEGA DEALS',
                  style: context.text.titleMedium!.copyWith(fontWeight: FontWeight.w900, color: context.colors.onSurface),
                ),
                const SizedBox(height: 3),
                Text(
                  'Big savings on\ndaily essentials',
                  style: context.text.bodySmall!.copyWith(fontWeight: FontWeight.w800, color: context.colors.onSurface),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: context.semantic.brandSurface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.card_giftcard_rounded,
                          size: 30, color: context.colors.onSurface),
                      Positioned(
                        right: 3,
                        top: 3,
                        child: CircleAvatar(
                          radius: 8,
                          backgroundColor: context.colors.onSurface,
                          child: Text(
                            '%',
                            style: context.text.labelSmall!.copyWith(color: context.colors.surface, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onShopNowTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7.5),
                    decoration: BoxDecoration(
                      color: context.colors.onSurface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Shop Now',
                          style: context.text.labelSmall!.copyWith(color: context.colors.surface, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 11, color: context.colors.surface),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Right deal-products list.
          Expanded(
            child: SizedBox(
              height: 142,
              child: deals.isEmpty
                  ? ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 3,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, _) =>
                          const ShimmerBox(width: 98, height: 142),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: deals.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) =>
                          _DealCard(product: deals[index], onTap: onItemTap),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.product, this.onTap});

  final Product product;
  final ValueChanged<Product>? onTap;

  @override
  Widget build(BuildContext context) {
    final strike = product.strikePrice;

    return GestureDetector(
      onTap: () => onTap?.call(product),
      child: Container(
        width: 98,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.semantic.surfaceAlt),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.semantic.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AppNetworkImage(
                    url: product.imageUrl,
                    width: double.infinity,
                    fallbackIcon: Icons.shopping_bag_outlined,
                    desaturated: !product.isPurchasable,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall!.copyWith(fontWeight: FontWeight.w800, color: context.colors.onSurface),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  product.price.asCurrency,
                  style: context.text.bodySmall!.copyWith(fontWeight: FontWeight.w900, color: context.colors.onSurface),
                ),
                if (strike != null) ...[
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      strike.asCurrency,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall!.copyWith(decoration: TextDecoration.lineThrough, color: context.semantic.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            if (product.isDiscounted)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: context.semantic.brandSurface,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${product.discountPercent}% OFF',
                  style: context.text.labelSmall!.copyWith(fontWeight: FontWeight.w900, color: context.colors.onSurface),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
