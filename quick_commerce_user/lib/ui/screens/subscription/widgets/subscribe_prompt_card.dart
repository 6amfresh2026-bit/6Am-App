import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../di/app_providers.dart';
import '../../../../domain/model/product.dart';
import '../../../../domain/model/product_variant.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/feedback/app_dialog.dart';
import 'subscribe_sheet.dart';

/// Offers recurring delivery on the product page.
///
/// Hidden unless the seller has actually enabled subscriptions for this item.
/// `subscriptionEnabled` only arrives on the restaurant menu endpoint, so a
/// product resolved from `/search/products` reports false and the card stays
/// hidden — which is the safe direction: the create call rejects such items
/// with "This product is not available for subscription", and offering a
/// button that always fails is worse than not offering it.
class SubscribePromptCard extends ConsumerWidget {
  const SubscribePromptCard({
    super.key,
    required this.product,
    this.variant,
  });

  final Product product;
  final ProductVariant? variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!product.subscriptionEnabled ||
        product.sellerId.isEmpty ||
        !product.isAvailable) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Material(
        color: context.colors.primary.withValues(alpha: 0.07),
        borderRadius: AppRadii.rLg,
        child: InkWell(
          borderRadius: AppRadii.rLg,
          onTap: () => _open(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(
                  Icons.event_repeat_rounded,
                  color: context.colors.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Get this delivered regularly',
                        style: context.text.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Daily, weekly or monthly — at a time you pick. '
                        'Skip or pause any time.',
                        style: context.text.bodySmall?.copyWith(
                          color: context.semantic.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    // A subscription is delivered to a saved address by id, so one has to
    // exist before the sheet can collect anything useful.
    if (ref.read(selectedAddressProvider) == null) {
      final goPick = await AppDialog.confirm(
        context,
        title: 'Add a delivery address',
        message:
            'Subscriptions are delivered to one of your saved addresses. Add '
            'one to continue.',
        confirmLabel: 'Add address',
        icon: Icons.location_on_outlined,
      );
      if (!goPick || !context.mounted) return;
      await context.push(RoutePaths.addresses);
      if (!context.mounted || ref.read(selectedAddressProvider) == null) return;
    }

    await SubscribeSheet.show(context, product: product, variant: variant);
  }
}
