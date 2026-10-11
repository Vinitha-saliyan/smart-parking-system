import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_parking_user/core/constants/app_constants.dart';

class AppException implements Exception {
  final String message;

  AppException(this.message);

  @override
  String toString() => message;
}

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
          final token = prefs.getString('auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: _handleUnauthorized,
      ),
    );
  }

  late final Dio _dio;
  late final Dio _refreshDio;
  final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast();
  Future<bool>? _refreshFuture;

  Stream<void> get sessionExpired => _sessionExpiredController.stream;

  Future<void> _handleUnauthorized(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final path = request.path;
    final isAuthenticationRequest = path.endsWith('/auth/login') ||
        path.endsWith('/auth/register') ||
        path.endsWith('/auth/refresh');
    final alreadyRetried = request.extra['auth_retry'] == true;

    if (error.response?.statusCode != 401 || isAuthenticationRequest) {
      handler.next(error);
      return;
    }

    if (!alreadyRetried && await _refreshAccessTokenOnce()) {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('auth_token');
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
    final refreshToken = prefs.getString('auth_refresh_token');
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

      await prefs.setString('auth_token', accessToken);
      if (rotatedRefreshToken != null && rotatedRefreshToken.isNotEmpty) {
        await prefs.setString('auth_refresh_token', rotatedRefreshToken);
      }
      return true;
    } on DioException {
      return false;
    }
  }

  Future<void> _expireSession() async {
    final prefs = await SharedPreferences.getInstance();
    final hadSession = (prefs.getString('auth_token') ?? '').isNotEmpty ||
        (prefs.getString('auth_refresh_token') ?? '').isNotEmpty;
    await prefs.remove('auth_token');
    await prefs.remove('auth_refresh_token');
    if (hadSession && !_sessionExpiredController.isClosed) {
      _sessionExpiredController.add(null);
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
      );
      return response.data;
    } on DioException catch (error) {
      throw _handleError(error);
    }
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data;
    } on DioException catch (error) {
      throw _handleError(error);
    }
  }

  Future<dynamic> postForm(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return response.data;
    } on DioException catch (error) {
      throw _handleError(error);
    }
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    try {
      final response = await _dio.put(path, data: data);
      return response.data;
    } on DioException catch (error) {
      throw _handleError(error);
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return response.data;
    } on DioException catch (error) {
      throw _handleError(error);
    }
  }

  AppException _handleError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return AppException(
        'Cannot reach ${AppConstants.apiBaseUrl}. Start the backend on port 8000.',
      );
    }

    final data = error.response?.data;
    if (data is Map && data['detail'] != null) {
      return AppException(data['detail'].toString());
    }
    if (data is Map && data['message'] != null) {
      return AppException(data['message'].toString());
    }
    if (error.response != null) {
      return AppException('Request failed (${error.response?.statusCode})');
    }
    return AppException('Network error');
  }

  void dispose() {
    _sessionExpiredController.close();
    _dio.close(force: true);
    _refreshDio.close(force: true);
  }
}
