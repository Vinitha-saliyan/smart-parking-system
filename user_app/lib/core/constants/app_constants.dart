import 'package:flutter/foundation.dart';

class AppConstants {
  static const String _apiOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  static const String _webApiUrl = 'http://127.0.0.1:8000/api/v1';

  static const String _physicalDeviceApiUrl = 'http://127.0.0.1:8000/api/v1';

  static String get apiBaseUrl {
    final url = _apiOverride.isNotEmpty
        ? _apiOverride
        : kIsWeb
            ? _webApiUrl
            : _physicalDeviceApiUrl;

    // Prevent accidental double slashes in API endpoints.
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static String get wsBaseUrl {
    return apiBaseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://')
        .replaceFirst('/api/v1', '/ws');
  }

  static const int reservationTimeoutMinutes = 30;

  static const Duration animationDuration = Duration(
    milliseconds: 300,
  );
}

enum SlotStatus {
  VACANT,
  OCCUPIED,
  RESERVED,
  MAINTENANCE,
}

enum SlotType {
  STANDARD,
  VIP,
  EV,
  DISABLED,
}
