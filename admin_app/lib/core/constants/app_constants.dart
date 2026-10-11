import 'package:flutter/foundation.dart';

class AppConstants {
  static const String _apiOverride = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_apiOverride.isNotEmpty) return _apiOverride;
    if (kIsWeb) return 'http://127.0.0.1:8000/api/v1';
    return 'http://10.0.2.2:8000/api/v1';
  }

  static String get wsBaseUrl => apiBaseUrl
      .replaceFirst('http://', 'ws://')
      .replaceFirst('https://', 'wss://')
      .replaceFirst('/api/v1', '/ws');
}

enum Role {
  USER,
  ADMIN,
  MANAGER,
  OPERATOR,
  SECURITY
}

enum SlotStatus {
  available,
  occupied,
  reserved,
  maintenance
}

enum SlotType {
  standard,
  vip,
  ev,
  disabled
}
