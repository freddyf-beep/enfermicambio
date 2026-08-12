import 'package:flutter/material.dart';

class AppColors {
  // Brand colors
  static const Color primary = Color(0xFF0284C7);
  static const Color primaryLight = Color(0xFF38BDF8);
  static const Color fitnessGreen = Color(0xFF10B981);
  static const Color streakOrange = Color(0xFFF97316);
  static const Color trophyPurple = Color(0xFFA855F7);
  static const Color macroCarbs = Color(0xFFEAB308);
  static const Color macroFat = Color(0xFFEC4899);

  // Dark Theme surface palette
  static const Color darkBackground = Color(0xFF0B132B);
  static const Color darkSurface = Color(0xFF162544);
  static const Color darkSurfaceVariant = Color(0xFF1E325C);
  static const Color darkBorder = Color(0xFF2A437E);

  // Light Theme surface palette
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        secondary: AppColors.fitnessGreen,
        tertiary: AppColors.streakOrange,
        surface: AppColors.darkSurface,
        surfaceContainerHighest: AppColors.darkSurfaceVariant,
        onSurface: Color(0xFFF8FAFC),
        onSurfaceVariant: Color(0xFF94A3B8),
        outline: AppColors.darkBorder,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.fitnessGreen,
        tertiary: AppColors.streakOrange,
        surface: AppColors.lightSurface,
        surfaceContainerHighest: AppColors.lightSurfaceVariant,
        onSurface: Color(0xFF0F172A),
        onSurfaceVariant: Color(0xFF64748B),
        outline: AppColors.lightBorder,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
