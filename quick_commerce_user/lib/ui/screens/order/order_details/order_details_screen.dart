import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/num_extensions.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../di/app_providers.dart';
import '../../../../di/repository_providers.dart';
import '../../../../domain/model/order.dart';
import '../../../../domain/model/order_status.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/buttons/secondary_button.dart';
import '../../../common/widgets/feedback/app_bottom_sheet.dart';
import '../../../common/widgets/feedback/app_dialog.dart';
import '../../../common/widgets/feedback/app_toast.dart';
import '../../../common/widgets/loaders/full_page_loader.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import '../../../common/widgets/misc/rating_stars.dart';
import '../../../common/widgets/states/error_state_widget.dart';
import '../order_tracking/widgets/tracking_timeline.dart';
import '../widgets/order_status_chip.dart';
import 'order_details_provider.dart';

class OrderDetailsScreen extends ConsumerWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderDetailProvider(orderId));
    final order = state.order;

    if (state.isLoading && order == null) {
      return const Scaffold(body: FullPageLoader(message: 'Loading order…'));
    }
    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorStateWidget(
          failure: state.failure!,
          onRetry: () => ref.read(orderDetailProvider(orderId).notifier).load(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(order.displayId)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.sellerName.isEmpty
                              ? 'Suvio Quick'
                              : order.sellerName,
                          style: context.text.headlineSmall,
                        ),
                        Text(
                          'Placed on ${_dateTime(order.placedAt)}',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  OrderStatusChip(status: order.status),
                ],
              ),
            ),
            if (order.status.isActive)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: PrimaryButton(
                  label: 'Track this order',
                  icon: Icons.delivery_dining_rounded,
                  onPressed: () =>
                      context.push(RoutePaths.orderTrackingOf(order.id)),
                ),
              ),
            _Section(
              title: 'Status',
              child: TrackingTimeline(order: order),
            ),
            _Section(
              title: '${order.itemCount} items',
              child: Column(
                children: [
                  for (final line in order.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: AppRadii.rSm,
                            child: AppNetworkImage(
                              url: line.imageUrl,
                              height: 44,
                              width: 44,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(line.name, style: context.text.bodyLarge),
                                Text(
                                  [
                                    if (line.variantName.isNotEmpty)
                                      line.variantName,
                                    // The delivered figure, which is what the
                                    // bill charges for.
                                    '×${line.quantity}',
                                    ...line.addonNames,
                                  ].join(' · '),
                                  style: context.text.bodySmall,
                                ),
                                // A basket that silently arrives smaller and
                                // cheaper reads as a mistake, or as theft,
                                // depending which way it is noticed first.
                                if (line.shortPickLabel != null)
                                  Text(
                                    '${line.shortPickLabel} — '
                                    'the rest was refunded',
                                    style: context.text.labelSmall?.copyWith(
                                      color: context.semantic.warning,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            line.lineTotal.asCurrency,
                            style: context.text.titleSmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _Section(
              title: 'Bill summary',
              child: Column(
                children: [
                  _BillRow(label: 'Item total', value: order.pricing.subtotal),
                  _BillRow(
                    label: 'Delivery',
                    value:
                        order.pricing.deliveryFee +
                        order.pricing.deliveryFeeGst,
                    free: order.pricing.deliveryFee <= 0,
                  ),
                  _BillRow(
                    label: 'Platform fee',
                    value: order.pricing.platformFee,
                  ),
                  _BillRow(label: 'Taxes & GST', value: order.pricing.tax),
                  if (order.pricing.discount > 0)
                    _BillRow(
                      label: 'Coupon ${order.pricing.couponCode ?? ''}'.trim(),
                      value: order.pricing.discount,
                      discount: true,
                    ),
                  Divider(color: context.semantic.border),
                  const SizedBox(height: AppSpacing.sm),
                  _BillRow(
                    label: 'Total paid',
                    value: order.pricing.total,
                    emphasise: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 15,
                        color: context.semantic.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Paid via ${order.paymentMethod.label}',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (order.address != null)
              _Section(
                title: 'Delivered to',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 17,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.address!.label.wireValue,
                            style: context.text.titleSmall,
                          ),
                          Text(
                            order.address!.fullLine,
                            style: context.text.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (order.status == OrderStatus.delivered && !order.isRated)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: PrimaryButton(
                  label: 'Rate your order',
                  icon: Icons.star_rounded,
                  onPressed: () => _rate(context, ref, order),
                ),
              ),
            if (order.isRated)
              _Section(
                title: 'Your rating',
                child: RatingStars(rating: order.restaurantRating!, size: 18),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  SecondaryButton(
                    label: 'Reorder these items',
                    icon: Icons.replay_rounded,
                    expand: true,
                    onPressed: () => _reorder(context, ref, order),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    label: 'Get help with this order',
                    icon: Icons.support_agent_rounded,
                    expand: true,
                    tonal: false,
                    onPressed: () => context.push(RoutePaths.help),
                  ),
                  if (order.status.isCancellable) ...[
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      label: 'Cancel order',
                      icon: Icons.cancel_outlined,
                      expand: true,
                      tonal: false,
                      destructive: true,
                      isLoading: state.isMutating,
                      onPressed: () => _cancel(context, ref),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      icon: Icons.cancel_outlined,
      title: 'Cancel this order?',
      message:
          'We will stop packing it right away. Any payment is refunded to the '
          'original method.',
      confirmLabel: 'Cancel order',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref
          .read(orderDetailProvider(orderId).notifier)
          .cancel('Cancelled from the app');
      if (context.mounted)
        AppToast.success(context, 'Your order was cancelled');
      ref.invalidate(orderDetailProvider(orderId));
    } catch (_) {
      if (context.mounted) {
        AppToast.error(context, 'We could not cancel this order');
      }
    }
  }

  Future<void> _rate(BuildContext context, WidgetRef ref, Order order) async {
    final rating = await _RatingSheet.show(context, order: order);
    if (rating == null || !context.mounted) return;

    try {
      await ref
          .read(orderDetailProvider(orderId).notifier)
          .rate(
            sellerRating: rating.seller,
            riderRating: order.deliveryPartner == null ? null : rating.rider,
            comment: rating.comment,
          );
      if (context.mounted) AppToast.success(context, 'Thanks for the feedback');
    } catch (_) {
      if (context.mounted) {
        AppToast.error(context, 'Could not save your rating');
      }
    }
  }

  /// Re-adds the order's items from the live catalog, so prices and stock are
  /// current rather than the snapshot stored on the order.
  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final repository = ref.read(productRepositoryProvider);
    var added = 0;
    var missing = 0;

    for (final line in order.lines) {
      try {
        final product = await repository.getById(
          line.itemId,
          sellerId: order.sellerId,
        );
        if (!product.isPurchasable) {
          missing++;
          continue;
        }
        await ref
            .read(cartProvider.notifier)
            .add(product, quantity: line.quantity, skipVariantPrompt: true);
        added++;
      } catch (_) {
        missing++;
      }
      if (!context.mounted) return;
    }

    if (added == 0) {
      AppToast.error(context, 'None of these items are available right now');
      return;
    }

    AppToast.success(
      context,
      missing == 0
          ? '$added items added to your cart'
          : '$added added · $missing unavailable',
    );
    context.go(RoutePaths.cart);
  }

  static String _dateTime(DateTime time) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '${time.day} ${months[time.month - 1]} ${time.year}, '
        '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: context.semantic.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.titleLarge),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    required this.value,
    this.discount = false,
    this.free = false,
    this.emphasise = false,
  });

  final String label;
  final double value;
  final bool discount;
  final bool free;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: emphasise
                ? context.text.titleMedium
                : context.text.bodyMedium,
          ),
          if (free)
            Text(
              'FREE',
              style: context.text.badgeLabel.copyWith(
                color: context.semantic.success,
              ),
            )
          else
            Text(
              '${discount ? '− ' : ''}${value.asCurrency}',
              style: emphasise
                  ? context.text.price
                  : context.text.titleSmall!.copyWith(
                      color: discount ? context.semantic.success : null,
                    ),
            ),
        ],
      ),
    );
  }
}

typedef _RatingDraft = ({int seller, int rider, String comment});

class _RatingSheet extends StatefulWidget {
  const _RatingSheet({required this.order});

  final Order order;

  static Future<_RatingDraft?> show(
    BuildContext context, {
    required Order order,
  }) => AppBottomSheet.show<_RatingDraft>(
    context,
    title: 'How did we do?',
    subtitle: 'Your rating helps the whole Suvio network',
    child: _RatingSheet(order: order),
  );

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  final _comment = TextEditingController();
  int _seller = 0;
  int _rider = 0;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRider = widget.order.deliveryPartner != null;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your order', style: context.text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: RatingInput(
              rating: _seller,
              onChanged: (value) => setState(() => _seller = value),
            ),
          ),
          if (hasRider) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Your rider, ${widget.order.deliveryPartner!.name}',
              style: context.text.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: RatingInput(
                rating: _rider,
                onChanged: (value) => setState(() => _rider = value),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _comment,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Anything you would like us to know?',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Submit rating',
            onPressed: _seller == 0 || (hasRider && _rider == 0)
                ? null
                : () => Navigator.of(context).pop((
                    seller: _seller,
                    rider: _rider,
                    comment: _comment.text.trim(),
                  )),
          ),
        ],
      ),
    );
  }
}
