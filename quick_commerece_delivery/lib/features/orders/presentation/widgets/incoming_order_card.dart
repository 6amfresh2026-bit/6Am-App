import 'package:flutter/material.dart';

import 'package:food_user_application/core/theme/app_colors.dart';
import '../../data/models/delivery_order.dart';

/// The incoming-order alert card.
///
/// Deliberately free of Riverpod, ScreenUtil and every other plugin: it is
/// rendered by BOTH the in-app [IncomingOrderScreen] and the background overlay
/// bubble, and the overlay runs in its own Flutter engine with no provider
/// scope and no ScreenUtil init. Sizes are plain logical pixels for the same
/// reason — they are already density-independent, and the card scrolls in both
/// hosts so a large system font size grows it instead of clipping it.
class IncomingOrderCard extends StatelessWidget {
  const IncomingOrderCard({
    super.key,
    required this.order,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.onAccept,
    required this.onReject,
    this.etaMins,
    this.busy = false,
  });

  final DeliveryOrder order;
  final int secondsLeft;

  /// The full offer window, so the progress bar is a true fraction. This used
  /// to be hardcoded to 45 while the window came from the backend, so the bar
  /// started part-filled (or pinned full) whenever the two disagreed.
  final int totalSeconds;

  /// Null disables the button — used while a tap is in flight so neither
  /// action can be fired twice.
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  /// Live routed ETA from `/orders/:id/route` when it has come back; falls
  /// back to the order's own estimate.
  final double? etaMins;

  /// True between the tap and the API answering.
  final bool busy;

  static const _cream = Color(0xFFFFFBEB);

  String get _etaLabel {
    final mins = etaMins ?? order.tripDurationMins;
    if (mins == null || mins <= 0) return '—';
    final rounded = mins.round();
    return '$rounded–${rounded + 5} mins';
  }

  static String _km(double? value) =>
      (value == null || value <= 0) ? '—' : '${value.toStringAsFixed(1)} km';

