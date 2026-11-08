import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Uppercase section label (Geist, label-sm) shown above grouped cards.
/// Indented 8px from the card edge to align with the content inside, per the
/// design spec.
class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text.toUpperCase(),
      style: context.text.labelSmall?.copyWith(letterSpacing: 1.2),
    );

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.sm,
        top: AppSpacing.md,
        bottom: AppSpacing.gutter,
      ),
      child: trailing == null
          ? label
          : Row(
              children: [
                Expanded(child: label),
                trailing!,
              ],
            ),
    );
  }
}
