import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_parking_admin/core/constants/app_constants.dart';

class ApiService {
  ApiService() {
    final options = BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Accept': 'application/json'},
    );
    _dio = Dio(options);
    _refreshDio = Dio(options);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('admin_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: _handleError,
      ),
    );
  }

  late final Dio _dio;
  late final Dio _refreshDio;
  final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast();
  Future<bool>? _refreshFuture;

  Dio get client => _dio;

  Stream<void> get sessionExpired => _sessionExpiredController.stream;

  Future<void> _handleError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final path = request.path;
    final isAuthenticationRequest = path.endsWith('/auth/login') ||
        path.endsWith('/auth/refresh');
    final alreadyRetried = request.extra['auth_retry'] == true;

    if (error.response?.statusCode != 401 || isAuthenticationRequest) {
      handler.next(error);
      return;
    }

    if (!alreadyRetried && await _refreshAccessTokenOnce()) {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('admin_token');
      if (accessToken != null && accessToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $accessToken';
        request.extra['auth_retry'] = true;
        try {
          final response = await _dio.fetch<dynamic>(request);
          handler.resolve(response);
          return;
        } on DioException catch (retryError) {
          await _expireSession();
          handler.next(retryError);
          return;
        }
      }
    }

    await _expireSession();
    handler.next(error);
  }

  Future<bool> _refreshAccessTokenOnce() {
    final running = _refreshFuture;
    if (running != null) return running;

    final future = _refreshAccessToken();
    _refreshFuture = future;
    future.whenComplete(() {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    });
    return future;
  }

  Future<bool> _refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('admin_refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data;
      final accessToken = data?['access_token']?.toString();
      final rotatedRefreshToken = data?['refresh_token']?.toString();
      if (accessToken == null || accessToken.isEmpty) return false;

      await prefs.setString('admin_token', accessToken);
      if (rotatedRefreshToken != null && rotatedRefreshToken.isNotEmpty) {
        await prefs.setString('admin_refresh_token', rotatedRefreshToken);
      }
      return true;
    } on DioException {
      return false;
    }
  }

  Future<void> _expireSession() async {
    final prefs = await SharedPreferences.getInstance();
    final hadSession = (prefs.getString('admin_token') ?? '').isNotEmpty ||
        (prefs.getString('admin_refresh_token') ?? '').isNotEmpty;
    await prefs.remove('admin_token');
    await prefs.remove('admin_refresh_token');
    if (hadSession && !_sessionExpiredController.isClosed) {
      _sessionExpiredController.add(null);
    }
  }

  void dispose() {
    _sessionExpiredController.close();
    _dio.close(force: true);
    _refreshDio.close(force: true);
  }

  static String errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Cannot reach the backend at ${AppConstants.apiBaseUrl}. '
            'Start FastAPI on port 8000 and try again.';
      }
      return error.message ?? 'Backend request failed';
    }
    return error.toString();
  }
}
