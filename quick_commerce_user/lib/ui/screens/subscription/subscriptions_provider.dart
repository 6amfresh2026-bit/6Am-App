import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../di/app_providers.dart';
import '../../../di/repository_providers.dart';
import '../../../domain/model/payment_method.dart';
import '../../../domain/model/product_subscription.dart';

class SubscriptionsState {
  const SubscriptionsState({
    this.subscriptions = const [],
    this.isLoading = true,
    this.failure,
  });

  final List<ProductSubscription> subscriptions;
  final bool isLoading;
  final Failure? failure;

  bool get isEmpty =>
      !isLoading && subscriptions.isEmpty && failure == null;

  /// Cancelled subscriptions are kept out of the main list — they are history,
  /// not something the customer can act on.
  List<ProductSubscription> get live =>
      subscriptions.where((s) => !s.status.isCancelled).toList();

  List<ProductSubscription> get cancelled =>
      subscriptions.where((s) => s.status.isCancelled).toList();

  SubscriptionsState copyWith({
    List<ProductSubscription>? subscriptions,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      SubscriptionsState(
        subscriptions: subscriptions ?? this.subscriptions,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class SubscriptionsController extends Notifier<SubscriptionsState> {
  @override
  SubscriptionsState build() {
    if (ref.watch(authProvider).isSignedIn) Future.microtask(load);
    return const SubscriptionsState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final subscriptions =
          await ref.read(subscriptionRepositoryProvider).list();
      state = state.copyWith(subscriptions: subscriptions, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        failure: ErrorMapper.toFailure(e),
      );
    }
  }

  Future<ProductSubscription?> create({
    required String restaurantId,
    required String itemId,
    required int quantity,
    required SubscriptionFrequency frequency,
    required String deliveryTime,
    required DateTime startDate,
    required String addressId,
    String? variantId,
    List<int> daysOfWeek = const [],
    int? dayOfMonth,
    PaymentMethod method = PaymentMethod.cash,
  }) async {
    try {
      final created = await ref.read(subscriptionRepositoryProvider).create(
            restaurantId: restaurantId,
            itemId: itemId,
            quantity: quantity,
            frequency: frequency,
            deliveryTime: deliveryTime,
            startDate: startDate,
            addressId: addressId,
            variantId: variantId,
            daysOfWeek: daysOfWeek,
            dayOfMonth: dayOfMonth,
            method: method,
          );
      state = state.copyWith(
        subscriptions: [created, ...state.subscriptions],
        clearFailure: true,
      );
      return created;
    } catch (e) {
      state = state.copyWith(failure: ErrorMapper.toFailure(e));
      return null;
    }
  }

  /// Pauses or resumes a single subscription — the per-card toggle on the
  /// list, without needing to open its detail screen.
  Future<bool> setStatus(String subscriptionId, SubscriptionStatus status) async {
    try {
      final updated = await ref
          .read(subscriptionRepositoryProvider)
          .update(subscriptionId, status: status);
      upsert(updated);
      return true;
    } catch (e) {
      state = state.copyWith(failure: ErrorMapper.toFailure(e));
      return false;
    }
  }

  /// The master toggle: pauses or resumes every live subscription at once.
  Future<bool> setAllStatus(SubscriptionStatus status) async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      await ref.read(subscriptionRepositoryProvider).bulkUpdateStatus(status);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, failure: ErrorMapper.toFailure(e));
      return false;
    }
  }

  /// Folds a subscription changed elsewhere back into the cache. The detail
  /// screen carries occurrences the list endpoint never returns, so an
  /// existing schedule is preserved when the update did not include one.
  void upsert(ProductSubscription subscription) {
    final index =
        state.subscriptions.indexWhere((s) => s.id == subscription.id);
    if (index < 0) {
      state = state.copyWith(subscriptions: [subscription, ...state.subscriptions]);
      return;
    }
    final existing = state.subscriptions[index];
    final merged = subscription.occurrences.isEmpty && existing.occurrences.isNotEmpty
        ? subscription.copyWith(occurrences: existing.occurrences)
        : subscription;
    final next = [...state.subscriptions]..[index] = merged;
    state = state.copyWith(subscriptions: next);
  }

  void clearFailure() => state = state.copyWith(clearFailure: true);
}

final subscriptionsProvider =
    NotifierProvider<SubscriptionsController, SubscriptionsState>(
  SubscriptionsController.new,
);

/// The live discount rate (%) by frequency, straight from the backend — the
/// "Save 12%" badges and "You save ₹X" figure on the subscribe screen must
/// read from this, never from a number written into the widget.
final subscriptionDiscountConfigProvider =
    FutureProvider<Map<SubscriptionFrequency, int>>((ref) {
  return ref.read(subscriptionRepositoryProvider).discountConfig();
});
