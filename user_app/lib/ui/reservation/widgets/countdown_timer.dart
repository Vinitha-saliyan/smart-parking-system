import 'dart:async';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
import 'package:smart_parking_user/core/constants/app_constants.dart';

class CountdownTimer extends StatefulWidget {
  final DateTime targetTime;
  final VoidCallback? onExpire;

  const CountdownTimer({
    super.key,
    required this.targetTime,
    this.onExpire,
  });

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  final Duration _totalDuration = const Duration(
    minutes: AppConstants.reservationTimeoutMinutes,
  );

  @override
  void initState() {
    super.initState();
    _updateTime();
    if (_remaining > Duration.zero) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    }
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _remaining = widget.targetTime.difference(now);
      if (_remaining.isNegative) {
        _remaining = Duration.zero;
        _timer?.cancel();
        widget.onExpire?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage =
        (_remaining.inSeconds / _totalDuration.inSeconds).clamp(0.0, 1.0);
    final color = _remaining.inMinutes > 5
        ? AppColors.success
        : (_remaining.inMinutes > 2 ? AppColors.warning : AppColors.error);

    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularPercentIndicator(
            radius: 42.0,
            lineWidth: 8.0,
            percent: percentage,
            center: Icon(Icons.timer_outlined, color: color, size: 28),
            progressColor: color,
            backgroundColor: color.withOpacity(0.2),
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animateFromLastPercent: true,
          ),
          const SizedBox(width: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$minutes:$seconds',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Entry time remaining',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
