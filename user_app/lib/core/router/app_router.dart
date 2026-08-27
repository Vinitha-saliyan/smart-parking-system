import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_parking_user/domain/providers/auth_provider.dart';
import 'package:smart_parking_user/ui/auth/forgot_password_screen.dart';
import 'package:smart_parking_user/ui/auth/login_screen.dart';
import 'package:smart_parking_user/ui/auth/register_screen.dart';
import 'package:smart_parking_user/ui/dashboard/dashboard_screen.dart';
import 'package:smart_parking_user/ui/notifications/notifications_screen.dart';
import 'package:smart_parking_user/data/models/reservation_model.dart';
import 'package:smart_parking_user/ui/navigation/indoor_navigation_screen.dart';
import 'package:smart_parking_user/ui/parking_map/parking_map_screen.dart';
import 'package:smart_parking_user/ui/payment/payment_screen.dart';
import 'package:smart_parking_user/ui/profile/history_screen.dart';
import 'package:smart_parking_user/ui/profile/profile_screen.dart';
import 'package:smart_parking_user/ui/profile/settings_screen.dart';
import 'package:smart_parking_user/ui/reservation/reservation_screen.dart';
import 'package:smart_parking_user/ui/search/search_screen.dart';
import 'package:smart_parking_user/ui/shared/main_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  late final GoRouter router;

  router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final location = state.uri.path;

      final isAuthenticated = authState is AuthAuthenticated;
      final isChecking = authState is AuthInitial || authState is AuthLoading;

      final isPublicAuthPage = location == '/login' ||
          location == '/register' ||
          location == '/forgot-password';

      // Keep the user on login/register while an authentication
      // operation is running.
      if (isChecking) {
        if (isPublicAuthPage) {
          return null;
        }

        return '/login';
      }

      // Unauthenticated users can only open authentication pages.
      if (!isAuthenticated) {
        if (isPublicAuthPage) {
          return null;
        }

        return '/login';
      }

      // Authenticated users should not return to authentication pages.
      if (isAuthenticated && (isPublicAuthPage || location == '/')) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/login',
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/payment',
        builder: (context, state) {
          final args = state.extra;
          if (args is! PaymentScreenArgs) {
            return const Scaffold(
              body: Center(
                child: Text('Payment details are missing.'),
              ),
            );
          }

          return PaymentScreen(args: args);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(
            navigationShell: navigationShell,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/parking-map',
                builder: (context, state) => const ParkingMapScreen(),
                routes: [
                  GoRoute(
                    path: ':areaId',
                    builder: (context, state) {
                      return ParkingMapScreen(
                        areaId: state.pathParameters['areaId'],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reservations',
                builder: (context, state) => const ReservationScreen(),
                routes: [
                  GoRoute(
                    path: 'navigate',
                    builder: (context, state) {
                      final reservation = state.extra;
                      if (reservation is! ReservationModel) {
                        return const Scaffold(
                          body: Center(
                            child: Text('Navigation details are unavailable.'),
                          ),
                        );
                      }

                      return IndoorNavigationScreen(
                        reservation: reservation,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => const HistoryScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  // Refresh redirects without rebuilding and resetting the router.
  ref.listen(authStateProvider, (previous, next) {
    router.refresh();
  });

  ref.onDispose(router.dispose);

  return router;
});
