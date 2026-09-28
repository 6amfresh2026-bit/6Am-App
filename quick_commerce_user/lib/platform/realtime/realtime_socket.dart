import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/utils/logger.dart';
import '../../domain/model/chat_message.dart';
import '../../domain/model/order.dart';

/// The app's single real-time socket, shared by chat and live order tracking.
///
/// One connection carries several server → client streams:
/// - `chat:message` / `chat:typing` — customer↔rider chat.
/// - `order_status_update` — order/delivery status changes (to the `user:<id>`
///   room the socket auto-joins from the auth token).
/// - `location-update` — the rider's live GPS, for the tracking room a screen
///   subscribes to with [joinTracking].
///
/// socket_io_client reconnects on its own when the network drops; [reconnect]
/// is the extra nudge for an app that was frozen in the background.
class RealtimeSocket {
  RealtimeSocket();

  io.Socket? _socket;
  String? _token;
  String? _origin;

  /// Tracking rooms we asked to join, re-joined automatically after a reconnect.
  final _trackedOrders = <String>{};

  final _messages = StreamController<ChatMessage>.broadcast();
  final _connection = StreamController<bool>.broadcast();
  final _typing = StreamController<TypingEvent>.broadcast();
  final _riderLocations = StreamController<RiderLocationEvent>.broadcast();
  final _statusUpdates = StreamController<OrderStatusEvent>.broadcast();

  /// New chat messages (any conversation; callers filter by order id).
  Stream<ChatMessage> get messages => _messages.stream;

  /// Connected / disconnected, for a live status indicator.
  Stream<bool> get connectionState => _connection.stream;

  Stream<TypingEvent> get typing => _typing.stream;

  /// Live rider GPS for a tracked order.
  Stream<RiderLocationEvent> get riderLocations => _riderLocations.stream;

