import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../di/repository_providers.dart';
import '../../../domain/model/product_subscription.dart';
import 'subscriptions_provider.dart';

class SubscriptionDetailState {
  const SubscriptionDetailState({
    this.subscription,
    this.isLoading = true,
    this.isSaving = false,
    this.failure,
  });

  final ProductSubscription? subscription;
  final bool isLoading;
  final bool isSaving;
  final Failure? failure;

  SubscriptionDetailState copyWith({
    ProductSubscription? subscription,
    bool? isLoading,
    bool? isSaving,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      SubscriptionDetailState(
        subscription: subscription ?? this.subscription,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class SubscriptionDetailController
    extends FamilyNotifier<SubscriptionDetailState, String> {
  @override
  SubscriptionDetailState build(String subscriptionId) {
    final cached = ref
        .read(subscriptionsProvider)
        .subscriptions
        .where((s) => s.id == subscriptionId)
        .firstOrNull;

    Future.microtask(load);
    return SubscriptionDetailState(
      subscription: cached,
      isLoading: cached == null,
    );
  }

  Future<void> load() async {
    state = state.copyWith(
      isLoading: state.subscription == null,
      clearFailure: true,
    );
    try {
      final subscription =
          await ref.read(subscriptionRepositoryProvider).getById(arg);
      state = state.copyWith(subscription: subscription, isLoading: false);
      ref.read(subscriptionsProvider.notifier).upsert(subscription);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        failure: ErrorMapper.toFailure(e),
      );
    }
  }

  Future<bool> pause() => _setStatus(SubscriptionStatus.paused);

  Future<bool> resume() => _setStatus(SubscriptionStatus.active);

  Future<bool> setQuantity(int quantity) =>
      _update(() => ref
          .read(subscriptionRepositoryProvider)
          .update(arg, quantity: quantity));

  Future<bool> setDeliveryTime(String deliveryTime) =>
      _update(() => ref
          .read(subscriptionRepositoryProvider)
          .update(arg, deliveryTime: deliveryTime));

  Future<bool> setAddress(String addressId) =>
      _update(() => ref
          .read(subscriptionRepositoryProvider)
          .update(arg, addressId: addressId));

  Future<bool> cancelSubscription() async {
    state = state.copyWith(isSaving: true, clearFailure: true);
    try {
      await ref.read(subscriptionRepositoryProvider).cancel(arg);
      state = state.copyWith(isSaving: false);
      // DELETE returns only `{success}`, so the fresh state is refetched
      // rather than guessed — it also brings back the cancelled occurrences.
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, failure: ErrorMapper.toFailure(e));
      return false;
    }
  }

  /// Calls off a single upcoming delivery, leaving the rest of the series
  /// running. Refused by the backend once the delivery day has begun.
  Future<bool> cancelOccurrence(
    SubscriptionOccurrence occurrence, {
    String? reason,
  }) async {
    state = state.copyWith(isSaving: true, clearFailure: true);
    try {
      final updated = await ref
          .read(subscriptionRepositoryProvider)
          .cancelOccurrence(arg, occurrence.id, reason: reason);

      final current = state.subscription;
      if (current != null) {
        final occurrences = current.occurrences
            .map((o) => o.id == updated.id ? updated : o)
            .toList();
        final next = current.copyWith(occurrences: occurrences);
        state = state.copyWith(subscription: next, isSaving: false);
        ref.read(subscriptionsProvider.notifier).upsert(next);
      } else {
        state = state.copyWith(isSaving: false);
      }
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, failure: ErrorMapper.toFailure(e));
      return false;
    }
  }

  void clearFailure() => state = state.copyWith(clearFailure: true);

  Future<bool> _setStatus(SubscriptionStatus status) async {
    final ok = await _update(
      () => ref.read(subscriptionRepositoryProvider).update(arg, status: status),
    );
    // Pausing cancels every future occurrence and resuming regenerates them,
    // both server-side — so the schedule shown must come from a refetch.
    if (ok) await load();
    return ok;
  }

  Future<bool> _update(Future<ProductSubscription> Function() call) async {
    state = state.copyWith(isSaving: true, clearFailure: true);
    try {
      final updated = await call();
      // PATCH returns the subscription without its schedule; keep the one
      // already loaded so the occurrence list does not blank out on save.
      final current = state.subscription;
      final merged = current == null
          ? updated
          : updated.copyWith(occurrences: current.occurrences);
      state = state.copyWith(subscription: merged, isSaving: false);
      ref.read(subscriptionsProvider.notifier).upsert(merged);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, failure: ErrorMapper.toFailure(e));
      return false;
    }
  }
}

final subscriptionDetailProvider = NotifierProvider.family<
    SubscriptionDetailController, SubscriptionDetailState, String>(
  SubscriptionDetailController.new,
);
