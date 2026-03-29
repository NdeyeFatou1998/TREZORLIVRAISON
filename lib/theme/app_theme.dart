import 'package:flutter/material.dart';

/// Couleurs et thème identiques à Trezor App — cohérence visuelle garantie.
class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const primaryLight = Color(0xFFEDE9FF);
  static const accent = Color(0xFFFFD700);

  static const gold = Color(0xFFD4A843);
  static const goldLight = Color(0xFFF5E6B8);
  static const goldDark = Color(0xFFB8922E);

  static const deepPurple = Color(0xFF1E0A3C);
  static const deepPurpleLight = Color(0xFF2D1254);
  static const deepPurpleDark = Color(0xFF120625);

  static const lightBg = Color(0xFFF8F9FC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF1A1D2E);
  static const lightTextSecondary = Color(0xFF5A5E78);
  static const lightTextMuted = Color(0xFF9498B0);
  static const lightBorder = Color(0xFFE8E9F0);
  static const lightInputBg = Color(0xFFF4F5F9);

  static const darkBg = Color(0xFF0F1117);
  static const darkSurface = Color(0xFF1A1D2E);
  static const darkCard = Color(0xFF1E2134);
  static const darkText = Color(0xFFF0F1F5);
  static const darkTextSecondary = Color(0xFFA0A4C0);
  static const darkTextMuted = Color(0xFF6B6F8D);
  static const darkBorder = Color(0xFF2A2D42);
  static const darkInputBg = Color(0xFF252840);
  static const darkPrimaryLight = Color(0xFF2A2650);

  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  // Couleur d'accentuation livraison
  static const delivery = Color(0xFF00C853);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.lightBg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.lightSurface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.deepPurple,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightCard,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedItemColor: AppColors.deepPurple,
      unselectedItemColor: AppColors.lightTextMuted,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.darkSurface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.deepPurple,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkCard,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: AppColors.darkTextMuted,
    ),
  );
}
