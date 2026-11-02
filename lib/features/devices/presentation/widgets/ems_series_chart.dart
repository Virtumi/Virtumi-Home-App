import 'package:flutter/material.dart';

import '../../../../shared/models/models.dart';

/// Area chart for one climate series inside [windowStart] and [windowEnd].
class EmsSeriesChart extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final spanUs = windowEnd.difference(windowStart).inMicroseconds;
    final samples = spanUs <= 0 ? const <_Sample>[] : _samples(spanUs);
    final gapFraction = spanUs <= 0
        ? 1.0
        : const Duration(minutes: 30).inMicroseconds / spanUs;
    return CustomPaint(
      painter: _SeriesChartPainter(
        samples: samples,
        color: color,
        dotColor: dotColor,
        gapFraction: gapFraction,
      ),
      child: const SizedBox.expand(),
    );
  }

  List<_Sample> _samples(int spanUs) {
    final values = <(DateTime, double)>[];
    for (final point in points) {
      if (point.loggedAt.isBefore(windowStart)) continue;
      if (point.loggedAt.isAfter(windowEnd)) continue;
      final value = point.valueFor(metric);
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
    final span = maxValue - minValue;
    if (span < 0.01) {
      minValue -= 1;
      maxValue += 1;
    } else {
      final pad = span * 0.14;
      minValue -= pad;
      maxValue += pad;
    }
    final valueSpan = maxValue - minValue;

    var focusIndex = -1;
    final focus = focusAt;
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
          x: values[i].$1.difference(windowStart).inMicroseconds / spanUs,
          y: (1 - (values[i].$2 - minValue) / valueSpan).clamp(0, 1),
          focused: i == focusIndex,
        ),
    ];
  }
}

class _Sample {
  const _Sample({required this.x, required this.y, this.focused = false});

  final double x;
  final double y;
  final bool focused;
}

class _SeriesChartPainter extends CustomPainter {
  _SeriesChartPainter({
    required this.samples,
    required this.color,
    required this.dotColor,
    required this.gapFraction,
  });

  final List<_Sample> samples;
  final Color color;
  final Color dotColor;

  /// Time gap, as a fraction of the visible window, that breaks the line.
  final double gapFraction;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final plot = Rect.fromLTWH(4, 12, size.width - 12, size.height - 20);
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
        oldDelegate.samples != samples;
  }
}
