import 'package:flutter/material.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/theme/app_theme.dart';

/// Circular icon button used in app bars, over images and on cards.
class IconButtonCircle extends StatefulWidget {
  const IconButtonCircle({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 40,
    this.iconSize = 20,
    this.background,
    this.foreground,
    this.tooltip,
    this.badgeCount,
    this.elevated = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? background;
  final Color? foreground;
  final String? tooltip;
  final int? badgeCount;
  final bool elevated;

  @override
  State<IconButtonCircle> createState() => _IconButtonCircleState();
}

class _IconButtonCircleState extends State<IconButtonCircle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: AppDurations.instant,
        child: Container(
          height: widget.size,
          width: widget.size,
          decoration: BoxDecoration(
            color: widget.background ?? context.colors.surface,
            shape: BoxShape.circle,
            boxShadow: widget.elevated ? context.semantic.cardShadow : null,
          ),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: widget.foreground ?? context.colors.onSurface,
          ),
        ),
      ),
    );

    final withBadge = widget.badgeCount == null || widget.badgeCount == 0
        ? button
        : Stack(
            clipBehavior: Clip.none,
            children: [
              button,
              Positioned(
                right: -2,
                top: -2,
                child: _CountBadge(count: widget.badgeCount!),
              ),
            ],
          );

    return Semantics(
      button: true,
      label: widget.tooltip,
      child: widget.tooltip == null
          ? withBadge
          : Tooltip(message: widget.tooltip!, child: withBadge),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    // The bump animation is keyed on the value, so the badge pulses whenever
    // the count actually changes.
    return TweenAnimationBuilder<double>(
      key: ValueKey(count),
      tween: Tween(begin: 0.6, end: 1),
      duration: AppDurations.medium,
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        constraints: const BoxConstraints(minWidth: 18),
        decoration: BoxDecoration(
          color: context.semantic.accent,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: context.colors.surface, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: context.text.labelSmall!.copyWith(color: context.colors.onSurface),
        ),
      ),
    );
  }
}
