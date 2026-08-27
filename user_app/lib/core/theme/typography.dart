import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextTheme textTheme(Brightness brightness) {
    final baseTextTheme = brightness == Brightness.light
        ? Typography.material2021().black
        : Typography.material2021().white;

    return TextTheme(
      displayLarge: GoogleFonts.outfit(
        textStyle: baseTextTheme.displayLarge,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: GoogleFonts.outfit(
        textStyle: baseTextTheme.displayMedium,
        fontWeight: FontWeight.bold,
      ),
      displaySmall: GoogleFonts.outfit(
        textStyle: baseTextTheme.displaySmall,
        fontWeight: FontWeight.w600,
      ),
      headlineLarge: GoogleFonts.outfit(
        textStyle: baseTextTheme.headlineLarge,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.outfit(
        textStyle: baseTextTheme.headlineMedium,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.outfit(
        textStyle: baseTextTheme.headlineSmall,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.outfit(
        textStyle: baseTextTheme.titleLarge,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: GoogleFonts.outfit(
        textStyle: baseTextTheme.titleMedium,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: GoogleFonts.outfit(
        textStyle: baseTextTheme.titleSmall,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: GoogleFonts.inter(
        textStyle: baseTextTheme.bodyLarge,
        fontWeight: FontWeight.normal,
      ),
      bodyMedium: GoogleFonts.inter(
        textStyle: baseTextTheme.bodyMedium,
        fontWeight: FontWeight.normal,
      ),
      bodySmall: GoogleFonts.inter(
        textStyle: baseTextTheme.bodySmall,
        fontWeight: FontWeight.normal,
      ),
      labelLarge: GoogleFonts.inter(
        textStyle: baseTextTheme.labelLarge,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: GoogleFonts.inter(
        textStyle: baseTextTheme.labelMedium,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: GoogleFonts.inter(
        textStyle: baseTextTheme.labelSmall,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
