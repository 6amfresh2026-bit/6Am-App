import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../di/repository_providers.dart';
import '../../../domain/model/chat_message.dart';
import '../../../platform/realtime/realtime_socket.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.isLoading = true,
    this.isSending = false,
    this.isConnected = false,
    this.riderTyping = false,
    this.failure,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final bool isConnected;
  final bool riderTyping;
  final Failure? failure;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    bool? isConnected,
    bool? riderTyping,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        isSending: isSending ?? this.isSending,
        isConnected: isConnected ?? this.isConnected,
        riderTyping: riderTyping ?? this.riderTyping,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

/// One controller per order thread. Loads history over REST, then keeps the
/// list live from the shared socket's `chat:message` stream.
class ChatController extends FamilyNotifier<ChatState, String> {
  String get _orderId => arg;

  RealtimeSocket get _socket => ref.read(realtimeSocketProvider);

  int _tempCounter = 0;

  @override
  ChatState build(String orderId) {
    // Reading the socket provider is what opens/keeps the connection alive.
    final socket = ref.read(realtimeSocketProvider);

    final messageSub = socket.messages.listen(_onIncoming);
    final connSub = socket.connectionState.listen((connected) {
      state = state.copyWith(isConnected: connected);
      // A reconnect can happen after messages were sent while we were away;
      // pull anything the stream might have missed.
      if (connected) _reconcile();
    });
    final typingSub = socket.typing.listen((event) {
      if (event.conversationId == _orderId && event.fromRole != 'USER') {
        state = state.copyWith(riderTyping: event.typing);
      }
    });

    ref.onDispose(() {
      messageSub.cancel();
      connSub.cancel();
      typingSub.cancel();
    });

    Future.microtask(_loadHistory);
    return ChatState(isConnected: socket.isConnected);
  }

  Future<void> _loadHistory() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final messages =
          await ref.read(chatRepositoryProvider).history(_orderId);
      // Keep any optimistic messages that have not landed yet.
      final pending = state.messages.where((m) => m.pending);
      state = state.copyWith(
        messages: _merge(messages, pending),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, failure: ErrorMapper.toFailure(e));
    }
  }

  /// Pull history again after a reconnect, to fill any socket gap.
  Future<void> _reconcile() async {
    try {
      final messages =
          await ref.read(chatRepositoryProvider).history(_orderId);
      final pending = state.messages.where((m) => m.pending);
      state = state.copyWith(messages: _merge(messages, pending));
    } catch (_) {
      // Non-fatal: the live stream will keep the thread current.
    }
  }

  void _onIncoming(ChatMessage message) {
    if (message.orderId != _orderId) return; // another conversation
    state = state.copyWith(
      messages: _merge(state.messages, [message]),
      riderTyping: message.isMine ? state.riderTyping : false,
    );
  }

  Future<void> refresh() => _loadHistory();

  Future<void> send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return;

    // Optimistic: show it immediately, marked pending, so the input feels
    // instant even before the server confirms.
    final temp = ChatMessage(
      id: 'temp-${_tempCounter++}',
      orderId: _orderId,
      text: text,
      isMine: true,
      senderRole: 'USER',
      createdAt: DateTime.now(),
      pending: true,
    );
    state = state.copyWith(
      messages: [...state.messages, temp],
      isSending: true,
      clearFailure: true,
    );

    try {
      final saved =
          await ref.read(chatRepositoryProvider).send(orderId: _orderId, text: text);
      // Swap the optimistic bubble for the persisted one (dedup by id handles
      // the socket echo that also arrives for our own message).
      final withoutTemp = state.messages.where((m) => m.id != temp.id);
      state = state.copyWith(
        messages: _merge(withoutTemp, [saved]),
        isSending: false,
      );
    } catch (e) {
      // Drop the optimistic bubble and surface why (e.g. "No delivery partner
      // is assigned to this order yet").
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != temp.id).toList(),
        isSending: false,
        failure: ErrorMapper.toFailure(e),
      );
    }
  }

  void setTyping(bool typing, {String riderId = ''}) {
    _socket.sendTyping(orderId: _orderId, riderId: riderId, typing: typing);
  }

  /// De-duplicates by id and keeps the list sorted oldest→newest.
  static List<ChatMessage> _merge(
    Iterable<ChatMessage> a,
    Iterable<ChatMessage> b,
  ) {
    final byId = <String, ChatMessage>{};
    for (final m in a) {
      byId[m.id] = m;
    }
    for (final m in b) {
      byId[m.id] = m;
    }
    final list = byId.values.toList()
      ..sort((x, y) => x.createdAt.compareTo(y.createdAt));
    return list;
  }
}

final chatProvider =
    NotifierProvider.family<ChatController, ChatState, String>(
  ChatController.new,
);
