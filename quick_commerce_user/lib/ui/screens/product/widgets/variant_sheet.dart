import 'package:flutter/material.dart';

import '../../../../core/extensions/num_extensions.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/product.dart';
import '../../../../domain/model/product_variant.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/feedback/app_bottom_sheet.dart';
import '../../../common/widgets/misc/app_network_image.dart';

/// Single-select variant chooser. Opened instead of adding directly whenever a
/// product has more than one pack size.
class VariantSheet extends StatefulWidget {
  const VariantSheet({super.key, required this.product, this.initial});

  final Product product;
  final ProductVariant? initial;

  static Future<ProductVariant?> show(
    BuildContext context, {
    required Product product,
    ProductVariant? initial,
  }) =>
      AppBottomSheet.show<ProductVariant>(
        context,
        title: product.name,
        subtitle: 'Choose a pack size',
        child: VariantSheet(product: product, initial: initial),
      );

  @override
  State<VariantSheet> createState() => _VariantSheetState();
}

class _VariantSheetState extends State<VariantSheet> {
  late ProductVariant _selected =
      widget.initial ?? widget.product.variants.first;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            itemCount: widget.product.variants.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final variant = widget.product.variants[index];
              return _VariantTile(
                product: widget.product,
                variant: variant,
                selected: variant.id == _selected.id,
                onTap: () => setState(() => _selected = variant),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: PrimaryButton(
            label: 'Add ${_selected.name} · ${_selected.price.asCurrency}',
            icon: Icons.add_shopping_cart_rounded,
            onPressed: () => Navigator.of(context).pop(_selected),
          ),
        ),
      ],
    );
  }
}

class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.product,
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  final Product product;
  final ProductVariant variant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.primary.withValues(alpha: 0.07)
              : context.colors.surface,
          borderRadius: AppRadii.rMd,
          border: Border.all(
            color: selected ? context.colors.primary : context.semantic.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadii.rSm,
              child: AppNetworkImage(
                url: product.imageUrl,
                width: 48,
                height: 48,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(variant.name, style: context.text.titleMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      Text(variant.price.asCurrency, style: context.text.price),
                      if (variant.isDiscounted) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          variant.comparePrice!.asCurrency,
                          style: context.text.mrp,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${variant.discountPercent}% off',
                          style: context.text.labelMedium!
                              .copyWith(color: context.semantic.success),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? context.colors.primary : context.semantic.border,
            ),
          ],
        ),
      ),
    );
  }
}
