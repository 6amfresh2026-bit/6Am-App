import 'package:flutter/material.dart';

import '../../../../core/extensions/num_extensions.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/cart_item.dart';
import '../../../common/widgets/badges/delivery_time_badge.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import '../../../common/widgets/misc/quantity_stepper.dart';

/// One cart line, swipeable to remove.
class CartLineTile extends StatelessWidget {
  const CartLineTile({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onTap,
  });

  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.lineId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        // Swiping a line away is a removal → heavy, matching delete elsewhere.
        AppHaptics.heavy();
        onRemove();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: context.semantic.dangerSoft,
          borderRadius: AppRadii.rLg,
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: context.semantic.danger,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AppRadii.rMd,
                child: AppNetworkImage(
                  url: item.product.imageUrl,
                  height: 62,
                  width: 62,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        VegIndicator(isVeg: item.product.isVeg, size: 11),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            item.product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(item.variantLabel, style: context.text.bodySmall),
                    if (item.addons.isNotEmpty)
                      Text(
                        item.addonSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall!
                            .copyWith(color: context.colors.primary),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Text(item.lineTotal.asCurrency, style: context.text.price),
                        if (item.unitStrikePrice != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(item.lineStrikeTotal.asCurrency,
                              style: context.text.mrp),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              QuantityStepper(
                quantity: item.quantity,
                height: 32,
                compact: true,
                canIncrement: item.quantity < item.product.maxOrderableQty,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
