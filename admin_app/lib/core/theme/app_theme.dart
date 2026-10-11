import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_parking_admin/core/constants/app_colors.dart';

class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        surface: AppColors.surfaceLight,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.surfaceLight,
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
      ),
      textTheme: _textTheme(Colors.black87),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: AppColors.surfaceDark,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.surfaceDark,
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white10),
        ),
        margin: EdgeInsets.zero,
      ),
      textTheme: _textTheme(Colors.white),
    );
  }

  static TextTheme _textTheme(Color color) {
    return TextTheme(
      displayLarge: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold),
      displayMedium: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold),
      displaySmall: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold),
      headlineLarge: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w600),
      headlineMedium: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.inter(color: color, fontWeight: FontWeight.w500),
      titleSmall: GoogleFonts.inter(color: color, fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.inter(color: color),
      bodyMedium: GoogleFonts.inter(color: color),
      bodySmall: GoogleFonts.inter(color: color.withOpacity(0.7)),
      labelLarge: GoogleFonts.inter(color: color, fontWeight: FontWeight.w600),
      labelMedium: GoogleFonts.inter(color: color, fontWeight: FontWeight.w500),
      labelSmall: GoogleFonts.inter(color: color, fontWeight: FontWeight.w500),
    );
  }
}
