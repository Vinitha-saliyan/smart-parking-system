import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_parking_admin/core/constants/app_constants.dart';

class ApiService {
  ApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.apiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: const {'Accept': 'application/json'},
          ),
        ) {
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
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.endsWith('/auth/login')) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('admin_token');
            await prefs.remove('admin_refresh_token');
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;

  Dio get client => _dio;

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
