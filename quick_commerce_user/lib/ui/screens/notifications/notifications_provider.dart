import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../di/app_providers.dart';
import '../../../di/repository_providers.dart';
import '../../../domain/model/notification_item.dart';

class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.unreadCount = 0,
    this.isLoading = true,
    this.failure,
  });

  final List<NotificationItem> items;
  final int unreadCount;
  final bool isLoading;
  final Failure? failure;

  bool get isEmpty => !isLoading && items.isEmpty && failure == null;

  List<NotificationItem> get today => items.where((i) => i.isToday).toList();
  List<NotificationItem> get earlier => items.where((i) => !i.isToday).toList();

  NotificationsState copyWith({
    List<NotificationItem>? items,
    int? unreadCount,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      NotificationsState(
        items: items ?? this.items,
        unreadCount: unreadCount ?? this.unreadCount,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class NotificationsController extends Notifier<NotificationsState> {
  @override
  NotificationsState build() {
    if (ref.watch(authProvider).isSignedIn) Future.microtask(load);
    return const NotificationsState();
  }

  static const _pageSize = 50;

  /// A guard, not a limit: stops a bad `total` from looping forever.
  static const _maxPages = 10;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      // The inbox has no "load more" affordance, so a single page silently
      // hid every notification past the first 50.
      final repository = ref.read(notificationRepositoryProvider);
      var result = await repository.inbox(pageSize: _pageSize);
      final unreadCount = result.unreadCount;
      var items = result.page.items;
      while (result.page.hasMore && result.page.page < _maxPages) {
        result = await repository.inbox(
          page: result.page.page + 1,
          pageSize: _pageSize,
        );
        items = [...items, ...result.page.items];
      }

      state = state.copyWith(
        items: items,
        unreadCount: unreadCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, failure: ErrorMapper.toFailure(e));
    }
  }

  Future<void> markRead(String id) async {
    // Optimistic — the badge should drop the instant the row is tapped.
    state = state.copyWith(
      items: state.items
          .map((i) => i.id == id ? i.copyWith(isRead: true) : i)
          .toList(),
      unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
    );
    try {
      await ref.read(notificationRepositoryProvider).markRead(id);
    } catch (_) {
      await load();
    }
  }

  Future<void> markAllRead() async {
    final unread =
        state.items.where((i) => !i.isRead).map((i) => i.id).toList();
    if (unread.isEmpty) return;

    state = state.copyWith(
      items: state.items.map((i) => i.copyWith(isRead: true)).toList(),
      unreadCount: 0,
    );
    try {
      await ref.read(notificationRepositoryProvider).markAllRead(unread);
    } catch (_) {
      await load();
    }
  }

  Future<void> dismiss(String id) async {
    state = state.copyWith(
      items: state.items.where((i) => i.id != id).toList(),
    );
    try {
      await ref.read(notificationRepositoryProvider).dismiss(id);
    } catch (_) {
      await load();
    }
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
  NotificationsController.new,
);
