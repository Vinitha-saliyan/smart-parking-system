import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_parking_user/data/models/user_model.dart';
import 'package:smart_parking_user/data/repositories/auth_repository.dart';
import 'package:smart_parking_user/data/services/api_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  final service = ApiService();
  ref.onDispose(service.dispose);
  return service;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiServiceProvider));
});

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final UserModel user;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository) : super(const AuthInitial()) {
    _sessionExpiredSubscription = _repository.sessionExpired.listen((_) {
      state = const AuthUnauthenticated();
    });
    checkAuthStatus();
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _sessionExpiredSubscription;

  @override
  void dispose() {
    _sessionExpiredSubscription.cancel();
    super.dispose();
  }

  Future<void> checkAuthStatus() async {
    try {
      if (!await _repository.isLoggedIn()) {
        state = const AuthUnauthenticated();
        return;
      }
      final user = await _repository.getCurrentUser();
      state = AuthAuthenticated(user);
    } catch (_) {
      await _repository.logout();
      state = const AuthUnauthenticated();
    }
  }

  Future<bool> login(String email, String password) async {
    state = const AuthLoading();
    try {
      final user = await _repository.login(email, password);
      state = AuthAuthenticated(user);
      return true;
    } catch (error) {
      state = AuthError(_cleanMessage(error));
      return false;
    }
  }

  Future<bool> register(
    String email,
    String password,
    String fullName,
    String phone,
  ) async {
    state = const AuthLoading();
    try {
      final user = await _repository.register(
        email,
        password,
        fullName,
        phone,
      );
      state = AuthAuthenticated(user);
      return true;
    } catch (error) {
      state = AuthError(_cleanMessage(error));
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthUnauthenticated();
  }

  String _cleanMessage(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

final currentUserProvider = Provider<UserModel?>((ref) {
  final state = ref.watch(authStateProvider);
  return state is AuthAuthenticated ? state.user : null;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider) is AuthAuthenticated;
});
