import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/model/cart_item.dart';
import '../../../di/app_providers.dart';
import '../../../navigation/route_paths.dart';
import '../../common/widgets/feedback/app_dialog.dart';
import '../../common/widgets/feedback/app_toast.dart';
import '../../common/widgets/states/empty_state_widget.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  String _selectedTab = 'All';
  final Set<String> _savedForLaterIds = {};

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF108061);
    const darkTextColor = Color(0xFF142922);
    const lightBg = Color(0xFFF4FAF7);
    const cardBorderColor = Color(0xFFDFE8E3);
    const secondaryTextColor = Color(0xFF758A82);

    final cartState = ref.watch(cartProvider);
    final realCart = cartState.cart;

    // Filter items based on active tab — 'Saved' is the only real split this
    // cart supports; there is no order-status concept (Active/Delivered/…)
    // on items that have not been ordered yet.
    final displayItems = realCart.items.where((i) {
      if (_selectedTab == 'Saved') {
        return _savedForLaterIds.contains(i.product.id);
      }
      return !_savedForLaterIds.contains(i.product.id);
    }).toList();

    // Server-priced when available (coupons, delivery-zone fee, GST slabs all
    // live there); the local sum is only a same-frame placeholder while that
    // call is in flight.
    double subtotal = 0;
    for (final item in displayItems) {
      subtotal += item.product.price * item.quantity;
    }
    final pricing = realCart.pricing;
    final hasServerPricing = pricing.total > 0;
    final double deliveryFee = hasServerPricing ? pricing.deliveryFee : 0;
    final double taxes = hasServerPricing ? pricing.tax : 0;
    final double total = displayItems.isEmpty
        ? 0
        : hasServerPricing
            ? pricing.total
            : subtotal;

    return Scaffold(
      backgroundColor: lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (Navigator.of(context).canPop())
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: darkTextColor, size: 24),
                      onPressed: () => context.pop(),
                    ),
                  const SizedBox(width: 4),
                  const Text(
                    'My Cart',
                    style: TextStyle(
                      color: darkTextColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: darkTextColor, size: 24),
                    onPressed: () => _confirmClear(context),
                  ),
                ],
              ),
            ),

            // Filter Tabs Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _FilterChipTab(
                    label: 'All',
                    isSelected: _selectedTab == 'All',
                    onTap: () => setState(() => _selectedTab = 'All'),
                  ),
                  if (_savedForLaterIds.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _FilterChipTab(
                      label: 'Saved',
                      isSelected: _selectedTab == 'Saved',
                      onTap: () => setState(() => _selectedTab = 'Saved'),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Cart Items & Summary
            Expanded(
              child: displayItems.isEmpty
                  ? Center(
                      child: EmptyStateWidget(
                        icon: Icons.shopping_cart_outlined,
                        title: 'Your cart is empty',
                        message: 'Add fresh items to your cart to continue.',
                        actionLabel: 'Browse Products',
                        onAction: () => context.go(RoutePaths.home),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      children: [
                        // Cart Item Cards
                        for (final item in displayItems)
                          _CartItemCard(
                            item: item,
                            isSavedForLater: _savedForLaterIds.contains(item.product.id),
                            onIncrement: () =>
                                ref.read(cartProvider.notifier).increment(item.lineId),
                            onDecrement: () =>
                                ref.read(cartProvider.notifier).decrement(item.lineId),
                            onRemove: () =>
                                ref.read(cartProvider.notifier).removeLine(item.lineId),
                            onToggleSaveForLater: () {
                              setState(() {
                                if (_savedForLaterIds.contains(item.product.id)) {
                                  _savedForLaterIds.remove(item.product.id);
                                  AppToast.success(context, 'Moved back to cart');
                                } else {
                                  _savedForLaterIds.add(item.product.id);
                                  AppToast.success(context, 'Saved for later');
                                }
                              });
                            },
                          ),

                        const SizedBox(height: 16),

                        // Apply Coupon Card
                        GestureDetector(
                          onTap: () => context.push(RoutePaths.coupons),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorderColor),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.local_offer_outlined,
                                  color: darkTextColor,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Apply Coupon',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: darkTextColor,
                                  ),
                                ),
                                Spacer(),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: secondaryTextColor,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Bill Details Breakdown
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              _BillDetailRow(
                                label: 'Subtotal',
                                value: '₹${subtotal.toInt()}',
                              ),
                              const SizedBox(height: 8),
                              _BillDetailRow(
                                label: 'Delivery Fee',
                                value: cartState.isPricing
                                    ? '…'
                                    : hasServerPricing
                                        ? (deliveryFee > 0 ? '₹${deliveryFee.toInt()}' : 'FREE')
                                        : 'Calculated at checkout',
                              ),
                              const SizedBox(height: 8),
                              _BillDetailRow(
                                label: 'Taxes',
                                value: cartState.isPricing
                                    ? '…'
                                    : hasServerPricing
                                        ? '₹${taxes.toInt()}'
                                        : 'Calculated at checkout',
                              ),
                              const SizedBox(height: 16),

                              // Total Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: darkTextColor,
                                    ),
                                  ),
                                  Text(
                                    '₹${total.toInt()}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: darkTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Main CTA Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            onPressed: () => context.push(RoutePaths.checkout),
                            child: const Text(
                              'Proceed to Checkout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await AppDialog.confirm(
      context,
      icon: Icons.remove_shopping_cart_outlined,
      title: 'Clear your cart?',
      message: 'This removes everything you have added so far.',
      confirmLabel: 'Clear cart',
      destructive: true,
    );
    if (confirmed) {
      ref.read(cartProvider.notifier).clear();
      setState(() {});
    }
  }
}

class _FilterChipTab extends StatelessWidget {
  const _FilterChipTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF108061);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : const Color(0xFFEFF3F1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF556861),
          ),
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.isSavedForLater,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onToggleSaveForLater,
  });

  final CartItem item;
  final bool isSavedForLater;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback onToggleSaveForLater;

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF108061);
    const darkTextColor = Color(0xFF142922);
    const cardBorderColor = Color(0xFFDFE8E3);
    const secondaryTextColor = Color(0xFF758A82);

    final product = item.product;
    final isDairy = product.categoryName.toLowerCase().contains('dairy') ||
        product.name.toLowerCase().contains('milk');

    final badgeLabel = isDairy
        ? 'Dairy'
        : (product.categoryName.isNotEmpty ? product.categoryName : 'Fresh Produce');

    final badgeBg = isDairy ? const Color(0xFFE3F2FD) : const Color(0xFFDDF7EC);
    final badgeTextColor = isDairy ? const Color(0xFF1976D2) : primaryGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06108061),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F9F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  product.imageUrl.isNotEmpty
                      ? product.imageUrl
                      : 'assets/images/cat_vegetables.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    isDairy ? Icons.local_drink_rounded : Icons.eco_rounded,
                    color: primaryGreen,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: darkTextColor,
                      ),
                    ),
                    if (product.packSize.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        product.packSize,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '₹${product.price.toInt()}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: darkTextColor,
                          ),
                        ),
                        if (product.mrp != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '₹${product.mrp!.toInt()}',
                            style: const TextStyle(
                              fontSize: 13,
                              decoration: TextDecoration.lineThrough,
                              color: Color(0xFF99AAA3),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Tag Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          color: badgeTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Trash bin icon top right
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFF99AAA3),
                  size: 20,
                ),
                onPressed: onRemove,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Bottom Action Row: Stepper & Save for Later
          Row(
            children: [
              // Stepper
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardBorderColor),
                ),
                child: Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28),
                      icon: const Icon(Icons.remove, color: primaryGreen, size: 16),
                      onPressed: onDecrement,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: darkTextColor,
                        ),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28),
                      icon: const Icon(Icons.add, color: primaryGreen, size: 16),
                      onPressed: onIncrement,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Save for Later
              GestureDetector(
                onTap: onToggleSaveForLater,
                child: Row(
                  children: [
                    Icon(
                      isSavedForLater
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: primaryGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSavedForLater ? 'Saved' : 'Save for Later',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: darkTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BillDetailRow extends StatelessWidget {
  const _BillDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF758A82),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF142922),
          ),
        ),
      ],
    );
  }
}
