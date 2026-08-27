import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';

class ParkingElapsedTimer extends StatefulWidget {
  const ParkingElapsedTimer({
    super.key,
    required this.checkInTime,
  });

  final DateTime checkInTime;

  @override
  State<ParkingElapsedTimer> createState() => _ParkingElapsedTimerState();
}

class _ParkingElapsedTimerState extends State<ParkingElapsedTimer> {
  Timer? _timer;
  int _elapsedSeconds = 1;

  @override
  void initState() {
    super.initState();
    _updateElapsedTime();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateElapsedTime(),
    );
  }

  @override
  void didUpdateWidget(covariant ParkingElapsedTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checkInTime != widget.checkInTime) {
      _updateElapsedTime();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateElapsedTime() {
    final seconds = DateTime.now().difference(widget.checkInTime).inSeconds;
    if (!mounted) return;
    setState(() => _elapsedSeconds = seconds < 1 ? 1 : seconds);
  }

  int get _totalFee {
    if (_elapsedSeconds <= 3600) return 20;
    final extraStartedHours = (_elapsedSeconds - 3600 + 3599) ~/ 3600;
    return 20 + (extraStartedHours * 5);
  }

  String get _formattedElapsed {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final checkoutBalance = _totalFee - 10;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, color: AppColors.success),
                SizedBox(width: 8),
                Text(
                  'Parking time',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _formattedElapsed,
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            _FeeRow(label: 'Current parking fee', amount: _totalFee),
            const SizedBox(height: 8),
            const _FeeRow(label: 'Advance paid', amount: -10),
            const SizedBox(height: 8),
            _FeeRow(
              label: 'Current checkout balance',
              amount: checkoutBalance,
              emphasize: true,
            ),
            const SizedBox(height: 12),
            const Text(
              '₹20 covers the first hour. Each started extra hour adds ₹5.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({
    required this.label,
    required this.amount,
    this.emphasize = false,
  });

  final String label;
  final int amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final value = amount < 0 ? '-₹${amount.abs()}' : '₹$amount';
    final style = TextStyle(
      fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
      color: emphasize ? AppColors.primary : null,
      fontSize: emphasize ? 17 : null,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}
