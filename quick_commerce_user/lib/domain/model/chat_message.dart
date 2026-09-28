/// One message in an order's customer↔rider thread.
///
/// The backend keys this thread on the order id (`conversationId == orderId`
/// for the user↔rider pair), so nothing here needs the rider's id — the server
/// derives the counterpart from the order.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.orderId,
    required this.text,
    required this.isMine,
    required this.senderRole,
    required this.createdAt,
    this.readAt,
    this.pending = false,
  });

  final String id;
  final String orderId;
  final String text;

  /// True when the customer (this app) sent it — drives left/right alignment.
  final bool isMine;

  /// `USER` | `DELIVERY_PARTNER` | `RESTAURANT` | `ADMIN`, as the backend sends.
  final String senderRole;
  final DateTime createdAt;
  final DateTime? readAt;

  /// A locally-shown optimistic message not yet confirmed by the server.
  final bool pending;

  ChatMessage copyWith({String? id, bool? pending, DateTime? createdAt}) =>
      ChatMessage(
        id: id ?? this.id,
        orderId: orderId,
        text: text,
        isMine: isMine,
        senderRole: senderRole,
        createdAt: createdAt ?? this.createdAt,
        readAt: readAt,
        pending: pending ?? this.pending,
      );

  @override
  bool operator ==(Object other) => other is ChatMessage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
