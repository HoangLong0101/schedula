import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
    );
    final baseTheme = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    final ralewayTextTheme = GoogleFonts.ralewayTextTheme(baseTheme.textTheme);
    final textTheme = ralewayTextTheme.copyWith(
      displayLarge: GoogleFonts.bricolageGrotesque(
        textStyle: ralewayTextTheme.displayLarge,
      ),
      displayMedium: GoogleFonts.bricolageGrotesque(
        textStyle: ralewayTextTheme.displayMedium,
      ),
      displaySmall: GoogleFonts.bricolageGrotesque(
        textStyle: ralewayTextTheme.displaySmall,
      ),
      headlineLarge: GoogleFonts.bricolageGrotesque(
        textStyle: ralewayTextTheme.headlineLarge,
      ),
      headlineMedium: GoogleFonts.bricolageGrotesque(
        textStyle: ralewayTextTheme.headlineMedium,
      ),
      headlineSmall: GoogleFonts.bricolageGrotesque(
        textStyle: ralewayTextTheme.headlineSmall,
      ),
      titleLarge: GoogleFonts.bricolageGrotesque(
        textStyle: ralewayTextTheme.titleLarge,
      ),
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: const Color(0xFFF7FAFC),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
