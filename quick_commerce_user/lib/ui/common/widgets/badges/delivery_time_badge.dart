import 'package:flutter/material.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';

/// "8 MINS" delivery promise chip.
class DeliveryTimeBadge extends StatelessWidget {
  const DeliveryTimeBadge({super.key, required this.minutes, this.dense = true});

  final int minutes;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 5 : 8,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: context.semantic.surfaceAlt,
        borderRadius: AppRadii.rSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_rounded,
            size: dense ? 11 : 14,
            color: context.semantic.accent,
          ),
          const SizedBox(width: 2),
          Text(
            '$minutes MINS',
            style: context.text.badgeLabel.copyWith(
              color: context.semantic.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small green/red square that marks a veg or non-veg item.
class VegIndicator extends StatelessWidget {
  const VegIndicator({super.key, required this.isVeg, this.size = 12});

  final bool isVeg;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? context.semantic.success : context.semantic.danger;
    return Semantics(
      label: isVeg ? 'Vegetarian' : 'Non-vegetarian',
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.4),
          borderRadius: BorderRadius.circular(2),
        ),
        alignment: Alignment.center,
        child: Container(
          height: size * 0.42,
          width: size * 0.42,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
