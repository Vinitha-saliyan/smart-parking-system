import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension BuildContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  Size get screenSize => MediaQuery.of(this).size;
  bool get isTablet => screenSize.width > 600;
  bool get isDarkMode => theme.brightness == Brightness.dark;
}

extension StringExtensions on String {
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  bool get isValidEmail {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);
  }
}

extension DateTimeExtensions on DateTime {
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inDays > 365)
      return '${(difference.inDays / 365).floor()} years ago';
    if (difference.inDays > 30)
      return '${(difference.inDays / 30).floor()} months ago';
    if (difference.inDays > 0) return '${difference.inDays} days ago';
    if (difference.inHours > 0) return '${difference.inHours} hours ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes} minutes ago';
    return 'Just now';
  }

  String get formatDate {
    return DateFormat('MMM dd, yyyy').format(this);
  }

  String get formatTime {
    return DateFormat('hh:mm a').format(this);
  }
}

extension DoubleExtensions on double {
  String toCurrency({String symbol = '₹'}) {
    return NumberFormat.currency(symbol: symbol, decimalDigits: 0).format(this);
  }
}
