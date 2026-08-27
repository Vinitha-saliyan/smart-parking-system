import 'package:flutter/material.dart';

class AppColors {
  // Brand colors used by the redesigned parking experience.
  static const Color primary = Color(0xFF2F6FED);
  static const Color primaryDark = Color(0xFF1749B8);
  static const Color primaryLight = Color(0xFF69A1FF);
  static const Color secondary = Color(0xFF18C394);
  static const Color accent = Color(0xFF38BDF8);

  // Surface colors
  static const Color surfaceLight = Color(0xFFF4F7FC);
  static const Color surfaceDark = Color(0xFF071426);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF102139);
  static const Color cardDarkElevated = Color(0xFF172A44);
  static const Color borderDark = Color(0xFF2A415F);
  static const Color textSecondaryDark = Color(0xFFA8B4C7);

  // Status colors
  static const Color error = Color(0xFFF04B55);
  static const Color warning = Color(0xFFFF9F1C);
  static const Color success = Color(0xFF18C394);

  // Slot status colors
  static const Color slotVacant = Color(0xFF18C394); // Green
  static const Color slotOccupied = Color(0xFFF04B55); // Red
  static const Color slotReserved = Color(0xFF3B82F6); // Blue
  static const Color slotVIP = Color(0xFF8B5CF6); // Purple
  static const Color slotEV = Color(0xFFF59E0B); // Amber
  static const Color slotDisabled = Color(0xFF6B7280); // Gray
  static const Color slotMaintenance = Color(0xFFF97316); // Orange

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF347DFF), Color(0xFF1749B8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [Color(0xFF071426), Color(0xFF0B1C32)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
