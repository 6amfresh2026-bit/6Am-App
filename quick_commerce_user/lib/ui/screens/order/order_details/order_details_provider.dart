import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../di/repository_providers.dart';
import '../../../../domain/model/order.dart';

class OrderDetailState {
  const OrderDetailState({
    this.order,
    this.route = OrderRoute.empty,
    this.dropOtp = '',
    this.liveRiderLocation,
    this.isLoading = true,
    this.isMutating = false,
    this.failure,
  });

  final Order? order;
  final OrderRoute route;
  final String dropOtp;

  /// The rider's latest GPS from the socket. Kept apart from `order` so a status
  /// re-fetch (which may carry a stale or absent rider position over REST) never
  /// snaps the map marker backwards.
  final GeoPoint? liveRiderLocation;
  final bool isLoading;
  final bool isMutating;
  final Failure? failure;

  /// What the map should draw: the live socket position when we have one, else
  /// whatever the order last carried.
  GeoPoint? get riderLocation => liveRiderLocation ?? order?.riderLocation;

  OrderDetailState copyWith({
    Order? order,
    OrderRoute? route,
    String? dropOtp,
    GeoPoint? liveRiderLocation,
    bool? isLoading,
    bool? isMutating,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      OrderDetailState(
        order: order ?? this.order,
        route: route ?? this.route,
        dropOtp: dropOtp ?? this.dropOtp,
        liveRiderLocation: liveRiderLocation ?? this.liveRiderLocation,
        isLoading: isLoading ?? this.isLoading,
        isMutating: isMutating ?? this.isMutating,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

/// One order, kept live by the shared realtime socket:
/// - `order_status_update` → re-pull the full order (status, route, drop OTP).
/// - `location-update` → move only the rider, so the map's zoom/camera and the
///   rest of the UI are left exactly as the user left them.
///
/// A slow poll stays as a safety net for the rare case the socket is down; the
/// socket is what makes updates feel instant.
class OrderDetailController extends FamilyNotifier<OrderDetailState, String> {
  Timer? _poll;

  @override
  OrderDetailState build(String orderId) {
    // Reading the provider opens/keeps the one shared connection; joining the
    // order's tracking room starts the rider GPS stream (re-joined for us
    // automatically after any reconnect).
    final socket = ref.read(realtimeSocketProvider);
    socket.joinTracking(orderId);

    final locSub = socket.riderLocations.listen((event) {
      if (event.orderId.isNotEmpty && event.orderId != orderId) return;
      // Rider marker only — no re-fetch, no camera/zoom change. Held separately
      // from the order so a status poll cannot overwrite it.
      state = state.copyWith(liveRiderLocation: event.location);
    });

    final statusSub = socket.orderStatusUpdates.listen((event) {
      if (event.orderId != orderId) return;
      // A status change can also change the route and drop OTP, so pull the
      // whole order fresh rather than patching one field.
      load();
    });

    ref.onDispose(() {
      _poll?.cancel();
      locSub.cancel();
      statusSub.cancel();
      socket.leaveTracking(orderId);
    });

    Future.microtask(load);
    return const OrderDetailState();
  }

  Future<void> load() async {
    try {
      final order = await ref.read(orderRepositoryProvider).getById(arg);
      state = state.copyWith(order: order, isLoading: false, clearFailure: true);
      await _loadLiveExtras(order);
      _schedulePolling(order);
    } catch (e) {
      state = state.copyWith(isLoading: false, failure: ErrorMapper.toFailure(e));
    }
  }

  /// Route and drop OTP only exist once a rider is on the way.
  Future<void> _loadLiveExtras(Order order) async {
    if (!order.status.isActive) return;

    final repository = ref.read(orderRepositoryProvider);
    final route = await repository.routeFor(arg).catchError((_) => OrderRoute.empty);
    final otp = order.status.isOutForDelivery
        ? await repository.dropOtp(arg).catchError((_) => '')
        : '';

    state = state.copyWith(route: route, dropOtp: otp);
  }

  /// Polls while the order is live; stops the moment it reaches a terminal
  /// state so a delivered order does not keep hitting the API forever.
  void _schedulePolling(Order order) {
    _poll?.cancel();
    if (!order.status.isActive) return;

    _poll = Timer.periodic(AppDurations.trackingPoll, (timer) async {
      try {
        final fresh = await ref.read(orderRepositoryProvider).getById(arg);
        state = state.copyWith(order: fresh);
        await _loadLiveExtras(fresh);
        if (!fresh.status.isActive) timer.cancel();
      } catch (_) {
        // A dropped poll is not worth surfacing; the next tick retries.
      }
    });
  }

  Future<void> cancel(String reason) async {
    state = state.copyWith(isMutating: true, clearFailure: true);
    try {
      final order =
          await ref.read(orderRepositoryProvider).cancel(arg, reason: reason);
      _poll?.cancel();
      state = state.copyWith(order: order, isMutating: false);
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        failure: ErrorMapper.toFailure(e),
      );
      rethrow;
    }
  }

  Future<void> rate({
    required int sellerRating,
    int? riderRating,
    String? comment,
  }) async {
    state = state.copyWith(isMutating: true);
    try {
      final order = await ref.read(orderRepositoryProvider).rate(
            orderId: arg,
            sellerRating: sellerRating,
            riderRating: riderRating,
            comment: comment,
          );
      state = state.copyWith(order: order, isMutating: false);
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        failure: ErrorMapper.toFailure(e),
      );
      rethrow;
    }
  }

  Future<void> updateInstructions(String instructions) async {
    final order = await ref
        .read(orderRepositoryProvider)
        .updateInstructions(arg, instructions);
    state = state.copyWith(order: order);
  }
}

final orderDetailProvider =
    NotifierProvider.family<OrderDetailController, OrderDetailState, String>(
  OrderDetailController.new,
);
