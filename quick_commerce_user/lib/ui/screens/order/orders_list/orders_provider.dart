import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../di/app_providers.dart';
import '../../../../di/repository_providers.dart';
import '../../../../domain/model/order.dart';

class OrdersState {
  const OrdersState({
    this.orders = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.page = 1,
    this.failure,
  });

  final List<Order> orders;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final Failure? failure;

  bool get isEmpty => !isLoading && orders.isEmpty && failure == null;

  /// Live orders are pinned to the top with a tracking CTA.
  List<Order> get active => orders.where((o) => o.status.isActive).toList();
  List<Order> get past => orders.where((o) => !o.status.isActive).toList();

  OrdersState copyWith({
    List<Order>? orders,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      OrdersState(
        orders: orders ?? this.orders,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class OrdersController extends Notifier<OrdersState> {
  static const _pageSize = 15;

  @override
  OrdersState build() {
    if (ref.watch(authProvider).isSignedIn) {
      Future.microtask(() => load(reset: true));
      return const OrdersState();
    }
    return const OrdersState(isLoading: false);
  }

  Future<void> load({bool reset = false}) async {
    if (reset) state = state.copyWith(isLoading: true, page: 1, clearFailure: true);

    try {
      final page = await ref.read(orderRepositoryProvider).list(
            page: reset ? 1 : state.page,
            pageSize: _pageSize,
          );

      state = state.copyWith(
        orders: reset ? page.items : [...state.orders, ...page.items],
        isLoading: false,
        isLoadingMore: false,
        hasMore: page.hasMore,
        page: page.page,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        failure: ErrorMapper.toFailure(e),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, page: state.page + 1);
    await load();
  }

  /// Background poll for the live-order card: refreshes page one without
  /// flipping `isLoading`, so the Orders tab (kept alive in the shell's
  /// IndexedStack) does not flash its skeleton every few seconds. Silent on
  /// failure — a dropped poll must not replace the list with an error.
  Future<void> silentRefresh() async {
    if (!ref.read(authProvider).isSignedIn) return;
    try {
      final page =
          await ref.read(orderRepositoryProvider).list(page: 1, pageSize: _pageSize);
      state = state.copyWith(
        orders: page.items,
        hasMore: page.hasMore,
        page: page.page,
        clearFailure: true,
      );
    } catch (_) {
      // Keep whatever is on screen; the next poll retries.
    }
  }
}

final ordersProvider =
    NotifierProvider<OrdersController, OrdersState>(OrdersController.new);
