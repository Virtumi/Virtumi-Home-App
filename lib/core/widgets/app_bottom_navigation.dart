import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/theme.dart';
import 'press_scale.dart';

/// A bottom navigation destination definition.
class AppNavDestination {
  const AppNavDestination({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Floating glassmorphic bottom navigation bar, identical on every tab screen.
///
/// The active tab is highlighted with a filled icon inside a soft circle plus
/// a blurred glow. Home stays blue, Szenen green, Favoriten red, Einstellungen
/// orange.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<AppNavDestination> destinations = [
    AppNavDestination(icon: Symbols.home, label: 'Home'),
    AppNavDestination(icon: Symbols.bolt, label: 'Szenen'),
    AppNavDestination(icon: Symbols.favorite, label: 'Favoriten'),
    AppNavDestination(icon: Symbols.settings, label: 'Einstellungen'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: ClipRRect(
        borderRadius: AppRadius.full,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
            decoration: BoxDecoration(
              color: palette.flatElevation
                  ? colors.surfaceContainerHighest.withValues(alpha: 0.6)
                  : palette.neuSurface.withValues(alpha: 0.55),
              borderRadius: AppRadius.full,
              border: Border.all(
                color: palette.flatElevation
                    ? Colors.white.withValues(alpha: 0.1)
                    : palette.shadowLight.withValues(alpha: 0.6),
              ),
              boxShadow: palette.flatElevation ? null : palette.floating,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < destinations.length; i++)
                  _NavItem(
                    destination: destinations[i],
                    active: i == currentIndex,
                    accent: _accentFor(context, i),
                    onTap: () => onTap(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Saturated red for the Favoriten tab in dark mode. The palette red there
/// is a pale pink and would not read as red.
const _favoriteRedDark = Color(0xFFFF4D5A);

Color _accentFor(BuildContext context, int index) {
  final palette = context.palette;
  return switch (index) {
    0 => context.colors.primary,
    1 => palette.accentGreen,
    2 => Theme.of(context).brightness == Brightness.dark
        ? _favoriteRedDark
        : palette.accentRed,
    3 => palette.accentOrange,
    _ => context.colors.primary,
  };
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactive = context.colors.onSurfaceVariant.withValues(alpha: 0.6);
    final palette = context.palette;

    return PressScale(
      onTap: onTap,
      semanticLabel: destination.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (active)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: palette.flatElevation
                            ? accent.withValues(alpha: 0.15)
                            : context.colors.surfaceContainerHighest
                                .withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: palette.flatElevation
                            ? Border.all(
                                color: accent.withValues(alpha: 0.35),
                              )
                            : null,
                        boxShadow: palette.flatElevation
                            ? null
                            : [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                      ),
                    ),
                  Icon(
                    destination.icon,
                    size: 24,
                    fill: active ? 1 : 0,
                    color: active ? accent : inactive,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              style: context.text.labelSmall?.copyWith(
                color: active ? accent : inactive,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
