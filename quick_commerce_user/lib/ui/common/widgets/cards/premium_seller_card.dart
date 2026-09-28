import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../domain/model/product.dart';
import '../../../../domain/model/seller.dart';
import '../misc/app_network_image.dart';

/// Premium Seller Card for Quick Commerce with:
/// 1. Staggered Entrance Animation (Fade + Vertical Slide + Scale)
/// 2. Auto-Sliding Catalog Carousel (2.8s interval, pause on touch, dynamic product badge & indicator dots)
/// 3. Favorite Heart Pulse Animation (300ms scale bump + haptic feedback)
/// 4. Vertical Page-Up Product Highlight Ticker (2.8s vertical slide cycle)
/// 5. Offline / Closed State Desaturation (Grayscale ColorFilter + IgnorePointer + Closed status badge)
/// 6. Complete Data Model & Visual Hierarchy (Verified badge, Rating, Distance, ETA, Locality, Tags, Min Order)
class PremiumSellerCard extends StatefulWidget {
  const PremiumSellerCard({
    super.key,
    required this.seller,
    required this.onTap,
    this.index = 0,
    this.isFavorite = false,
    this.onFavoriteTap,
  });

  final Seller seller;
  final VoidCallback onTap;
  final int index;
  final bool isFavorite;
  final ValueChanged<bool>? onFavoriteTap;

  @override
  State<PremiumSellerCard> createState() => _PremiumSellerCardState();
}

