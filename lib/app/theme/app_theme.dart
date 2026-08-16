import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const navy = Color(0xFF121C2A);
  static const primary = Color(0xFF2D323D);
  static const accentBlue = Color(0xFF2563EB);
  static const paleBlueSurface = Color(0xFFEFF6FF);
  static const paleBlue = Color(0xFFBFDBFE);
  static const charcoal = Color(0xFF292D2D);
  static const canvas = Color(0xFFF7F8F6);
  static const border = Color(0xFFE1E8E4);
  static const mutedInk = Color(0xFF5F6B65);

  static final ThemeData light = ThemeData(
    colorScheme: const ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      secondary: paleBlue,
      onSecondary: navy,
      surface: Colors.white,
      onSurface: navy,
      error: Color(0xFFB3261E),
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: canvas,
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: border),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: border),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: Color(0xFF7B8781)),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll<double>(0),
      backgroundColor: const WidgetStatePropertyAll<Color>(Colors.white),
      side: const WidgetStatePropertyAll<BorderSide>(BorderSide(color: border)),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
  );
}
