import 'package:flutter/widgets.dart';

/// Neumorphic shadow recipes from the Stitch `DESIGN.md`.
///
/// The neumorphic look relies on a dual-shadow triad: a soft dark shadow at the
/// bottom-right and a light shadow at the top-left. These builders take the
/// theme-specific [dark] / [light] colors so the same recipe works for both
/// the light and the dark theme.
class AppShadows {
  AppShadows._();

  /// No shadow — only used by the optional flat elevation mode
  /// (`AppPalette.flatElevation`), currently unused by both themes.
  static const List<BoxShadow> none = [];

  /// Standard "raised" elevation: `8px 8px 16px dark, -8px -8px 16px light`.
  static List<BoxShadow> raised(Color dark, Color light) => [
        BoxShadow(
          color: dark,
          offset: const Offset(8, 8),
          blurRadius: 16,
        ),
        BoxShadow(
          color: light,
          offset: const Offset(-8, -8),
          blurRadius: 16,
        ),
      ];

  /// Smaller "raised" elevation for buttons: `4px 4px 8px / -4px -4px 8px`.
  static List<BoxShadow> raisedSmall(Color dark, Color light) => [
        BoxShadow(
          color: dark,
          offset: const Offset(4, 4),
          blurRadius: 8,
        ),
        BoxShadow(
          color: light,
          offset: const Offset(-4, -4),
          blurRadius: 8,
        ),
      ];

  /// Soft drop shadow used by the glassmorphic floating navigation bar.
  static List<BoxShadow> floating(Color dark) => [
        BoxShadow(
          color: dark.withValues(alpha: 0.35),
          offset: const Offset(0, 8),
          blurRadius: 24,
        ),
      ];

  /// Flat card elevation (optional mode): tonal layering only, no drop shadow.
  static List<BoxShadow> flatCard() => none;

  /// Smaller flat elevation for compact buttons in dark mode.
  static List<BoxShadow> flatCardSmall() => none;

  /// Floating nav in dark mode — border + blur only.
  static List<BoxShadow> flatFloating() => none;

  /// Colored glow used behind primary buttons / active toggles.
  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.4),
          blurRadius: 12,
          spreadRadius: 1,
        ),
      ];
}
