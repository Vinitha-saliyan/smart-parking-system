import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_parking_user/core/router/app_router.dart';
import 'package:smart_parking_user/core/theme/app_theme.dart';
import 'package:smart_parking_user/domain/providers/theme_provider.dart';

class SmartParkingApp extends ConsumerWidget {
  const SmartParkingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Smart Parking',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      routerConfig: router,
    );
  }
}
