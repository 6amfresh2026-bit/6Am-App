import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../loaders/shimmer_box.dart';

/// Cached, correctly-downscaled network image with a shimmer placeholder and a
/// non-broken fallback.
///
/// Decoding is capped at 2× the rendered size so a 2000px catalog photo never
/// lands in a 116px thumbnail.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.shopping_basket_outlined,
    this.desaturated = false,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;

  /// Out-of-stock products render greyed out.
  final bool desaturated;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return _fallback(context);

    final ratio = MediaQuery.devicePixelRatioOf(context);
    final image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      // `double.infinity` is a legitimate width here (a card image that fills
      // its column), but it cannot be turned into a decode budget — so cap on
      // whichever dimension is actually finite.
      memCacheWidth: _cachePixels(width, ratio),
      memCacheHeight: _cachePixels(height, ratio),
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => ShimmerBox(width: width, height: height ?? 100),
      errorWidget: (_, _, _) => _fallback(context),
    );

    if (!desaturated) return image;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0, //
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: image,
    );
  }

  /// Decode budget in device pixels, or null when the dimension is unbounded.
  static int? _cachePixels(double? logical, double ratio) {
    if (logical == null || !logical.isFinite || logical <= 0) return null;
    return (logical * ratio).round();
  }

  Widget _fallback(BuildContext context) => Container(
        width: width,
        height: height,
        color: context.semantic.surfaceAlt,
        alignment: Alignment.center,
        child: Icon(
          fallbackIcon,
          size: ((height ?? 48) * 0.34).clamp(16, 40),
          color: context.semantic.textSecondary,
        ),
      );
}
