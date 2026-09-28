import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// "20% OFF" flag on a product card. Rendered only when there is a discount.
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({super.key, required this.percent, this.compact = false});

  final int percent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (percent <= 0) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: context.semantic.brandSurface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Text(
        '$percent% OFF',
        style: context.text.labelSmall!.copyWith(color: context.semantic.onBrandSurface, fontWeight: FontWeight.w900),
      ),
    );
  }
}
