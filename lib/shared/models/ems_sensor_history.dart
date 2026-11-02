import 'package:flutter/foundation.dart';

import 'ems_sensor_reading.dart';

/// One stored climate sample from `ems_sensordata_history`.
@immutable
class EmsHistoryPoint {
  const EmsHistoryPoint({
    required this.loggedAt,
    this.iaq,
    this.rawTemperature,
    this.rawHumidity,
    this.rawPressure,
  });

  /// Local time. Naive database timestamps are treated as UTC.
  final DateTime loggedAt;
  final double? iaq;
  final double? rawTemperature;
  final double? rawHumidity;
  final double? rawPressure;

  static EmsHistoryPoint? fromJson(Map<String, dynamic> json) {
    final loggedAt = parseEmsLoggedAt(json['logged_at']);
    if (loggedAt == null) return null;
    return EmsHistoryPoint(
      loggedAt: loggedAt,
      iaq: _asDouble(json['iaq']),
      rawTemperature: _asDouble(json['raw_temperature']),
      rawHumidity: _asDouble(json['raw_humidity']),
      rawPressure: _asDouble(json['raw_pressure']),
    );
  }

  double? valueFor(EmsHistoryMetric metric) {
    return switch (metric) {
      EmsHistoryMetric.aqi => iaq,
      EmsHistoryMetric.temperature => rawTemperature,
      EmsHistoryMetric.humidity => rawHumidity,
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
