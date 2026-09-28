import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_labels.dart';
import '../../../di/app_providers.dart';
import '../../../di/service_providers.dart';
import '../../../domain/model/product_subscription.dart';
import '../../../navigation/route_paths.dart';
import '../../common/widgets/loaders/list_skeleton.dart';
import '../../common/widgets/misc/section_header.dart';
import '../../common/widgets/misc/sound_refresh_indicator.dart';
import '../../common/widgets/misc/staggered_entrance.dart';
import '../../common/widgets/states/empty_state_widget.dart';
import '../../common/widgets/states/error_state_widget.dart';
import 'subscriptions_provider.dart';

/// Recurring auto-delivery of a single product — the counterpart to monthly
/// lists, which never order on their own.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authProvider).isSignedIn;
    final state = ref.watch(subscriptionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      body: SafeArea(
        child: switch (true) {
          _ when !signedIn => EmptyStateWidget(
              icon: Icons.event_repeat_rounded,
              title: 'Sign in to manage subscriptions',
              message:
                  'Get milk, bread and daily essentials delivered automatically.',
              actionLabel: 'Sign in',
              onAction: () => context.push(RoutePaths.login),
            ),
          _ when state.isLoading && state.subscriptions.isEmpty =>
            const ListSkeleton(count: 4, height: 104),
          _ when state.failure != null && state.subscriptions.isEmpty =>
            ErrorStateWidget(
              failure: state.failure!,
              onRetry: () => ref.read(subscriptionsProvider.notifier).load(),
            ),
          _ when state.isEmpty => EmptyStateWidget(
              icon: Icons.event_repeat_rounded,
              title: 'No subscriptions yet',
              message:
                  'Open any product and tap "Subscribe" to have it delivered '
                  'on a schedule you choose.',
              actionLabel: 'Browse products',
              onAction: () => context.go(RoutePaths.home),
            ),
          _ => SoundRefreshIndicator(
              onRefresh: () => ref.read(subscriptionsProvider.notifier).load(),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  ...state.live.indexed.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: StaggeredEntrance(
                        index: entry.$1,
                        child: _SubscriptionCard(subscription: entry.$2),
                      ),
                    ),
                  ),
                  if (state.cancelled.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const SectionHeader(title: 'Cancelled'),
                    const SizedBox(height: AppSpacing.sm),
                    ...state.cancelled.map(
                      (subscription) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _SubscriptionCard(subscription: subscription),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        },
      ),
    );
  }
}

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard({required this.subscription});

  final ProductSubscription subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(subscriptionScheduleServiceProvider);
    final next = schedule.nextDelivery(subscription);

    return Material(
      color: context.colors.surface,
      borderRadius: AppRadii.rLg,
      child: InkWell(
        borderRadius: AppRadii.rLg,
        onTap: () =>
            context.push(RoutePaths.subscriptionDetailsOf(subscription.id)),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadii.rLg,
            border: Border.all(color: context.semantic.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subscription.itemName.isEmpty
                          ? 'Subscribed product'
                          : subscription.itemName,
                      style: context.text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusChip(status: subscription.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${subscription.quantity} × · ${schedule.describe(subscription)}',
                style: context.text.bodySmall?.copyWith(
                  color: context.semantic.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 16,
                    color: context.semantic.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      // A paused or cancelled series has no next delivery, and
                      // saying so is clearer than showing nothing at all.
                      next == null
                          ? subscription.isActive
                              ? 'No upcoming delivery scheduled'
                              : 'Deliveries are ${subscription.status.label.toLowerCase()}'
                          : 'Next: ${DateLabels.relativeDay(next.scheduledDate)}'
                              ' at ${DateLabels.clockFromWire(next.deliveryTime)}',
                      style: context.text.labelMedium?.copyWith(
                        color: next == null
                            ? context.semantic.textSecondary
                            : context.colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      SubscriptionStatus.active => (
          context.semantic.successSoft,
          context.semantic.success,
        ),
      SubscriptionStatus.paused => (
          context.semantic.warningSoft,
          context.semantic.warning,
        ),
      SubscriptionStatus.cancelled => (
          context.semantic.dangerSoft,
          context.semantic.danger,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.rPill,
      ),
      child: Text(
        status.label,
        style: context.text.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
