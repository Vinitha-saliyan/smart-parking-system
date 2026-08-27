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
  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {'Accept': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401 &&
              !e.requestOptions.path.endsWith('/auth/login')) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('auth_token');
          }

          return handler.next(e);
        },
      ),
    );
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
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic data,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // FastAPI OAuth2 login requires application/x-www-form-urlencoded
  Future<dynamic> postForm(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> put(
    String path, {
    dynamic data,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final response = await _dio.delete(path);

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  AppException _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return AppException(
        'Cannot reach ${AppConstants.apiBaseUrl}. Start the backend on port 8000.',
      );
    }

    if (e.response != null) {
      final data = e.response?.data;

      if (data is Map && data['detail'] != null) {
        return AppException(data['detail'].toString());
      }

      if (data is Map && data['message'] != null) {
        return AppException(data['message'].toString());
      }

      return AppException(
        'Request failed (${e.response?.statusCode})',
      );
    }

    return AppException('Network error');
  }
}
