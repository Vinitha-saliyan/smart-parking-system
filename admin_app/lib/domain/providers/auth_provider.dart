import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_parking_admin/data/models/user_model.dart';
import 'package:smart_parking_admin/data/repositories/auth_repository.dart';
import 'package:smart_parking_admin/data/services/api_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

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
    checkAuthStatus();
  }

  final AuthRepository _repository;

  Future<void> checkAuthStatus() async {
    try {
      final user = await _repository.getCurrentAdmin();
      state = user == null
          ? const AuthUnauthenticated()
          : AuthAuthenticated(user);
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
      final message = error
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Exception: ', '');
      state = AuthError(message);
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthUnauthenticated();
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
