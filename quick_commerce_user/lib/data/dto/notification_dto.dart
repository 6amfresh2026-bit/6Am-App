import 'json_reader.dart';

/// An inbox row from `GET /food/notifications/inbox`.
class NotificationDto {
  const NotificationDto({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.link = '',
    this.category = '',
    this.source = '',
  });

  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String link;
  final String category;
  final String source;

  factory NotificationDto.fromJson(Map<String, dynamic> json) => NotificationDto(
        id: json.id(),
        title: json.str('title'),
        message: json.str('message'),
        createdAt: json.date('createdAt'),
        isRead: json.boolean('isRead'),
        link: json.str('link'),
        category: json.str('category'),
        source: json.str('source'),
      );
}
