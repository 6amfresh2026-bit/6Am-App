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
import '../../common/widgets/feedback/app_toast.dart';
import '../../common/widgets/loaders/list_skeleton.dart';
import '../../common/widgets/misc/section_header.dart';
import '../../common/widgets/misc/sound_refresh_indicator.dart';
import '../../common/widgets/misc/staggered_entrance.dart';
import '../../common/widgets/states/empty_state_widget.dart';
import '../../common/widgets/states/error_state_widget.dart';
import 'subscriptions_provider.dart';

/// Recurring auto-delivery of a single product — the counterpart to monthly
/// lists, which never order on their own.
class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  /// When set, only subscriptions started on or after this date are shown.
  DateTime? _startedFrom;

  Future<void> _pickStartedFrom(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startedFrom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _startedFrom = picked);
  }

  List<ProductSubscription> _filtered(List<ProductSubscription> list) {
    final from = _startedFrom;
    if (from == null) return list;
    final cutoff = DateTime(from.year, from.month, from.day);
    return list.where((s) => !s.startDate.isBefore(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authProvider).isSignedIn;
    final state = ref.watch(subscriptionsProvider);
    final live = _filtered(state.live);
    final cancelled = _filtered(state.cancelled);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          if (signedIn)
            IconButton(
              icon: Icon(
                _startedFrom == null
                    ? Icons.calendar_today_outlined
                    : Icons.event_available_rounded,
                color: _startedFrom == null ? null : context.colors.primary,
              ),
              tooltip: 'Filter by start date',
              onPressed: () => _pickStartedFrom(context),
            ),
        ],
      ),
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
                  if (_startedFrom != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _FilterChip(
                        date: _startedFrom!,
                        onClear: () => setState(() => _startedFrom = null),
                      ),
                    ),
                  if (state.live.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _MasterToggleRow(subscriptions: state.live),
                    ),
                  if (live.isEmpty && _startedFrom != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xl,
                      ),
                      child: Center(
                        child: Text(
                          'No subscriptions started on or after that date.',
                          style: context.text.bodyMedium?.copyWith(
                            color: context.semantic.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ...live.indexed.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: StaggeredEntrance(
                        index: entry.$1,
                        child: _SubscriptionCard(subscription: entry.$2),
                      ),
                    ),
                  ),
                  if (cancelled.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const SectionHeader(title: 'Cancelled'),
                    const SizedBox(height: AppSpacing.sm),
                    ...cancelled.map(
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.date, required this.onClear});

  final DateTime date;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: const Icon(Icons.calendar_today_outlined, size: 16),
        label: Text('Started from ${DateLabels.dayMonthYear(date)}'),
        onDeleted: onClear,
        deleteIcon: const Icon(Icons.close_rounded, size: 16),
      ),
    );
  }
}

/// The single switch that pauses or resumes every live subscription at once.
/// Reads as "on" only when every one of them is already active.
class _MasterToggleRow extends ConsumerWidget {
  const _MasterToggleRow({required this.subscriptions});

  final List<ProductSubscription> subscriptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allActive = subscriptions.every((s) => s.isActive);
    final busy = ref.watch(subscriptionsProvider).isLoading;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.semantic.surfaceAlt,
        borderRadius: AppRadii.rLg,
      ),
      child: Row(
        children: [
          Icon(
            allActive ? Icons.notifications_active_outlined : Icons.pause_circle_outline,
            color: context.semantic.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              allActive ? 'All subscriptions active' : 'Some subscriptions paused',
              style: context.text.labelLarge,
            ),
          ),
          Switch(
            value: allActive,
            onChanged: busy
                ? null
                : (value) => ref.read(subscriptionsProvider.notifier).setAllStatus(
                      value ? SubscriptionStatus.active : SubscriptionStatus.paused,
                    ),
          ),
        ],
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
                  if (subscription.status.isCancelled)
                    _StatusChip(status: subscription.status)
                  else
                    _SubscriptionToggle(subscription: subscription),
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

/// Per-card pause/resume switch — turns off just this one subscription
/// without opening its detail screen.
class _SubscriptionToggle extends ConsumerStatefulWidget {
  const _SubscriptionToggle({required this.subscription});

  final ProductSubscription subscription;

  @override
  ConsumerState<_SubscriptionToggle> createState() => _SubscriptionToggleState();
}

class _SubscriptionToggleState extends ConsumerState<_SubscriptionToggle> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    final ok = await ref.read(subscriptionsProvider.notifier).setStatus(
          widget.subscription.id,
          value ? SubscriptionStatus.active : SubscriptionStatus.paused,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      AppToast.error(
        context,
        ref.read(subscriptionsProvider).failure?.message ??
            'Could not update that subscription.',
      );
      ref.read(subscriptionsProvider.notifier).clearFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Switch(
          value: widget.subscription.isActive,
          onChanged: _busy ? null : _toggle,
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
