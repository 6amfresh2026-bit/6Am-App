import 'package:flutter/material.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// The main call to action. Handles pressed, disabled and loading states so no
/// screen re-implements them.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.destructive = false,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final bool destructive;

  /// Optional right-aligned content, e.g. the cart total on a checkout bar.
  final Widget? trailing;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    final background = widget.destructive
        ? context.semantic.danger
        : context.colors.primary;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled
            ? () {
                // The main CTA is a committing action → medium, or heavy when
                // it is the destructive variant. Flow outcomes (payment, order)
                // fire their own success/error pulse separately.
                widget.destructive ? AppHaptics.heavy() : AppHaptics.medium();
                widget.onPressed!.call();
              }
            : null,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: AppDurations.instant,
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.45,
            duration: AppDurations.fast,
            child: Container(
              width: widget.expand ? double.infinity : null,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: AppRadii.rMd,
                boxShadow: enabled && !_pressed
                    ? context.semantic.floatingShadow
                    : null,
              ),
              child: _content(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (widget.isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: context.colors.onPrimary,
        ),
      );
    }

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelLarge!.copyWith(color: Colors.white),
          ),
        ),
      ],
    );

    // `heightFactor: 1` makes Center hug the label vertically. Without it, a
    // parent that gives loose bounded constraints — a Scaffold's
    // bottomNavigationBar — lets Center expand to the full screen height.
    if (widget.trailing == null) return Center(heightFactor: 1, child: label);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: widget.trailing!),
        label,
      ],
    );
  }
}
