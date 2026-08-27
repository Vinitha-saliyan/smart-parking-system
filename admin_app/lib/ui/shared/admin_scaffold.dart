import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_parking_admin/domain/providers/theme_provider.dart';
import 'package:smart_parking_admin/domain/providers/auth_provider.dart';

class AdminScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AdminScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Smart Parking Admin'),
        actions: [
          IconButton(
            icon: Icon(ref.watch(themeProvider) ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => ref.read(themeProvider.notifier).state = !ref.read(themeProvider),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: isDesktop
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (index) => navigationShell.goBranch(index),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
                    NavigationRailDestination(icon: Icon(Icons.local_parking), label: Text('Parking')),
                    NavigationRailDestination(icon: Icon(Icons.people), label: Text('Users')),
                    NavigationRailDestination(icon: Icon(Icons.book_online), label: Text('Reservations')),
                    NavigationRailDestination(icon: Icon(Icons.analytics), label: Text('Analytics')),
                    NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Settings')),
                  ],
                ),
                Expanded(child: navigationShell),
              ],
            )
          : navigationShell,
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: navigationShell.currentIndex,
              onTap: (index) => navigationShell.goBranch(index),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.local_parking), label: 'Parking'),
                BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
                BottomNavigationBarItem(icon: Icon(Icons.book_online), label: 'Reservations'),
                BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
                BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
              ],
            ),
    );
  }
}
