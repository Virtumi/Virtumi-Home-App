import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/providers/data_providers.dart';
import '../../../rooms/presentation/widgets/device_card_text_styles.dart';
import 'ems_metric_selector.dart';
import 'ems_series_chart.dart';

/// 24-hour climate chart for the air-quality device overview.
class EmsHistoryChart extends ConsumerStatefulWidget {
  const EmsHistoryChart({super.key, required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<EmsHistoryChart> createState() => _EmsHistoryChartState();
}

class _EmsHistoryChartState extends ConsumerState<EmsHistoryChart> {
  EmsHistoryMetric _metric = EmsHistoryMetric.aqi;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(emsSensorHistoryProvider(widget.deviceId));
    final points = historyAsync.asData?.value ?? const <EmsHistoryPoint>[];

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Symbols.show_chart,
                color: context.colors.primary,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '24h Verlauf',
                  style: DeviceCardTextStyles.title(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _HistoryDetailsButton(
                onPressed: () =>
                    context.push(Paths.emsHistory(widget.deviceId)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gutter),
          EmsMetricSelector(
            isSelected: (metric) => metric == _metric,
            onSelected: (metric) => setState(() => _metric = metric),
          ),
          const SizedBox(height: AppSpacing.gutter),
          SizedBox(
            height: 148,
            child: _ChartBody(
              metric: _metric,
              points: points,
              loading: historyAsync.isLoading && !historyAsync.hasValue,
              hasError: historyAsync.hasError,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AxisLabels(now: DateTime.now()),
        ],
      ),
    );
  }
}

class _ChartBody extends StatelessWidget {
  const _ChartBody({
    required this.metric,
    required this.points,
    required this.loading,
    required this.hasError,
  });

  final EmsHistoryMetric metric;
  final List<EmsHistoryPoint> points;
  final bool loading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (hasError) {
      return Center(
        child: Text(
          'Verlauf nicht verfügbar',
          style: DeviceCardTextStyles.caption(context).copyWith(
            color: context.colors.error,
          ),
        ),
      );
    }

    final now = DateTime.now();
    final samples = points.where((point) {
      final value = point.valueFor(metric);
      return value != null &&
          !point.loggedAt.isBefore(now.subtract(const Duration(hours: 24))) &&
          !point.loggedAt.isAfter(now);
    });
    if (samples.isEmpty) {
      return Center(
        child: Text(
          'Noch keine Verlaufsdaten',
          style: DeviceCardTextStyles.subtitle(context),
        ),
      );
    }

    return EmsSeriesChart(
      metric: metric,
      points: points,
      windowStart: now.subtract(const Duration(hours: 24)),
      windowEnd: now,
      color: context.colors.primary,
      dotColor: context.colors.onPrimary,
    );
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final marks = _axisMarks(now);
    return SizedBox(
      height: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final placed = <double>[width];
          return Stack(
            children: [
              for (final mark in marks)
                if (mark.emphasis || _fits(mark, width, placed))
                  Positioned(
                    left: mark.emphasis
                        ? null
                        : (mark.fraction * width).clamp(0, width - 44),
                    right: mark.emphasis ? 0 : null,
                    child: Text(
                      mark.label,
                      style: DeviceCardTextStyles.caption(
                        context,
                        emphasis: mark.emphasis,
                      ).copyWith(
                        color: mark.emphasis
                            ? context.colors.primary
                            : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  bool _fits(_AxisMark mark, double width, List<double> placed) {
    final x = mark.fraction * width;
    for (final previous in placed) {
      if ((x - previous).abs() < 46) return false;
    }
    placed.add(x);
    return true;
  }
}

class _AxisMark {
  const _AxisMark(this.label, this.fraction, {this.emphasis = false});

  final String label;
  final double fraction;
  final bool emphasis;
}

const _window = Duration(hours: 24);

List<_AxisMark> _axisMarks(DateTime now) {
  final start = now.subtract(_window);
  final total = _window.inMilliseconds;
  final marks = <_AxisMark>[];
  for (final hour in const [0, 6, 12, 18]) {
    var cursor = DateTime(start.year, start.month, start.day, hour);
    if (!cursor.isAfter(start)) {
      cursor = cursor.add(const Duration(days: 1));
    }
    if (!cursor.isBefore(now)) continue;
    if (now.difference(cursor) < const Duration(hours: 2)) continue;
    final fraction = cursor.difference(start).inMilliseconds / total;
    final label = '${cursor.hour.toString().padLeft(2, '0')}:00';
    marks.add(_AxisMark(label, fraction));
  }
  marks.add(const _AxisMark('Jetzt', 1, emphasis: true));
  return marks;
}

class _HistoryDetailsButton extends StatelessWidget {
  const _HistoryDetailsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return PressScale(
      style: PressScaleStyle.compact,
      onTap: onPressed,
      semanticLabel: 'Verlauf öffnen',
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          Symbols.arrow_forward,
          color: context.colors.onPrimary,
          size: 20,
        ),
      ),
    );
  }
}
