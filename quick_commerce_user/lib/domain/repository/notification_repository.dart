import '../model/notification_item.dart';
import '../model/paged_result.dart';

abstract interface class NotificationRepository {
  Future<({PagedResult<NotificationItem> page, int unreadCount})> inbox({
    int page,
    int pageSize,
  });

  Future<void> markRead(String id);

  Future<void> dismiss(String id);

  Future<void> markAllRead(List<String> ids);
}
