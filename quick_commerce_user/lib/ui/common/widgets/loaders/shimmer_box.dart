import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_theme.dart';

/// The single shimmer primitive. Every skeleton in the app is built from it,
/// so the sweep timing and colours stay identical everywhere.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = AppRadii.rSm,
    this.shape,
  });

  const ShimmerBox.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = AppRadii.rPill,
        shape = BoxShape.circle;

  final double? width;
  final double height;
  final BorderRadius radius;
  final BoxShape? shape;

  @override
  Widget build(BuildContext context) {
    final base = context.semantic.surfaceAlt;
    final highlight = context.isDark
        ? context.semantic.border
        : Colors.white.withValues(alpha: 0.85);

    // Shimmer repaints continuously; isolating it keeps the rest of the tree
    // out of the animation's raster work.
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        period: const Duration(milliseconds: 1300),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: base,
            borderRadius: shape == BoxShape.circle ? null : radius,
            shape: shape ?? BoxShape.rectangle,
          ),
        ),
      ),
    );
  }
}
