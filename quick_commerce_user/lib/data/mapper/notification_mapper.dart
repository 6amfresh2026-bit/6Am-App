import '../../domain/model/notification_item.dart';
import '../dto/notification_dto.dart';

abstract final class NotificationMapper {
  static NotificationItem toDomain(NotificationDto dto) => NotificationItem(
        id: dto.id,
        title: dto.title,
        message: dto.message,
        createdAt: dto.createdAt,
        isRead: dto.isRead,
        link: dto.link,
        category: dto.category,
        source: dto.source,
      );

  static List<NotificationItem> toDomainList(List<NotificationDto> dtos) =>
      dtos.map(toDomain).toList();
}
