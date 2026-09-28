import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../common/delivery_promise.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/order.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/buttons/secondary_button.dart';
import '../../../common/widgets/feedback/app_toast.dart';
import '../../../common/widgets/loaders/full_page_loader.dart';
import '../../../common/widgets/misc/rating_stars.dart';
import '../../../common/widgets/maps/order_route_map.dart';
import '../../../common/widgets/states/error_state_widget.dart';
import '../../chat/chat_screen.dart';
import '../order_details/order_details_provider.dart';
import '../widgets/order_status_chip.dart';
import 'widgets/tracking_timeline.dart';

/// Live order tracking. Polls the order endpoint while the order is in flight.
class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Everything the page chrome renders — but NOT the rider location, which
    // updates every couple of seconds and is watched by the isolated map alone.
    // The extra status/eta/rider tokens are here because `Order.==` is id-only
    // and would otherwise hide those changes from the record's equality check.
    final view = ref.watch(
      orderDetailProvider(orderId).select(
        (s) => (
          order: s.order,
          status: s.order?.status,
          eta: s.order?.etaMinutes,
          hasRider: s.order?.deliveryPartner != null,
          dropOtp: s.dropOtp,
          isLoading: s.isLoading,
          failure: s.failure,
        ),
      ),
    );
    final order = view.order;

    if (view.isLoading && order == null) {
      return const Scaffold(
        body: FullPageLoader(message: 'Fetching your order…'),
      );
    }
    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorStateWidget(
          failure: view.failure!,
          onRetry: () => ref.read(orderDetailProvider(orderId).notifier).load(),
        ),
      );
    }

    // Reached two ways: pushed from the orders list (pop works), and `go`n to
    // from the order-success screen, which leaves no history — back there used
    // to fall through to the OS and close the app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(RoutePaths.home);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(order.displayId),
          actions: [
            OrderStatusChip(status: order.status),
            const SizedBox(width: AppSpacing.lg),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              _LiveStatusBanner(order: order),
              // Isolated: only this widget rebuilds when the rider moves, so a
              // location ping never re-runs the banner, timeline or buttons.
              _TrackingMap(orderId: orderId),
              if (order.status.isOutForDelivery && view.dropOtp.isNotEmpty)
                _DropOtpCard(otp: view.dropOtp),
              if (order.deliveryPartner != null)
                _RiderCard(partner: order.deliveryPartner!, orderId: order.id),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TrackingTimeline(order: order),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: SecondaryButton(
                  label: 'Need help with this order?',
                  icon: Icons.support_agent_rounded,
                  expand: true,
                  backgroundColor: const Color(0xFF43B5A8),
                  // backgroundColor: const Color(0xFFF5C000),
                  foregroundColor: Colors.black,
                  borderColor: Colors.transparent,
                  fontWeight: FontWeight.bold,
                  onPressed: () => context.push(RoutePaths.help),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: SecondaryButton(
                  label: 'View order details',
                  icon: Icons.receipt_long_rounded,
                  expand: true,
                  backgroundColor: const Color(0xFF43B5A8),
                  // backgroundColor: const Color(0xFFF5C000),
                  foregroundColor: Colors.black,
                  borderColor: Colors.transparent,
                  fontWeight: FontWeight.bold,
                  onPressed: () =>
                      context.push(RoutePaths.orderDetailsOf(order.id)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The live map, isolated so it is the only thing that rebuilds on a rider
/// GPS ping. It watches just the route and the rider position (the latter now
/// value-compared via `GeoPoint.==`, so an identical ping rebuilds nothing).
class _TrackingMap extends ConsumerWidget {
  const _TrackingMap({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = orderDetailProvider(orderId);
    final route = ref.watch(provider.select((s) => s.route));
    final riderLocation = ref.watch(provider.select((s) => s.riderLocation));

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      // Real route, drawn from the polyline the backend returns. The map SDK
      // carries its own native key. Prefers the live socket position.
      child: OrderRouteMap(route: route, riderLocation: riderLocation),
    );
  }
}

/// Pulsing scooter + live ETA at the top of the screen.
class _LiveStatusBanner extends StatefulWidget {
  const _LiveStatusBanner({required this.order});

  final Order order;

  @override
  State<_LiveStatusBanner> createState() => _LiveStatusBannerState();
}

class _LiveStatusBannerState extends State<_LiveStatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final live = order.status.isActive;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.primary,
        borderRadius: AppRadii.rLg,
        boxShadow: context.semantic.floatingShadow,
      ),
      child: Row(
        children: [
          RepaintBoundary(
            child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.08).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  live ? Icons.delivery_dining_rounded : Icons.check_rounded,
                  size: 26,
                  color: context.colors.surface,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // A booking accepted long before its window would otherwise
                  // read "Preparing your order" for something due tomorrow.
                  order.isBookingAt(DateTime.now())
                      ? 'Scheduled'
                      : order.status.label,
                  style: context.text.titleLarge!.copyWith(
                    color: context.colors.surface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  live
                      ? DeliveryPromise.forOrder(order)
                      : 'Thanks for shopping with Suvio',
                  style: context.text.bodyMedium!.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DropOtpCard extends StatelessWidget {
  const _DropOtpCard({required this.otp});

  final String otp;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.semantic.warningSoft,
        borderRadius: AppRadii.rLg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery OTP', style: context.text.titleMedium),
                Text(
                  'Share this with your rider at handover',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          Row(
            children: otp
                .split('')
                .map(
                  (digit) => Container(
                    margin: const EdgeInsets.only(left: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: AppRadii.rSm,
                    ),
                    child: Text(digit, style: context.text.priceLarge),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.partner, required this.orderId});

  final DeliveryPartner partner;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: context.semantic.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: context.colors.primary.withValues(alpha: 0.12),
            child: Icon(Icons.person_rounded, color: context.colors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partner.name, style: context.text.titleMedium),
                if (partner.rating > 0)
                  RatingStars(rating: partner.rating, size: 11),
                if (partner.vehicleNumber.isNotEmpty)
                  Text(partner.vehicleNumber, style: context.text.bodySmall),
              ],
            ),
          ),
          _RiderAction(
            icon: Icons.call_rounded,
            label: 'Call',
            // The rider's real phone comes populated on the order
            // (`dispatch.deliveryPartnerId.phone`). Enabled only when it is
            // present; disabled otherwise so we never dial a blank number.
            onTap: partner.phone.trim().isEmpty
                ? null
                : () => _callRider(context, partner.phone),
          ),
          const SizedBox(width: AppSpacing.sm),
          _RiderAction(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Message',
            // The rider is assigned by the time this card renders, so chat is
            // live. Open the real thread keyed on this order.
            onTap: () => context.push(
              RoutePaths.orderChatOf(orderId),
              extra: ChatArgs(riderName: partner.name),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the system dialer pre-filled with the rider's number. Works on both
  /// Android and iOS — a `tel:` URL is the platform-native "start a call" intent.
  Future<void> _callRider(BuildContext context, String rawPhone) async {
    // Keep digits and a single leading '+'; strip spaces, dashes, brackets so
    // the dialer gets a clean number.
    final cleaned = rawPhone.trim();
    final digits = cleaned.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.replaceAll('+', '').isEmpty) {
      AppToast.error(context, 'No phone number for this rider yet');
      return;
    }

    final uri = Uri(scheme: 'tel', path: digits);
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        AppToast.error(context, 'Could not open the dialer');
      }
    } catch (_) {
      if (context.mounted) AppToast.error(context, 'Could not open the dialer');
    }
  }
}

class _RiderAction extends StatelessWidget {
  const _RiderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  /// Null disables the action — same shape, dimmed, ignores taps.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: context.colors.primary),
          ),
        ),
      ),
    );
  }
}
