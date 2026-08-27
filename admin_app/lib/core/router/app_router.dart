import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_parking_admin/domain/providers/auth_provider.dart';
import 'package:smart_parking_admin/ui/analytics/analytics_screen.dart';
import 'package:smart_parking_admin/ui/auth/admin_login_screen.dart';
import 'package:smart_parking_admin/ui/dashboard/admin_dashboard_screen.dart';
import 'package:smart_parking_admin/ui/parking_management/parking_management_screen.dart';
import 'package:smart_parking_admin/ui/reservations/reservation_management_screen.dart';
import 'package:smart_parking_admin/ui/settings/admin_settings_screen.dart';
import 'package:smart_parking_admin/ui/shared/admin_scaffold.dart';
import 'package:smart_parking_admin/ui/user_management/user_management_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final onLoginPage = state.matchedLocation == '/login';
      if (authState is AuthInitial || authState is AuthLoading) {
        return onLoginPage ? null : '/login';
      }
      if (authState is AuthAuthenticated) {
        return onLoginPage ? '/dashboard' : null;
      }
      return onLoginPage ? null : '/login';
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdminScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const AdminDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/parking',
                builder: (context, state) => const ParkingManagementScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/users',
                builder: (context, state) => const UserManagementScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reservations',
                builder: (context, state) =>
                    const ReservationManagementScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analytics',
                builder: (context, state) => const AnalyticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const AdminSettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
