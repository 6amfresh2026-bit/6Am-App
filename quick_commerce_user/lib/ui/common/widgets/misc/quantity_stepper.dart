import 'package:flutter/material.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_theme.dart';

/// − qty + control. The quantity itself animates so a change is felt, not just
/// seen.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.height = 36,
    this.compact = false,
    this.canIncrement = true,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final double height;
  final bool compact;
  final bool canIncrement;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;

    return Container(
      height: height,
      decoration: BoxDecoration(color: primary, borderRadius: AppRadii.rSm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            // Every quantity change routes through this shared control, so one
            // light cue here covers cards, the cart and the product page —
            // without ever double-firing.
            onTap: () {
              AppHaptics.light();
              onDecrement();
            },
            compact: compact,
            semanticLabel: 'Decrease quantity',
          ),
          AnimatedSwitcher(
            duration: AppDurations.fast,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Text(
              '$quantity',
              key: ValueKey(quantity),
              style: context.text.labelLarge!.copyWith(color: Colors.white),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onTap: canIncrement
                ? () {
                    AppHaptics.light();
                    onIncrement();
                  }
                : null,
            compact: compact,
            semanticLabel: 'Increase quantity',
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.compact,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool compact;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rSm,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 11),
          child: Icon(
            icon,
            size: compact ? 15 : 17,
            color: Colors.white.withValues(alpha: onTap == null ? 0.4 : 1),
          ),
        ),
      ),
    );
  }
}
