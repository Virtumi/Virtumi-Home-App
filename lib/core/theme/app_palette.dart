import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_shadows.dart';

/// Theme extension that exposes the neumorphic surface + shadow triad and the
/// functional accent colors to widgets in a theme-aware way.
///
/// Access via `Theme.of(context).extension<AppPalette>()!` or the
/// `context.palette` extension getter.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.neuSurface,
    required this.shadowDark,
    required this.shadowLight,
    required this.divider,
    required this.cardBorder,
    required this.flatElevation,
    required this.controlSurface,
    required this.accentBlue,
    required this.accentSky,
    required this.accentCyan,
    required this.accentIndigo,
    required this.accentPurple,
    required this.accentTeal,
    required this.accentGreen,
    required this.accentOrange,
    required this.accentAmber,
    required this.accentYellow,
    required this.accentRed,
    required this.accentStone,
    required this.statusOnline,
  });

  final Color neuSurface;
  final Color shadowDark;
  final Color shadowLight;
  final Color divider;
  final Color cardBorder;

  /// When true, surfaces use flat tonal elevation (border, no shadows)
  /// instead of dual neumorphic shadows.
  final bool flatElevation;

  /// Raised surface for secondary controls on cards (settings, zone buttons).
  final Color controlSurface;

  final Color accentBlue;
  final Color accentSky;
  final Color accentCyan;
  final Color accentIndigo;
  final Color accentPurple;
  final Color accentTeal;
  final Color accentGreen;
  final Color accentOrange;
  final Color accentAmber;
  final Color accentYellow;
  final Color accentRed;
  final Color accentStone;
  final Color statusOnline;

  /// Standard raised shadow set (neumorphic in light, flat in dark).
  List<BoxShadow> get raised => flatElevation
      ? AppShadows.flatCard()
      : AppShadows.raised(shadowDark, shadowLight);

  /// Smaller raised shadow set for buttons.
  List<BoxShadow> get raisedSmall => flatElevation
      ? AppShadows.flatCardSmall()
      : AppShadows.raisedSmall(shadowDark, shadowLight);

  /// Soft drop shadow for the floating navigation bar.
  List<BoxShadow> get floating => flatElevation
      ? AppShadows.flatFloating()
      : AppShadows.floating(shadowDark);

  static const AppPalette light = AppPalette(
    neuSurface: AppColors.surface,
    shadowDark: AppColors.shadowDark,
    shadowLight: AppColors.shadowLight,
    divider: AppColors.outlineVariant,
    cardBorder: Colors.transparent,
    flatElevation: false,
    controlSurface: AppColors.surface,
    accentBlue: AppColors.accentBlue,
    accentSky: AppColors.accentSky,
    accentCyan: AppColors.accentCyan,
    accentIndigo: AppColors.accentIndigo,
    accentPurple: AppColors.accentPurple,
    accentTeal: AppColors.accentTeal,
    accentGreen: AppColors.accentGreen,
    accentOrange: AppColors.accentOrange,
    accentAmber: AppColors.accentAmber,
    accentYellow: AppColors.accentYellow,
    accentRed: AppColors.accentRed,
    accentStone: AppColors.accentStone,
    statusOnline: AppColors.statusOnline,
  );

  static const AppPalette dark = AppPalette(
    neuSurface: AppColorsDark.surfaceContainer,
    shadowDark: AppColorsDark.shadowDark,
    shadowLight: AppColorsDark.shadowLight,
    divider: AppColorsDark.cardBorder,
    cardBorder: AppColorsDark.cardBorder,
    flatElevation: false,
    controlSurface: AppColorsDark.surfaceContainer,
    accentBlue: AppColorsDark.accentBlue,
    accentSky: AppColorsDark.accentSky,
    accentCyan: AppColorsDark.accentCyan,
    accentIndigo: AppColorsDark.accentIndigo,
    accentPurple: AppColorsDark.accentPurple,
    accentTeal: AppColorsDark.accentTeal,
    accentGreen: AppColorsDark.accentGreen,
    accentOrange: AppColorsDark.accentOrange,
    accentAmber: AppColorsDark.accentAmber,
    accentYellow: AppColorsDark.accentYellow,
    accentRed: AppColorsDark.accentRed,
    accentStone: AppColorsDark.accentStone,
    statusOnline: AppColors.statusOnline,
  );

  @override
  AppPalette copyWith({
    Color? neuSurface,
    Color? shadowDark,
    Color? shadowLight,
    Color? divider,
    Color? cardBorder,
    bool? flatElevation,
    Color? controlSurface,
    Color? accentBlue,
    Color? accentSky,
    Color? accentCyan,
    Color? accentIndigo,
    Color? accentPurple,
    Color? accentTeal,
    Color? accentGreen,
    Color? accentOrange,
    Color? accentAmber,
    Color? accentYellow,
    Color? accentRed,
    Color? accentStone,
    Color? statusOnline,
  }) {
    return AppPalette(
      neuSurface: neuSurface ?? this.neuSurface,
      shadowDark: shadowDark ?? this.shadowDark,
      shadowLight: shadowLight ?? this.shadowLight,
      divider: divider ?? this.divider,
      cardBorder: cardBorder ?? this.cardBorder,
      flatElevation: flatElevation ?? this.flatElevation,
      controlSurface: controlSurface ?? this.controlSurface,
      accentBlue: accentBlue ?? this.accentBlue,
      accentSky: accentSky ?? this.accentSky,
      accentCyan: accentCyan ?? this.accentCyan,
      accentIndigo: accentIndigo ?? this.accentIndigo,
      accentPurple: accentPurple ?? this.accentPurple,
      accentTeal: accentTeal ?? this.accentTeal,
      accentGreen: accentGreen ?? this.accentGreen,
      accentOrange: accentOrange ?? this.accentOrange,
      accentAmber: accentAmber ?? this.accentAmber,
      accentYellow: accentYellow ?? this.accentYellow,
      accentRed: accentRed ?? this.accentRed,
      accentStone: accentStone ?? this.accentStone,
      statusOnline: statusOnline ?? this.statusOnline,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      neuSurface: Color.lerp(neuSurface, other.neuSurface, t)!,
      shadowDark: Color.lerp(shadowDark, other.shadowDark, t)!,
      shadowLight: Color.lerp(shadowLight, other.shadowLight, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      flatElevation: t < 0.5 ? flatElevation : other.flatElevation,
      controlSurface: Color.lerp(controlSurface, other.controlSurface, t)!,
      accentBlue: Color.lerp(accentBlue, other.accentBlue, t)!,
      accentSky: Color.lerp(accentSky, other.accentSky, t)!,
      accentCyan: Color.lerp(accentCyan, other.accentCyan, t)!,
      accentIndigo: Color.lerp(accentIndigo, other.accentIndigo, t)!,
      accentPurple: Color.lerp(accentPurple, other.accentPurple, t)!,
      accentTeal: Color.lerp(accentTeal, other.accentTeal, t)!,
      accentGreen: Color.lerp(accentGreen, other.accentGreen, t)!,
      accentOrange: Color.lerp(accentOrange, other.accentOrange, t)!,
      accentAmber: Color.lerp(accentAmber, other.accentAmber, t)!,
      accentYellow: Color.lerp(accentYellow, other.accentYellow, t)!,
      accentRed: Color.lerp(accentRed, other.accentRed, t)!,
      accentStone: Color.lerp(accentStone, other.accentStone, t)!,
      statusOnline: Color.lerp(statusOnline, other.statusOnline, t)!,
    );
  }
}

/// Convenience access to [AppPalette] from a [BuildContext].
extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
