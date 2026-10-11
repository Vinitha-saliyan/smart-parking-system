import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_parking_admin/core/constants/app_constants.dart';
import 'package:smart_parking_admin/core/widgets/admin_card.dart';
import 'package:smart_parking_admin/domain/providers/auth_provider.dart';
import 'package:smart_parking_admin/domain/providers/theme_provider.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            AdminCard(
              title: 'Administrator Account',
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(user?.name ?? 'Administrator'),
                    subtitle: Text(user?.email ?? 'No account loaded'),
                    trailing: Text(user?.role.name ?? ''),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: const Text('Backend API'),
                    subtitle: Text(AppConstants.apiBaseUrl),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    onTap: () async {
                      await ref.read(authStateProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AdminCard(
              title: 'Appearance',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dark mode'),
                value: ref.watch(themeProvider),
                onChanged: (value) =>
                    ref.read(themeProvider.notifier).state = value,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
