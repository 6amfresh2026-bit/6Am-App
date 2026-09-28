import '../../core/network/api_client.dart';
import '../../domain/model/notification_item.dart';
import '../../domain/model/paged_result.dart';
import '../../domain/repository/notification_repository.dart';
import '../dto/json_reader.dart';
import '../dto/notification_dto.dart';
import '../mapper/notification_mapper.dart';
import 'api_paths.dart';

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._client);

  final ApiClient _client;

  @override
  Future<({PagedResult<NotificationItem> page, int unreadCount})> inbox({
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await _client.get(
      ApiPaths.notificationInbox,
      query: {'page': page, 'limit': pageSize},
      requiresAuth: true,
    );

    if (json is! Map<String, dynamic>) {
      return (page: PagedResult.empty<NotificationItem>(), unreadCount: 0);
    }

    final dtos = json.objects('items').map(NotificationDto.fromJson).toList();
    final meta = PageMeta.from(json, fallbackCount: dtos.length);

    return (
      page: PagedResult(
        items: NotificationMapper.toDomainList(dtos),
        total: meta.total,
        page: meta.page,
        pageSize: meta.pageSize,
      ),
      unreadCount: json.integer('unreadCount'),
    );
  }

  @override
  Future<void> markRead(String id) =>
      _client.patch(ApiPaths.notificationRead(id), requiresAuth: true);

  @override
  Future<void> dismiss(String id) =>
      _client.delete(ApiPaths.notificationDismiss(id), requiresAuth: true);

  @override
  Future<void> markAllRead(List<String> ids) async {
    // `DELETE /inbox/all` is shadowed by `DELETE /:id` upstream, so bulk
    // read-marking is done id by id. Noted in README → Backend Gaps.
    await Future.wait(ids.map(markRead));
  }
}
