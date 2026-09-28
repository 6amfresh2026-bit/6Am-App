import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../domain/model/chat_message.dart';
import '../../domain/repository/chat_repository.dart';
import '../dto/json_reader.dart';
import 'api_paths.dart';

class ApiChatRepository implements ChatRepository {
  ApiChatRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<ChatMessage>> history(String orderId) async {
    final json = await _client.get(
      ApiPaths.chatMessages,
      // For the user↔rider pair the conversation id is the order id itself.
      query: {'conversationId': orderId, 'limit': 100},
      requiresAuth: true,
    );
    if (json is! Map<String, dynamic>) return const [];
    return json
        .objects('messages')
        .map((m) => _fromJson(m, orderId))
        .toList(growable: false);
  }

  @override
  Future<ChatMessage> send({
    required String orderId,
    required String text,
  }) async {
    // Only `orderId` + `text`: the backend derives the recipient (the assigned
    // rider) from the order, never from a client-supplied id.
    final json = await _client.post(
      ApiPaths.chatMessages,
      body: {'orderId': orderId, 'text': text},
      requiresAuth: true,
    );
    if (json is! Map<String, dynamic>) {
      throw const ParseException('Unexpected chat response.');
    }
    return _fromJson(json.mapAt('message'), orderId);
  }

  /// The customer app owns the `USER` side, so a message is "mine" when the
  /// sender role is USER — the only USER on an order thread is this customer.
  static ChatMessage _fromJson(Map<String, dynamic> m, String orderId) {
    final senderRole = m.str('senderRole');
    return ChatMessage(
      id: m.str('id'),
      orderId: m.str('orderId').isNotEmpty ? m.str('orderId') : orderId,
      text: m.str('text'),
      isMine: senderRole == 'USER',
      senderRole: senderRole,
      createdAt: m.date('createdAt'),
      readAt: m.dateOrNull('readAt'),
    );
  }
}
