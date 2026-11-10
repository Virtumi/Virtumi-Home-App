import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Scenes tab. Only the title card is live; the rest is still in development.
class ScenesPage extends StatelessWidget {
  const ScenesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppHeader(showBack: false),
      body: AppScrollView(
        children: [
          SectionHeaderCard(
            title: 'Szenen',
            icon: Symbols.bolt,
            subtitle: 'Automatisierungen mit einem Tipp',
            accent: context.palette.accentGreen,
            filled: true,
          ),
          const _InDevelopmentCard(),
        ],
      ),
    );
  }
}

class _InDevelopmentCard extends StatelessWidget {
  const _InDevelopmentCard();

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accentGreen;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Symbols.construction,
              size: 44,
              color: accent,
              fill: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),
          Text(
            'Dieser Bereich ist noch in der Entwicklung.',
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
