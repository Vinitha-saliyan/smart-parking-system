import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
import 'package:smart_parking_user/domain/providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader('Preferences'),
          _buildSettingTile(
            context: context,
            title: 'Dark Mode',
            icon: Icons.dark_mode_outlined,
            trailing: Switch(
              value: themeMode == ThemeMode.dark,
              onChanged: (val) {
                ref.read(themeProvider.notifier).toggle();
              },
              activeColor: AppColors.primary,
            ),
          ),
          _buildSettingTile(
            context: context,
            title: 'Language',
            icon: Icons.language,
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('English', style: TextStyle(color: Colors.grey)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Notifications'),
          _buildSettingTile(
            context: context,
            title: 'Push Notifications',
            icon: Icons.notifications_active_outlined,
            trailing: Switch(
              value: true,
              onChanged: (val) {},
              activeColor: AppColors.primary,
            ),
          ),
          _buildSettingTile(
            context: context,
            title: 'Email Updates',
            icon: Icons.email_outlined,
            trailing: Switch(
              value: false,
              onChanged: (val) {},
              activeColor: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Security & Account'),
          _buildSettingTile(
            context: context,
            title: 'Change Password',
            icon: Icons.lock_outline,
            onTap: () {},
          ),
          _buildSettingTile(
            context: context,
            title: 'Delete Account',
            icon: Icons.delete_outline,
            iconColor: AppColors.error,
            textColor: AppColors.error,
            onTap: () {},
          ),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'App Version 1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: iconColor ?? AppColors.primary),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: textColor ?? Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey)
                : null),
      ),
    );
  }
}
