import 'package:flutter/material.dart';

class AppTheme {
  // Industrial Navy Color Palette (from globals.css)
  static const Color background = Color(0xFF0A1120); // --bg
  static const Color surface = Color(0xFF111A2E); // --panel
  static const Color panel2 = Color(0xFF16213A); // --panel-2
  static const Color inset = Color(0xFF0B1322); // --inset
  static const Color border = Color(0xFF22304D); // --border
  static const Color borderStrong = Color(0xFF33456B); // --border-strong
  static const Color textPrimary = Color(0xFFDBE4F5); // --text
  static const Color textStrong = Color(0xFFF2F6FD); // --text-strong
  static const Color textSecondary = Color(0xFF94A5C4); // --muted
  static const Color dim = Color(0xFF6B7A99); // --dim

  static const Color primary = Color(0xFF38BDF8); // --accent (cyan)
  static const Color primaryLight = Color(
    0xFF16213A,
  ); // --panel-2 / active container
  static const Color primaryDark = Color(0xFF38BDF8); // --accent

  // Status & SCADA Colors
  static const Color success = Color(0xFF34D399); // --good (green)
  static const Color error = Color(0xFFF87171); // --bad (red)
  static const Color warning = Color(0xFFFBBF24); // --warn (yellow)
  static const Color inactive = Color(0xFF6B7A99); // --dim
  static const Color navActive = Color(0xFF2563EB); // --nav-active (blue)

  // SCADA specific canvas colors
  static const Color scadaClosed = Color(0xFFF87171); // Red for closed
  static const Color scadaOpen = Color(0xFF34D399); // Green for open
  static const Color scadaIntermediate = Color(
    0xFFFBBF24,
  ); // Yellow for transition
  static const Color scadaUnknown = Color(0xFF6B7A99); // Grey for unknown

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark, // Changed to dark brightness
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primary,
        surface: surface,
        error: error,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textStrong,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textStrong,
        ),
        bodyLarge: TextStyle(fontSize: 14, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 13, color: textSecondary),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: border, width: 1)),
        iconTheme: IconThemeData(color: textPrimary),
      ),
    );
  }
}