  /// Falls back to the tail of the Mongo id when the readable code is missing —
  /// the whole 24-character id is not something a partner can read off a card.
  String get _orderRef {
    if (order.orderCode.isNotEmpty) return order.orderCode;
    final id = order.id;
    return id.length > 6
        ? '#${id.substring(id.length - 6).toUpperCase()}'
        : id;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _pickupRow(),
                      const SizedBox(height: 18),
                      _dropRow(),
                      const SizedBox(height: 18),
                      _itemsRow(),
                      const SizedBox(height: 18),
                      _valueRow(),
                      const SizedBox(height: 18),
                      _earningsStrip(),
                      const SizedBox(height: 18),
                      _actions(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _bellBadge(),
      ],
    );
  }

  // -------------------------------------------------------------- header

  Widget _bellBadge() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.5),
            blurRadius: 20,
          ),
        ],
      ),
      child: const Icon(
        Icons.notifications_active_rounded,
        size: 38,
        color: AppColors.onPrimary,
      ),
    );
  }

  Widget _header() {
    final fraction = totalSeconds <= 0
        ? 0.0
        : (secondsLeft / totalSeconds).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 18),
      decoration: const BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'New Order Available!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.lightTextPrimary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Accept before the time runs out',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 18, color: AppColors.onPrimary),
                const SizedBox(width: 8),
                // Flexible, so a large system font size wraps the label instead
                // of pushing it off the edge of the pill.
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onPrimary,
                      ),
                      children: [
                        const TextSpan(text: 'Accept within '),
                        TextSpan(
                          text: '$secondsLeft',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.successText,
                          ),
                        ),
                        const TextSpan(text: ' sec'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Ticks once a second; the tween carries it smoothly between ticks so
          // the bar drains continuously rather than in visible steps.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: fraction, end: fraction),
            duration: const Duration(milliseconds: 950),
            curve: Curves.linear,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: Colors.black.withValues(alpha: 0.07),
                valueColor: AlwaysStoppedAnimation(
                  value <= 0.3 ? AppColors.error : AppColors.success,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Order $_orderRef',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- rows

  Widget _infoRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required Widget content,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              content,
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing],
      ],
    );
  }

  Widget _placeContent(String name, String address) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.lightTextPrimary,
          ),
        ),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.lightTextSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _distanceChip(double? km) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Text(
        _km(km),
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.successText,
        ),
      ),
    );
  }

  Widget _pickupRow() => _infoRow(
        icon: Icons.storefront_rounded,
        iconBg: AppColors.primaryLight,
        iconColor: AppColors.onPrimary,
        label: 'Pickup from',
        content: _placeContent(
          order.store.name.isNotEmpty ? order.store.name : 'Store',
          order.store.address,
        ),
        trailing: _distanceChip(order.pickupDistanceKm),
      );

  Widget _dropRow() => _infoRow(
        icon: Icons.person_rounded,
        iconBg: AppColors.successBg,
        iconColor: AppColors.successText,
        label: 'Deliver to',
        content: _placeContent(
          order.customerName.isNotEmpty ? order.customerName : 'Customer',
          order.deliveryAddress.fullAddress,
        ),
        trailing: _distanceChip(order.tripDistanceKm),
      );

  Widget _itemsRow() => _infoRow(
        icon: Icons.inventory_2_rounded,
        iconBg: AppColors.lightSurfaceVariant,
        iconColor: AppColors.lightTextPrimary,
        label: 'Items',
        content: Text(
          order.items.isEmpty ? 'Items on the way' : order.itemsSummary,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.lightTextPrimary,
          ),
        ),
        trailing: _thumbnails(),
      );

  /// Up to three product photos plus a "+N" pill.
  ///
  /// Uses [Image.network] rather than the app's usual CachedNetworkImage: this
  /// card also renders inside the overlay engine, where plugin-backed caching
  /// (path_provider) is not guaranteed to be registered. A thumbnail is
  /// decoration — it must never be the thing that takes the alert down.
  Widget _thumbnails() {
    final withImages =
        order.items.where((i) => (i.image ?? '').isNotEmpty).toList();
    if (order.items.isEmpty) return const SizedBox.shrink();

    final shown = withImages.take(3).toList();
    final remaining = order.items.length - shown.length;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in shown) ...[
            _thumbBox(
              child: Image.network(
                item.image!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.shopping_bag_rounded,
                  size: 18,
                  color: AppColors.lightTextSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (remaining > 0)
            _thumbBox(
              child: Center(
                child: Text(
                  '+$remaining',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _thumbBox({required Widget child}) {
    return Container(
      width: 38,
      height: 38,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: child,
    );
  }

  Widget _valueRow() => _infoRow(
        icon: Icons.currency_rupee_rounded,
        iconBg: AppColors.errorBg,
        iconColor: AppColors.errorText,
        label: 'Order Value',
        content: Text(
          '₹${order.total.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.lightTextPrimary,
          ),
        ),
        trailing: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _paymentChip(),
        ),
      );

  /// Payment state carries an icon as well as a colour — colour alone would
  /// leave a colour-blind rider unable to tell cash from prepaid, which is the
  /// difference between collecting money at the door and not.
  Widget _paymentChip() {
    final isCash = order.isCashOnDelivery;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCash ? AppColors.pendingBg : AppColors.successBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCash ? Icons.payments_rounded : Icons.credit_card_rounded,
            size: 16,
            color: isCash ? AppColors.pendingText : AppColors.successText,
          ),
          const SizedBox(width: 6),
          Text(
            isCash ? 'Cash' : 'Prepaid',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isCash ? AppColors.pendingText : AppColors.successText,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- earnings

  Widget _earningsStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Row(
        children: [
          _statCell(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.successText,
            label: 'Your Earning',
            value: '₹${order.riderEarning.toStringAsFixed(0)}',
            valueColor: AppColors.successText,
            emphasise: true,
          ),
          _divider(),
          _statCell(
            icon: Icons.route_rounded,
            iconColor: AppColors.primaryDark,
            label: 'Total Distance',
            value: _km(order.tripDistanceKm),
          ),
          _divider(),
          _statCell(
            icon: Icons.schedule_rounded,
            iconColor: AppColors.lightTextPrimary,
            label: 'Est. Delivery',
            value: _etaLabel,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 34,
        color: AppColors.primaryLight,
      );

  Widget _statCell({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color valueColor = AppColors.lightTextPrimary,
    bool emphasise = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: emphasise ? 19 : 14,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ actions

  Widget _actions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 4,
              child: Semantics(
                button: true,
                label: 'Reject order $_orderRef',
                child: _ActionButton(
                  onTap: onReject,
                  height: 62,
                  background: Colors.white,
                  border: AppColors.error,
                  child: const _ActionLabel(
                    icon: Icons.cancel_outlined,
                    text: 'REJECT',
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Semantics(
                button: true,
                label:
                    'Accept order $_orderRef for ₹${order.riderEarning.toStringAsFixed(0)}',
                child: _ActionButton(
                  onTap: onAccept,
                  height: 62,
                  background: AppColors.successText,
                  child: busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const _ActionLabel(
                          icon: Icons.check_circle_outline_rounded,
                          text: 'ACCEPT ORDER',
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_user_rounded,
                size: 15, color: AppColors.primaryDark),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                order.isCashOnDelivery
                    ? 'Collect ₹${order.total.toStringAsFixed(0)} in cash at delivery'
                    : "We'll notify the customer once you accept",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// A null [onTap] both disables the gesture and dims the button, so "already
/// tapped" and "expired" are visible rather than only unresponsive.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.onTap,
    required this.height,
    required this.background,
    required this.child,
    this.border,
  });

  final VoidCallback? onTap;
  final double height;
  final Color background;
  final Color? border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border:
                  border == null ? null : Border.all(color: border!, width: 2),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Shown for a beat after the countdown runs out, so the alert doesn't just
/// vanish and leave the rider wondering whether they missed a tap.
class IncomingOrderExpiredCard extends StatelessWidget {
  const IncomingOrderExpiredCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_off_rounded, size: 40, color: AppColors.error),
          SizedBox(height: 12),
          Text(
            'Order expired',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.lightTextPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'This order has been offered to another partner.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
