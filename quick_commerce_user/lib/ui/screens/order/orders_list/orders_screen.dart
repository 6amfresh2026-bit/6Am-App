import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../di/app_providers.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/loaders/list_skeleton.dart';
import '../../../common/widgets/misc/section_header.dart';
import '../../../common/widgets/states/empty_state_widget.dart';
import '../../../common/widgets/states/error_state_widget.dart';
import '../widgets/order_card.dart';
import 'orders_provider.dart';
import '../../../common/widgets/misc/sound_refresh_indicator.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final position = _scrollController.position;
      if (position.pixels >= position.maxScrollExtent * 0.8) {
        ref.read(ordersProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authProvider).isSignedIn;
    final state = ref.watch(ordersProvider);
    final controller = ref.read(ordersProvider.notifier);

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text('Your orders')) : null,
      body: SafeArea(
        child: !signedIn
            ? EmptyStateWidget(
                icon: Icons.receipt_long_outlined,
                title: 'Sign in to see your orders',
                message: 'Every order you place shows up here with live tracking.',
                actionLabel: 'Sign in',
                onAction: () => context.push(RoutePaths.login),
              )
            : switch (state) {
                _ when state.isLoading && state.orders.isEmpty =>
                  const ListSkeleton(count: 4, height: 148),
                _ when state.failure != null && state.orders.isEmpty =>
                  ErrorStateWidget(
                    failure: state.failure!,
                    onRetry: () => controller.load(reset: true),
                  ),
                _ when state.isEmpty => EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    title: 'No orders yet',
                    message:
                        'Your first Suvio order is minutes away — literally.',
                    actionLabel: 'Start shopping',
                    onAction: () => context.go(RoutePaths.home),
                  ),
                _ => SoundRefreshIndicator(
                    onRefresh: () => controller.load(reset: true),
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                      children: [
                        if (state.active.isNotEmpty) ...[
                          const SectionHeader(
                            title: 'On the way',
                            subtitle: 'Track your live orders',
                          ),
                          for (final order in state.active)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                AppSpacing.md,
                              ),
                              child: OrderCard(
                                order: order,
                                highlighted: true,
                                onTap: () => context.push(
                                  RoutePaths.orderDetailsOf(order.id),
                                ),
                                onTrack: () => context.push(
                                  RoutePaths.orderTrackingOf(order.id),
                                ),
                              ),
                            ),
                        ],
                        if (state.past.isNotEmpty) ...[
                          const SectionHeader(title: 'Past orders'),
                          for (final order in state.past)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                AppSpacing.md,
                              ),
                              child: OrderCard(
                                order: order,
                                onTap: () => context.push(
                                  RoutePaths.orderDetailsOf(order.id),
                                ),
                                onTrack: () => context.push(
                                  RoutePaths.orderTrackingOf(order.id),
                                ),
                              ),
                            ),
                        ],
                        if (state.isLoadingMore)
                          const Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            ),
                          ),
                      ],
                    ),
                  ),
              },
      ),
    );
  }
}
