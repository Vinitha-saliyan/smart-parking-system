import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_parking_admin/core/constants/app_colors.dart';
import 'package:smart_parking_admin/core/widgets/admin_card.dart';
import 'package:smart_parking_admin/data/models/parking_area_model.dart';
import 'package:smart_parking_admin/domain/providers/admin_provider.dart';

class ParkingManagementScreen extends ConsumerWidget {
  const ParkingManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = ref.watch(parkingAreasProvider);
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
                    'Parking Management',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh areas',
                  onPressed: () => ref.invalidate(parkingAreasProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Parking areas and live slot counts from PostgreSQL',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: areas.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _ParkingError(
                  error: error,
                  onRetry: () => ref.invalidate(parkingAreasProvider),
                ),
                data: (items) => items.isEmpty
                    ? const Center(
                        child: Text(
                          'No parking areas found. Run the backend seed command.',
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(parkingAreasProvider);
                          await ref.read(parkingAreasProvider.future);
                        },
                        child: GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 430,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.45,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) => _AreaCard(
                            area: items[index],
                            onActiveChanged: (value) async {
                              try {
                                await ref
                                    .read(adminRepositoryProvider)
                                    .setAreaActive(items[index].id, value);
                                ref.invalidate(parkingAreasProvider);
                                ref.invalidate(dashboardStatsProvider);
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        error
                                            .toString()
                                            .replaceFirst('Bad state: ', ''),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
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
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.area, required this.onActiveChanged});

  final ParkingAreaModel area;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      title: area.name,
      trailing: Switch(value: area.isActive, onChanged: onActiveChanged),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(area.address, maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _SlotMetric(
                  label: 'Total',
                  value: area.totalSlots,
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: _SlotMetric(
                  label: 'Available',
                  value: area.availableSlots,
                  color: AppColors.success,
                ),
              ),
              Expanded(
                child: _SlotMetric(
                  label: 'Occupied',
                  value: area.occupiedSlots,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotMetric extends StatelessWidget {
  const _SlotMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _ParkingError extends StatelessWidget {
  const _ParkingError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error.toString().replaceFirst('Bad state: ', ''),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
