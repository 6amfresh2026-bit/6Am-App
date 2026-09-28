import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_labels.dart';
import '../../../di/app_providers.dart';
import '../../../domain/model/monthly_list.dart';
import '../../../navigation/route_paths.dart';
import '../../common/widgets/feedback/app_dialog.dart';
import '../../common/widgets/feedback/app_toast.dart';
import '../../common/widgets/loaders/list_skeleton.dart';
import '../../common/widgets/misc/sound_refresh_indicator.dart';
import '../../common/widgets/misc/staggered_entrance.dart';
import '../../common/widgets/states/empty_state_widget.dart';
import '../../common/widgets/states/error_state_widget.dart';
import 'monthly_lists_provider.dart';

/// The customer's saved monthly baskets.
///
/// These are re-ordered on demand — deliberately not a subscription. The copy
/// says so, because the two features sit next to each other in the account.
class MonthlyListsScreen extends ConsumerWidget {
  const MonthlyListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authProvider).isSignedIn;
    final state = ref.watch(monthlyListsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly lists')),
      body: SafeArea(
        child: switch (true) {
          _ when !signedIn => EmptyStateWidget(
              icon: Icons.playlist_add_check_rounded,
              title: 'Sign in to build a monthly list',
              message:
                  'Save the things you buy every month and re-order them in one tap.',
              actionLabel: 'Sign in',
              onAction: () => context.push(RoutePaths.login),
            ),
          _ when state.isLoading && state.lists.isEmpty =>
            const ListSkeleton(count: 4, height: 96),
          _ when state.failure != null && state.lists.isEmpty => ErrorStateWidget(
              failure: state.failure!,
              onRetry: () => ref.read(monthlyListsProvider.notifier).load(),
            ),
          _ when state.isEmpty => EmptyStateWidget(
              icon: Icons.playlist_add_check_rounded,
              title: 'No monthly lists yet',
              message:
                  'Fill your cart, then tap "Save as monthly list" to re-order '
                  'the same items whenever you like.',
              actionLabel: 'Start shopping',
              onAction: () => context.go(RoutePaths.home),
            ),
          _ => SoundRefreshIndicator(
              onRefresh: () => ref.read(monthlyListsProvider.notifier).load(),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: state.lists.length + 1,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  if (index == 0) return const _HowItWorksNote();
                  final list = state.lists[index - 1];
                  return StaggeredEntrance(
                    index: index - 1,
                    child: _MonthlyListCard(
                      list: list,
                      onTap: () => context.push(
                        RoutePaths.monthlyListDetailsOf(list.id),
                      ),
                      onDelete: () => _confirmDelete(context, ref, list),
                    ),
                  );
                },
              ),
            ),
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MonthlyList list,
  ) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete this list?',
      message:
          '"${list.name}" will be removed. Orders already placed from it are '
          'not affected.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !context.mounted) return;

    final ok = await ref.read(monthlyListsProvider.notifier).delete(list.id);
    if (!context.mounted) return;
    if (ok) {
      AppToast.success(context, 'List deleted');
    } else {
      AppToast.error(
        context,
        ref.read(monthlyListsProvider).failure?.message ??
            'Could not delete that list.',
      );
    }
  }
}

/// Names the difference between a monthly list and a subscription up front —
/// the two are easy to confuse and behave very differently.
class _HowItWorksNote extends StatelessWidget {
  const _HowItWorksNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.08),
        borderRadius: AppRadii.rMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: context.colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Nothing is ordered automatically. Open a list and tap "Order '
              'this month" whenever you want it delivered.',
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyListCard extends StatelessWidget {
  const _MonthlyListCard({
    required this.list,
    required this.onTap,
    required this.onDelete,
  });

  final MonthlyList list;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadii.rLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadii.rLg,
            border: Border.all(color: context.semantic.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadii.rMd,
                ),
                child: Icon(
                  Icons.playlist_add_check_rounded,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            list.name,
                            style: context.text.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!list.isActive) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const _PausedChip(),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${list.itemCount} item${list.itemCount == 1 ? '' : 's'}'
                      '${list.restaurantName.isEmpty ? '' : ' · ${list.restaurantName}'}',
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (list.lastOrderedAt != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Last ordered ${DateLabels.dayMonth(list.lastOrderedAt!)}',
                        style: context.text.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: context.semantic.danger,
                tooltip: 'Delete list',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PausedChip extends StatelessWidget {
  const _PausedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: context.semantic.warningSoft,
        borderRadius: AppRadii.rPill,
      ),
      child: Text(
        'Paused',
        style: context.text.labelSmall?.copyWith(
          color: context.semantic.warning,
        ),
      ),
    );
  }
}
