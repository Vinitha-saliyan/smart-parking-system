import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_parking_user/data/services/websocket_service.dart';

final webSocketProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, areaId) {
  final wsService = WebSocketService(areaId: areaId);

  ref.onDispose(() {
    wsService.disconnect();
  });

  return wsService.stream;
});
