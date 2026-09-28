import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/constants/app_durations.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../common/widgets/misc/app_network_image.dart';

/// Swipeable gallery. Auto-scrolls until the user takes over, then stops —
/// nothing is more irritating than a carousel that fights your thumb.
class ProductImageCarousel extends StatefulWidget {
  const ProductImageCarousel({
    super.key,
    required this.images,
    required this.heroTag,
    this.height = 320,
    this.desaturated = false,
  });

  final List<String> images;
  final String heroTag;
  final double height;
  final bool desaturated;

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;
  bool _userInteracted = false;

  @override
  void initState() {
    super.initState();
    if (widget.images.length > 1) {
      _timer = Timer.periodic(AppDurations.bannerAutoScroll, (_) {
        if (!mounted || _userInteracted || !_controller.hasClients) return;
        _controller.animateToPage(
          (_index + 1) % widget.images.length,
          duration: AppDurations.slow,
          curve: Curves.easeInOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: Listener(
            onPointerDown: (_) => _userInteracted = true,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, index) {
                final image = AppNetworkImage(
                  url: widget.images[index],
                  height: widget.height,
                  fit: BoxFit.contain,
                  desaturated: widget.desaturated,
                );
                // Only the first frame participates in the Hero flight.
                return index == 0
                    ? Hero(tag: widget.heroTag, child: image)
                    : image;
              },
            ),
          ),
        ),
        if (widget.images.length > 1) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.images.length,
              (i) => AnimatedContainer(
                duration: AppDurations.medium,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                height: 5,
                width: i == _index ? 18 : 5,
                decoration: BoxDecoration(
                  color: i == _index
                      ? context.colors.primary
                      : context.semantic.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
