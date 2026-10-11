import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_parking_admin/core/widgets/admin_card.dart';
import 'package:smart_parking_admin/core/widgets/search_field.dart';
import 'package:smart_parking_admin/core/widgets/status_badge.dart';
import 'package:smart_parking_admin/data/models/user_model.dart';
import 'package:smart_parking_admin/domain/providers/admin_provider.dart';
import 'package:smart_parking_admin/domain/providers/auth_provider.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState
    extends ConsumerState<UserManagementScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider(_search));
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'User Management',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh users',
                  onPressed: () => ref.invalidate(usersProvider(_search)),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SearchField(
              hint: 'Search by name or email',
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: users.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error.toString().replaceFirst('Bad state: ', ''),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(usersProvider(_search)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (items) => AdminCard(
                  title: '${items.length} user${items.length == 1 ? '' : 's'}',
                  padding: EdgeInsets.zero,
                  child: items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No matching users found')),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Action')),
                            ],
                            rows: [
                              for (final user in items)
                                _buildRow(
                                  context,
                                  ref,
                                  user,
                                  isCurrentUser: user.id == currentUser?.id,
                                ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildRow(
    BuildContext context,
    WidgetRef ref,
    UserModel user, {
    required bool isCurrentUser,
  }) {
    return DataRow(
      cells: [
        DataCell(Text(user.name)),
        DataCell(Text(user.email)),
        DataCell(StatusBadge(text: user.role.name, variant: BadgeVariant.info)),
        DataCell(
          StatusBadge(
            text: user.isActive ? 'Active' : 'Suspended',
            variant: user.isActive
                ? BadgeVariant.success
                : BadgeVariant.error,
          ),
        ),
        DataCell(
          TextButton(
            onPressed: isCurrentUser
                ? null
                : () => _toggleSuspended(context, ref, user),
            child: Text(user.isActive ? 'Suspend' : 'Activate'),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleSuspended(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) async {
    try {
      await ref
          .read(adminRepositoryProvider)
          .setUserSuspended(user.id, user.isActive);
      ref.invalidate(usersProvider(_search));
      ref.invalidate(dashboardStatsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }
}
