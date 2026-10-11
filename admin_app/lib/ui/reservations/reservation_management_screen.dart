import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_parking_admin/core/widgets/admin_card.dart';
import 'package:smart_parking_admin/core/widgets/status_badge.dart';
import 'package:smart_parking_admin/data/models/reservation_model.dart';
import 'package:smart_parking_admin/domain/providers/admin_provider.dart';

class ReservationManagementScreen extends StatelessWidget {
  const ReservationManagementScreen({super.key});

  static const statuses = ['ACTIVE', 'PENDING', 'COMPLETED', 'CANCELLED'];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: statuses.length,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reservations',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Active'),
                  Tab(text: 'Pending'),
                  Tab(text: 'Completed'),
                  Tab(text: 'Cancelled'),
                ],
              ),
              const SizedBox(height: 16),
              const Expanded(
                child: TabBarView(
                  children: [
                    _ReservationTab(status: 'ACTIVE'),
                    _ReservationTab(status: 'PENDING'),
                    _ReservationTab(status: 'COMPLETED'),
                    _ReservationTab(status: 'CANCELLED'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReservationTab extends ConsumerWidget {
  const _ReservationTab({required this.status});

  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservations = ref.watch(reservationsProvider(status));
    return reservations.when(
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
              onPressed: () => ref.invalidate(reservationsProvider(status)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (items) => AdminCard(
        title: '${items.length} ${status.toLowerCase()}',
        padding: EdgeInsets.zero,
        child: items.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('No ${status.toLowerCase()} reservations'),
                ),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _ReservationsTable(
                  reservations: items,
                  onCancel: (reservation) =>
                      _cancel(context, ref, reservation),
                ),
              ),
      ),
    );
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    ReservationModel reservation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel reservation?'),
        content: Text(
          'Cancel ${reservation.userName}\'s reservation for '
          '${reservation.slotId}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel reservation'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(adminRepositoryProvider)
          .forceCancelReservation(reservation.id);
      ref.invalidate(reservationsProvider(status));
      ref.invalidate(reservationsProvider(''));
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

class _ReservationsTable extends StatelessWidget {
  const _ReservationsTable({
    required this.reservations,
    required this.onCancel,
  });

  final List<ReservationModel> reservations;
  final ValueChanged<ReservationModel> onCancel;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return DataTable(
      columns: const [
        DataColumn(label: Text('User')),
        DataColumn(label: Text('Slot')),
        DataColumn(label: Text('Area')),
        DataColumn(label: Text('Number Plate')),
        DataColumn(label: Text('Start time')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Amount')),
        DataColumn(label: Text('Action')),
      ],
      rows: [
        for (final reservation in reservations)
          DataRow(
            cells: [
              DataCell(Text(reservation.userName)),
              DataCell(Text(reservation.slotId)),
              DataCell(Text(reservation.areaName)),
              DataCell(Text(reservation.vehicleNumber)),
              DataCell(
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a')
                      .format(reservation.startTime.toLocal()),
                ),
              ),
              DataCell(
                StatusBadge(
                  text: reservation.status,
                  variant: _statusVariant(reservation.status),
                ),
              ),
              DataCell(Text(currency.format(reservation.amount))),
              DataCell(
                TextButton(
                  onPressed: reservation.canCancel
                      ? () => onCancel(reservation)
                      : null,
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

BadgeVariant _statusVariant(String status) {
  switch (status) {
    case 'ACTIVE':
    case 'COMPLETED':
      return BadgeVariant.success;
    case 'PENDING':
      return BadgeVariant.warning;
    case 'CANCELLED':
    case 'EXPIRED':
      return BadgeVariant.error;
    default:
      return BadgeVariant.info;
  }
}
