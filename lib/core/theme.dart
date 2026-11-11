import 'package:flutter/material.dart';

/// CampusBell design tokens.
/// Neutral (white / near-black) for most UI; deep blue [accent] only for
/// brand spots: logo, bottom bar, Home action tiles.
class AppColors {
  // Neutral primary: buttons, chips, selected states.
  static const primary = Color(0xFF1F1F23);
  static const primaryDark = Color(0xFF111114);
  static const primaryLight = Color(0xFFEDEDED);
  static const gradient = [Color(0xFF2E2E33), Color(0xFF1F1F23)];
  static const darkGradient = [Color(0xFF2B2B30), Color(0xFF161618)];

  // Brand accent: deep blue.
  static const accent = Color(0xFF1E3A8A);
  static const accentLight = Color(0xFFE8EEFB);
  static const accentGradient = [Color(0xFF1E3A8A), Color(0xFF172E6E)];

  static const bg = Color(0xFFF2F2F7); // iOS grouped background
  static const card = Colors.white;
  static const text = Color(0xFF1F1F23);
  static const muted = Color(0xFF7A7A80);
  static const border = Color(0xFFEAEAEA);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
}

const departments = [
  'Computer Science & Engineering',
  'Information Technology',
  'Electronics & Communication',
  'Electrical & Electronics',
  'Mechanical Engineering',
  'Civil Engineering',
  'MBA',
  'Administration',
  'Other',
];

/// Short department label, e.g. "Computer Science & Engineering" -> "CSE".
String deptShort(String d) => switch (d) {
  'Computer Science & Engineering' => 'CSE',
  'Information Technology' => 'IT',
  'Electronics & Communication' => 'ECE',
  'Electrical & Electronics' => 'EEE',
  'Mechanical Engineering' => 'MECH',
  'Civil Engineering' => 'CIVIL',
  _ => d,
};

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: Colors.white,
  );
  final radius = BorderRadius.circular(14);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: const TextTheme().apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
