import 'package:flutter/material.dart';
import 'package:smart_parking_user/core/constants/app_constants.dart';

class AnimatedCounter extends StatelessWidget {
  final num targetValue;
  final String prefix;
  final String suffix;
  final TextStyle? textStyle;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.targetValue,
    this.prefix = '',
    this.suffix = '',
    this.textStyle,
    this.duration = const Duration(seconds: 1),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<num>(
      tween: Tween<num>(begin: 0, end: targetValue),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        String formattedValue = targetValue is int
            ? value.toInt().toString()
            : value.toStringAsFixed(1);
        return Text(
          '$prefix$formattedValue$suffix',
          style: textStyle,
        );
      },
    );
  }
}
