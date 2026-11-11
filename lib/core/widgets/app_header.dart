import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/theme.dart';
import 'app_scaffold.dart';
import 'neumorphic_icon_button.dart';

/// Shared screen header used on all detail screens.
///
/// Renders a round back button on the left and optional edit / refresh buttons
/// on the right, exactly matching the Stitch header pattern. Configure per
/// screen by supplying the relevant callbacks (omit to hide a button).
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.onBack,
    this.showBack = true,
    this.onEdit,
    this.onRefresh,
    this.isEditing = false,
    this.trailing,
  });

  /// Called when the back button is tapped. Defaults to popping the route.
  final VoidCallback? onBack;
  final bool showBack;

  /// When provided, shows the edit (pencil) button.
  final VoidCallback? onEdit;

  /// When provided, shows the refresh button.
  final VoidCallback? onRefresh;

  /// Highlights the edit button while in editing mode.
  final bool isEditing;

  /// Optional custom trailing widget (overrides edit/refresh row).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final hasTrailing =
        trailing != null || onEdit != null || onRefresh != null;

    return BackActionRegistration(
      showBack: showBack,
      onBack: onBack,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.containerPadding,
          AppSpacing.containerPadding,
          AppSpacing.containerPadding,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            if (showBack)
              NeumorphicIconButton(
                icon: Symbols.chevron_left,
                tooltip: 'Zurück',
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              )
            else
              const SizedBox(width: AppSizes.headerButton),
            const Spacer(),
            if (hasTrailing)
              trailing ??
                  Row(
                    children: [
                      if (onEdit != null)
                        NeumorphicIconButton(
                          icon: isEditing ? Symbols.close : Symbols.edit,
                          tooltip: 'Bearbeiten',
                          iconColor: isEditing
                              ? context.colors.error
                              : context.colors.primary,
                          onPressed: onEdit,
                        ),
                      if (onEdit != null && onRefresh != null)
                        const SizedBox(width: AppSpacing.gutter),
                      if (onRefresh != null)
                        NeumorphicIconButton(
                          icon: Symbols.refresh,
                          tooltip: 'Aktualisieren',
                          onPressed: onRefresh,
                        ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
