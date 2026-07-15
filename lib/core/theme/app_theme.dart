import 'package:flutter/material.dart';

/// Cozy, warm visual foundation for Cat-ch (see docs/product/01-vision.md).
///
/// Deliberately small in Phase 0 — a seed colour and rounded shapes to set the
/// tone. The full design system grows alongside the UI.
class AppTheme {
  const AppTheme._();

  // Warm, soft "sunlit windowsill" palette.
  static const Color _seed = Color(0xFFF6A96A);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }
}
