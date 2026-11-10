import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_card.dart';

/// Large title card placed at the top of most screens: a rounded tinted icon
/// (or image) tile next to a headline, optionally with a subtitle.
class SectionHeaderCard extends StatelessWidget {
  const SectionHeaderCard({
    super.key,
    required this.title,
    this.icon,
    this.imageAsset,
    this.subtitle,
    this.detail,
    this.accent,
    this.onTap,
    this.heroTag,
    this.trailing,
    this.filled = true,
  }) : assert(icon != null || imageAsset != null);

  final String title;
  final IconData? icon;
  final String? imageAsset;
  final String? subtitle;

  /// Second small line under [subtitle], for example the place path.
  final String? detail;
  final Color? accent;
  final VoidCallback? onTap;
  final Object? heroTag;
  final Widget? trailing;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final accentColor = accent ?? context.colors.primary;

    Widget tile = Container(
      width: AppSizes.avatar,
      height: AppSizes.avatar,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.2),
            context.palette.accentTeal.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: AppRadius.mdAll,
      ),
      alignment: Alignment.center,
      child: imageAsset != null
          ? Image.asset(imageAsset!, width: 32, height: 32, fit: BoxFit.contain)
          : Icon(icon!, color: accentColor, size: 28, fill: filled ? 1 : 0),
    );

    if (heroTag != null) {
      tile = Hero(tag: heroTag!, child: tile);
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          tile,
          const SizedBox(width: AppSpacing.containerPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.text.headlineMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (detail != null) ...[
                  SizedBox(
                    height: subtitle == null ? AppSpacing.xs : 2,
                  ),
                  Text(
                    detail!,
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
