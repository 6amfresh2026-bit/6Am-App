import 'package:flutter/material.dart';

import '../../../../../core/theme/app_radii.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../domain/model/product.dart';

/// Description / ingredients / nutrition, as an accordion.
///
/// The backend's catalog carries a free-text description only; ingredients and
/// nutrition are not modelled upstream, so those panels present the structured
/// attributes we do have (brand, pack size, category, veg status) rather than
/// inventing values. Noted in README → Backend Gaps.
class ProductInfoTabs extends StatelessWidget {
  const ProductInfoTabs({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: context.theme.copyWith(dividerColor: Colors.transparent),
      child: Column(
        children: [
          if (product.description.trim().isNotEmpty)
            _Panel(
              title: 'Description',
              initiallyExpanded: true,
              child: Text(product.description, style: context.text.bodyLarge),
            ),
          _Panel(
            title: 'Product details',
            child: Column(
              children: [
                _SpecRow(label: 'Brand', value: product.brand),
                _SpecRow(label: 'Pack size', value: product.packSize),
                _SpecRow(label: 'Category', value: product.categoryName),
                _SpecRow(
                  label: 'Food type',
                  value: product.isVeg ? 'Vegetarian' : 'Non-vegetarian',
                ),
                _SpecRow(
                  label: 'Sold by',
                  value: product.sellerName,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: context.semantic.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(title, style: context.text.titleMedium),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: context.text.bodyMedium),
          ),
          Expanded(child: Text(value, style: context.text.bodyLarge)),
        ],
      ),
    );
  }
}
