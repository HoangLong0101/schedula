import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AdminTheme {
  static const teal = Color(0xFF22AFC2);
  static const tealDark = Color(0xFF127D8C);
  static const orange = Color(0xFFF28C28);
  static const success = Color(0xFF168A5B);
  static const ink = Color(0xFF030213);
  static const mutedInk = Color(0xFF5E6270);
  static const canvas = Color(0xFFEDF3F4);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF1F5F6);
  static const inputBackground = Color(0xFFF0F4F5);
  static const loadingBackground = Color(0xFFF5F8F9);
  static const skeleton = Color(0xFFE5ECEE);
  static const border = Color(0x26030213);
  static const strongBorder = Color(0x3D030213);
  static const danger = Color(0xFFD4183D);

  static ThemeData get light {
    final base = ThemeData(useMaterial3: true);
    final body = GoogleFonts.ralewayTextTheme(base.textTheme);
    final text = body.copyWith(
      headlineLarge: GoogleFonts.bricolageGrotesque(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: ink,
      ),
      headlineMedium: GoogleFonts.bricolageGrotesque(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.33,
        color: ink,
      ),
      titleLarge: GoogleFonts.bricolageGrotesque(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleMedium: GoogleFonts.bricolageGrotesque(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    );
    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: tealDark,
        onPrimary: Colors.white,
        secondary: teal,
        surface: surface,
        onSurface: ink,
        error: danger,
        outlineVariant: border,
      ),
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      textTheme: text,
      dividerColor: strongBorder,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: _inputBorder(border),
        enabledBorder: _inputBorder(border),
        focusedBorder: _inputBorder(tealDark, 1.5),
        errorBorder: _inputBorder(danger),
        labelStyle: const TextStyle(color: ink),
        hintStyle: const TextStyle(color: mutedInk),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: tealDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: tealDark,
          side: const BorderSide(color: strongBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: tealDark),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: strongBorder),
        ),
        titleTextStyle: text.titleLarge,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(6),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: strongBorder),
            ),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: strongBorder),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(Color(0xFFF3F7F8)),
        headingTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        dataTextStyle: TextStyle(fontSize: 13),
        headingRowHeight: 52,
        dataRowMinHeight: 54,
        dataRowMaxHeight: 66,
        dividerThickness: 0.7,
        horizontalMargin: 18,
        columnSpacing: 28,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
