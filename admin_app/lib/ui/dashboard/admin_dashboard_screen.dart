import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:smart_parking_admin/core/constants/app_colors.dart';
import 'package:smart_parking_admin/core/widgets/admin_card.dart';
import 'package:smart_parking_admin/core/widgets/stat_card.dart';
import 'package:smart_parking_admin/core/widgets/status_badge.dart';
import 'package:smart_parking_admin/data/models/reservation_model.dart';
import 'package:smart_parking_admin/data/models/stats_model.dart';
import 'package:smart_parking_admin/domain/providers/admin_provider.dart';
import 'package:smart_parking_admin/ui/dashboard/widgets/camera_status_grid.dart';
import 'package:smart_parking_admin/ui/dashboard/widgets/occupancy_gauge.dart';
import 'package:smart_parking_admin/ui/dashboard/widgets/revenue_chart.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    return Scaffold(
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _LoadError(
          error: error,
          onRetry: () => ref.invalidate(dashboardStatsProvider),
        ),
        data: (data) => _DashboardContent(stats: data),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.stats});

  final StatsModel stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final recentReservations = ref.watch(reservationsProvider(''));
    final cameras = ref.watch(camerasProvider);
    final number = NumberFormat.decimalPattern('en_IN');
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(reservationsProvider(''));
        ref.invalidate(camerasProvider);
        await ref.read(dashboardStatsProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Dashboard Overview',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh live data',
                  onPressed: () {
                    ref.invalidate(dashboardStatsProvider);
                    ref.invalidate(reservationsProvider(''));
                    ref.invalidate(camerasProvider);
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isDesktop ? 4 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isDesktop ? 1.5 : 1.15,
              children: [
                StatCard(
                  title: 'Total Slots',
                  value: number.format(stats.totalSlots),
                  icon: Icons.local_parking,
                  color: AppColors.primary,
                  change: '${stats.availableSlots} available',
                  isPositive: true,
                  changeLabel: 'in database',
                ),
                StatCard(
                  title: 'Occupied Now',
                  value: number.format(stats.occupiedSlots),
                  icon: Icons.directions_car,
                  color: AppColors.error,
                  change: '${stats.occupancyRate.toStringAsFixed(1)}%',
                  isPositive: stats.occupancyRate < 90,
                  changeLabel: 'occupancy',
                ),
                StatCard(
                  title: 'Total Revenue',
                  value: currency.format(stats.totalRevenue),
                  icon: Icons.currency_rupee,
                  color: AppColors.success,
                  change: '${stats.totalReservations}',
                  isPositive: true,
                  changeLabel: 'reservations',
                ),
                StatCard(
                  title: 'Active Users',
                  value: number.format(stats.activeUsers),
                  icon: Icons.people,
                  color: AppColors.accent,
                  change: '${stats.totalUsers} total',
                  isPositive: true,
                  changeLabel: 'accounts',
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: RevenueChart(points: stats.revenueLast7Days),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: OccupancyGauge(
                      available: stats.availableSlots,
                      occupied: stats.occupiedSlots,
                      reserved: stats.reservedSlots,
                      occupancyRate: stats.occupancyRate,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  RevenueChart(points: stats.revenueLast7Days),
                  const SizedBox(height: 24),
                  OccupancyGauge(
                    available: stats.availableSlots,
                    occupied: stats.occupiedSlots,
                    reserved: stats.reservedSlots,
                    occupancyRate: stats.occupancyRate,
                  ),
                ],
              ),
            const SizedBox(height: 24),
            AdminCard(
              title: 'Recent Reservations',
              trailing: TextButton(
                onPressed: () => context.go('/reservations'),
                child: const Text('View all'),
              ),
              child: recentReservations.when(
                loading: () => const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => _InlineError(
                  error: error,
                  onRetry: () => ref.invalidate(reservationsProvider('')),
                ),
                data: (items) => _RecentReservationsTable(
                  reservations: items.take(5).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: cameras.when(
                      loading: () => const AdminCard(
                        title: 'Camera Status',
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stackTrace) => AdminCard(
                        title: 'Camera Status',
                        child: _InlineError(
                          error: error,
                          onRetry: () => ref.invalidate(camerasProvider),
                        ),
                      ),
                      data: (items) => CameraStatusGrid(cameras: items),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(child: _QuickActions()),
                ],
              )
            else ...[
              cameras.when(
                loading: () => const AdminCard(
                  title: 'Camera Status',
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => AdminCard(
                  title: 'Camera Status',
                  child: _InlineError(
                    error: error,
                    onRetry: () => ref.invalidate(camerasProvider),
                  ),
                ),
                data: (items) => CameraStatusGrid(cameras: items),
              ),
              const SizedBox(height: 24),
              _QuickActions(),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentReservationsTable extends StatelessWidget {
  const _RecentReservationsTable({required this.reservations});

  final List<ReservationModel> reservations;

  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('No reservations in the database yet')),
      );
    }
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('User')),
          DataColumn(label: Text('Slot')),
          DataColumn(label: Text('Area')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Start')),
          DataColumn(label: Text('Amount')),
        ],
        rows: [
          for (final reservation in reservations)
            DataRow(
              cells: [
                DataCell(Text(reservation.userName)),
                DataCell(Text(reservation.slotId)),
                DataCell(Text(reservation.areaName)),
                DataCell(
                  StatusBadge(
                    text: reservation.status,
                    variant: _variantForStatus(reservation.status),
                  ),
                ),
                DataCell(Text(DateFormat('dd MMM, hh:mm a').format(reservation.startTime.toLocal()))),
                DataCell(Text(currency.format(reservation.amount))),
              ],
            ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AdminCard(
      title: 'Quick Actions',
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.local_parking, color: AppColors.primary),
            title: const Text('Manage Parking'),
            onTap: () => context.go('/parking'),
          ),
          ListTile(
            leading: Icon(Icons.people, color: AppColors.accent),
            title: const Text('Manage Users'),
            onTap: () => context.go('/users'),
          ),
          ListTile(
            leading: Icon(Icons.book_online, color: AppColors.success),
            title: const Text('Review Reservations'),
            onTap: () => context.go('/reservations'),
          ),
          ListTile(
            leading: Icon(Icons.analytics, color: AppColors.warning),
            title: const Text('View Analytics'),
            onTap: () => context.go('/analytics'),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('Could not load backend data'),
            const SizedBox(height: 8),
            Text(
              error.toString().replaceFirst('Bad state: ', ''),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

BadgeVariant _variantForStatus(String status) {
  switch (status.toUpperCase()) {
    case 'ACTIVE':
    case 'COMPLETED':
      return BadgeVariant.success;
    case 'PENDING':
    case 'RESERVED':
      return BadgeVariant.warning;
    case 'CANCELLED':
    case 'EXPIRED':
      return BadgeVariant.error;
    default:
      return BadgeVariant.info;
  }
}
