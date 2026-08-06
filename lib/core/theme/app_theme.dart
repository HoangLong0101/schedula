import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const brand = Color(0xFF22AFC2);
  static const brandDark = Color(0xFF148A9C);
  static const brandSoft = Color(0xFF58D8E3);
  static const canvas = Color(0xFFF0EEF8);
  static const surface = Color(0xFFFCFCFD);
  static const ink = Color(0xFF111827);

  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: brand,
          brightness: Brightness.light,
        ).copyWith(
          primary: brandDark,
          onPrimary: Colors.white,
          secondary: brand,
          onSecondary: Colors.white,
          surface: surface,
          onSurface: ink,
        );
    final baseTheme = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    final ralewayTextTheme = GoogleFonts.ralewayTextTheme(baseTheme.textTheme);
    final textTheme = ralewayTextTheme.copyWith(
      headlineLarge: GoogleFonts.bricolageGrotesque(
        textStyle: ralewayTextTheme.headlineLarge,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.52,
      ),
      headlineMedium: GoogleFonts.bricolageGrotesque(
        textStyle: ralewayTextTheme.headlineMedium,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.27,
      ),
      headlineSmall: GoogleFonts.bricolageGrotesque(
        textStyle: ralewayTextTheme.headlineSmall,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.16,
      ),
      titleLarge: GoogleFonts.bricolageGrotesque(
        textStyle: ralewayTextTheme.titleLarge,
        fontWeight: FontWeight.w600,
      ),
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
