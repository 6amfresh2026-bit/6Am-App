import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../domain/model/banner.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import '../../../common/widgets/loaders/shimmer_box.dart';
import '../../../../core/theme/app_theme.dart';

/// Auto-scrolling promo carousel with width-animating pagination dots.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({
    super.key,
    required this.banners,
    required this.onTap,
    this.isLoading = false,
    this.height = AppDimens.bannerHeight,
  });

  final List<PromoBanner> banners;
  final ValueChanged<PromoBanner> onTap;
  final bool isLoading;
  final double height;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _controller = PageController(viewportFraction: 0.98);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (widget.banners.length < 2) return;
    _timer = Timer.periodic(AppDurations.bannerAutoScroll, (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_index + 1) % widget.banners.length,
        duration: AppDurations.slow,
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: ShimmerBox(height: 170, radius: AppRadii.rLg),
      );
    }

    // No banners published means no carousel. Inventing a "Daily Essentials
    // Delivered in 10 Minutes" card here filled the space with a promotion no
    // merchant had made, and it tapped through to nowhere.
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    final bannersToDisplay = widget.banners;

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: RepaintBoundary(
            child: PageView.builder(
              controller: _controller,
              itemCount: bannersToDisplay.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, index) {
                final banner = bannersToDisplay[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GestureDetector(
                    onTap: () => widget.onTap(banner),
                    child: _HeroBannerCard(banner: banner),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Pagination Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            bannersToDisplay.length,
            (i) => AnimatedContainer(
              duration: AppDurations.fast,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: i == _index ? 18 : 6,
              decoration: BoxDecoration(
                color: i == _index ? const Color(0xFF43B5A8) : const Color(0xFFE5E7EB),
                // color: i == _index ? const Color(0xFFFFC107) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroBannerCard extends StatelessWidget {
  const _HeroBannerCard({required this.banner});

  final PromoBanner banner;

  @override
  Widget build(BuildContext context) {
    final hasCustomImage = banner.imageUrl.trim().isNotEmpty;

    // Show full backend banner image edge-to-edge without extra overlays.
    if (hasCustomImage) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AppNetworkImage(
            url: banner.imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      );
    }

    // No image on the banner: render the banner's own copy on the brand
    // gradient. This branch used to draw a fixed "Daily Essentials Delivered in
    // 10 Minutes" card that ignored `banner` completely, so whatever the admin
    // actually published was replaced by that slogan.
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7CB), Color(0xFFFFD54F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (banner.title.trim().isNotEmpty)
              Text(
                banner.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleLarge!.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  height: 1.15,
                  color: const Color(0xFF1F2937),
                ),
              ),
            if (banner.ctaText.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      banner.ctaText,
                      style: context.text.labelSmall!.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
