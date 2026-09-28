import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_labels.dart';
import '../../../../domain/model/order.dart';
import '../../../../domain/model/order_status.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/loaders/full_page_loader.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import '../../../common/widgets/states/empty_state_widget.dart';
import '../../../common/widgets/states/error_state_widget.dart';
import '../orders_list/orders_provider.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _selectedTab = 'All';

  @override
  Widget build(BuildContext context) {
    const darkTextColor = Color(0xFF142922);
    const lightBg = Color(0xFFF4FAF7);

    final ordersState = ref.watch(ordersProvider);
    final allOrders = ordersState.orders;

    // Filter list based on selected tab
    final filteredOrders = allOrders.where((o) {
      if (_selectedTab == 'Delivered') {
        return o.status == OrderStatus.delivered;
      }
      if (_selectedTab == 'Cancelled') {
        return o.status.isCancelled;
      }
      return true;
    }).toList();

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
                    'Order History',
                    style: TextStyle(
                      color: darkTextColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search_rounded, color: darkTextColor, size: 24),
                    onPressed: () => context.push(RoutePaths.search),
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
                  const SizedBox(width: 8),
                  _FilterChipTab(
                    label: 'Delivered',
                    isSelected: _selectedTab == 'Delivered',
                    onTap: () => setState(() => _selectedTab = 'Delivered'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipTab(
                    label: 'Cancelled',
                    isSelected: _selectedTab == 'Cancelled',
                    onTap: () => setState(() => _selectedTab = 'Cancelled'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Orders List
            Expanded(
              child: ordersState.isLoading && allOrders.isEmpty
                  ? const FullPageLoader()
                  : ordersState.failure != null && allOrders.isEmpty
                      ? Center(
                          child: ErrorStateWidget(
                            failure: ordersState.failure!,
                            onRetry: () => ref.read(ordersProvider.notifier).load(),
                          ),
                        )
                      : filteredOrders.isEmpty
                          ? Center(
                              child: EmptyStateWidget(
                                icon: Icons.receipt_long_outlined,
                                title: 'No orders yet',
                                message: 'Orders you place will show up here.',
                                actionLabel: 'Start shopping',
                                onAction: () => context.go(RoutePaths.home),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              itemCount: filteredOrders.length,
                              itemBuilder: (context, index) {
                                final order = filteredOrders[index];
                                return _OrderHistoryCard(
                                  order: order,
                                  onTap: () {
                                    context.push(RoutePaths.orderTrackingOf(order.id));
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
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

class _OrderHistoryCard extends StatelessWidget {
  const _OrderHistoryCard({
    required this.order,
    required this.onTap,
  });

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF108061);
    const darkTextColor = Color(0xFF142922);
    const cardBorderColor = Color(0xFFDFE8E3);
    const secondaryTextColor = Color(0xFF758A82);

    final isCancelled = order.status.isCancelled;
    final statusBg = isCancelled ? const Color(0xFFFFEBEE) : const Color(0xFFDDF7EC);
    final statusTextColor = isCancelled ? const Color(0xFFE53935) : primaryGreen;
    final statusLabel = order.status.label;
    final thumbnailUrl = order.lines.isNotEmpty ? order.lines.first.imageUrl : '';

    final totalItems = order.itemCount > 0 ? order.itemCount : order.lines.length;
    final date = order.placedAt;
    final formattedDate =
        '${DateLabels.month(date.month)} ${date.day}, ${date.year}  •  ${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
        child: Row(
          children: [
            // Order Image Thumbnail Container
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F9F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: AppNetworkImage(
                url: thumbnailUrl,
                fit: BoxFit.contain,
                fallbackIcon: Icons.shopping_bag_outlined,
              ),
            ),
            const SizedBox(width: 14),

            // Order Details Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.displayId.startsWith('#')
                            ? order.displayId
                            : '#${order.displayId}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: darkTextColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$totalItems items  •  ₹${order.pricing.total.toInt()}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: darkTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF99AAA3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
