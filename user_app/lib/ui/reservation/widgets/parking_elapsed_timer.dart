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

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.success.withOpacity(0.45)),
          ),
          child: Column(
            children: [
              Text(
                _formattedElapsed,
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Parking time',
                style: TextStyle(color: AppColors.textSecondaryDark),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: [
              const _FeeRow(label: 'First hour', amount: 20),
              const SizedBox(height: 10),
              const _FeeRow(
                  label: 'Each started extra hour', amount: 5, prefix: '+'),
              const SizedBox(height: 10),
              _FeeRow(label: 'Current parking fee', amount: _totalFee),
              const Divider(height: 26),
              const _FeeRow(label: 'Advance paid', amount: -10),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _FeeRow(
                  label: 'Current balance',
                  amount: checkoutBalance,
                  emphasize: true,
                ),
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
      ],
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({
    required this.label,
    required this.amount,
    this.emphasize = false,
    this.prefix = '',
  });

  final String label;
  final int amount;
  final bool emphasize;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final value = amount < 0 ? '-₹${amount.abs()}' : '$prefix₹$amount';
    final style = TextStyle(
      fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
      color: emphasize ? AppColors.success : null,
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
