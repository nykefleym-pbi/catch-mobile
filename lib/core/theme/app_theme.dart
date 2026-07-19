import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cat-ch visual system, implemented from the "Cat-ch Mobile UI" design
/// reference (Claude Design): a warm "sunlit windowsill" palette, Fredoka for
/// display/labels and Nunito Sans for body, generous rounding and soft warm
/// shadows. The cats themselves are pixel art; the app chrome stays cozy.
///
/// Shared shape/shadow tokens live here too so screens can reach for the same
/// language (card radius 20, pill 44, sheet 28; soft brown/apricot shadows).
class AppTheme {
  const AppTheme._();

  // --- Brand palette (exact values from the design) ------------------------
  static const apricot = Color(0xFFF6A96A); // primary signature
  static const terracotta = Color(0xFFE07A5F); // accent / CTA
  static const sage = Color(0xFFA7C4A0); // secondary / nature
  static const peach = Color(0xFFFBE3CD); // soft apricot container

  // Light neutrals
  static const _pageLight = Color(0xFFF0EAE1); // scaffold background
  static const _surfaceLight = Color(0xFFFFF7EF); // surface (design token)
  static const _containerLight = Color(0xFFFFFDF8); // surface-container (cards)
  static const _surfaceLightAlt = Color(0xFFF3E9DF);
  static const _borderLight = Color(0xFFEBDDCB);
  static const ink = Color(0xFF3E2F26); // primary text
  static const _inkMutedLight = Color(0xFF8A7462);

  // Dark neutrals — warm charcoal, never cold black.
  static const _pageDark = Color(0xFF201A16);
  static const _surfaceDark = Color(0xFF2B2420);
  static const _surfaceDarkAlt = Color(0xFF3C332B);
  static const _borderDark = Color(0xFF463427);
  static const _inkDark = Color(0xFFF3E9DF);
  static const _inkMutedDark = Color(0xFFB7A896);

  // Shared shape tokens.
  static const radiusCard = 20.0;
  static const radiusButton = 16.0;
  static const radiusSheet = 28.0;
  static const radiusChip = 10.0;

  /// Soft warm card shadow (matches the design's `0 14px 34px rgba(62,47,38,.12)`).
  static List<BoxShadow> cardShadow(Brightness b) => [
        BoxShadow(
          color: (b == Brightness.light ? ink : Colors.black)
              .withValues(alpha: b == Brightness.light ? 0.12 : 0.40),
          blurRadius: 34,
          offset: const Offset(0, 14),
        ),
      ];

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isLight = b == Brightness.light;
    final scheme = ColorScheme(
      brightness: b,
      primary: apricot,
      onPrimary: ink,
      primaryContainer: isLight ? peach : _surfaceDarkAlt,
      onPrimaryContainer: isLight ? ink : _inkDark,
      // Roles follow the design sheet: secondary = sage (nature/calm),
      // tertiary = terracotta (the accent / CTA colour).
      secondary: sage,
      onSecondary: const Color(0xFF2E3A2A),
      secondaryContainer: isLight ? const Color(0xFFDEEAD9) : _surfaceDarkAlt,
      onSecondaryContainer: isLight ? ink : _inkDark,
      tertiary: terracotta,
      onTertiary: const Color(0xFFFFF7EF),
      tertiaryContainer: isLight ? const Color(0xFFF7D9CE) : _surfaceDarkAlt,
      onTertiaryContainer: isLight ? ink : _inkDark,
      error: const Color(0xFFB3583F),
      onError: const Color(0xFFFFF7EF),
      surface: isLight ? _surfaceLight : _surfaceDark,
      onSurface: isLight ? ink : _inkDark,
      onSurfaceVariant: isLight ? _inkMutedLight : _inkMutedDark,
      outline: isLight ? _borderLight : _borderDark,
      outlineVariant:
          isLight ? const Color(0xFFDFD2C0) : const Color(0xFF3C332B),
      surfaceContainerLowest:
          isLight ? const Color(0xFFFFFFFF) : const Color(0xFF1A1512),
      surfaceContainerLow: isLight ? _surfaceLight : _surfaceDark,
      surfaceContainer: isLight ? const Color(0xFFFBF4EA) : _surfaceDark,
      surfaceContainerHigh: isLight ? _surfaceLightAlt : _surfaceDarkAlt,
      surfaceContainerHighest:
          isLight ? const Color(0xFFEFE4D6) : const Color(0xFF473C33),
      inverseSurface: isLight ? ink : _inkDark,
      onInverseSurface: isLight ? _surfaceLight : ink,
      shadow: ink,
    );

    final baseText =
        GoogleFonts.nunitoSansTextTheme(ThemeData(brightness: b).textTheme);
    TextStyle fred(TextStyle? s, {FontWeight w = FontWeight.w600}) =>
        GoogleFonts.fredoka(textStyle: s, fontWeight: w);
    final textTheme = baseText
        .copyWith(
          displayLarge: fred(baseText.displayLarge),
          displayMedium: fred(baseText.displayMedium),
          displaySmall: fred(baseText.displaySmall),
          headlineLarge: fred(baseText.headlineLarge),
          headlineMedium: fred(baseText.headlineMedium),
          headlineSmall: fred(baseText.headlineSmall),
          titleLarge: fred(baseText.titleLarge),
          titleMedium: fred(baseText.titleMedium),
          titleSmall: fred(baseText.titleSmall, w: FontWeight.w500),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    final page = isLight ? _pageLight : _pageDark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: page,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: page,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.fredoka(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: isLight ? _containerLight : _surfaceDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle:
              GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 16),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          // Primary CTAs are pills in the design sheet.
          shape: const StadiumBorder(),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          textStyle:
              GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 16),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.tertiary,
          textStyle:
              GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? _surfaceLight : _surfaceDark,
        indicatorColor: isLight ? peach : _surfaceDarkAlt,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight ? _surfaceLight : _surfaceDark,
        modalBackgroundColor: isLight ? _surfaceLight : _surfaceDark,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? _surfaceLightAlt : _surfaceDarkAlt,
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusChip)),
        labelStyle: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: scheme.onSurface,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      dividerTheme:
          DividerThemeData(color: scheme.outline, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle:
            GoogleFonts.nunitoSans(color: const Color(0xFFFFF7EF)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
