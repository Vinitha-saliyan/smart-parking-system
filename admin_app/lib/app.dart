import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_parking_admin/core/router/app_router.dart';
import 'package:smart_parking_admin/core/theme/app_theme.dart';
import 'package:smart_parking_admin/domain/providers/theme_provider.dart';

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final isDarkMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Smart Parking Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
