import 'package:flutter/material.dart';

class AppColors {
  static const bg          = Color(0xFF0B0B1E);
  static const surface     = Color(0xFF14142B);
  static const card        = Color(0xFF1C1C38);
  static const cardBorder  = Color(0xFF2A2A50);
  static const primary     = Color(0xFFFF6B35);
  static const primaryDark = Color(0xFFCC4A1A);
  static const accent      = Color(0xFFFFD600);
  static const success     = Color(0xFF4CAF50);
  static const danger      = Color(0xFFEF5350);
  static const text        = Color(0xFFFFFFFF);
  static const textSub     = Color(0xFFAAAAAA);
  static const textHint    = Color(0xFF666680);
  static const purple      = Color(0xFF7B1FA2);
  static const navBg       = Color(0xFF0F0F28);
}

ThemeData buildDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
    ),
    useMaterial3: true,
  );
}
