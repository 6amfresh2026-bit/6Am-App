import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/extensions/num_extensions.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../di/app_providers.dart';
import '../../../../di/service_providers.dart';
import '../../../../domain/model/product.dart';
import '../../cart_actions.dart';
import '../badges/delivery_time_badge.dart';
import '../badges/discount_badge.dart';
import '../buttons/animated_add_button.dart';
import '../misc/app_network_image.dart';
import '../misc/rating_stars.dart';

/// The product card used on home, listing, search, wishlist and cross-sell.
///
/// Watches only the slice of cart state it needs (this product's quantity) so
/// adding one item does not rebuild every other card on screen.
class ProductCard extends ConsumerStatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.width = AppDimens.productCardWidth,
    this.rank,
    this.heroTag,
    this.showWishlist = true,
  });

  final Product product;
  final VoidCallback onTap;
  final double width;

  /// Best-seller rank badge (#1, #2 …).
  final int? rank;

  /// Namespaces the Hero so the same product in two rows does not collide.
  final String? heroTag;
  final bool showWishlist;

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  final _imageKey = GlobalKey();
  bool _pressed = false;

  Product get _product => widget.product;

  @override
  Widget build(BuildContext context) {
    final quantity = ref.watch(
      cartProvider.select((s) => s.cart.quantityOf(_product.id)),
    );
    final isWishlisted = ref.watch(isWishlistedProvider(_product.id));
    final stockLabel = ref.watch(stockServiceProvider).stockLabel(_product);
    final outOfStock = _product.stockStatus == StockStatus.outOfStock;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        // Opening a product is a selection. The add pill and wishlist heart sit
        // in nested gesture detectors with their own cues, so this only fires
        // on a body tap.
        AppHaptics.selection();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: AppDurations.instant,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: widget.width,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: AppRadii.rLg,
            border: Border.all(color: context.semantic.border),
            boxShadow: _pressed ? null : context.semantic.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The image absorbs whatever height the cell has left over. With
              // a fixed image height instead, any card that also had to fit a
              // strike-through price or a stock label overflowed its grid cell
              // by a few pixels — and each grid uses a different aspect ratio,
              // so tuning them one by one never held.
              Expanded(
                child: _image(
                  context,
                  isWishlisted: isWishlisted,
                  outOfStock: outOfStock,
                ),
              ),
              const SizedBox(height: 4),
              _meta(context),
              const SizedBox(height: 2),
              Text(
                _product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                _product.hasVariants
                    ? '${_product.variants.length} options'
                    : _product.unitLabel,
                style: context.text.bodySmall,
              ),
              if (stockLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  stockLabel,
                  style: context.text.labelMedium!.copyWith(
                    color: outOfStock
                        ? context.semantic.textSecondary
                        : context.semantic.warning,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              _priceRow(context, quantity: quantity, outOfStock: outOfStock),
            ],
          ),
        ),
      ),
    );
  }

  Widget _image(
    BuildContext context, {
    required bool isWishlisted,
    required bool outOfStock,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: AppRadii.rMd,
          child: Hero(
            tag: '${widget.heroTag ?? 'product'}-${_product.id}',
            child: AppNetworkImage(
              key: _imageKey,
              url: _product.imageUrl,
              height: double.infinity,
              width: double.infinity,
              desaturated: outOfStock,
            ),
          ),
        ),
        if (_product.discountPercent > 0)
          Positioned(
            left: 0,
            top: 0,
            child: DiscountBadge(percent: _product.discountPercent, compact: true),
          ),
        if (widget.rank != null)
          Positioned(
            left: AppSpacing.xs,
            bottom: AppSpacing.xs,
            child: _RankBadge(rank: widget.rank!),
          ),
        if (widget.showWishlist)
          Positioned(
            right: -4,
            top: -4,
            child: _WishlistHeart(
              isWishlisted: isWishlisted,
              onTap: () => CartActions.toggleWishlist(context, ref, _product),
            ),
          ),
        if (outOfStock)
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surface.withValues(alpha: 0.92),
                  borderRadius: AppRadii.rSm,
                ),
                child: Text(
                  'Out of stock',
                  style: context.text.badgeLabel
                      .copyWith(color: context.semantic.textSecondary),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _meta(BuildContext context) {
    final minutes = _product.deliveryMinutes;
    return Row(
      children: [
        VegIndicator(isVeg: _product.isVeg, size: 11),
        const SizedBox(width: AppSpacing.xs),
        if (minutes != null && minutes > 0)
          Flexible(child: DeliveryTimeBadge(minutes: minutes))
        else if (_product.rating > 0)
          Flexible(
            child: RatingStars(
              rating: _product.rating,
              count: _product.ratingCount,
              size: 11,
            ),
          ),
      ],
    );
  }

  Widget _priceRow(
    BuildContext context, {
    required int quantity,
    required bool outOfStock,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_product.strikePrice != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _product.strikePrice!.asCurrency,
                    maxLines: 1,
                    softWrap: false,
                    style: context.text.mrp,
                  ),
                ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _product.price.asCurrency,
                  maxLines: 1,
                  softWrap: false,
                  style: context.text.price,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        AnimatedAddButton(
          quantity: quantity,
          enabled: !outOfStock && _product.sellerAcceptingOrders,
          hasVariants: _product.hasVariants,
          canIncrement: quantity < _product.maxOrderableQty,
          onAdd: () => CartActions.add(
            context,
            ref,
            product: _product,
            sourceKey: _imageKey,
          ),
          onIncrement: () => CartActions.increment(ref, _product),
          onDecrement: () => CartActions.decrement(ref, _product),
        ),
      ],
    );
  }
}

/// Heart with a "pop" on toggle.
class _WishlistHeart extends StatelessWidget {
  const _WishlistHeart({required this.isWishlisted, required this.onTap});

  final bool isWishlisted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: TweenAnimationBuilder<double>(
          key: ValueKey(isWishlisted),
          tween: Tween(begin: isWishlisted ? 0.55 : 1, end: 1),
          duration: AppDurations.medium,
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.colors.surface.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 15,
              color: isWishlisted
                  ? context.semantic.danger
                  : context.semantic.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.onSurface.withValues(alpha: 0.82),
        borderRadius: AppRadii.rSm,
      ),
      child: Text(
        '#$rank',
        style: context.text.badgeLabel.copyWith(color: context.colors.surface),
      ),
    );
  }
}