  /// Order/delivery status changes pushed to this customer.
  Stream<OrderStatusEvent> get orderStatusUpdates => _statusUpdates.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Opens the connection (idempotent). [origin] is the API host without the
  /// `/api/v1` path — Socket.IO lives at the server root.
  void connect({required String token, required String origin}) {
    if (_socket != null && _token == token && _origin == origin) {
      if (!isConnected) _socket!.connect();
      return;
    }

    _disposeSocket();
    _token = token;
    _origin = origin;

    final socket = io.io(
      origin,
      io.OptionBuilder()
          // Server is Socket.IO v4. Prefer websocket but keep polling as a
          // fallback so a proxy that does not upgrade websockets still connects.
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(9999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    socket.onConnect((_) {
      AppLogger.debug('REALTIME SOCKET CONNECTED', scope: 'socket');
      _connection.add(true);
      // Re-subscribe to every tracking room after a (re)connect so live GPS
      // resumes without the screen doing anything.
      for (final orderId in _trackedOrders) {
        socket.emit('join-tracking', orderId);
      }
    });
    socket.onDisconnect((_) {
      AppLogger.debug('REALTIME SOCKET DISCONNECTED', scope: 'socket');
      _connection.add(false);
    });
    socket.onConnectError(
      (e) => AppLogger.debug('REALTIME SOCKET connect_error: $e', scope: 'socket'),
    );
    socket.onError(
      (e) => AppLogger.debug('REALTIME SOCKET error: $e', scope: 'socket'),
    );

    socket.on('chat:message', (data) {
      final message = _parseMessage(data);
      if (message != null) _messages.add(message);
    });

    socket.on('chat:typing', (data) {
      if (data is Map) {
        _typing.add(TypingEvent(
          conversationId: '${data['conversationId'] ?? ''}',
          fromRole: '${data['fromRole'] ?? ''}',
          typing: data['typing'] == true,
        ));
      }
    });

    socket.on('location-update', (data) {
      final event = _parseLocation(data);
      if (event != null) {
        AppLogger.debug(
          'RIDER LOCATION UPDATE: order=${event.orderId}',
          scope: 'socket',
        );
        _riderLocations.add(event);
      }
    });

    socket.on('order_status_update', (data) {
      if (data is! Map) return;
      final orderId = '${data['orderId'] ?? data['orderMongoId'] ?? ''}';
      if (orderId.isEmpty) return;
      AppLogger.debug(
        'ORDER STATUS UPDATE: order=$orderId status=${data['orderStatus']}',
        scope: 'socket',
      );
      _statusUpdates.add(OrderStatusEvent(
        orderId: orderId,
        status: '${data['orderStatus'] ?? ''}',
      ));
    });

    _socket = socket;
    socket.connect();
  }

  /// Subscribe to an order's tracking room so `location-update` events for it
  /// start flowing. Safe to call repeatedly; remembered across reconnects.
  void joinTracking(String orderId) {
    if (orderId.isEmpty) return;
    _trackedOrders.add(orderId);
    if (isConnected) _socket?.emit('join-tracking', orderId);
  }

  void leaveTracking(String orderId) => _trackedOrders.remove(orderId);

  /// Tells the rider "customer is typing" (best-effort; ignored if offline).
  void sendTyping({
    required String orderId,
    required String riderId,
    required bool typing,
  }) {
    if (!isConnected || riderId.isEmpty) return;
    _socket?.emit('chat:typing', {
      'conversationId': orderId,
      'toRole': 'DELIVERY_PARTNER',
      'toId': riderId,
      'typing': typing,
    });
  }

  /// Force a reconnect — used when the app returns to the foreground and the
  /// socket may have been silently killed by the OS.
  void reconnect() {
    final socket = _socket;
    if (socket == null) return;
    if (!socket.connected) {
      AppLogger.debug('REALTIME SOCKET reconnecting (app resumed)', scope: 'socket');
      socket.connect();
    }
  }

  static ChatMessage? _parseMessage(dynamic data) {
    if (data is! Map) return null;
    final map = data.map((k, v) => MapEntry('$k', v));
    final id = '${map['id'] ?? ''}';
    if (id.isEmpty) return null;
    final senderRole = '${map['senderRole'] ?? ''}';
    final createdRaw = map['createdAt'];
    final created = createdRaw is String
        ? DateTime.tryParse(createdRaw)?.toLocal() ?? DateTime.now()
        : DateTime.now();
    return ChatMessage(
      id: id,
      orderId: '${map['orderId'] ?? map['conversationId'] ?? ''}',
      text: '${map['text'] ?? ''}',
      isMine: senderRole == 'USER',
      senderRole: senderRole,
      createdAt: created,
      readAt: map['readAt'] is String
          ? DateTime.tryParse('${map['readAt']}')?.toLocal()
          : null,
    );
  }

  static RiderLocationEvent? _parseLocation(dynamic data) {
    if (data is! Map) return null;
    final map = data.map((k, v) => MapEntry('$k', v));
    // The payload carries lat/lng (with boy_lat/boy_lng and a riderLocation
    // array as compatibility aliases). Read whichever is present.
    double? asDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
    var lat = asDouble(map['lat']) ?? asDouble(map['boy_lat']);
    var lng = asDouble(map['lng']) ?? asDouble(map['boy_lng']);
    final arr = map['riderLocation'];
    if ((lat == null || lng == null) && arr is List && arr.length >= 2) {
      lat = asDouble(arr[0]);
      lng = asDouble(arr[1]);
    }
    if (lat == null || lng == null) return null;
    return RiderLocationEvent(
      orderId: '${map['orderId'] ?? ''}',
      location: GeoPoint(lat, lng),
    );
  }

  void _disposeSocket() {
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    _disposeSocket();
    _messages.close();
    _connection.close();
    _typing.close();
    _riderLocations.close();
    _statusUpdates.close();
  }
}

class TypingEvent {
  const TypingEvent({
    required this.conversationId,
    required this.fromRole,
    required this.typing,
  });

  final String conversationId;
  final String fromRole;
  final bool typing;
}

class RiderLocationEvent {
  const RiderLocationEvent({required this.orderId, required this.location});

  final String orderId;
  final GeoPoint location;
}

class OrderStatusEvent {
  const OrderStatusEvent({required this.orderId, required this.status});

  final String orderId;
  final String status;
}
