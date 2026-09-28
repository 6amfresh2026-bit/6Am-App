import '../model/chat_message.dart';

/// Customer↔rider chat over the backend's REST endpoints. Real-time delivery of
/// new messages is a separate concern handled by the socket service; this is the
/// durable path (history + send).
abstract interface class ChatRepository {
  /// Oldest→newest messages for an order's thread.
  Future<List<ChatMessage>> history(String orderId);

  /// Sends [text] to the assigned rider and returns the persisted message.
  /// Throws if no rider is assigned yet (the backend rejects it).
  Future<ChatMessage> send({required String orderId, required String text});
}
