import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// App Theme
///
/// Defines a single source of truth for Material 3 theming across the app.
/// The [themed] function builds a [ThemeData] from a provided [ColorScheme].
///
/// Responsibilities:
///  • Configure typography, colors, paddings, radii
///  • Apply consistent styles to AppBar, Input fields, Buttons, Cards, etc.
///  • Make it easy to maintain a unified look-and-feel
/// ---------------------------------------------------------------------------

ThemeData themed(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'AnonymousPro',

    // -----------------------------------------------------------------------
    // AppBar
    // -----------------------------------------------------------------------
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
    ),

    // -----------------------------------------------------------------------
    // Text Fields / Input Decorations
    // -----------------------------------------------------------------------
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      floatingLabelStyle:
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error),
      ),
    ),

    // -----------------------------------------------------------------------
    // Buttons
    // -----------------------------------------------------------------------
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(88, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        textStyle: const TextStyle(
          fontFamily: 'AnonymousPro',
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(88, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        textStyle: const TextStyle(
          fontFamily: 'AnonymousPro',
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // -----------------------------------------------------------------------
    // Dividers & Cards
    // -----------------------------------------------------------------------
    dividerTheme: DividerThemeData(
      thickness: 1,
      color: scheme.outlineVariant,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}