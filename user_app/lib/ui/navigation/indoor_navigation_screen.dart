import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
import 'package:smart_parking_user/core/widgets/gradient_button.dart';
import 'package:smart_parking_user/data/models/reservation_model.dart';
import 'package:smart_parking_user/domain/providers/reservation_provider.dart';

class IndoorNavigationScreen extends ConsumerStatefulWidget {
  const IndoorNavigationScreen({
    super.key,
    required this.reservation,
  });

  final ReservationModel reservation;

  @override
  ConsumerState<IndoorNavigationScreen> createState() =>
      _IndoorNavigationScreenState();
}

class _IndoorNavigationScreenState
    extends ConsumerState<IndoorNavigationScreen> {
  String get _slotLabel =>
      widget.reservation.slotDetails?.slotId ?? widget.reservation.slotId;

  int get _floor => widget.reservation.slotDetails?.floor ?? 1;

  void _viewBookingStatus() {
    ref.invalidate(activeReservationProvider);
    ref.invalidate(reservationsListProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The timer starts automatically after the camera confirms your vehicle in the allotted slot.',
        ),
        backgroundColor: AppColors.primary,
      ),
    );
    context.go('/reservations');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Navigate to $_slotLabel'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.35),
                  ),
                ),
                child: Text(
                  'Floor $_floor',
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _ParkingFloorPlan(targetSlot: _slotLabel),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: const Column(
                children: [
                  _DirectionRow(
                    icon: Icons.arrow_upward_rounded,
                    title: 'Continue straight from Gate 1',
                    subtitle: 'Follow the highlighted driving lane',
                  ),
                  Divider(height: 26),
                  _DirectionRow(
                    icon: Icons.turn_left_rounded,
                    title: 'Turn left at the marked zone',
                    subtitle: 'Your allocated slot is highlighted in green',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GradientButton(
              text: 'Check Camera Confirmation',
              icon: Icons.videocam_outlined,
              onPressed: _viewBookingStatus,
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.textSecondaryDark,
                ),
                SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Use this route from Gate 1. Billing begins only after the parking camera confirms your vehicle in $_slotLabel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ParkingFloorPlan extends StatelessWidget {
  const _ParkingFloorPlan({required this.targetSlot});

  final String targetSlot;

  List<String> get _slots {
    final match = RegExp(r'^[A-Za-z]+').firstMatch(targetSlot);
    final prefix = match?.group(0)?.toUpperCase() ?? 'A';
    final result = List.generate(
      8,
      (index) => '$prefix${(index + 1).toString().padLeft(2, '0')}',
    );
    if (!result.contains(targetSlot)) result[0] = targetSlot;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots;
    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1C31),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderDark),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = (constraints.maxWidth - 128) / 2;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RoutePainter(),
                ),
              ),
              Positioned(
                top: 18,
                left: constraints.maxWidth / 2 - 34,
                child: _zoneLabel(),
              ),
              for (var index = 0; index < 4; index++)
                Positioned(
                  left: 14,
                  top: 18 + (index * 72),
                  child: _slotCard(
                    slots[index],
                    slotWidth,
                    slots[index] == targetSlot,
                  ),
                ),
              for (var index = 0; index < 4; index++)
                Positioned(
                  right: 14,
                  top: 18 + (index * 72),
                  child: _slotCard(
                    slots[index + 4],
                    slotWidth,
                    slots[index + 4] == targetSlot,
                  ),
                ),
              Positioned(
                bottom: 18,
                left: constraints.maxWidth / 2 - 42,
                child: Container(
                  width: 84,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cardDarkElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.my_location_rounded,
                        color: AppColors.primaryLight,
                        size: 20,
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Gate 1',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _zoneLabel() {
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'ZONE',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.primaryLight,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _slotCard(String label, double width, bool selected) {
    final color = selected ? AppColors.success : AppColors.borderDark;
    return Container(
      width: width,
      height: 58,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.success.withOpacity(0.18)
            : AppColors.cardDark.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: selected ? 2 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_filled_rounded,
            size: 20,
            color: selected ? AppColors.success : AppColors.textSecondaryDark,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final route = Paint()
      ..color = AppColors.primaryLight
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final glow = Paint()
      ..color = AppColors.primary.withOpacity(0.35)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width / 2, size.height - 72)
      ..lineTo(size.width / 2, 76)
      ..lineTo(78, 76);
    canvas.drawPath(path, glow);
    canvas.drawPath(path, route);

    final arrow = Path()
      ..moveTo(size.width / 2 - 8, size.height / 2 + 8)
      ..lineTo(size.width / 2, size.height / 2)
      ..lineTo(size.width / 2 + 8, size.height / 2 + 8);
    canvas.drawPath(arrow, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DirectionRow extends StatelessWidget {
  const _DirectionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
