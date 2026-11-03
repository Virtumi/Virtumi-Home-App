import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/models/models.dart';

/// Pill selector for the climate series shown in a chart.
class EmsMetricSelector extends StatelessWidget {
  const EmsMetricSelector({
    super.key,
    required this.isSelected,
    required this.onSelected,
  });

  final bool Function(EmsHistoryMetric metric) isSelected;
  final ValueChanged<EmsHistoryMetric> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: AppRadius.full,
      ),
      child: Row(
        children: [
          for (final metric in EmsHistoryMetric.values)
            Expanded(
              child: _MetricSegment(
                label: metric.label,
                selected: isSelected(metric),
                onTap: () => onSelected(metric),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricSegment extends StatelessWidget {
  const _MetricSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    final foreground = selected
        ? context.colors.onPrimary
        : context.colors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.full,
          splashColor: primary.withValues(alpha: 0.12),
          highlightColor: primary.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? primary : Colors.transparent,
              borderRadius: AppRadius.full,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
