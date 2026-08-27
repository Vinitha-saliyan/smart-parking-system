import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
import 'package:smart_parking_user/core/constants/app_constants.dart';
import 'package:smart_parking_user/core/utils/extensions.dart';
import 'package:smart_parking_user/core/widgets/gradient_button.dart';
import 'package:smart_parking_user/core/widgets/shimmer_loading.dart';
import 'package:smart_parking_user/data/models/reservation_model.dart';
import 'package:smart_parking_user/domain/providers/reservation_provider.dart';
import 'package:smart_parking_user/ui/payment/payment_screen.dart';
import 'package:smart_parking_user/ui/reservation/widgets/countdown_timer.dart';
import 'package:smart_parking_user/ui/reservation/widgets/parking_elapsed_timer.dart';
import 'package:smart_parking_user/ui/reservation/widgets/reservation_card.dart';

class ReservationScreen extends ConsumerStatefulWidget {
  const ReservationScreen({super.key});

  @override
  ConsumerState<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends ConsumerState<ReservationScreen> {
  bool _isActionLoading = false;

  Future<void> _onRefresh() async {
    ref.invalidate(activeReservationProvider);
    ref.invalidate(reservationsListProvider);
  }

  Future<void> _cancelReservation(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Reservation'),
        content: const Text(
          'Are you sure? Any ₹10 advance already paid is non-refundable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(reservationRepositoryProvider).cancelReservation(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation cancelled')),
      );
      await _onRefresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Unable to cancel this reservation. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _beginCheckout(ReservationModel reservation) async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);

    try {
      final checkout = await ref
          .read(reservationRepositoryProvider)
          .checkOut(reservation.id);
      final totalAmount = checkout.totalAmount ?? 20;
      final amountDuePaise = ((totalAmount - 10) * 100).round();

      ref.invalidate(activeReservationProvider);
      ref.invalidate(reservationsListProvider);
      if (!mounted) return;
      setState(() => _isActionLoading = false);

      await context.push(
        '/payment',
        extra: PaymentScreenArgs(
          reservationId: checkout.id,
          amountPaise: amountDuePaise,
          purpose: 'SETTLEMENT',
        ),
      );
      if (!mounted) return;
      await _onRefresh();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isActionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to complete checkout. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeReservation = ref.watch(activeReservationProvider);
    final reservationHistory = ref.watch(reservationsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            activeReservation.when(
              data: (reservation) {
                if (reservation == null) {
                  return _buildEmptyState().animate().fadeIn();
                }

                switch (reservation.status) {
                  case 'PAYMENT_PENDING':
                    return _buildAdvancePayment(reservation).animate().fadeIn();
                  case 'PENDING':
                    return _buildWaitingForEntry(reservation)
                        .animate()
                        .fadeIn();
                  case 'ACTIVE':
                    return _buildActiveParking(reservation).animate().fadeIn();
                  case 'CHECKOUT_PAYMENT_PENDING':
                    return _buildCheckoutPayment(reservation)
                        .animate()
                        .fadeIn();
                  default:
                    return _buildEmptyState().animate().fadeIn();
                }
              },
              loading: () => Column(
                children: [
                  const SizedBox(height: 20),
                  ShimmerLoading.card(height: 200),
                  const SizedBox(height: 20),
                  ShimmerLoading.card(height: 300),
                ],
              ),
              error: (error, _) => _buildLoadError(
                'Unable to load your active booking.',
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Past Bookings',
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            reservationHistory.when(
              data: (history) {
                final past = history.where((reservation) {
                  return reservation.status != 'ACTIVE' &&
                      reservation.status != 'PENDING' &&
                      reservation.status != 'PAYMENT_PENDING' &&
                      reservation.status != 'CHECKOUT_PAYMENT_PENDING';
                }).toList();

                if (past.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No past bookings',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: past.length,
                  itemBuilder: (context, index) {
                    return ReservationCard(reservation: past[index])
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: 100 * index))
                        .slideX(begin: 0.1, end: 0);
                  },
                );
              },
              loading: () => ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                itemBuilder: (context, index) => const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: ShimmerLoading(width: double.infinity, height: 120),
                ),
              ),
              error: (error, _) => _buildLoadError(
                'Unable to load past bookings.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _entryDeadline(ReservationModel reservation) {
    final reservedAt = reservation.createdAt ?? reservation.startTime;
    return reservedAt.add(
      const Duration(minutes: AppConstants.reservationTimeoutMinutes),
    );
  }

  Widget _buildAdvancePayment(ReservationModel reservation) {
    return Column(
      children: [
        _statusIcon(
          icon: Icons.lock_outline_rounded,
          color: AppColors.primary,
        ),
        const SizedBox(height: 18),
        Text(
          'Complete Your Reservation',
          textAlign: TextAlign.center,
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pay the ₹10 advance to confirm the selected slot.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: 22),
        _bookingSummaryCard(reservation),
        const SizedBox(height: 20),
        CountdownTimer(
          targetTime: _entryDeadline(reservation),
          onExpire: _onRefresh,
        ),
        const SizedBox(height: 22),
        GradientButton(
          text: 'Pay ₹10 Advance',
          icon: Icons.payment,
          onPressed: () => context.push(
            '/payment',
            extra: PaymentScreenArgs(
              reservationId: reservation.id,
              amountPaise: 1000,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => _cancelReservation(reservation.id),
          child: const Text(
            'Cancel Reservation',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingForEntry(ReservationModel reservation) {
    final slotLabel = _slotLabel(reservation);
    return Column(
      children: [
        _statusIcon(
          icon: Icons.check_rounded,
          color: AppColors.success,
        ),
        const SizedBox(height: 18),
        Text(
          'Booking Confirmed',
          textAlign: TextAlign.center,
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your ₹10 advance is paid. Enter before the hold expires.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: 22),
        _bookingSummaryCard(reservation),
        const SizedBox(height: 18),
        CountdownTimer(
          targetTime: _entryDeadline(reservation),
          onExpire: _onRefresh,
        ),
        const SizedBox(height: 22),
        GradientButton(
          text: 'Navigate to Slot $slotLabel',
          icon: Icons.navigation_rounded,
          onPressed: () => context.push(
            '/reservations/navigate',
            extra: reservation,
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => _cancelReservation(reservation.id),
          child: const Text(
            'Cancel (₹10 advance is non-refundable)',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveParking(ReservationModel reservation) {
    final checkInTime = reservation.actualCheckIn;
    if (checkInTime == null) {
      return const Center(child: Text('Waiting for check-in time...'));
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.success.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 18,
              ),
              const SizedBox(width: 7),
              Text(
                'Vehicle checked in · ${_slotLabel(reservation)}',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _bookingSummaryCard(reservation),
        const SizedBox(height: 18),
        ParkingElapsedTimer(checkInTime: checkInTime),
        const SizedBox(height: 20),
        GradientButton(
          text: 'End Parking & Pay',
          icon: Icons.exit_to_app,
          isLoading: _isActionLoading,
          onPressed:
              _isActionLoading ? null : () => _beginCheckout(reservation),
        ),
      ],
    );
  }

  Widget _buildCheckoutPayment(ReservationModel reservation) {
    final total = reservation.totalAmount ?? 20;
    final balancePaise = ((total - 10) * 100).round();

    return Column(
      children: [
        _statusIcon(
          icon: Icons.payments_outlined,
          color: AppColors.warning,
        ),
        const SizedBox(height: 18),
        Text(
          'Complete Your Checkout',
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'The parking timer has stopped.',
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _AmountRow(label: 'Total parking fee', amount: total),
                const SizedBox(height: 10),
                const _AmountRow(label: 'Advance paid', amount: -10),
                const Divider(height: 28),
                _AmountRow(
                  label: 'Balance to pay',
                  amount: total - 10,
                  emphasize: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'The slot remains occupied until the final payment is verified.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        GradientButton(
          text: 'Pay Final Balance',
          icon: Icons.payment,
          onPressed: () => context.push(
            '/payment',
            extra: PaymentScreenArgs(
              reservationId: reservation.id,
              amountPaise: balancePaise,
              purpose: 'SETTLEMENT',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car,
            size: 80,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Active Reservations',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'You don\'t have any active parking reservations at the moment.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          GradientButton(
            text: 'Find Parking',
            icon: Icons.search,
            onPressed: () => context.go('/search'),
          ),
        ],
      ),
    );
  }

  Widget _bookingSummaryCard(ReservationModel reservation) {
    final floor = reservation.slotDetails?.floor ?? 1;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.local_parking_rounded,
              color: AppColors.primaryLight,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reservation.areaName ?? 'Smart Parking',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Slot ${_slotLabel(reservation)} · Floor $floor',
                  style: const TextStyle(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusIcon({required IconData icon, required Color color}) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.45), width: 2),
      ),
      child: Icon(icon, color: color, size: 44),
    );
  }

  String _slotLabel(ReservationModel reservation) {
    return reservation.slotDetails?.slotId ?? reservation.slotId;
  }

  Widget _buildLoadError(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.warning),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.emphasize = false,
  });

  final String label;
  final double amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final prefix = amount < 0 ? '-' : '';
    final style = TextStyle(
      fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
      color: emphasize ? AppColors.primary : null,
      fontSize: emphasize ? 18 : null,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          '$prefix₹${amount.abs().toStringAsFixed(2)}',
          style: style,
        ),
      ],
    );
  }
}
