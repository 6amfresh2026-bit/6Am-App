import 'package:flutter/material.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/utils/app_haptics.dart';
import '../misc/quantity_stepper.dart';
import '../../../../core/theme/app_theme.dart';

/// "ADD" that morphs into a quantity stepper once the item is in the cart.
///
/// The morph is a size+fade transition on a spring curve rather than two
/// swapped widgets, so the control feels like one object changing shape.
class AnimatedAddButton extends StatelessWidget {
  const AnimatedAddButton({
    super.key,
    required this.quantity,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
    this.enabled = true,
    this.hasVariants = false,
    this.canIncrement = true,
    this.height = 32,
    this.width = 78,
    this.compact = true,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool enabled;

  /// Variant products open a sheet instead of adding directly; the button says
  /// so with a small chevron.
  final bool hasVariants;
  final bool canIncrement;
  final double height;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppDurations.medium,
      curve: Curves.easeOutBack,
      alignment: Alignment.centerRight,
      child: AnimatedSwitcher(
        duration: AppDurations.medium,
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: quantity > 0
            ? SizedBox(
                key: const ValueKey('stepper'),
                height: height,
                child: QuantityStepper(
                  quantity: quantity,
                  height: height,
                  compact: compact,
                  canIncrement: canIncrement,
                  onIncrement: onIncrement,
                  onDecrement: onDecrement,
                ),
              )
            : _AddPill(
                key: const ValueKey('add'),
                // Add to cart is a committing action → medium. Placed on the
                // pill (not on `CartActions.add`) so batch adds like "add all
                // in-stock" fire once, not once per item.
                onTap: enabled
                    ? () {
                        AppHaptics.medium();
                        onAdd();
                      }
                    : null,
                hasVariants: hasVariants,
                height: height,
                width: width,
              ),
      ),
    );
  }
}

class _AddPill extends StatefulWidget {
  const _AddPill({
    super.key,
    required this.onTap,
    required this.hasVariants,
    required this.height,
    required this.width,
  });

  final VoidCallback? onTap;
  final bool hasVariants;
  final double height;
  final double width;

  @override
  State<_AddPill> createState() => _AddPillState();
}

class _AddPillState extends State<_AddPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Add to cart',
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1,
          duration: AppDurations.instant,
          child: Container(
            height: widget.height,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: enabled ? const Color(0xFF43B5A8) : context.semantic.border,
              // color: enabled ? const Color(0xFFFFC107) : context.semantic.border,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Add',
                  style: context.text.labelSmall!.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Colors.white,
                    // color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.add_rounded,
                    size: 14,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
