import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_parking_admin/core/constants/app_colors.dart';
import 'package:smart_parking_admin/core/widgets/admin_card.dart';
import 'package:smart_parking_admin/core/widgets/stat_card.dart';
import 'package:smart_parking_admin/data/models/parking_area_model.dart';
import 'package:smart_parking_admin/domain/providers/admin_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final areas = ref.watch(parkingAreasProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Analytics',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh analytics',
                  onPressed: () {
                    ref.invalidate(dashboardStatsProvider);
                    ref.invalidate(parkingAreasProvider);
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 24),
            stats.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _AnalyticsError(error: error),
              data: (value) => GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isDesktop ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isDesktop ? 1.55 : 1.15,
                children: [
                  StatCard(
                    title: 'Parking Areas',
                    value: '${value.totalAreas}',
                    icon: Icons.location_city,
                    color: AppColors.primary,
                    change: '${value.totalSlots} slots',
                    isPositive: true,
                    changeLabel: 'configured',
                  ),
                  StatCard(
                    title: 'Occupancy',
                    value: '${value.occupancyRate.toStringAsFixed(1)}%',
                    icon: Icons.directions_car,
                    color: AppColors.error,
                    change: '${value.occupiedSlots}',
                    isPositive: value.occupancyRate < 90,
                    changeLabel: 'occupied',
                  ),
                  StatCard(
                    title: 'Reservations',
                    value: '${value.totalReservations}',
                    icon: Icons.book_online,
                    color: AppColors.accent,
                    change: '${value.reservedSlots}',
                    isPositive: true,
                    changeLabel: 'reserved slots',
                  ),
                  StatCard(
                    title: 'Revenue',
                    value: NumberFormat.currency(
                      locale: 'en_IN',
                      symbol: '₹',
                      decimalDigits: 0,
                    ).format(value.totalRevenue),
                    icon: Icons.currency_rupee,
                    color: AppColors.success,
                    change: 'Live',
                    isPositive: true,
                    changeLabel: 'database total',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AdminCard(
              title: 'Occupancy by Area',
              child: areas.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _AnalyticsError(error: error),
                data: (items) => items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No parking areas available')),
                      )
                    : Column(
                        children: [
                          for (final area in items) _AreaOccupancyRow(area: area),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaOccupancyRow extends StatelessWidget {
  const _AreaOccupancyRow({required this.area});

  final ParkingAreaModel area;

  @override
  Widget build(BuildContext context) {
    final rate = area.totalSlots == 0
        ? 0.0
        : (area.occupiedSlots / area.totalSlots).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              area.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 12,
              borderRadius: BorderRadius.circular(8),
              color: rate >= 0.9 ? AppColors.error : AppColors.primary,
              backgroundColor: AppColors.success.withOpacity(0.2),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 90,
            child: Text(
              '${area.occupiedSlots}/${area.totalSlots}',
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsError extends StatelessWidget {
  const _AnalyticsError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          error.toString().replaceFirst('Bad state: ', ''),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
