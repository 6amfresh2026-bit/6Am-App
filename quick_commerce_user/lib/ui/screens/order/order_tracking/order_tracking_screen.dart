import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/failure.dart';
import '../../../../domain/model/order_status.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/feedback/app_toast.dart';
import '../../../common/widgets/loaders/full_page_loader.dart';
import '../../../common/widgets/states/error_state_widget.dart';
import '../order_details/order_details_provider.dart';

class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const primaryGreen = Color(0xFF108061);
    const darkTextColor = Color(0xFF142922);
    const lightBg = Color(0xFFF4FAF7);
    const cardBorderColor = Color(0xFFDFE8E3);
    const secondaryTextColor = Color(0xFF758A82);

    final orderDetailState = ref.watch(orderDetailProvider(orderId));
    final order = orderDetailState.order;

    if (order == null) {
      return Scaffold(
        backgroundColor: lightBg,
        body: SafeArea(
          child: orderDetailState.isLoading
              ? const FullPageLoader()
              : Center(
                  child: ErrorStateWidget(
                    failure: orderDetailState.failure ??
                        const UnknownFailure('Order not found.'),
                    onRetry: () =>
                        ref.read(orderDetailProvider(orderId).notifier).load(),
                  ),
                ),
        ),
      );
    }

    final rider = order.deliveryPartner;
    final lines = order.lines;
    final hasLiveLocation = orderDetailState.liveRiderLocation != null;

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
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: darkTextColor, size: 24),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(RoutePaths.orders);
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Your Order',
                    style: TextStyle(
                      color: darkTextColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.headset_mic_outlined, color: darkTextColor, size: 24),
                    onPressed: () => context.push(RoutePaths.help),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status & Stepper Progress Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorderColor),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08108061),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header inside card
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order ${order.displayId.startsWith('#') ? order.displayId : '#${order.displayId}'}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: darkTextColor,
                                ),
                              ),
                              Text(
                                order.etaMinutes != null
                                    ? 'Arrives in ${order.etaMinutes} min'
                                    : 'ETA not available yet',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: primaryGreen,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Horizontal Stepper Timeline
                          _OrderTrackerTimeline(status: order.status),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    if (rider == null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorderColor),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.two_wheeler_rounded, color: secondaryTextColor),
                            SizedBox(width: 10),
                            Text(
                              'Looking for a delivery partner…',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                    // Delivery Partner Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorderColor),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Rider Avatar
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFE8F5E9),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/header_delivery_rider.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                      Icons.person_rounded,
                                      color: primaryGreen,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Partner Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rider.name.isNotEmpty ? rider.name : 'Delivery partner',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: darkTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Delivery Partner',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Call & Message Icon Buttons
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEFF3F1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.phone_outlined,
                                    color: primaryGreen,
                                    size: 18,
                                  ),
                                ),
                                onPressed: () {
                                  if (rider.phone.isNotEmpty) {
                                    launchUrl(Uri.parse('tel:${rider.phone}'));
                                  } else {
                                    AppToast.show(context, 'Calling delivery partner...');
                                  }
                                },
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEFF3F1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: primaryGreen,
                                    size: 18,
                                  ),
                                ),
                                onPressed: () {
                                  context.push(RoutePaths.orderChatOf(order.id));
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.two_wheeler_rounded,
                                    color: secondaryTextColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    rider.vehicleNumber.isNotEmpty
                                        ? rider.vehicleNumber
                                        : '—',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: darkTextColor,
                                    ),
                                  ),
                                ],
                              ),

                              // Live Tracking Tag — shown only once a real GPS
                              // fix has arrived over the tracking socket; there
                              // is no map on this screen to jump to yet, so the
                              // tag states that tracking is live rather than
                              // inventing a distance no sensor produced.
                              if (hasLiveLocation)
                              GestureDetector(
                                onTap: () => AppToast.show(
                                  context,
                                  "Your delivery partner's location is updating live.",
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDDF7EC),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_rounded,
                                        color: primaryGreen,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Live Tracking',
                                        style: TextStyle(
                                          color: primaryGreen,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Items List
                    Text(
                      'Items (${lines.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: darkTextColor,
                      ),
                    ),
                    const SizedBox(height: 10),

                    for (final item in lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cardBorderColor),
                              ),
                              child: Image.asset(
                                item.imageUrl.isNotEmpty
                                    ? item.imageUrl
                                    : 'assets/images/cat_vegetables.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.eco_rounded,
                                  color: primaryGreen,
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: darkTextColor,
                                    ),
                                  ),
                                  if (item.variantName.isNotEmpty)
                                    Text(
                                      item.variantName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${(item.price * item.quantity).toInt()}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: darkTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Bill Breakdown
                    Column(
                      children: [
                        _PriceRow(
                          label: 'Subtotal',
                          value: '₹${order.pricing.subtotal.toInt()}',
                        ),
                        const SizedBox(height: 6),
                        _PriceRow(
                          label: 'Delivery Fee',
                          value: '₹${order.pricing.deliveryFee.toInt()}',
                        ),
                        const SizedBox(height: 6),
                        _PriceRow(
                          label: 'Taxes',
                          value: '₹${order.pricing.tax.toInt()}',
                        ),
                        const SizedBox(height: 14),
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
                              '₹${order.pricing.total.toInt()}',
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

                    const SizedBox(height: 24),

                    // Need Help Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDDF7EC),
                          foregroundColor: primaryGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        icon: const Icon(Icons.headset_mic_outlined, size: 20),
                        label: const Text(
                          'Need Help?',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => context.push(RoutePaths.help),
                      ),
                    ),
                    const SizedBox(height: 16),
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

class _OrderTrackerTimeline extends StatelessWidget {
  const _OrderTrackerTimeline({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF108061);
    const inactiveColor = Color(0xFFD3DFDA);
    const darkTextColor = Color(0xFF142922);
    const secondaryTextColor = Color(0xFF99AAA3);

    final isPlaced = status.index >= OrderStatus.created.index;
    final isPreparing = status.index >= OrderStatus.confirmed.index;
    final isOut = status.index >= OrderStatus.pickedUp.index;
    final isDelivered = status == OrderStatus.delivered;

    return Column(
      children: [
        Row(
          children: [
            // Step 1: Placed
            _StepNode(
              isActive: isPlaced,
              icon: Icons.check,
            ),
            Expanded(child: Container(height: 3, color: isPreparing ? primaryGreen : inactiveColor)),

            // Step 2: Preparing
            _StepNode(
              isActive: isPreparing,
              icon: Icons.check,
            ),
            Expanded(child: Container(height: 3, color: isOut ? primaryGreen : inactiveColor)),

            // Step 3: Out for Delivery
            _StepNode(
              isActive: isOut,
              icon: Icons.two_wheeler_rounded,
            ),
            Expanded(child: Container(height: 3, color: isDelivered ? primaryGreen : inactiveColor)),

            // Step 4: Delivered
            _StepNode(
              isActive: isDelivered,
              icon: Icons.inventory_2_outlined,
            ),
          ],
        ),

        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Placed',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isPlaced ? FontWeight.w700 : FontWeight.w500,
                color: isPlaced ? darkTextColor : secondaryTextColor,
              ),
            ),
            Text(
              'Preparing',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isPreparing ? FontWeight.w700 : FontWeight.w500,
                color: isPreparing ? darkTextColor : secondaryTextColor,
              ),
            ),
            Text(
              'Out for Delivery',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isOut ? FontWeight.w700 : FontWeight.w500,
                color: isOut ? primaryGreen : secondaryTextColor,
              ),
            ),
            Text(
              'Delivered',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isDelivered ? FontWeight.w700 : FontWeight.w500,
                color: isDelivered ? darkTextColor : secondaryTextColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.isActive,
    required this.icon,
  });

  final bool isActive;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF108061);
    const inactiveColor = Color(0xFFDFE8E3);

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isActive ? primaryGreen : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? primaryGreen : inactiveColor,
          width: 2,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 15,
          color: isActive ? Colors.white : const Color(0xFF99AAA3),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value});

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
