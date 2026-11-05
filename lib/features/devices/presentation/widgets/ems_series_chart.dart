import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/models/models.dart';

/// Area chart for one climate series inside [windowStart] and [windowEnd].
///
/// A short click or tap places a vertical probe on the nearest sample.
class EmsSeriesChart extends StatefulWidget {
  const EmsSeriesChart({
    super.key,
    required this.metric,
    required this.points,
    required this.windowStart,
    required this.windowEnd,
    required this.color,
    required this.dotColor,
    this.focusAt,
  });

  final EmsHistoryMetric metric;
  final List<EmsHistoryPoint> points;
  final DateTime windowStart;
  final DateTime windowEnd;
  final Color color;
  final Color dotColor;

  /// When set, the marker sits on the sample closest to this time.
  final DateTime? focusAt;

  @override
  State<EmsSeriesChart> createState() => _EmsSeriesChartState();
}

class _EmsSeriesChartState extends State<EmsSeriesChart> {
  DateTime? _probeAt;
  int? _pointer;
  Offset? _down;

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _down = event.localPosition;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final down = _down;
    _pointer = null;
    _down = null;
    if (down == null) return;
    if ((event.localPosition - down).distance > kTouchSlop) return;
    _select(event.localPosition);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _down = null;
  }

  void _select(Offset local) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final plot = _plotRect(box.size);
    if (plot.width <= 0) return;
    final samples = _samples();
    if (samples.isEmpty) return;
    final fraction = ((local.dx - plot.left) / plot.width).clamp(0.0, 1.0);
    var best = samples.first;
    var bestDistance = (best.x - fraction).abs();
    for (final sample in samples.skip(1)) {
      final distance = (sample.x - fraction).abs();
      if (distance < bestDistance) {
        best = sample;
        bestDistance = distance;
      }
    }
    setState(() => _probeAt = best.at);
  }

  @override
  Widget build(BuildContext context) {
    final spanUs = widget.windowEnd.difference(widget.windowStart).inMicroseconds;
    final samples = spanUs <= 0 ? const <_Sample>[] : _samples(spanUs);
    final gapFraction = spanUs <= 0
        ? 1.0
        : const Duration(minutes: 30).inMicroseconds / spanUs;
    final probe = _probeSample(samples);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: CustomPaint(
        painter: _SeriesChartPainter(
          samples: samples,
          color: widget.color,
          dotColor: widget.dotColor,
          gapFraction: gapFraction,
          probeColor: context.colors.onSurface,
          probeBackground: context.colors.surface,
          probe: probe,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  _Sample? _probeSample(List<_Sample> samples) {
    final probeAt = _probeAt;
    if (probeAt == null) return null;
    for (final sample in samples) {
      if (sample.at == probeAt) return sample;
    }
    return null;
  }

  List<_Sample> _samples([int? spanUs]) {
    final span = spanUs ??
        widget.windowEnd.difference(widget.windowStart).inMicroseconds;
    if (span <= 0) return const [];
    final values = <(DateTime, double)>[];
    for (final point in widget.points) {
      if (point.loggedAt.isBefore(widget.windowStart)) continue;
      if (point.loggedAt.isAfter(widget.windowEnd)) continue;
      final value = point.valueFor(widget.metric);
      if (value == null) continue;
      values.add((point.loggedAt, value));
    }
    if (values.isEmpty) return const [];

    var minValue = values.first.$2;
    var maxValue = values.first.$2;
    for (final sample in values) {
      if (sample.$2 < minValue) minValue = sample.$2;
      if (sample.$2 > maxValue) maxValue = sample.$2;
    }
    final range = maxValue - minValue;
    if (range < 0.01) {
      minValue -= 1;
      maxValue += 1;
    } else {
      final pad = range * 0.14;
      minValue -= pad;
      maxValue += pad;
    }
    final valueSpan = maxValue - minValue;

    var focusIndex = -1;
    final focus = widget.focusAt;
    if (focus != null) {
      var bestDelta = 1 << 62;
      for (var i = 0; i < values.length; i++) {
        final delta = values[i].$1.difference(focus).inMicroseconds.abs();
        if (delta < bestDelta) {
          bestDelta = delta;
          focusIndex = i;
        }
      }
      if (bestDelta > const Duration(minutes: 2).inMicroseconds) {
        focusIndex = -1;
      }
    }

    return [
      for (var i = 0; i < values.length; i++)
        _Sample(
          x: values[i].$1.difference(widget.windowStart).inMicroseconds / span,
          y: (1 - (values[i].$2 - minValue) / valueSpan).clamp(0, 1),
          at: values[i].$1,
          label: formatEmsHistoryValue(widget.metric, values[i].$2),
          focused: i == focusIndex,
        ),
    ];
  }
}

class _Sample {
  const _Sample({
    required this.x,
    required this.y,
    required this.at,
    required this.label,
    this.focused = false,
  });

  final double x;
  final double y;
  final DateTime at;
  final String label;
  final bool focused;
}

Rect _plotRect(Size size) {
  return Rect.fromLTWH(4, 12, size.width - 12, size.height - 20);
}

class _SeriesChartPainter extends CustomPainter {
  _SeriesChartPainter({
    required this.samples,
    required this.color,
    required this.dotColor,
    required this.gapFraction,
    required this.probeColor,
    required this.probeBackground,
    required this.probe,
  });

  final List<_Sample> samples;
  final Color color;
  final Color dotColor;
  final double gapFraction;
  final Color probeColor;
  final Color probeBackground;
  final _Sample? probe;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final plot = _plotRect(size);
    if (plot.width <= 0 || plot.height <= 0) return;
    final pixels = [
      for (final sample in samples)
        Offset(
          plot.left + sample.x.clamp(0, 1) * plot.width,
          plot.top + sample.y * plot.height,
        ),
    ];

    final segments = <List<Offset>>[];
    var current = <Offset>[pixels.first];
    for (var i = 1; i < pixels.length; i++) {
      if (samples[i].x - samples[i - 1].x > gapFraction) {
        segments.add(current);
        current = [pixels[i]];
      } else {
        current.add(pixels[i]);
      }
    }
    segments.add(current);

    for (final segment in segments) {
      _drawSegment(canvas, segment, plot, color);
    }

    final focusIndex = samples.indexWhere((sample) => sample.focused);
    final dot = focusIndex >= 0 ? pixels[focusIndex] : pixels.last;
    if (focusIndex >= 0) {
      canvas.drawLine(
        Offset(dot.dx, plot.top),
        Offset(dot.dx, plot.bottom),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1.5,
      );
    }
    _drawDot(canvas, dot, color);
    final selected = probe;
    if (selected == null) return;
    final index = samples.indexWhere((sample) => sample.at == selected.at);
    if (index < 0) return;
    _drawProbe(canvas, pixels[index], plot, selected);
  }

  void _drawProbe(Canvas canvas, Offset point, Rect plot, _Sample sample) {
    canvas.drawLine(
      Offset(point.dx, plot.top),
      Offset(point.dx, plot.bottom),
      Paint()
        ..color = probeColor
        ..strokeWidth = 1.75,
    );
    _drawDot(canvas, point, probeColor);

    final label = TextPainter(
      text: TextSpan(
        text: sample.label,
        style: TextStyle(
          color: probeColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const pad = 4.0;
    final chipWidth = label.width + pad * 2;
    final chipHeight = label.height + pad * 2;
    var left = point.dx + 8;
    var top = point.dy - chipHeight / 2;
    if (left + chipWidth > plot.right) left = point.dx - 8 - chipWidth;
    if (left < plot.left) left = plot.left;
    if (top < plot.top) top = plot.top;
    if (top + chipHeight > plot.bottom) top = plot.bottom - chipHeight;

    final chip = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, chipWidth, chipHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(chip, Paint()..color = probeBackground);
    canvas.drawRRect(
      chip,
      Paint()
        ..color = probeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    label.paint(canvas, Offset(left + pad, top + pad));
  }

  void _drawSegment(Canvas canvas, List<Offset> points, Rect plot, Color color) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final midX = (previous.dx + current.dx) / 2;
      final midY = (previous.dy + current.dy) / 2;
      path.quadraticBezierTo(previous.dx, previous.dy, midX, midY);
    }
    path.lineTo(points.last.dx, points.last.dy);

    final fill = Path.from(path)
      ..lineTo(points.last.dx, plot.bottom)
      ..lineTo(points.first.dx, plot.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(plot),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawDot(Canvas canvas, Offset point, Color color) {
    canvas.drawCircle(point, 5.5, Paint()..color = color);
    canvas.drawCircle(point, 3.2, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _SeriesChartPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.gapFraction != gapFraction ||
        oldDelegate.probeColor != probeColor ||
        oldDelegate.probeBackground != probeBackground ||
        oldDelegate.probe?.at != probe?.at ||
        oldDelegate.probe?.label != probe?.label ||
        oldDelegate.samples != samples;
  }
}
