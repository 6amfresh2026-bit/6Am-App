import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../../../../domain/model/banner.dart';
import '../../../common/widgets/loaders/shimmer_box.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import 'delivery_header.dart';

/// Default landing page banners matching exact user reference design
final List<PromoBanner> _defaultLandingBanners = [
  const PromoBanner(
    id: 'landing_1',
    title: 'Fresh Farm Harvest',
    imageUrl: 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?auto=format&fit=crop&w=1000&q=80',
    ctaText: 'Shop Now',
    ctaLink: 'category/fresh-produce',
  ),
  const PromoBanner(
    id: 'landing_2',
    title: 'Newly Arrived Fresh',
    imageUrl: 'https://images.unsplash.com/photo-1595123550441-d377e017de6a?auto=format&fit=crop&w=1000&q=80',
    ctaText: 'Explore New',
    ctaLink: 'category/fruits',
  ),
];

/// Header component where backend/landing-page banners occupy the background
/// with location bar, search bar, and landing promo cards layered seamlessly.
class FullBackgroundVideoHeader extends StatefulWidget {
  const FullBackgroundVideoHeader({
    super.key,
    required this.banners,
    this.isLoading = false,
    this.onBannerTap,
    this.searchBar,
    this.deliveryBadge,
  });

  final List<PromoBanner> banners;
  final bool isLoading;
  final ValueChanged<PromoBanner>? onBannerTap;
  final Widget? searchBar;
  final Widget? deliveryBadge;

  @override
  State<FullBackgroundVideoHeader> createState() =>
      _FullBackgroundVideoHeaderState();
}

class _FullBackgroundVideoHeaderState
    extends State<FullBackgroundVideoHeader> {
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  int _currentIndex = 0;

  List<PromoBanner> get _effectiveBanners =>
      widget.banners.isNotEmpty ? widget.banners : _defaultLandingBanners;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(FullBackgroundVideoHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _startAutoScroll();
    }
  }

  /// Each slide gets a fixed 10 seconds before advancing — including a video
  /// one, which loops forever on its own (`setLooping(true)`) and so never
  /// produces a natural "finished" moment to advance on instead.
  static const _slideDuration = Duration(seconds: 10);

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (_effectiveBanners.length < 2) return;
    _autoScrollTimer = Timer.periodic(_slideDuration, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextIndex = (_currentIndex + 1) % _effectiveBanners.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannersToDisplay = _effectiveBanners;

    return Container(
      height: 345.0,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // ── Layer 1: Full-Bleed Video / Image Background ──────────────────
          Positioned.fill(
            child: widget.isLoading
                ? const ShimmerBox(
                    height: double.infinity,
                    radius: BorderRadius.zero,
                  )
                : PageView.builder(
                    controller: _pageController,
                    itemCount: bannersToDisplay.length,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final banner = bannersToDisplay[index];
                      return GestureDetector(
                        onTap: () => widget.onBannerTap?.call(banner),
                        child: banner.isVideo
                            ? _FullBackgroundVideoPlayer(banner: banner)
                            : _FullBackgroundImage(
                                banner: banner,
                                isFirstCard: index == 0,
                              ),
                      );
                    },
                  ),
          ),

          // ── Layer 3: Overlaid Header UI Elements ──────────────────────────
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 1. Top Location, Address & Actions Bar
                  const DeliveryHeader(),

                  const Spacer(),

                  // 3. Search Bar + 10 Min Delivery Badge Row
                  if (widget.searchBar != null && widget.deliveryBadge != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                      child: Row(
                        children: [
                          Expanded(child: widget.searchBar!),
                          const SizedBox(width: 8),
                          widget.deliveryBadge!,
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-bleed Video Player Widget.
class _FullBackgroundVideoPlayer extends StatefulWidget {
  const _FullBackgroundVideoPlayer({required this.banner});

  final PromoBanner banner;

  @override
  State<_FullBackgroundVideoPlayer> createState() =>
      __FullBackgroundVideoPlayerState();
}

class __FullBackgroundVideoPlayerState
    extends State<_FullBackgroundVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(_FullBackgroundVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banner.mediaUrl != widget.banner.mediaUrl) {
      _controller?.dispose();
      _isInitialized = false;
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final url = widget.banner.mediaUrl;
    if (url.isEmpty) return;

    try {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        _controller = VideoPlayerController.asset(url);
      }

      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(0);
      await _controller!.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Header video player initialization error for $url: $e');
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

    if (widget.banner.imageUrl.isNotEmpty) {
      return AppNetworkImage(
        url: widget.banner.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Container(
      color: const Color(0xFF0E6844),
    );
  }
}

/// Full-bleed Image Banner Widget with rich landing card text & button overlays.
class _FullBackgroundImage extends StatelessWidget {
  const _FullBackgroundImage({
    required this.banner,
    this.isFirstCard = true,
  });

  final PromoBanner banner;
  final bool isFirstCard;

  @override
  Widget build(BuildContext context) {
    final title = banner.title.isNotEmpty
        ? banner.title
        : (isFirstCard ? 'Fresh Farm Harvest' : 'Newly Arrived Fresh');
    final subtitle = isFirstCard ? 'Strawberries & Kale' : 'Peaches';
    final offer = isFirstCard ? 'Up to 30% Off' : '\$5.99/lb';
    final note = isFirstCard ? 'Bold Weight, 20px' : 'Fresh Pick';
    final buttonText = banner.ctaText.isNotEmpty
        ? banner.ctaText
        : (isFirstCard ? 'Shop Now' : 'Explore New');

    return Stack(
      fit: StackFit.expand,
      children: [
        AppNetworkImage(
          url: banner.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
        // Overlay promo card text matching reference design
        Positioned(
          left: 20,
          bottom: 40,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                  shadows: const [
                    Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    offer,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isFirstCard ? const Color(0xFFFFD54F) : const Color(0xFFA3E635),
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      note,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Pill Action Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8.5),
                decoration: BoxDecoration(
                  color: isFirstCard ? Colors.white : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      buttonText,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

