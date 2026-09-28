import 'package:flutter/material.dart';

import '../../../../core/theme/app_radii.dart';
import '../misc/app_network_image.dart';

/// Key attached to the cart icon so the fly animation knows where to land.
final GlobalKey cartAnchorKey = GlobalKey(debugLabel: 'cart-anchor');

/// Animates a ghost of the product image from the tapped card to the cart icon.
///
/// Implemented as a real [OverlayEntry] so it flies over app bars, sheets and
/// the bottom navigation bar.
abstract final class FlyToCart {
  static void run(
    BuildContext context, {
    required GlobalKey sourceKey,
    required String imageUrl,
  }) {
    final overlay = Overlay.maybeOf(context);
    final sourceBox = sourceKey.currentContext?.findRenderObject();
    final targetBox = cartAnchorKey.currentContext?.findRenderObject();
    if (overlay == null || sourceBox is! RenderBox || targetBox is! RenderBox) {
      return;
    }

    final start = sourceBox.localToGlobal(Offset.zero);
    final end = targetBox.localToGlobal(Offset.zero);
    final size = sourceBox.size;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FlyingGhost(
        imageUrl: imageUrl,
        start: start,
        startSize: size,
        end: end + Offset(targetBox.size.width / 2, targetBox.size.height / 2),
        onDone: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _FlyingGhost extends StatefulWidget {
  const _FlyingGhost({
    required this.imageUrl,
    required this.start,
    required this.startSize,
    required this.end,
    required this.onDone,
  });

  final String imageUrl;
  final Offset start;
  final Size startSize;
  final Offset end;
  final VoidCallback onDone;

  @override
  State<_FlyingGhost> createState() => _FlyingGhostState();
}

class _FlyingGhostState extends State<_FlyingGhost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOutCubic.transform(_controller.value);
        final scale = 1 - 0.72 * t;

        // A quadratic Bézier with a lifted control point gives the arc an
        // object thrown toward the cart would follow.
        final control = Offset(
          (widget.start.dx + widget.end.dx) / 2,
          widget.start.dy - 90,
        );
        final position = _quadratic(widget.start, control, widget.end, t);

        return Positioned(
          left: position.dx,
          top: position.dy,
          child: Opacity(
            opacity: (1 - t * 0.85).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: child,
            ),
          ),
        );
      },
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: AppRadii.rMd,
          child: AppNetworkImage(
            url: widget.imageUrl,
            width: widget.startSize.width,
            height: widget.startSize.height,
          ),
        ),
      ),
    );
  }

  static Offset _quadratic(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
    );
  }
}
