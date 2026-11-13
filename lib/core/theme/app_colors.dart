import 'package:flutter/material.dart';

/// Central color tokens for the Virtumi Home design system.
///
/// All values are derived 1:1 from the Google Stitch `DESIGN.md` reference
/// ("Aura Neumorphic"). Never hardcode colors in widgets, always reference
/// these tokens (or the [ColorScheme] / [AppPalette] theme extension).
class AppColors {
  AppColors._();

  // --- Core surfaces (Light / "Liquid Cyan" neutral base) ---
  static const Color surface = Color(0xFFF2FBFC);
  static const Color surfaceDim = Color(0xFFD3DCDD);
  static const Color surfaceBright = Color(0xFFF2FBFC);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFECF5F6);
  static const Color surfaceContainer = Color(0xFFE7F0F1);
  static const Color surfaceContainerHigh = Color(0xFFE1EAEB);
  static const Color surfaceContainerHighest = Color(0xFFDBE4E5);
  static const Color surfaceVariant = Color(0xFFDBE4E5);
  static const Color background = Color(0xFFF2FBFC);

  // --- Foreground / text ---
  static const Color onSurface = Color(0xFF151D1E);
  static const Color onSurfaceVariant = Color(0xFF414754);
  static const Color onBackground = Color(0xFF151D1E);
  static const Color outline = Color(0xFF727785);
  static const Color outlineVariant = Color(0xFFC1C6D6);
  static const Color inverseSurface = Color(0xFF293233);
  static const Color inverseOnSurface = Color(0xFFE9F2F3);

  // --- Brand / primary ("Electric Blue") ---
  static const Color primary = Color(0xFF0070EA);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF0070EA);
  static const Color onPrimaryContainer = Color(0xFFFDFBFF);
  static const Color surfaceTint = Color(0xFF005BC0);

  // --- Secondary ---
  static const Color secondary = Color(0xFF00668A);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF8DD5FE);
  static const Color onSecondaryContainer = Color(0xFF005D7E);

  // --- Tertiary ---
  static const Color tertiary = Color(0xFF9E3E00);
  static const Color onTertiary = Color(0xFFFFFFFF);

  // --- Error ---
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // --- Neumorphic shadow triad ---
  static const Color shadowDark = Color(0xFFD1D9E6);
  static const Color shadowLight = Color(0xFFFFFFFF);

  // --- Functional accents (used as icon-box tints & glows) ---
  static const Color accentBlue = Color(0xFF0070EA);
  static const Color accentSky = Color(0xFF0EA5E9);
  static const Color accentCyan = Color(0xFF3DC2FD);
  static const Color accentIndigo = Color(0xFF4F46E5);
  static const Color accentPurple = Color(0xFF9333EA);
  static const Color accentTeal = Color(0xFF14B8A6);
  static const Color accentGreen = Color(0xFF22C55E);
  static const Color accentOrange = Color(0xFFEA580C);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentYellow = Color(0xFFEAB308);
  static const Color accentRed = Color(0xFFDC2626);
  static const Color accentStone = Color(0xFF78716C);

  // --- Status ---
  static const Color statusOnline = Color(0xFF22C55E);
  static const Color statusError = Color(0xFFBA1A1A);
}

/// Dark-mode palette from the Google Stitch "Aura Intelligence" reference.
///
/// Uses tonal layering (anthracite base + elevated card surfaces) combined with
/// the same dual neumorphic shadows as the light theme.
class AppColorsDark {
  AppColorsDark._();

  // --- Core surfaces (Anthracite base + tonal elevation) ---
  static const Color surface = Color(0xFF181818);
  static const Color surfaceDim = Color(0xFF141414);
  static const Color surfaceBright = Color(0xFF3A3A3A);
  static const Color surfaceContainerLowest = Color(0xFF121212);
  static const Color surfaceContainerLow = Color(0xFF1C1C1C);
  static const Color surfaceContainer = Color(0xFF242424);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerHighest = Color(0xFF323232);
  static const Color surfaceVariant = Color(0xFF2A2A2A);
  static const Color background = Color(0xFF181818);

  // --- Foreground / text ---
  static const Color onSurface = Color(0xFFE0E0E0);
  static const Color onSurfaceVariant = Color(0xFF879299);
  static const Color onBackground = Color(0xFFE0E0E0);
  static const Color outline = Color(0xFF879299);
  static const Color outlineVariant = Color(0xFF2C2C2C);
  static const Color inverseSurface = Color(0xFFDFE3E7);
  static const Color inverseOnSurface = Color(0xFF2C3134);

  // --- Brand / primary (Turquoise accent) ---
  static const Color primary = Color(0xFF64D2FF);
  static const Color onPrimary = Color(0xFF003546);
  static const Color primaryContainer = Color(0xFF64D2FF);
  static const Color onPrimaryContainer = Color(0xFF005973);
  static const Color surfaceTint = Color(0xFF68D3FF);

  // --- Secondary (Violet accent) ---
  static const Color secondary = Color(0xFFCEBDFF);
  static const Color onSecondary = Color(0xFF390094);
  static const Color secondaryContainer = Color(0xFF5028AE);
  static const Color onSecondaryContainer = Color(0xFFBEA8FF);

  // --- Tertiary ---
  static const Color tertiary = Color(0xFFFFDCAF);
  static const Color onTertiary = Color(0xFF452B00);

  // --- Error ---
  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // --- Neumorphic shadow pair (opaque on purpose: several widgets call
  // `withValues(alpha: ...)` on these, which overrides the alpha channel) ---
  static const Color cardBorder = Color(0x1AFFFFFF);
  static const Color shadowDark = Color(0xFF0B0B0B);
  static const Color shadowLight = Color(0xFF2E2E2E);

  // --- Functional accents (turquoise-forward in dark) ---
  static const Color accentBlue = Color(0xFF64D2FF);
  static const Color accentSky = Color(0xFF64D2FF);
  static const Color accentCyan = Color(0xFF68D3FF);
  static const Color accentIndigo = Color(0xFF9D7BFF);
  static const Color accentPurple = Color(0xFFCEBDFF);
  static const Color accentTeal = Color(0xFF14B8A6);
  static const Color accentGreen = Color(0xFF22C55E);
  static const Color accentOrange = Color(0xFFEA580C);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentYellow = Color(0xFFEAB308);
  static const Color accentRed = Color(0xFFFFB4AB);
  static const Color accentStone = Color(0xFF879299);
}
