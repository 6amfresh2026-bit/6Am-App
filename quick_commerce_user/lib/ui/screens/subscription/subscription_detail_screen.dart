import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_labels.dart';
import '../../../di/service_providers.dart';
import '../../../domain/model/product_subscription.dart';
import '../../../navigation/route_paths.dart';
import '../../common/widgets/buttons/secondary_button.dart';
import '../../common/widgets/feedback/app_dialog.dart';
import '../../common/widgets/feedback/app_toast.dart';
import '../../common/widgets/loaders/full_page_loader.dart';
import '../../common/widgets/misc/quantity_stepper.dart';
import '../../common/widgets/misc/section_header.dart';
import '../../common/widgets/states/error_state_widget.dart';
import 'subscription_detail_provider.dart';

class SubscriptionDetailScreen extends ConsumerWidget {
  const SubscriptionDetailScreen({super.key, required this.subscriptionId});

  final String subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = subscriptionDetailProvider(subscriptionId);
    final state = ref.watch(provider);
    final subscription = state.subscription;

    if (state.isLoading && subscription == null) {
      return const Scaffold(body: FullPageLoader());
    }
    if (subscription == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorStateWidget(
          failure: state.failure!,
          onRetry: () => ref.read(provider.notifier).load(),
        ),
      );
    }

    final schedule = ref.watch(subscriptionScheduleServiceProvider);
    final upcoming = schedule.upcomingFrom(subscription);
    final history = schedule.historyBefore(subscription);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          subscription.itemName.isEmpty
              ? 'Subscription'
              : subscription.itemName,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ScheduleCard(
              subscription: subscription,
              description: schedule.describe(subscription),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!subscription.status.isCancelled) ...[
              _QuantityRow(
                subscriptionId: subscriptionId,
                subscription: subscription,
                enabled: !state.isSaving,
              ),
              const SizedBox(height: AppSpacing.md),
              _StatusActions(
                subscriptionId: subscriptionId,
                subscription: subscription,
                busy: state.isSaving,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            const SectionHeader(
              title: 'Upcoming deliveries',
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (upcoming.isEmpty)
              Text(
                subscription.isActive
                    // Only ~14 days are generated at a time and an hourly job
                    // extends them, so an empty list right after resuming is
                    // normal rather than a failure.
                    ? 'Nothing scheduled right now. The next dates are '
                        'generated automatically and will appear here shortly.'
                    : 'Deliveries are ${subscription.status.label.toLowerCase()}.',
                style: context.text.bodySmall?.copyWith(
                  color: context.semantic.textSecondary,
                ),
              )
            else
              ...upcoming.map(
                (occurrence) => _OccurrenceRow(
                  occurrence: occurrence,
                  busy: state.isSaving,
                  onCancel: () =>
                      _cancelOccurrence(context, ref, occurrence),
                  onOpenOrder: occurrence.hasOrder
                      ? () => context.push(
                            RoutePaths.orderDetailsOf(occurrence.orderId),
                          )
                      : null,
                ),
              ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(
                title: 'Earlier',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppSpacing.sm),
              ...history.map(
                (occurrence) => _OccurrenceRow(
                  occurrence: occurrence,
                  busy: state.isSaving,
                  onCancel: () {},
                  onOpenOrder: occurrence.hasOrder
                      ? () => context.push(
                            RoutePaths.orderDetailsOf(occurrence.orderId),
                          )
                      : null,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              'A delivery can be called off any time before midnight on the day '
              'it is due — the night before. After that the order is already on '
              'its way.',
              style: context.text.bodySmall?.copyWith(
                color: context.semantic.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelOccurrence(
    BuildContext context,
    WidgetRef ref,
    SubscriptionOccurrence occurrence,
  ) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Skip this delivery?',
      message:
          'Your ${DateLabels.dayMonth(occurrence.scheduledDate)} delivery will '
          'be cancelled. The rest of the subscription carries on as normal.',
      confirmLabel: 'Skip it',
      destructive: true,
      icon: Icons.event_busy_rounded,
    );
    if (!confirmed || !context.mounted) return;

    final notifier =
        ref.read(subscriptionDetailProvider(subscriptionId).notifier);
    final ok = await notifier.cancelOccurrence(occurrence);
    if (!context.mounted) return;

    if (ok) {
      AppToast.success(context, 'Delivery skipped');
      return;
    }
    // The server is the authority on the cutoff — if it refused, show its own
    // wording rather than a generic failure.
    AppToast.error(
      context,
      ref.read(subscriptionDetailProvider(subscriptionId)).failure?.message ??
          'Could not skip that delivery.',
    );
    notifier.clearFailure();
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.subscription,
    required this.description,
  });

  final ProductSubscription subscription;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.semantic.surfaceAlt,
        borderRadius: AppRadii.rLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description, style: context.text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Started ${DateLabels.dayMonthYear(subscription.startDate)} · '
            'Paid by ${subscription.paymentMethod.label}',
            style: context.text.bodySmall?.copyWith(
              color: context.semantic.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityRow extends ConsumerWidget {
  const _QuantityRow({
    required this.subscriptionId,
    required this.subscription,
    required this.enabled,
  });

  final String subscriptionId;
  final ProductSubscription subscription;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier =
        ref.read(subscriptionDetailProvider(subscriptionId).notifier);

    return Row(
      children: [
        Expanded(
          child: Text('Quantity per delivery', style: context.text.titleSmall),
        ),
        QuantityStepper(
          quantity: subscription.quantity,
          canIncrement: enabled,
          onIncrement: enabled
              ? () => notifier.setQuantity(subscription.quantity + 1)
              : () {},
          // One unit is the floor: a zero-quantity subscription is rejected
          // server-side, and cancelling is the real "stop" action.
          onDecrement: enabled && subscription.quantity > 1
              ? () => notifier.setQuantity(subscription.quantity - 1)
              : () {},
        ),
      ],
    );
  }
}

class _StatusActions extends ConsumerWidget {
  const _StatusActions({
    required this.subscriptionId,
    required this.subscription,
    required this.busy,
  });

  final String subscriptionId;
  final ProductSubscription subscription;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier =
        ref.read(subscriptionDetailProvider(subscriptionId).notifier);

    return Row(
      children: [
        Expanded(
          child: SecondaryButton(
            label: subscription.canResume ? 'Resume' : 'Pause',
            icon: subscription.canResume
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            expand: true,
            isLoading: busy,
            onPressed: busy
                ? null
                : () => subscription.canResume
                    ? notifier.resume()
                    : notifier.pause(),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: SecondaryButton(
            label: 'Cancel',
            icon: Icons.close_rounded,
            expand: true,
            destructive: true,
            onPressed: busy ? null : () => _cancel(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Cancel this subscription?',
      message:
          'All upcoming deliveries will be cancelled. This cannot be undone — '
          'you would need to subscribe again.',
      confirmLabel: 'Cancel subscription',
      cancelLabel: 'Keep it',
      destructive: true,
      icon: Icons.event_busy_rounded,
    );
    if (!confirmed || !context.mounted) return;

    final ok = await ref
        .read(subscriptionDetailProvider(subscriptionId).notifier)
        .cancelSubscription();
    if (!context.mounted) return;
    AppToast.show(
      context,
      ok ? 'Subscription cancelled' : 'Could not cancel that subscription.',
    );
  }
}

class _OccurrenceRow extends StatelessWidget {
  const _OccurrenceRow({
    required this.occurrence,
    required this.busy,
    required this.onCancel,
    this.onOpenOrder,
  });

  final SubscriptionOccurrence occurrence;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback? onOpenOrder;

  @override
  Widget build(BuildContext context) {
    // Recomputed on every build so the cancel action disappears the moment the
    // delivery day begins, without needing a refresh.
    final canCancel = occurrence.canCancelAt(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(_icon, size: 20, color: _color(context)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateLabels.relativeDay(occurrence.scheduledDate)} · '
                  '${DateLabels.clockFromWire(occurrence.deliveryTime)}',
                  style: context.text.bodyMedium,
                ),
                Text(
                  _subtitle,
                  style: context.text.labelSmall?.copyWith(
                    color: context.semantic.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onOpenOrder != null)
            TextButton(onPressed: onOpenOrder, child: const Text('View order'))
          else if (canCancel)
            TextButton(
              onPressed: busy ? null : onCancel,
              child: const Text('Skip'),
            ),
        ],
      ),
    );
  }

  String get _subtitle => switch (occurrence.status) {
        OccurrenceStatus.scheduled =>
          occurrence.canCancelAt(DateTime.now()) ? 'Scheduled' : 'Being prepared',
        OccurrenceStatus.orderPlaced => 'Order placed',
        OccurrenceStatus.cancelled => occurrence.cancelReason.isEmpty
            ? 'Cancelled'
            : 'Cancelled — ${occurrence.cancelReason}',
        OccurrenceStatus.failed => occurrence.failureReason.isEmpty
            ? 'Could not be placed'
            : 'Could not be placed — ${occurrence.failureReason}',
      };

  IconData get _icon => switch (occurrence.status) {
        OccurrenceStatus.scheduled => Icons.schedule_rounded,
        OccurrenceStatus.orderPlaced => Icons.check_circle_rounded,
        OccurrenceStatus.cancelled => Icons.cancel_outlined,
        OccurrenceStatus.failed => Icons.error_outline_rounded,
      };

  Color _color(BuildContext context) => switch (occurrence.status) {
        OccurrenceStatus.scheduled => context.colors.primary,
        OccurrenceStatus.orderPlaced => context.semantic.success,
        OccurrenceStatus.cancelled => context.semantic.textSecondary,
        OccurrenceStatus.failed => context.semantic.danger,
      };
}
