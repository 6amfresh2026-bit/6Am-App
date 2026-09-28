import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../di/repository_providers.dart';
import '../../../domain/model/address.dart';
import '../../../domain/model/monthly_list.dart';
import '../../../domain/model/order.dart';
import '../../../domain/model/payment_method.dart';
import 'monthly_lists_provider.dart';

class MonthlyListDetailState {
  const MonthlyListDetailState({
    this.list,
    this.isLoading = true,
    this.isSaving = false,
    this.isOrdering = false,
    this.failure,
  });

  final MonthlyList? list;
  final bool isLoading;

  /// A rename or item edit is in flight.
  final bool isSaving;

  /// "Order this month" is in flight — kept apart from [isSaving] so the two
  /// buttons show their own spinner.
  final bool isOrdering;
  final Failure? failure;

  bool get isBusy => isSaving || isOrdering;

  MonthlyListDetailState copyWith({
    MonthlyList? list,
    bool? isLoading,
    bool? isSaving,
    bool? isOrdering,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      MonthlyListDetailState(
        list: list ?? this.list,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        isOrdering: isOrdering ?? this.isOrdering,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class MonthlyListDetailController
    extends FamilyNotifier<MonthlyListDetailState, String> {
  @override
  MonthlyListDetailState build(String listId) {
    // Show whatever the list screen already fetched while the fresh copy
    // loads, so opening a list from the list screen is not a blank frame.
    final cached = ref
        .read(monthlyListsProvider)
        .lists
        .where((l) => l.id == listId)
        .firstOrNull;

    Future.microtask(load);
    return MonthlyListDetailState(list: cached, isLoading: cached == null);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: state.list == null, clearFailure: true);
    try {
      final list = await ref.read(monthlyListRepositoryProvider).getById(arg);
      state = state.copyWith(list: list, isLoading: false);
      ref.read(monthlyListsProvider.notifier).upsert(list);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        failure: ErrorMapper.toFailure(e),
      );
    }
  }

  Future<bool> rename(String name) => _save(
        () => ref.read(monthlyListRepositoryProvider).update(arg, name: name),
      );

  Future<bool> setActive(bool isActive) => _save(
        () => ref
            .read(monthlyListRepositoryProvider)
            .update(arg, isActive: isActive),
      );

  /// Changes a line's quantity, or removes it when [quantity] drops to zero.
  /// The backend replaces the whole `items` array, so the edited list is sent
  /// in full rather than as a delta.
  Future<bool> setQuantity(MonthlyListItem item, int quantity) async {
    final current = state.list;
    if (current == null) return false;

    final items = <MonthlyListItem>[];
    for (final existing in current.items) {
      if (existing.lineId != item.lineId) {
        items.add(existing);
      } else if (quantity > 0) {
        items.add(existing.copyWith(quantity: quantity));
      }
    }

    // The backend requires at least one item, so the last line is removed by
    // deleting the list itself — not by sending an empty array it would reject.
    if (items.isEmpty) {
      state = state.copyWith(
        failure: const ValidationFailure(
          'A monthly list needs at least one item. Delete the list instead.',
        ),
      );
      return false;
    }

    return _save(
      () => ref.read(monthlyListRepositoryProvider).update(arg, items: items),
    );
  }

  /// Places this month's order. Returns the placed order so the screen can
  /// hand it to the shared payment flow, or null when the call failed.
  Future<PlacedOrder?> placeOrder({
    required Address address,
    PaymentMethod method = PaymentMethod.cash,
    String deliveryMode = 'basic',
    String? couponCode,
  }) async {
    state = state.copyWith(isOrdering: true, clearFailure: true);
    try {
      final placed = await ref.read(monthlyListRepositoryProvider).placeOrder(
            arg,
            // A saved address is referenced by id so the server uses its own
            // stored copy; an unsaved one is sent inline.
            addressId: address.id.isNotEmpty ? address.id : null,
            address: address.id.isEmpty ? address : null,
            method: method,
            deliveryMode: deliveryMode,
            couponCode: couponCode,
          );
      state = state.copyWith(isOrdering: false);
      // `lastOrderedAt` moved server-side; refresh so the card reflects it.
      unawaited(load());
      return placed;
    } catch (e) {
      state = state.copyWith(
        isOrdering: false,
        failure: ErrorMapper.toFailure(e),
      );
      return null;
    }
  }

  void clearFailure() => state = state.copyWith(clearFailure: true);

  Future<bool> _save(Future<MonthlyList> Function() call) async {
    state = state.copyWith(isSaving: true, clearFailure: true);
    try {
      final list = await call();
      state = state.copyWith(list: list, isSaving: false);
      ref.read(monthlyListsProvider.notifier).upsert(list);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, failure: ErrorMapper.toFailure(e));
      return false;
    }
  }
}

final monthlyListDetailProvider = NotifierProvider.family<
    MonthlyListDetailController, MonthlyListDetailState, String>(
  MonthlyListDetailController.new,
);
