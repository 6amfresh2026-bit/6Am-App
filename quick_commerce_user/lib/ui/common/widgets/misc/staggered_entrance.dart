import 'package:flutter/material.dart';

import '../../../../core/constants/app_durations.dart';

/// Fade + slide entrance for list/grid children.
///
/// Runs once per widget lifetime, so scrolling a long list does not re-animate
/// items every time they are recycled into view.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.horizontal = false,
    this.maxStaggered = 12,
  });

  final int index;
  final Widget child;

  /// Slides in from the right instead of from below.
  final bool horizontal;

  /// Items past this index appear immediately — a 40th row does not need a
  /// 1.6-second delay before it is legible.
  final int maxStaggered;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.medium,
  );

  @override
  void initState() {
    super.initState();
    if (widget.index >= widget.maxStaggered) {
      _controller.value = 1;
      return;
    }
    Future.delayed(AppDurations.staggerStep * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: widget.horizontal ? const Offset(0.14, 0) : const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}
