import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_parking_user/data/models/user_model.dart';
import 'package:smart_parking_user/data/services/api_service.dart';

class AuthRepository {
  AuthRepository(this._apiService);

  final ApiService _apiService;

  Stream<void> get sessionExpired => _apiService.sessionExpired;

  Future<UserModel> login(String email, String password) async {
    final response = await _apiService.postForm(
      '/auth/login',
      data: {
        'username': email.trim().toLowerCase(),
        'password': password,
      },
    );
    await _saveTokens(response);
    return getCurrentUser();
  }

  Future<UserModel> register(
    String email,
    String password,
    String fullName,
    String phone,
  ) async {
    final response = await _apiService.post(
      '/auth/register',
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
        'full_name': fullName.trim(),
        'phone': phone.trim().isEmpty ? null : phone.trim(),
      },
    );
    await _saveTokens(response);
    return getCurrentUser();
  }

  Future<void> _saveTokens(dynamic response) async {
    if (response is! Map || response['access_token'] == null) {
      throw AppException('The backend returned an invalid login response');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', response['access_token'].toString());
    if (response['refresh_token'] != null) {
      await prefs.setString(
        'auth_refresh_token',
        response['refresh_token'].toString(),
      );
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_refresh_token');
  }

  Future<UserModel> getCurrentUser() async {
    final response = await _apiService.get('/auth/me');
    if (response is! Map) {
      throw AppException('The backend returned invalid user data');
    }
    return UserModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> forgotPassword(String email) async {
    await _apiService.post(
      '/auth/forgot-password',
      data: {'email': email.trim().toLowerCase()},
    );
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
