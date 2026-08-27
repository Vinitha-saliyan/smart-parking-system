import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_parking_admin/data/models/user_model.dart';
import 'package:smart_parking_admin/data/services/api_service.dart';

class AuthRepository {
  AuthRepository(this._apiService);

  final ApiService _apiService;

  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _apiService.client.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'username': email.trim().toLowerCase(),
          'password': password,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final data = response.data;
      if (data == null || data['access_token'] == null) {
        throw StateError('The backend returned an invalid login response');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_token', data['access_token'] as String);
      final refreshToken = data['refresh_token'] as String?;
      if (refreshToken != null) {
        await prefs.setString('admin_refresh_token', refreshToken);
      }

      final user = await getCurrentAdmin();
      if (user == null || !user.isAdmin) {
        await logout();
        throw StateError('This account does not have admin access');
      }
      return user;
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError(ApiService.errorMessage(error));
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('admin_token') ?? '').isNotEmpty;
  }

  Future<UserModel?> getCurrentAdmin() async {
    if (!await isLoggedIn()) return null;
    try {
      final response = await _apiService.client.get<Map<String, dynamic>>(
        '/auth/me',
      );
      if (response.data == null) return null;
      final user = UserModel.fromJson(response.data!);
      return user.isAdmin ? user : null;
    } catch (error) {
      await logout();
      throw StateError(ApiService.errorMessage(error));
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    await prefs.remove('admin_refresh_token');
  }
}
