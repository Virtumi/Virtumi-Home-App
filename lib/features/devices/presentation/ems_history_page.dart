import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../rooms/presentation/widgets/device_card_text_styles.dart';
import 'widgets/ems_series_chart.dart';

/// Interactive climate history for one Environment Monitoring System.
class EmsHistoryPage extends ConsumerStatefulWidget {
  const EmsHistoryPage({super.key, required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<EmsHistoryPage> createState() => _EmsHistoryPageState();
}

class _ChartFocus {
  const _ChartFocus({
    required this.metric,
    required this.minimum,
    required this.at,
    required this.value,
  });

  final EmsHistoryMetric metric;
  final bool minimum;
  final DateTime at;
  final double value;
}

class _EmsHistoryPageState extends ConsumerState<EmsHistoryPage> {
  late DateTime _draftStart;
  late DateTime _draftEnd;
  late DateTime _appliedStart;
  late DateTime _appliedEnd;
  late DateTime _visibleStart;
  late DateTime _visibleEnd;
  final Set<EmsHistoryMetric> _metrics = {EmsHistoryMetric.aqi};
  _ChartFocus? _focus;
  bool _rangeError = false;

  @override
  void initState() {
    super.initState();
    final end = DateTime.now();
    final start = end.subtract(const Duration(hours: 24));
    _draftStart = start;
    _draftEnd = end;
    _appliedStart = start;
    _appliedEnd = end;
    _visibleStart = start;
    _visibleEnd = end;
  }

  EmsHistoryQuery get _query => EmsHistoryQuery(
        deviceId: widget.deviceId,
        start: _appliedStart,
        end: _appliedEnd,
      );

  Duration get _minSpan {
    final full = _appliedEnd.difference(_appliedStart);
    const floor = Duration(minutes: 2);
    if (full < floor) return full;
    return floor;
  }

  void _setVisible(DateTime start, DateTime end) {
    var nextStart = start;
    var nextEnd = end;
    final minSpan = _minSpan;
    if (nextEnd.difference(nextStart) < minSpan) {
      final midUs = nextStart.microsecondsSinceEpoch +
          nextEnd.difference(nextStart).inMicroseconds ~/ 2;
      final half = minSpan.inMicroseconds ~/ 2;
      nextStart = DateTime.fromMicrosecondsSinceEpoch(midUs - half);
      nextEnd = DateTime.fromMicrosecondsSinceEpoch(midUs + half);
    }
    if (nextStart.isBefore(_appliedStart)) {
      final span = nextEnd.difference(nextStart);
      nextStart = _appliedStart;
      nextEnd = nextStart.add(span);
    }
    if (nextEnd.isAfter(_appliedEnd)) {
      final span = nextEnd.difference(nextStart);
      nextEnd = _appliedEnd;
      nextStart = nextEnd.subtract(span);
    }
    if (nextStart.isBefore(_appliedStart)) nextStart = _appliedStart;
    if (nextEnd.isAfter(_appliedEnd)) nextEnd = _appliedEnd;
    if (!nextEnd.isAfter(nextStart)) {
      nextStart = _appliedStart;
      nextEnd = _appliedEnd;
    }
    _visibleStart = nextStart;
    _visibleEnd = nextEnd;
  }

  void _zoomAt(double fraction, double scale) {
    if (scale <= 0) return;
    final spanUs = _visibleEnd.difference(_visibleStart).inMicroseconds;
    final fullUs = _appliedEnd.difference(_appliedStart).inMicroseconds;
    final minUs = _minSpan.inMicroseconds;
    final nextUs = (spanUs / scale).round().clamp(minUs, fullUs);
    final anchor = _visibleStart.microsecondsSinceEpoch +
        (spanUs * fraction).round();
    final startUs = anchor - (nextUs * fraction).round();
    setState(() {
      _setVisible(
        DateTime.fromMicrosecondsSinceEpoch(startUs),
        DateTime.fromMicrosecondsSinceEpoch(startUs + nextUs),
      );
    });
  }

  void _pan(double fraction) {
    final span = _visibleEnd.difference(_visibleStart);
    final shift = Duration(microseconds: (span.inMicroseconds * fraction).round());
    setState(() {
      _setVisible(_visibleStart.add(shift), _visibleEnd.add(shift));
    });
  }

  void _showAll() {
    setState(() {
      _visibleStart = _appliedStart;
      _visibleEnd = _appliedEnd;
    });
  }

  void _applyDraft() {
    if (!_draftEnd.isAfter(_draftStart)) {
      setState(() => _rangeError = true);
      return;
    }
    setState(() {
      _rangeError = false;
      _appliedStart = _draftStart;
      _appliedEnd = _draftEnd;
      _visibleStart = _draftStart;
      _visibleEnd = _draftEnd;
      _focus = null;
    });
  }

  void _applyLast24Hours() {
    final end = DateTime.now();
    final start = end.subtract(const Duration(hours: 24));
    setState(() {
      _draftStart = start;
      _draftEnd = end;
      _appliedStart = start;
      _appliedEnd = end;
      _visibleStart = start;
      _visibleEnd = end;
      _focus = null;
      _rangeError = false;
    });
  }

  void _toggleMetric(EmsHistoryMetric metric) {
    setState(() {
      if (_metrics.contains(metric)) {
        if (_metrics.length == 1) return;
        _metrics.remove(metric);
        if (_focus?.metric == metric) _focus = null;
      } else {
        _metrics.add(metric);
      }
    });
  }

  void _focusOn(List<EmsHistoryPoint> points, EmsHistoryMetric metric, bool minimum) {
    final point = extremeEmsPoint(
      points,
      metric,
      minimum: minimum,
      start: _appliedStart,
      end: _appliedEnd,
    );
    final value = point?.valueFor(metric);
    if (point == null || value == null) return;
    final full = _appliedEnd.difference(_appliedStart);
    var span = Duration(microseconds: full.inMicroseconds ~/ 8);
    if (span < const Duration(minutes: 30) &&
        full >= const Duration(minutes: 30)) {
      span = const Duration(minutes: 30);
    }
    if (span > full) span = full;
    final half = Duration(microseconds: span.inMicroseconds ~/ 2);
    setState(() {
      _focus = _ChartFocus(
        metric: metric,
        minimum: minimum,
        at: point.loggedAt,
        value: value,
      );
      _setVisible(point.loggedAt.subtract(half), point.loggedAt.add(half));
    });
  }

  Future<void> _pickDate(bool start) async {
    final current = start ? _draftStart : _draftEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    final next = DateTime(
      picked.year,
      picked.month,
      picked.day,
      current.hour,
      current.minute,
    );
    setState(() {
      if (start) {
        _draftStart = next;
      } else {
        _draftEnd = next;
      }
      _rangeError = false;
    });
  }

  Future<void> _pickTime(bool start) async {
    final current = start ? _draftStart : _draftEnd;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null) return;
    final next = DateTime(
      current.year,
      current.month,
      current.day,
      picked.hour,
      picked.minute,
    );
    setState(() {
      if (start) {
        _draftStart = next;
      } else {
        _draftEnd = next;
      }
      _rangeError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(emsSensorHistoryRangeProvider(_query));
    final range = historyAsync.asData?.value ?? EmsHistoryRange.empty;
    final device = ref.watch(deviceProvider(widget.deviceId)).asData?.value;

    return AppScaffold(
      header: AppHeader(
        onRefresh: () => ref.invalidate(emsSensorHistoryRangeProvider(_query)),
      ),
      body: AppScrollView(
        children: [
          SectionHeaderCard(
            title: 'Verlauf',
            subtitle: device?.displayName ?? 'Luftqualität',
            icon: Symbols.show_chart,
            accent: context.colors.primary,
            filled: true,
          ),
          const SizedBox(height: AppSpacing.cardGap),
          _RangeCard(
            start: _draftStart,
            end: _draftEnd,
            rangeError: _rangeError,
            onPickStartDate: () => _pickDate(true),
            onPickStartTime: () => _pickTime(true),
            onPickEndDate: () => _pickDate(false),
            onPickEndTime: () => _pickTime(false),
            onApply: _applyDraft,
            onLast24Hours: _applyLast24Hours,
          ),
          const SizedBox(height: AppSpacing.cardGap),
          Row(
            children: [
              for (final metric in EmsHistoryMetric.values) ...[
                if (metric != EmsHistoryMetric.aqi)
                  const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _MetricChip(
                    label: metric.label,
                    selected: _metrics.contains(metric),
                    onTap: () => _toggleMetric(metric),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.gutter),
          Row(
            children: [
              NeumorphicIconButton(
                icon: Symbols.remove,
                tooltip: 'Verkleinern',
                size: 40,
                iconSize: 20,
                onPressed: () => _zoomAt(0.5, 0.8),
              ),
              const SizedBox(width: AppSpacing.sm),
              NeumorphicIconButton(
                icon: Symbols.add,
                tooltip: 'Vergrößern',
                size: 40,
                iconSize: 20,
                onPressed: () => _zoomAt(0.5, 1.25),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(onPressed: _showAll, child: const Text('Gesamt')),
              const Spacer(),
              Text(
                'Mausrad oder Ziehen',
                style: DeviceCardTextStyles.caption(context),
              ),
            ],
          ),
          if (range.truncated) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Es werden die neuesten 5000 Messpunkte angezeigt.',
              style: DeviceCardTextStyles.caption(context),
            ),
          ],
          if (historyAsync.hasError) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Verlauf nicht verfügbar',
              style: DeviceCardTextStyles.caption(context).copyWith(
                color: context.colors.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.cardGap),
          if (historyAsync.isLoading && !historyAsync.hasValue)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            for (final metric in EmsHistoryMetric.values)
              if (_metrics.contains(metric)) ...[
                _MetricChartCard(
                  metric: metric,
                  points: range.points,
                  windowStart: _visibleStart,
                  windowEnd: _visibleEnd,
                  focus: _focus?.metric == metric ? _focus : null,
                  onZoom: _zoomAt,
                  onPan: _pan,
                  onMinimum: () => _focusOn(range.points, metric, true),
                  onMaximum: () => _focusOn(range.points, metric, false),
                ),
                const SizedBox(height: AppSpacing.cardGap),
              ],
        ],
      ),
    );
  }
}

class _RangeCard extends StatelessWidget {
  const _RangeCard({
    required this.start,
    required this.end,
    required this.rangeError,
    required this.onPickStartDate,
    required this.onPickStartTime,
    required this.onPickEndDate,
    required this.onPickEndTime,
    required this.onApply,
    required this.onLast24Hours,
  });

  final DateTime start;
  final DateTime end;
  final bool rangeError;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickStartTime;
  final VoidCallback onPickEndDate;
  final VoidCallback onPickEndTime;
  final VoidCallback onApply;
  final VoidCallback onLast24Hours;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Zeitfenster', style: DeviceCardTextStyles.title(context)),
          const SizedBox(height: AppSpacing.gutter),
          _TimeRow(
            label: 'Start',
            value: start,
            onDate: onPickStartDate,
            onTime: onPickStartTime,
          ),
          const SizedBox(height: AppSpacing.sm),
          _TimeRow(
            label: 'Ende',
            value: end,
            onDate: onPickEndDate,
            onTime: onPickEndTime,
          ),
          if (rangeError) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Das Ende muss nach dem Start liegen.',
              style: DeviceCardTextStyles.caption(context).copyWith(
                color: context.colors.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.gutter),
          Row(
            children: [
              TextButton(
                onPressed: onLast24Hours,
                child: const Text('Letzte 24 Stunden'),
              ),
              const Spacer(),
              FilledButton(onPressed: onApply, child: const Text('Anwenden')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.onDate,
    required this.onTime,
  });

  final String label;
  final DateTime value;
  final VoidCallback onDate;
  final VoidCallback onTime;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label, style: DeviceCardTextStyles.subtitle(context)),
        ),
        Expanded(
          child: OutlinedButton(
            onPressed: onDate,
            child: Text(_formatDate(value)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton(
            onPressed: onTime,
            child: Text(_formatClock(value)),
          ),
        ),
      ],
    );
  }
}

class _MetricChartCard extends StatelessWidget {
  const _MetricChartCard({
    required this.metric,
    required this.points,
    required this.windowStart,
    required this.windowEnd,
    required this.focus,
    required this.onZoom,
    required this.onPan,
    required this.onMinimum,
    required this.onMaximum,
  });

  final EmsHistoryMetric metric;
  final List<EmsHistoryPoint> points;
  final DateTime windowStart;
  final DateTime windowEnd;
  final _ChartFocus? focus;
  final void Function(double fraction, double scale) onZoom;
  final void Function(double fraction) onPan;
  final VoidCallback onMinimum;
  final VoidCallback onMaximum;

  @override
  Widget build(BuildContext context) {
    final color = _metricColor(context, metric);
    final hasVisible = points.any((point) {
      final value = point.valueFor(metric);
      return value != null &&
          !point.loggedAt.isBefore(windowStart) &&
          !point.loggedAt.isAfter(windowEnd);
    });
    final span = windowEnd.difference(windowStart);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Symbols.show_chart, color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  metric.title,
                  style: DeviceCardTextStyles.title(context),
                ),
              ),
              TextButton(onPressed: onMinimum, child: const Text('Minimum')),
              TextButton(onPressed: onMaximum, child: const Text('Maximum')),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 168,
            child: _ChartViewport(
              onZoom: onZoom,
              onPan: onPan,
              child: Stack(
                children: [
                  EmsSeriesChart(
                    metric: metric,
                    points: points,
                    windowStart: windowStart,
                    windowEnd: windowEnd,
                    color: color,
                    dotColor: context.colors.onPrimary,
                    focusAt: focus?.at,
                  ),
                  if (!hasVisible)
                    Center(
                      child: Text(
                        'Keine Werte in diesem Ausschnitt',
                        style: DeviceCardTextStyles.subtitle(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _WindowAxis(start: windowStart, end: windowEnd, span: span),
          if (focus != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${focus!.minimum ? 'Minimum' : 'Maximum'}: '
              '${_formatValue(metric, focus!.value)} · ${_formatStamp(focus!.at)}',
              style: DeviceCardTextStyles.caption(context, emphasis: true),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartViewport extends StatefulWidget {
  const _ChartViewport({
    required this.onZoom,
    required this.onPan,
    required this.child,
  });

  final void Function(double fraction, double scale) onZoom;
  final void Function(double fraction) onPan;
  final Widget child;

  @override
  State<_ChartViewport> createState() => _ChartViewportState();
}

class _ChartViewportState extends State<_ChartViewport> {
  double _pinchScale = 1;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        GestureBinding.instance.pointerSignalResolver.register(event, (signal) {
          if (signal is! PointerScrollEvent) return;
          final box = context.findRenderObject() as RenderBox?;
          if (box == null || !box.hasSize || box.size.width <= 0) return;
          final local = box.globalToLocal(signal.position);
          final fraction = (local.dx / box.size.width).clamp(0.0, 1.0);
          final zoomIn = signal.scrollDelta.dy < 0;
          widget.onZoom(fraction, zoomIn ? 1.25 : 0.8);
        });
      },
      onPointerMove: (event) {
        if (event.kind != PointerDeviceKind.mouse) return;
        if (event.buttons != kPrimaryButton) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize || box.size.width <= 0) return;
        widget.onPan(-event.delta.dx / box.size.width);
      },
      child: GestureDetector(
        supportedDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
        onScaleStart: (_) => _pinchScale = 1,
        onScaleUpdate: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null || !box.hasSize || box.size.width <= 0) return;
          if (details.pointerCount >= 2) {
            if (_pinchScale == 0 || details.scale == 0) return;
            final step = details.scale / _pinchScale;
            _pinchScale = details.scale;
            final fraction =
                (details.localFocalPoint.dx / box.size.width).clamp(0.0, 1.0);
            widget.onZoom(fraction, step);
          } else {
            widget.onPan(-details.focalPointDelta.dx / box.size.width);
          }
        },
        onScaleEnd: (_) => _pinchScale = 1,
        child: widget.child,
      ),
    );
  }
}

class _WindowAxis extends StatelessWidget {
  const _WindowAxis({
    required this.start,
    required this.end,
    required this.span,
  });

  final DateTime start;
  final DateTime end;
  final Duration span;

  @override
  Widget build(BuildContext context) {
    final mid = start.add(Duration(microseconds: span.inMicroseconds ~/ 2));
    final style = DeviceCardTextStyles.caption(context);
    return Row(
      children: [
        Text(_formatAxis(start, span), style: style),
        Expanded(
          child: Text(
            _formatAxis(mid, span),
            style: style,
            textAlign: TextAlign.center,
          ),
        ),
        Text(_formatAxis(end, span), style: style),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? context.colors.onPrimary
        : context.colors.onSurfaceVariant;
    return Material(
      color: selected
          ? context.colors.primary
          : context.colors.surfaceContainerHighest,
      borderRadius: AppRadius.full,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.full,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

Color _metricColor(BuildContext context, EmsHistoryMetric metric) {
  return switch (metric) {
    EmsHistoryMetric.aqi => context.colors.primary,
    EmsHistoryMetric.temperature => context.palette.accentOrange,
    EmsHistoryMetric.humidity => context.palette.accentSky,
    EmsHistoryMetric.pressure => context.palette.accentIndigo,
  };
}

String _two(int value) => value.toString().padLeft(2, '0');

String _formatDate(DateTime time) =>
    '${_two(time.day)}.${_two(time.month)}.${time.year}';

String _formatClock(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

String _formatStamp(DateTime time) =>
    '${_formatDate(time)} ${_formatClock(time)}';

String _formatAxis(DateTime time, Duration span) {
  final clock = _formatClock(time);
  if (span.inHours >= 24) return '${_two(time.day)}.${_two(time.month)}. $clock';
  return clock;
}

String _formatValue(EmsHistoryMetric metric, double value) {
  final digits = metric == EmsHistoryMetric.temperature ? 1 : 0;
  final number = value.toStringAsFixed(digits);
  if (metric.unit.isEmpty) return number;
  return '$number ${metric.unit}';
}
