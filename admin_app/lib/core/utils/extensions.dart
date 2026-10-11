import 'package:intl/intl.dart';

extension NumberFormatting on num {
  String get compactFormat {
    if (this >= 1000000) {
      return '${(this / 1000000).toStringAsFixed(1)}M';
    } else if (this >= 1000) {
      return '${(this / 1000).toStringAsFixed(1)}K';
    }
    return toString();
  }
  
  String get currencyFormat {
    final format = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    return format.format(this);
  }
}
