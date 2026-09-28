import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/share_links.dart';
import '../../../../di/app_providers.dart';
import '../../../../domain/model/product.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/cart_actions.dart';
import '../../../common/widgets/loaders/full_page_loader.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import '../../../common/widgets/states/error_state_widget.dart';
import '../../subscription/subscriptions_provider.dart';
import 'product_details_provider.dart';
import 'product_details_state.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.productId,
    this.product,
    this.heroTag,
  });

  final String productId;
  final Product? product;
  final String? heroTag;

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  late final ProductDetailsArgs _args = ProductDetailsArgs(
    productId: widget.productId,
    product: widget.product,
  );

  int _selectedQuantity = 1;

  Future<void> _addToCart(ProductDetailsState state) async {
    final product = state.product;
    if (product == null) return;

    await CartActions.add(
      context,
      ref,
      product: product,
      variant: state.selectedVariant,
      addons: state.selectedAddons,
      quantity: _selectedQuantity,
      askForAddons: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productDetailsProvider(_args));

    if (state.isLoading && state.product == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7FCFA),
        body: FullPageLoader(message: 'Loading product details...'),
      );
    }

    final product = state.product;
    if (product == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7FCFA),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: ErrorStateWidget(
          failure: state.failure ??
              const NotFoundFailure(
                  'We could not load this product right now.'),
          onRetry: () =>
              ref.read(productDetailsProvider(_args).notifier).load(),
        ),
      );
    }

    final inCartQuantity = ref.watch(
      cartProvider.select((s) => s.cart.quantityOf(product.id)),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7FCFA),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Hero Product Image & Overlay Action Buttons
                  _buildHeroImageSection(context, product),

                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. Product Name
                        Text(
                          product.name,
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // 3. Rating Row (Dynamic)
                        if (product.rating > 0 || product.ratingCount > 0) ...[
                          _buildRatingRow(context, product),
                          const SizedBox(height: 10),
                        ],

                        // 4. Pricing Row (Dynamic Price, Strike Price, Discount Tag)
                        _buildPriceRow(context, product, state),

                        if (product.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            product.description,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF475569),
                              height: 1.4,
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),

                        // 5. Quantity Stepper Selector
                        if (product.isPurchasable) ...[
                          _buildQuantityStepper(context),
                          const SizedBox(height: 16),
                        ],

                        // 6. Subscribe & Save Card (Dynamic if subscription enabled)
                        if (product.subscriptionEnabled) ...[
                          _buildSubscribeCard(context, product),
                          const SizedBox(height: 22),
                        ],

                        // 7. Product Details Feature Badges (Dynamic from Product model)
                        _buildProductDetailsBadges(context, product),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Sticky Bottom Add to Cart Action Bar
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildBottomActionBar(
                context,
                state,
                product,
                inCartQuantity,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hero Product Image with Overlay Floating Back, Share & Favorite buttons
  Widget _buildHeroImageSection(BuildContext context, Product product) {
    final isWishlisted = ref.watch(isWishlistedProvider(product.id));

    return Stack(
      children: [
        // Main Product Image Container
        Container(
          width: double.infinity,
          height: 320,
          color: Colors.white,
          child: AppNetworkImage(
            url: product.imageUrl,
            fit: BoxFit.cover,
            fallbackIcon: Icons.shopping_bag_outlined,
          ),
        ),

        // Floating Top Back Button
        Positioned(
          top: 14,
          left: 14,
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF0F172A),
                size: 20,
              ),
            ),
          ),
        ),

        // Floating Top Action Buttons (Share & Wishlist)
        Positioned(
          top: 14,
          right: 14,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Share.share(
                  '${product.name} on Appzeto — ₹${product.price.toStringAsFixed(0)}\n'
                  '${ShareLinks.product(productId: product.id, sellerId: product.sellerId)}',
                  subject: product.name,
                ),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.share_outlined,
                    color: Color(0xFF0F172A),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => CartActions.toggleWishlist(context, ref, product),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isWishlisted
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isWishlisted
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF0F172A),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom-Right Stock Status Badge (Dynamic)
        Positioned(
          bottom: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: product.isPurchasable
                  ? const Color(0xFF00875A)
                  : const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.isPurchasable ? '🌿' : '⚠️',
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(width: 4),
                Text(
                  product.isPurchasable
                      ? (product.stockQty != null
                          ? '${product.stockQty} in stock'
                          : 'In Stock')
                      : 'Out of Stock',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Rating Row matching screenshot
  Widget _buildRatingRow(BuildContext context, Product product) {
    return Row(
      children: [
        const Icon(
          Icons.star_rounded,
          color: Color(0xFFF59E0B),
          size: 22,
        ),
        const SizedBox(width: 4),
        Text(
          product.rating.toStringAsFixed(1),
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        if (product.ratingCount > 0) ...[
          const SizedBox(width: 4),
          Text(
            '(${product.ratingCount})',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ],
    );
  }

  /// Price Row matching screenshot
  Widget _buildPriceRow(
    BuildContext context,
    Product product,
    ProductDetailsState state,
  ) {
    final price = state.effectiveUnitPrice;
    final strikePrice = state.effectiveStrikePrice ?? product.strikePrice;
    final discountPercent = product.discountPercent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '₹${price.toStringAsFixed(0)}',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF00875A),
          ),
        ),
        if (strikePrice != null && strikePrice > price) ...[
          const SizedBox(width: 10),
          Text(
            '₹${strikePrice.toStringAsFixed(0)}',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF94A3B8),
              decoration: TextDecoration.lineThrough,
            ),
          ),
          if (discountPercent > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$discountPercent% OFF',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF15803D),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  /// Quantity Stepper Control
  Widget _buildQuantityStepper(BuildContext context) {
    return Container(
      width: 120,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: () {
              if (_selectedQuantity > 1) {
                setState(() => _selectedQuantity--);
              }
            },
            child: const Icon(
              Icons.remove,
              color: Color(0xFF00875A),
              size: 20,
            ),
          ),
          Text(
            '$_selectedQuantity',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() => _selectedQuantity++);
            },
            child: const Icon(
              Icons.add,
              color: Color(0xFF00875A),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  /// Subscribe & Save Card
  Widget _buildSubscribeCard(BuildContext context, Product product) {
    // Headline with the best rate on offer — from the backend, not a guess.
    // Falls back to a rate-free label while the config is loading/unavailable
    // rather than showing a number nobody promised.
    final discountConfig = ref.watch(subscriptionDiscountConfigProvider);
    final bestPercent = discountConfig.maybeWhen(
      data: (rates) => rates.values.isEmpty
          ? 0
          : rates.values.reduce((a, b) => a > b ? a : b),
      orElse: () => 0,
    );
    final label = bestPercent > 0
        ? 'Subscribe & Save up to $bestPercent%'
        : 'Subscribe & Save';

    return GestureDetector(
      onTap: () =>
          context.push(RoutePaths.subscriptionCreate, extra: product),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF00875A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_offer_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF047857),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF047857),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  /// Product Details Feature Badges (Dynamic from product fields)
  Widget _buildProductDetailsBadges(BuildContext context, Product product) {
    final features = [
      if (product.isVeg)
        (Icons.eco_rounded, '100% Veg')
      else
        (Icons.restaurant_rounded, 'Non-Veg'),
      if (product.unitLabel.isNotEmpty)
        (Icons.inventory_2_rounded, product.unitLabel),
      if (product.brand.isNotEmpty)
        (Icons.verified_rounded, product.brand)
      else if (product.categoryName.isNotEmpty)
        (Icons.category_rounded, product.categoryName),
    ];

    if (features.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Details',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: features.map((feat) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(feat.$1, color: const Color(0xFF00875A), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    feat.$2,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Sticky Bottom Action Bar
  Widget _buildBottomActionBar(
    BuildContext context,
    ProductDetailsState state,
    Product product,
    int inCartQuantity,
  ) {
    final purchasable = product.isPurchasable && product.sellerAcceptingOrders;

    return GestureDetector(
      onTap: purchasable ? () => _addToCart(state) : null,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: purchasable
              ? const Color(0xFF00875A)
              : const Color(0xFF94A3B8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: purchasable
                  ? const Color(0xFF00875A).withValues(alpha: 0.35)
                  : Colors.black12,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              !purchasable
                  ? 'Out of Stock'
                  : (inCartQuantity > 0
                      ? 'Add More ($inCartQuantity in cart)'
                      : 'Add to Cart'),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
