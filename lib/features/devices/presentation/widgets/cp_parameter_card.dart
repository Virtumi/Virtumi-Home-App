import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/models.dart';

/// Summary card for one active Control Panel parameter.
class CpParameterCard extends StatelessWidget {
  const CpParameterCard({
    super.key,
    required this.parameter,
    required this.accent,
    required this.onTap,
    required this.onDelete,
  });

  final CpParameter parameter;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String get _title {
    final name = visibleStoredDeviceName(
      parameter.name,
      firmwareType: parameter.deviceType,
    );
    return name.isNotEmpty ? name : 'Parameter ${parameter.parameterIndex}';
  }

  String get _status => parameter.enabled == 1 ? 'Aktiv' : 'Deaktiviert';

  @override
  Widget build(BuildContext context) {
    final statusColor = parameter.enabled == 1
        ? context.palette.statusOnline
        : context.colors.onSurfaceVariant;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          IconBox(icon: Symbols.settings_input_component, color: accent),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.full,
                  ),
                  child: Text(
                    _status,
                    style: context.text.labelSmall?.copyWith(color: statusColor),
                  ),
                ),
              ],
            ),
          ),
          NeumorphicIconButton(
            icon: Symbols.delete,
            iconColor: context.colors.error,
            size: 40,
            iconSize: 20,
            tooltip: 'Parameter löschen',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
