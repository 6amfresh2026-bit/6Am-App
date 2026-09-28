import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/order_status.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import '../../order/orders_list/orders_provider.dart';

/// Active Order Floating Card matching the reference design.
///
/// Features:
/// - Floats above bottom navigation with rounded white card & subtle drop shadow.
/// - Left: Circular light background avatar with store/restaurant logo.
/// - Center: Store name + Current order status (Order Placed, Preparing, etc.) with small orange arrow indicator ▶.
/// - Right: Green pill badge showing live ETA (`~25 mins` or `Calculating...`).
/// - Functionality: 100% backend dynamic data, auto-refreshes on status change, auto-removes on terminal status (delivered/cancelled).
/// - Tap action: Navigates to live Order Tracking screen for that exact backend `order.id`.
class ActiveOrderFloatingCard extends ConsumerStatefulWidget {
  const ActiveOrderFloatingCard({super.key});

  @override
  ConsumerState<ActiveOrderFloatingCard> createState() =>
      _ActiveOrderFloatingCardState();
}

class _ActiveOrderFloatingCardState
    extends ConsumerState<ActiveOrderFloatingCard> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Poll for live status while home is visible. Silent refresh: a full
    // `load(reset: true)` here flips `isLoading` every 8s, which flickered the
    // Orders tab's skeleton and fired authed requests even when signed out.
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      ref.read(ordersProvider.notifier).silentRefresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _getFormattedStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.created:
        return 'Order Placed';
      case OrderStatus.confirmed:
        return 'Order Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.readyForPickup:
      case OrderStatus.reachedPickup:
        return 'Ready for Pickup';
      case OrderStatus.pickedUp:
        return 'Picked Up';
      case OrderStatus.reachedDrop:
        return 'Arriving';
      case OrderStatus.delivered:
        return 'Delivered';
      default:
        return status.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders = ref.watch(ordersProvider.select((s) => s.active));
    if (activeOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeOrder = activeOrders.first;
    final storeName = activeOrder.sellerName.trim().isNotEmpty
        ? activeOrder.sellerName.trim()
        : (activeOrder.lines.isNotEmpty
            ? activeOrder.lines.first.name
            : 'Active Order');

    final statusText = _getFormattedStatus(activeOrder.status);
    final etaText = activeOrder.etaMinutes != null && activeOrder.etaMinutes! > 0
        ? '~${activeOrder.etaMinutes} mins'
        : 'Calculating...';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1.2),
          end: Offset.zero,
        ).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Container(
        key: ValueKey<String>('${activeOrder.id}_${activeOrder.status.wireValue}'),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              context.push(RoutePaths.orderTrackingOf(activeOrder.id));
            },
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: const Color(0xFFF3F4F6),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Circular Light Peach Avatar Container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    child: activeOrder.sellerImageUrl.trim().isNotEmpty
                        ? AppNetworkImage(
                            url: activeOrder.sellerImageUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.restaurant_rounded,
                          )
                        : const Icon(
                            Icons.soup_kitchen_rounded,
                            size: 22,
                            color: Color(0xFFE65100),
                          ),
                  ),
                  const SizedBox(width: 12),

                  // Store Name & Status with Orange Arrow ▶
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall!.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                statusText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodySmall!.copyWith(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.play_arrow_rounded,
                              size: 13,
                              color: Color(0xFFF97316),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Green Pill Badge showing ETA / Status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      etaText,
                      style: context.text.labelSmall!.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