class _PremiumSellerCardState extends State<PremiumSellerCard>
    with TickerProviderStateMixin {
  // 1. Entrance Staggered Animation
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _entranceTimer;

  // 2. Carousel State & Auto-Slide
  late final PageController _pageController;
  Timer? _carouselTimer;
  Timer? _carouselResumeTimer;
  int _currentSlideIndex = 0;
  bool _isUserDragging = false;

  // 3. Heart Pulse Animation
  late final AnimationController _heartPulseController;
  late final Animation<double> _heartScaleAnimation;
  late bool _isFav;

  // 4. Highlight Ticker State
  Timer? _tickerTimer;
  int _tickerIndex = 0;

  List<String> get _images {
    final imgs = widget.seller.productImages;
    if (imgs.isNotEmpty) return imgs;
    if (widget.seller.imageUrl.trim().isNotEmpty) {
      return [widget.seller.imageUrl.trim()];
    }
    return const [];
  }

  List<String> get _highlights {
    if (widget.seller.highlights.isNotEmpty) {
      return widget.seller.highlights;
    }
    final list = <String>[];
    for (final p in widget.seller.products) {
      if (p.name.trim().isNotEmpty) {
        list.add('🔥 Popular: ${p.name.trim()} • ₹${p.price.toStringAsFixed(0)}');
      }
    }
    if (list.isEmpty) {
      list.addAll([
        '⚡ Express 10 Min Delivery Available',
        '🏷️ Up to 50% OFF on Top Essentials',
        '⭐ Top Rated Store near you',
      ]);
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _isFav = widget.isFavorite;
    _pageController = PageController();

    // Setup 1. Entrance Animation (500ms easeOutCubic)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final curvedAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(curvedAnimation);
    _scaleAnimation = Tween<double>(begin: 0.97, end: 1.0).animate(curvedAnimation);

    // Staggered entrance delay: (index % 6) * 60ms
    final delayMs = (widget.index % 6) * 60;
    _entranceTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) _entranceController.forward();
    });

    // Setup 3. Heart Pulse Animation (300ms scale bump)
    _heartPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.35, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(
      parent: _heartPulseController,
      curve: Curves.easeInOut,
    ));

    // Setup 2 & 4 Timers
    _startCarouselTimer();
    _startTickerTimer();
  }

  // 2. Carousel Auto-slide logic
  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    if (_images.length < 2) return;
    _carouselTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (!mounted || _isUserDragging || !_pageController.hasClients) return;
      final nextIndex = (_currentSlideIndex + 1) % _images.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification ||
        notification is UserScrollNotification) {
      setState(() => _isUserDragging = true);
      _carouselTimer?.cancel();
      _carouselResumeTimer?.cancel();
    } else if (notification is ScrollEndNotification) {
      _carouselResumeTimer?.cancel();
      // Resume auto-slide 3 seconds after touch end
      _carouselResumeTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _isUserDragging = false);
          _startCarouselTimer();
        }
      });
    }
  }

  // 4. Highlight Ticker logic
  void _startTickerTimer() {
    _tickerTimer?.cancel();
    final items = _highlights;
    if (items.length < 2) return;
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (!mounted) return;
      setState(() {
        _tickerIndex = (_tickerIndex + 1) % items.length;
      });
    });
  }

  void _onHeartTap() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isFav = !_isFav;
    });
    _heartPulseController.forward(from: 0.0);
    widget.onFavoriteTap?.call(_isFav);
  }

  @override
  void dispose() {
    _entranceTimer?.cancel();
    _carouselTimer?.cancel();
    _carouselResumeTimer?.cancel();
    _tickerTimer?.cancel();
    _entranceController.dispose();
    _heartPulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seller = widget.seller;
    final isOpen = seller.isOpen;

    // Build the main card widget
    Widget cardChild = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── TOP MEDIA & CAROUSEL BOX (Height 165px) ────────────────────────
          SizedBox(
            height: 165,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 2. Carousel PageView with Touch Pause Listener
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    _onScrollNotification(notification);
                    return false;
                  },
                  child: _images.isNotEmpty
                      ? PageView.builder(
                          controller: _pageController,
                          itemCount: _images.length,
                          onPageChanged: (index) {
                            setState(() => _currentSlideIndex = index);
                          },
                          itemBuilder: (context, index) {
                            return AppNetworkImage(
                              url: _images[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 165,
                            );
                          },
                        )
                      : Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(
                            Icons.storefront_rounded,
                            size: 48,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                ),

                // Top Gradient Scrim for Contrast
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black54, Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. Dynamic Product Name & Price Pill (Top Left Overlay)
                if (seller.products.isNotEmpty)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _buildActiveProductPill(
                      seller.products[_currentSlideIndex % seller.products.length],
                    ),
                  )
                else if (seller.discountText.isNotEmpty)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _buildDiscountBadge(seller.discountText),
                  ),

                // 3. Favorite Bookmark/Heart Button (Top Right Overlay with Pulse Animation)
                Positioned(
                  right: 10,
                  top: 10,
                  child: GestureDetector(
                    onTap: _onHeartTap,
                    behavior: HitTestBehavior.opaque,
                    child: ScaleTransition(
                      scale: _heartScaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.90),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 18,
                          color: _isFav
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. Animated Dot Indicators (Bottom Right Overlay)
                if (_images.length > 1)
                  Positioned(
                    right: 12,
                    bottom: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        _images.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          height: 5.0,
                          width: i == _currentSlideIndex ? 14.0 : 5.0,
                          decoration: BoxDecoration(
                            color: i == _currentSlideIndex
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Discount Banner Badge (Bottom Left Overlay)
                if (seller.discountText.isNotEmpty && seller.products.isNotEmpty)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _buildDiscountBadge(seller.discountText),
                  ),
              ],
            ),
          ),

          // ── 6. SELLER INFO & VISUAL HIERARCHY BODY ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Seller Name + Verified Badge + Rating Pill
                Row(
                  children: [
                    // Seller Name
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              seller.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (seller.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: Color(0xFF0EA5E9), // Verified blue check
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Rating Pill Badge (★ 4.8)
                    if (seller.hasRating)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              seller.rating.toStringAsFixed(1),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 5),

                // Row 2: ETA Pill + Distance + Locality + Min Order
                Row(
                  children: [
                    // ETA Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            size: 12,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 1),
                          Text(
                            seller.deliveryMinutes != null
                                ? '${seller.deliveryMinutes} mins'
                                : '10-15 mins',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Distance & Locality
                    Expanded(
                      child: Text(
                        '${seller.distanceKm != null ? '${seller.distanceKm!.toStringAsFixed(1)} km • ' : ''}${seller.locality.isNotEmpty ? seller.locality : 'Quick Commerce Merchant'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),

                    if (seller.minOrderPrice != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        'Min ₹${seller.minOrderPrice!.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),

                // Row 3: Categories / Tags
                if (seller.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    seller.tags.join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── 4. VERTICAL PAGE-UP PRODUCT HIGHLIGHT TICKER ────────────────────
          _buildHighlightTicker(),
        ],
      ),
    );

    // 5. Offline / Closed State Desaturation & IgnorePointer
    if (!isOpen) {
      cardChild = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: Stack(
          children: [
            IgnorePointer(ignoring: true, child: cardChild),

            // Top Closed Banner Overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                ),
                alignment: Alignment.center,
                child: Text(
                  'UNAVAILABLE • REOPENING SOON',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 1. Wrap with Staggered Entrance Animations & GestureDetector
    return GestureDetector(
      onTap: widget.onTap,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: cardChild,
          ),
        ),
      ),
    );
  }

  // 2. Active Product Overlay Pill (Top Left, Search-Style Vertical Page-Up Animation)
  Widget _buildActiveProductPill(Product product) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final isIncoming =
              (child.key as ValueKey<int>?)?.value == _currentSlideIndex;

          final inAnimation = Tween<Offset>(
            begin: const Offset(0.0, 1.2),
            end: Offset.zero,
          ).animate(animation);

          final outAnimation = Tween<Offset>(
            begin: const Offset(0.0, -1.2),
            end: Offset.zero,
          ).animate(animation);

          return SlideTransition(
            position: isIncoming ? inAnimation : outAnimation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey<int>(_currentSlideIndex),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '₹${product.price.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFFC700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Discount Badge Widget
  Widget _buildDiscountBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  // 4. Vertical Page-Up Product Highlight Ticker (Bottom Banner)
  Widget _buildHighlightTicker() {
    final items = _highlights;
    if (items.isEmpty) return const SizedBox.shrink();

    final currentText = items[_tickerIndex % items.length];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.0),
        ),
      ),
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            final isIncoming =
                (child.key as ValueKey<int>?)?.value == _tickerIndex;

            final inSlide = Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(animation);

            final outSlide = Tween<Offset>(
              begin: const Offset(0.0, -1.0),
              end: Offset.zero,
            ).animate(animation);

            return SlideTransition(
              position: isIncoming ? inSlide : outSlide,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: SizedBox(
            key: ValueKey<int>(_tickerIndex),
            width: double.infinity,
            child: Text(
              currentText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
