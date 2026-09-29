import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
  final _controller = PageController(viewportFraction: 1.0);
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
    _timer = Timer.periodic(AppDurations.heroBannerAutoScroll, (_) {
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
        padding: EdgeInsets.symmetric(horizontal: 0),
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
                return GestureDetector(
                  onTap: () => widget.onTap(banner),
                  child: _HeroBannerCard(banner: banner),
                );
              },
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
    final isVideo = banner.isVideo;

    if (isVideo) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: _BannerVideoPlayer(url: banner.mediaUrl),
      );
    }

    // Show full backend banner image edge-to-edge without extra overlays.
    if (hasCustomImage) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AppNetworkImage(
            url: banner.imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7CB), Color(0xFFFFD54F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
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

class _BannerVideoPlayer extends StatefulWidget {
  const _BannerVideoPlayer({required this.url});

  final String url;

  @override
  State<_BannerVideoPlayer> createState() => _BannerVideoPlayerState();
}

class _BannerVideoPlayerState extends State<_BannerVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (widget.url.isEmpty) return;
    try {
      if (widget.url.startsWith('http://') || widget.url.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      } else {
        _controller = VideoPlayerController.asset(widget.url);
      }
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(0);
      await _controller!.play();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Video error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialized && _controller != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }
    return Container(color: Colors.black12);
  }
}
