import 'package:flutter/material.dart';

/// Cores compartilhadas para listas, histórico e formulários.
abstract final class AppColors {
  static const primary = Color(0xFF6355D9);
  static const coral = Color(0xFFF47762);
  static const background = Color(0xFFF7F5FF);
  static const lavender = Color(0xFFECE8FF);
  static const ink = Color(0xFF282342);
  static const muted = Color(0xFF756F88);
  static const border = Color(0xFFE7E1F2);
  static const mint = Color(0xFFDDF4EB);
  static const green = Color(0xFF26735A);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  );
  return ThemeData(
    // Fonte empacotada localmente para manter a mesma aparência sem rede.
    fontFamily: 'AppRoboto',
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: AppColors.primary,
      secondary: AppColors.coral,
      onSurface: AppColors.ink,
      surface: AppColors.background,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    // Formulários e cartões usam os mesmos raios para dar unidade ao aplicativo.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(
          fontFamily: 'AppRoboto',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.ink,
      actionTextColor: Color(0xFFFFC0AD),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.coral,
      linearTrackColor: AppColors.lavender,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(
          fontFamily: 'AppRoboto',
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.lavender,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.1,
        color: AppColors.ink,
      ),
      headlineSmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.5),
      titleMedium: TextStyle(fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(height: 1.4),
    ),
  );
}
