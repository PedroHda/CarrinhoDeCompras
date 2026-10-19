import 'package:flutter/material.dart';

/// Tema único inspirado na proposta visual: verde, superfícies claras e leitura fácil.
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF147D50),
    brightness: Brightness.light,
  );
  return ThemeData(
    // Fonte empacotada localmente para manter a mesma aparência sem rede.
    fontFamily: 'AppRoboto',
    useMaterial3: true,
    colorScheme: scheme.copyWith(primary: const Color(0xFF147D50)),
    scaffoldBackgroundColor: const Color(0xFFF7F9F7),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF7F9F7),
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    // Formulários e cartões usam os mesmos raios para dar unidade ao aplicativo.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE1E8E2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE1E8E2)),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE6ECE7)),
      ),
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
      indicatorColor: const Color(0xFFE0F0E7),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.1,
        color: Color(0xFF17261E),
      ),
      headlineSmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.5),
      titleMedium: TextStyle(fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(height: 1.4),
    ),
  );
}
