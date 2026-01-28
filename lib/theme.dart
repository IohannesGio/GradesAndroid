import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: brightness,
      ),
    );
  }
}

/// Builds a [ThemeData] using the optional [ColorScheme] provided by
/// `dynamic_color`. If [colorScheme] is null a seed‑color fallback is used.
ThemeData buildTheme(ColorScheme? colorScheme, {bool isDark = false}) {
  final scheme = colorScheme ??
      ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: isDark ? Brightness.dark : Brightness.light,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
  );
}
