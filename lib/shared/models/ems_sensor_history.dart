import 'package:flutter/foundation.dart';

import 'ems_sensor_reading.dart';

/// One stored climate sample from `ems_sensordata_history`.
@immutable
class EmsHistoryPoint {
  const EmsHistoryPoint({
    required this.loggedAt,
    this.staticIaq,
    this.compensatedTemperature,
    this.compensatedHumidity,
    this.rawPressure,
  });

  /// Local time. Naive database timestamps are treated as UTC.
  final DateTime loggedAt;
  final double? staticIaq;
  final double? compensatedTemperature;
  final double? compensatedHumidity;
  final double? rawPressure;

  static EmsHistoryPoint? fromJson(Map<String, dynamic> json) {
    final loggedAt = parseEmsLoggedAt(json['logged_at']);
    if (loggedAt == null) return null;
    return EmsHistoryPoint(
      loggedAt: loggedAt,
      staticIaq: _asDouble(json['static_iaq']),
      compensatedTemperature: _asDouble(
        json['sensor_heat_compensated_temperature'],
      ),
      compensatedHumidity: _asDouble(json['sensor_heat_compensated_humidity']),
      rawPressure: _asDouble(json['raw_pressure']),
    );
  }

  double? valueFor(EmsHistoryMetric metric) {
    return switch (metric) {
      EmsHistoryMetric.aqi => staticIaq,
      EmsHistoryMetric.temperature => compensatedTemperature,
      EmsHistoryMetric.humidity => compensatedHumidity,
      EmsHistoryMetric.pressure => emsPressureHpa(rawPressure),
    };
  }
}

enum EmsHistoryMetric {
  aqi('AQI', 'AQI Index', ''),
  temperature('Temp', 'Temperatur', '°C'),
  humidity('Feuchte', 'Luftfeuchte', '%'),
  pressure('Druck', 'Luftdruck', 'hPa');

  const EmsHistoryMetric(this.label, this.title, this.unit);

  final String label;
  final String title;
  final String unit;
}

/// Query key for one device and one inclusive time window.
@immutable
class EmsHistoryQuery {
  const EmsHistoryQuery({
    required this.deviceId,
    required this.start,
    required this.end,
  });

  final String deviceId;
  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) {
    return other is EmsHistoryQuery &&
        other.deviceId == deviceId &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(deviceId, start, end);
}

/// Points loaded for a time window. [truncated] means only the newest 5000 fit.
@immutable
class EmsHistoryRange {
  const EmsHistoryRange({required this.points, this.truncated = false});

  final List<EmsHistoryPoint> points;
  final bool truncated;

  static const empty = EmsHistoryRange(points: []);
}

/// Lowest or highest sample of [metric] inside the optional window.
EmsHistoryPoint? extremeEmsPoint(
  List<EmsHistoryPoint> points,
  EmsHistoryMetric metric, {
  required bool minimum,
  DateTime? start,
  DateTime? end,
}) {
  EmsHistoryPoint? best;
  double? bestValue;
  for (final point in points) {
    if (start != null && point.loggedAt.isBefore(start)) continue;
    if (end != null && point.loggedAt.isAfter(end)) continue;
    final value = point.valueFor(metric);
    if (value == null) continue;
    if (bestValue == null ||
        (minimum ? value < bestValue : value > bestValue)) {
      best = point;
      bestValue = value;
    }
  }
  return best;
}

/// Newest sample of [metric] inside the optional window.
EmsHistoryPoint? latestEmsPoint(
  List<EmsHistoryPoint> points,
  EmsHistoryMetric metric, {
  DateTime? start,
  DateTime? end,
}) {
  EmsHistoryPoint? latest;
  for (final point in points) {
    if (start != null && point.loggedAt.isBefore(start)) continue;
    if (end != null && point.loggedAt.isAfter(end)) continue;
    if (point.valueFor(metric) == null) continue;
    if (latest == null || point.loggedAt.isAfter(latest.loggedAt)) {
      latest = point;
    }
  }
  return latest;
}

/// Display text for one history value, with the metric unit when it has one.
String formatEmsHistoryValue(EmsHistoryMetric metric, double value) {
  final digits = metric == EmsHistoryMetric.temperature ? 1 : 0;
  final number = value.toStringAsFixed(digits);
  if (metric.unit.isEmpty) return number;
  return '$number ${metric.unit}';
}

/// Parses `logged_at`. Values without a timezone are UTC.
DateTime? parseEmsLoggedAt(dynamic value) {
  if (value is DateTime) {
    return value.isUtc ? value.toLocal() : value;
  }
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty) return null;
  final hasZone = text.endsWith('Z') || _hasNumericOffset(text);
  final parsed = DateTime.tryParse(hasZone ? text : '${text}Z');
  return parsed?.toLocal();
}

bool _hasNumericOffset(String text) {
  final match = RegExp(r'[+-]\d{2}:\d{2}$').firstMatch(text);
  return match != null;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}
