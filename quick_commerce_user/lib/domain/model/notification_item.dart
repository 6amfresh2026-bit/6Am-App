/// An inbox notification.
class NotificationItem {
  const NotificationItem({
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

  bool get isToday {
    final now = DateTime.now();
    return createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
  }

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        title: title,
        message: message,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        link: link,
        category: category,
        source: source,
      );
}
