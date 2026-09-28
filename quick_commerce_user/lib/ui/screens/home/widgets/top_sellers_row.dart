import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_user/core/theme/app_theme_provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/product.dart';
import '../../../../domain/model/seller.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../di/app_providers.dart';
import '../../../common/widgets/feedback/app_toast.dart';
import '../../../common/widgets/loaders/shimmer_box.dart';
import '../../../common/widgets/misc/app_network_image.dart';

/// Compact "Top Sellers" section with modern, high-contrast cards.
///
/// Features:
/// - Fixed card dimensions (156px wide x 222px tall) with zero empty space.
/// - Product section pairing product image with real API product name & price.
/// - 3.5-second auto-cycling backend products/images per seller.
/// - Compact store footer with store logo, name, delivery time & rating.
class TopSellersRow extends StatelessWidget {
  const TopSellersRow({
    super.key,
    required this.sellers,
    required this.onSellerTap,
    this.onSeeAll,
    this.isLoading = false,
  });

  final List<Seller> sellers;
  final ValueChanged<Seller> onSellerTap;
  final VoidCallback? onSeeAll;
  final bool isLoading;

  static const double _cardWidth = 156.0;
  static const double _cardHeight = 222.0;

  @override
  Widget build(BuildContext context) {
    if (!isLoading && sellers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Header with Yellow Star Badge, Title, Subtitle & See All
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF43B5A8),
                  // color: Color(0xFFFFC107),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.star_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final isDarkMode =
                            ref.watch(themeProvider).mode == .dark;
                        return Text(
                          'Top Sellers',
                          style: context.text.titleMedium!.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 16.5,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF1F2937),
                          ),
                        );
                      },
                    ),
                    Text(
                      'Verified stores delivering near you',
                      style: context.text.bodySmall!.copyWith(
                        fontSize: 11,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (onSeeAll != null)
                GestureDetector(
                  onTap: onSeeAll,
                  child: Row(
                    children: [
                      Text(
                        'See all',
                        style: context.text.labelSmall!.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: Color(0xFF16A34A),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // 2. Horizontal Cards List (Height 222px)
        if (isLoading)
          SizedBox(
            height: _cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, _) => ShimmerBox(
                width: _cardWidth,
                height: _cardHeight,
                radius: BorderRadius.circular(14),
              ),
            ),
          )
        else
          SizedBox(
            height: _cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: sellers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final seller = sellers[index];
                return _SellerCard(
                  seller: seller,
                  width: _cardWidth,
                  height: _cardHeight,
                  onTap: () => onSellerTap(seller),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Redesigned compact seller card (156px wide x 222px tall).
class _SellerCard extends ConsumerStatefulWidget {
  const _SellerCard({
    required this.seller,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final Seller seller;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  ConsumerState<_SellerCard> createState() => _SellerCardState();
}

class _SellerCardState extends ConsumerState<_SellerCard> {
  Timer? _timer;
  int _currentIndex = 0;

  List<Product> get _products => widget.seller.products;
  List<String> get _images => widget.seller.productImages;

  int get _itemCount {
    if (_products.isNotEmpty) return _products.length;
    if (_images.isNotEmpty) return _images.length;
    return 1;
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  Future<void> _toggleSaved(Seller seller) async {
    if (!ref.read(authProvider).isSignedIn) {
      AppToast.show(context, 'Sign in to save stores');
      return;
    }
    AppHaptics.selection();
    try {
      await ref.read(wishlistProvider.notifier).toggleStore(seller.id);
      if (!mounted) return;

      // Named confirmation, same as the product heart — the icon is small and
      // a mis-tap otherwise looks identical to a hit.
      final saved = ref.read(wishlistProvider.notifier).containsStore(seller.id);
      final name = seller.name.trim().isEmpty ? 'Store' : seller.name.trim();
      AppToast.success(
        context,
        saved ? '$name saved' : '$name removed from saved stores',
      );
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Could not update your saved stores');
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_itemCount > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
        if (!mounted) return;
        setState(() {
          _currentIndex = (_currentIndex + 1) % _itemCount;
        });
      });
    }
  }

  @override
  void didUpdateWidget(covariant _SellerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seller.id != widget.seller.id ||
        oldWidget.seller.products.length != widget.seller.products.length) {
      _currentIndex = 0;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildAnimatedProductName({
    required String text,
    required TextStyle style,
  }) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final isIncoming =
              (child.key as ValueKey<int>?)?.value == _currentIndex;

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
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Align(
          key: ValueKey<int>(_currentIndex),
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seller = widget.seller;
    final products = _products;
    final images = _images;
    final isSaved = ref.watch(isStoreSavedProvider(seller.id));

    Product? currentProduct;
    String currentImage = '';
    String currentProductName = '';

    if (products.isNotEmpty) {
      currentProduct = products[_currentIndex % products.length];
      currentImage = currentProduct.imageUrl.trim().isNotEmpty
          ? currentProduct.imageUrl.trim()
          : (images.isNotEmpty ? images.first : seller.imageUrl);
      currentProductName = currentProduct.name.trim();
    } else if (images.isNotEmpty) {
      currentImage = images[_currentIndex % images.length];
      currentProductName = seller.name;
    } else {
      currentImage = seller.imageUrl;
      currentProductName = seller.name;
    }

    if (currentProductName.isEmpty) {
      currentProductName = seller.name;
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP PRODUCT SECTION (Image + Real API Product Name & Price)
            SizedBox(
              height: 104,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Product Image Area
                  Container(
                    width: double.infinity,
                    height: 104,
                    color: const Color(0xFFF9FAFB),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeOut,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.96,
                            end: 1.0,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: currentImage.isNotEmpty
                          ? AppNetworkImage(
                              key: ValueKey<String>(currentImage),
                              url: currentImage,
                              width: double.infinity,
                              height: 104,
                              fit: BoxFit.contain,
                              fallbackIcon: Icons.shopping_bag_outlined,
                            )
                          : Container(
                              key: const ValueKey<String>('empty'),
                              alignment: Alignment.center,
                              color: const Color(0xFFF9FAFB),
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                                size: 28,
                                color: Color(0xFFD1D5DB),
                              ),
                            ),
                    ),
                  ),

                  // Top-Left Badge: Green "Top Seller" Pill
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Top Seller',
                        style: context.text.labelSmall!.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 8.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Top-Right Icon: save this store
                  //
                  // This used to wishlist whichever product happened to be
                  // showing in the card's slideshow, with icon state held in a
                  // local bool that did not survive a rebuild. It now saves the
                  // store itself, server-side, and reads its filled state from
                  // the shared wishlist.
                  Positioned(
                    right: 6,
                    top: 6,
                    child: GestureDetector(
                      onTap: () => _toggleSaved(seller),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSaved
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 15,
                          color: isSaved
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Product Details Block (Visually connected directly below image)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Real Product Name with Search-style Vertical Page-Up Animation
                  _buildAnimatedProductName(
                    text: currentProductName,
                    style: context.text.titleSmall!.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Real Product Price & Pack Size from API
                  Row(
                    children: [
                      if (currentProduct != null) ...[
                        Text(
                          '₹${currentProduct.price.toStringAsFixed(0)}',
                          style: context.text.titleSmall!.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                        if (currentProduct.packSize.trim().isNotEmpty) ...[
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '• ${currentProduct.packSize.trim()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall!.copyWith(
                                fontWeight: FontWeight.w500,
                                fontSize: 9.5,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ] else ...[
                        Text(
                          '${seller.productCount} products',
                          style: context.text.bodySmall!.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 9.5,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 0.8, color: Color(0xFFF3F4F6)),

            // 2. BOTTOM STORE FOOTER SECTION (Store Name, Logo, Delivery Time & Stats)
            Expanded(
              child: Container(
                color: const Color(0xFFFAFAFA),
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Store Logo Avatar + Store Name
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 0.8,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: seller.imageUrl.trim().isNotEmpty
                              ? AppNetworkImage(
                                  url: seller.imageUrl,
                                  width: 18,
                                  height: 18,
                                  fit: BoxFit.cover,
                                  fallbackIcon: Icons.storefront_outlined,
                                )
                              : const Icon(
                                  Icons.storefront_outlined,
                                  size: 11,
                                  color: Color(0xFF4B5563),
                                ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            seller.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall!.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                              color: const Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Delivery Time Badge, Rating & Product Count Row
                    Row(
                      children: [
                        if (seller.deliveryMinutes != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${seller.deliveryMinutes}m',
                              style: context.text.labelSmall!.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (seller.hasRating) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 11,
                            color: Color(0xFF43B5A8),
                            // color: Color(0xFFFFC107),
                          ),
                          const SizedBox(width: 1),
                          Text(
                            seller.rating.toStringAsFixed(1),
                            style: context.text.titleSmall!.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 9.5,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          '${seller.productCount} ${seller.productCount == 1 ? 'item' : 'items'}',
                          style: context.text.bodySmall!.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 9,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
