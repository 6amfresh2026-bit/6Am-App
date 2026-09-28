import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../di/app_providers.dart';
import '../../../di/repository_providers.dart';
import '../../../domain/model/monthly_list.dart';

class MonthlyListsState {
  const MonthlyListsState({
    this.lists = const [],
    this.isLoading = true,
    this.failure,
  });

  final List<MonthlyList> lists;
  final bool isLoading;
  final Failure? failure;

  bool get isEmpty => !isLoading && lists.isEmpty && failure == null;

  MonthlyListsState copyWith({
    List<MonthlyList>? lists,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      MonthlyListsState(
        lists: lists ?? this.lists,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class MonthlyListsController extends Notifier<MonthlyListsState> {
  @override
  MonthlyListsState build() {
    if (ref.watch(authProvider).isSignedIn) Future.microtask(load);
    return const MonthlyListsState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final lists = await ref.read(monthlyListRepositoryProvider).list();
      state = state.copyWith(lists: lists, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        failure: ErrorMapper.toFailure(e),
      );
    }
  }

  /// Creates a list and prepends it, matching the backend's newest-first sort
  /// so the new list is where the customer expects without a refetch.
  Future<MonthlyList?> create({
    required String restaurantId,
    required List<MonthlyListItem> items,
    String? name,
  }) async {
    try {
      final created = await ref.read(monthlyListRepositoryProvider).create(
            restaurantId: restaurantId,
            items: items,
            name: name,
          );
      state = state.copyWith(lists: [created, ...state.lists]);
      return created;
    } catch (e) {
      state = state.copyWith(failure: ErrorMapper.toFailure(e));
      return null;
    }
  }

  Future<bool> rename(String listId, String name) =>
      _patch(listId, () => ref.read(monthlyListRepositoryProvider).update(
            listId,
            name: name,
          ));

  Future<bool> setActive(String listId, bool isActive) =>
      _patch(listId, () => ref.read(monthlyListRepositoryProvider).update(
            listId,
            isActive: isActive,
          ));

  Future<bool> replaceItems(String listId, List<MonthlyListItem> items) =>
      _patch(listId, () => ref.read(monthlyListRepositoryProvider).update(
            listId,
            items: items,
          ));

  Future<bool> delete(String listId) async {
    final previous = state.lists;
    // Optimistic: the row disappears on tap and comes back only if the call
    // fails, which reads better than a spinner on a delete.
    state = state.copyWith(
      lists: previous.where((l) => l.id != listId).toList(),
      clearFailure: true,
    );
    try {
      await ref.read(monthlyListRepositoryProvider).delete(listId);
      return true;
    } catch (e) {
      state = state.copyWith(lists: previous, failure: ErrorMapper.toFailure(e));
      return false;
    }
  }

  /// Folds a list updated elsewhere (the detail screen) back into this cache.
  void upsert(MonthlyList list) {
    final index = state.lists.indexWhere((l) => l.id == list.id);
    if (index < 0) {
      state = state.copyWith(lists: [list, ...state.lists]);
      return;
    }
    final next = [...state.lists]..[index] = list;
    state = state.copyWith(lists: next);
  }

  void clearFailure() => state = state.copyWith(clearFailure: true);

  Future<bool> _patch(
    String listId,
    Future<MonthlyList> Function() call,
  ) async {
    try {
      upsert(await call());
      return true;
    } catch (e) {
      state = state.copyWith(failure: ErrorMapper.toFailure(e));
      return false;
    }
  }
}

final monthlyListsProvider =
    NotifierProvider<MonthlyListsController, MonthlyListsState>(
  MonthlyListsController.new,
);
