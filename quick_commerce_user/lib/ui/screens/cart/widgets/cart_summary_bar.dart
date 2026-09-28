import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/extensions/num_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../di/app_providers.dart';
import '../../../../domain/model/cart_item.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/misc/app_network_image.dart';

/// Floating "View cart (N items)" pill bar with overlapping item thumbnails,
/// matching the sleek quick-commerce design.
class CartSummaryBar extends ConsumerWidget {
  const CartSummaryBar({
    super.key,
    this.label,
    this.aboveNavigationBar = false,
  });

  final String? label;

  /// When it sits on top of the tab bar, that bar already handles the home
  /// indicator — insetting again would float the pill well clear of it.
  final bool aboveNavigationBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider.select((s) => s.cart));

    return AnimatedSlide(
      offset: cart.isEmpty ? const Offset(0, 1.4) : Offset.zero,
      duration: AppDurations.medium,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: cart.isEmpty ? 0 : 1,
        duration: AppDurations.fast,
        child: cart.isEmpty
            ? const SizedBox(height: 0, width: double.infinity)
            : SafeArea(
                top: false,
                bottom: !aboveNavigationBar,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    aboveNavigationBar ? AppSpacing.sm : AppSpacing.md,
                  ),
                  child: GestureDetector(
                    onTap: () => context.go(RoutePaths.cart),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F7A52), Color(0xFF075E41)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F7A52).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                          const BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Stacked overlapping product thumbnails
                          _buildItemThumbnails(cart.items),

                          const SizedBox(width: 12),

                          // Text: "View cart (3 items)" + Total Price
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    label ??
                                        'View cart (${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'})',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '• ${(cart.pricing.total > 0 ? cart.pricing.total : cart.provisionalSubtotal).asCurrency}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Chevron Right Icon inside subtle semi-transparent circle
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildItemThumbnails(List<CartItem> cartItems) {
    final displayItems = cartItems.take(3).toList();
    if (displayItems.isEmpty) return const SizedBox.shrink();

    const double size = 38.0;
    const double overlap = 24.0;
    final double width = size + (displayItems.length - 1) * overlap;

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(displayItems.length, (index) {
          final item = displayItems[index];
          final imageUrl = item.product.imageUrl.trim().isNotEmpty
              ? item.product.imageUrl.trim()
              : (item.product.images.isNotEmpty
                  ? item.product.images.first.trim()
                  : '');

          return Positioned(
            left: index * overlap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x20000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: imageUrl.isNotEmpty
                    ? AppNetworkImage(
                        url: imageUrl,
                        fit: BoxFit.cover,
                        width: size,
                        height: size,
                      )
                    : Container(
                        color: const Color(0xFFF3F4F6),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          size: 18,
                          color: Color(0xFF0F7A52),
                        ),
                      ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
