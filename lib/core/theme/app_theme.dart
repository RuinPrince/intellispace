import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryBlue = Color(0xFF1E3A8A); // Deep Navy
  static const Color primaryCyan = Color(0xFF06B6D4); // Cyan Accent
  static const Color primaryGreen = Color(0xFF10B981); // Green Accent

  // Background Colors - Dark Theme
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800
  static const Color darkSurfaceVariant = Color(0xFF334155); // Slate 700

  // Background Colors - Light Theme
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9); // Slate 100

  // Text Colors
  static const Color textDark = Color(0xFFF8FAFC); // For dark theme
  static const Color textLight = Color(0xFF0F172A); // For light theme
  static const Color textMutedDark = Color(0xFF94A3B8); // Slate 400
  static const Color textMutedLight = Color(0xFF64748B); // Slate 500

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        secondary: primaryGreen,
        surface: darkSurface,
        background: darkBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textDark,
        onBackground: textDark,
        surfaceVariant: darkSurfaceVariant,
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(color: textDark, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.inter(color: textDark, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.inter(color: textDark, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: textDark),
        bodyMedium: GoogleFonts.inter(color: textDark),
        bodySmall: GoogleFonts.inter(color: textMutedDark),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkSurfaceVariant, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryCyan,
        unselectedItemColor: textMutedDark,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryCyan,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: primaryCyan,
        surface: lightSurface,
        background: lightBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textLight,
        onBackground: textLight,
        surfaceVariant: lightSurfaceVariant,
      ),
      scaffoldBackgroundColor: lightBackground,
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(color: textLight, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.inter(color: textLight, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.inter(color: textLight, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: textLight),
        bodyMedium: GoogleFonts.inter(color: textLight),
        bodySmall: GoogleFonts.inter(color: textMutedLight),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightSurfaceVariant, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textLight),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: primaryBlue,
        unselectedItemColor: textMutedLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
    );
  }
}
