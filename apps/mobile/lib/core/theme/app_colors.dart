import 'package:flutter/material.dart';

abstract class AppColors {
  // Backgrounds
  static const Color backgroundPrimary = Color(0xFF121212);
  static const Color backgroundSecondary = Color(0xFF1E1E1E);
  static const Color backgroundCard = Color(0xFF1E1E1E);
  static const Color backgroundElevated = Color(0xFF252525);

  // Surfaces
  static const Color surfaceElevated = Color(0xFF333333);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textDisabled = Color(0xFF666666);

  // Brand / Accent
  static const Color accentPrimary = Color(0xFF00E676);
  static const Color accentLight = Color(0xFF69F0AE);
  static const Color accentMuted = Color(0x1F00E676); // 12% opacity

  // Borders
  static const Color borderDefault = Color(0xFF3A3A3A);
  static const Color borderFocused = accentPrimary;

  // Semantic
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);
}
