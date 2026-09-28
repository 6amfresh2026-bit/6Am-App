import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../di/app_providers.dart';
import '../../../domain/model/notification_item.dart';
import '../../../navigation/route_paths.dart';
import '../../common/widgets/loaders/list_skeleton.dart';
import '../../common/widgets/misc/section_header.dart';
import '../../common/widgets/states/empty_state_widget.dart';
import '../../common/widgets/states/error_state_widget.dart';
import 'notifications_provider.dart';
import '../../common/widgets/misc/sound_refresh_indicator.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authProvider).isSignedIn;
    final state = ref.watch(notificationsProvider);
    final controller = ref.read(notificationsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: controller.markAllRead,
              child: Text(
                'Mark all read',
                style: context.text.labelMedium!
                    .copyWith(color: context.colors.primary),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: !signedIn
            ? EmptyStateWidget(
                icon: Icons.notifications_off_outlined,
                title: 'Sign in for updates',
                message:
                    'Order updates and offers land here once you are signed in.',
                actionLabel: 'Sign in',
                onAction: () => context.push(RoutePaths.login),
              )
            : switch (state) {
                _ when state.isLoading && state.items.isEmpty =>
                  const ListSkeleton(count: 6, height: 76),
                _ when state.failure != null && state.items.isEmpty =>
                  ErrorStateWidget(
                    failure: state.failure!,
                    onRetry: controller.load,
                  ),
                _ when state.isEmpty => const EmptyStateWidget(
                    icon: Icons.notifications_none_rounded,
                    title: 'Nothing new',
                    message:
                        'Order updates, delivery alerts and offers will show up here.',
                  ),
                _ => SoundRefreshIndicator(
                    onRefresh: controller.load,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      children: [
                        if (state.today.isNotEmpty) ...[
                          const SectionHeader(title: 'Today'),
                          for (final item in state.today)
                            _NotificationTile(
                              item: item,
                              onTap: () => controller.markRead(item.id),
                              onDismiss: () => controller.dismiss(item.id),
                            ),
                        ],
                        if (state.earlier.isNotEmpty) ...[
                          const SectionHeader(title: 'Earlier'),
                          for (final item in state.earlier)
                            _NotificationTile(
                              item: item,
                              onTap: () => controller.markRead(item.id),
                              onDismiss: () => controller.dismiss(item.id),
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.onDismiss,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        color: context.semantic.dangerSoft,
        child: Icon(Icons.delete_outline_rounded, color: context.semantic.danger),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          color: item.isRead
              ? null
              : context.colors.primary.withValues(alpha: 0.04),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.10),
                  borderRadius: AppRadii.rSm,
                ),
                child: Icon(
                  _icon(item),
                  size: 17,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: item.isRead
                          ? context.text.titleSmall
                          : context.text.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(item.message, style: context.text.bodyMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(_relative(item.createdAt), style: context.text.bodySmall),
                  ],
                ),
              ),
              if (!item.isRead)
                Container(
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icon(NotificationItem item) {
    final source = '${item.category} ${item.source}'.toLowerCase();
    if (source.contains('order')) return Icons.receipt_long_rounded;
    if (source.contains('support')) return Icons.support_agent_rounded;
    if (source.contains('offer') || source.contains('promo')) {
      return Icons.local_offer_rounded;
    }
    return Icons.campaign_rounded;
  }

  static String _relative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }
}
