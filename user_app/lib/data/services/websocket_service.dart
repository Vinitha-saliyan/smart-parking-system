import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:smart_parking_user/core/constants/app_constants.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  final String areaId;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  int _reconnectAttempts = 0;

  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  bool _isDisposed = false;

  WebSocketService({
    required this.areaId,
  }) {
    _connect();
  }

  Stream<Map<String, dynamic>> get stream {
    return _controller.stream;
  }

  bool get isConnected {
    return _channel != null && !_isDisposed;
  }

  void _connect() {
    if (_isDisposed || _channel != null) {
      return;
    }

    try {
      final uri = Uri.parse(
        '${AppConstants.wsBaseUrl}/parking/$areaId',
      );

      debugPrint('Connecting WebSocket: $uri');

      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      _subscription = channel.stream.listen(
        (message) {
          _reconnectAttempts = 0;

          final rawMessage = message.toString();

          // FastAPI heartbeat response is plain text.
          if (rawMessage == 'pong') {
            debugPrint('WebSocket heartbeat received');
            return;
          }

          try {
            final decoded = jsonDecode(rawMessage);

            if (decoded is Map) {
              if (!_controller.isClosed) {
                _controller.add(
                  Map<String, dynamic>.from(decoded),
                );
              }
            } else {
              debugPrint(
                'WebSocket ignored non-map message: $decoded',
              );
            }
          } catch (error) {
            debugPrint(
              'WebSocket message parse error: $error',
            );
          }
        },
        onDone: _handleDisconnect,
        onError: (Object error) {
          debugPrint('WebSocket error: $error');
          _handleDisconnect();
        },
        cancelOnError: false,
      );

      _startHeartbeat();
    } catch (error) {
      debugPrint('WebSocket connection error: $error');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _subscription?.cancel();
    _subscription = null;

    _channel?.sink.close();
    _channel = null;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (!_isDisposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed || (_reconnectTimer?.isActive ?? false)) {
      return;
    }

    const backoffSeconds = [1, 2, 4, 8, 30];

    final index = _reconnectAttempts < backoffSeconds.length
        ? _reconnectAttempts
        : backoffSeconds.length - 1;

    final delay = backoffSeconds[index];
    _reconnectAttempts++;

    debugPrint(
      'Reconnecting WebSocket in $delay seconds',
    );

    _reconnectTimer = Timer(
      Duration(seconds: delay),
      () {
        _reconnectTimer = null;
        _connect();
      },
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();

    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) {
        if (!isConnected) {
          return;
        }

        try {
          // FastAPI expects plain-text "ping".
          _channel?.sink.add('ping');
        } catch (error) {
          debugPrint(
            'WebSocket heartbeat error: $error',
          );

          _handleDisconnect();
        }
      },
    );
  }

  Future<void> disconnect() async {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    await _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
