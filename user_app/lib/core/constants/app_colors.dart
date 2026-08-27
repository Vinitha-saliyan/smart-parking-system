import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF2563EB); // Royal Blue
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color secondary = Color(0xFF10B981); // Emerald Green
  static const Color accent = Color(0xFF8B5CF6); // Violet

  // Surface colors
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1E293B);

  // Status colors
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);

  // Slot status colors
  static const Color slotVacant = Color(0xFF10B981); // Green
  static const Color slotOccupied = Color(0xFFEF4444); // Red
  static const Color slotReserved = Color(0xFF3B82F6); // Blue
  static const Color slotVIP = Color(0xFF8B5CF6); // Purple
  static const Color slotEV = Color(0xFFF59E0B); // Amber
  static const Color slotDisabled = Color(0xFF6B7280); // Gray
  static const Color slotMaintenance = Color(0xFFF97316); // Orange

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [surfaceDark, Color(0xFF1E293B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
