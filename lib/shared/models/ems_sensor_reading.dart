import 'package:flutter/foundation.dart';

/// One current climate sample from `ems_sensordata` or UDP protocol 10.
@immutable
class EmsSensorReading {
  const EmsSensorReading({
    this.iaq,
    this.accuracy,
    this.rawTemperature,
    this.rawPressure,
    this.rawHumidity,
    this.rawGas,
    this.stabilizationStatus,
    this.runInStatus,
    this.sensorHeatCompensatedTemperature,
    this.sensorHeatCompensatedHumidity,
    this.staticIaq,
    this.co2Equivalent,
    this.breathVocEquivalent,
    this.gasPercentage,
    this.compensatedGas,
  });

  final double? iaq;
  final double? accuracy;
  final double? rawTemperature;
  final double? rawPressure;
  final double? rawHumidity;
  final double? rawGas;
  final double? stabilizationStatus;
  final double? runInStatus;
  final double? sensorHeatCompensatedTemperature;
  final double? sensorHeatCompensatedHumidity;
  final double? staticIaq;
  final double? co2Equivalent;
  final double? breathVocEquivalent;
  final double? gasPercentage;
  final double? compensatedGas;

  static const empty = EmsSensorReading();

  factory EmsSensorReading.fromJson(Map<String, dynamic> json) {
    return EmsSensorReading(
      iaq: _asDouble(json['iaq']),
      accuracy: _asDouble(json['accuracy']),
      rawTemperature: _asDouble(json['raw_temperature']),
      rawPressure: _asDouble(json['raw_pressure']),
      rawHumidity: _asDouble(json['raw_humidity']),
      rawGas: _asDouble(json['raw_gas']),
      stabilizationStatus: _asDouble(json['stabilization_status']),
      runInStatus: _asDouble(json['run_in_status']),
      sensorHeatCompensatedTemperature: _asDouble(
        json['sensor_heat_compensated_temperature'],
      ),
      sensorHeatCompensatedHumidity: _asDouble(
        json['sensor_heat_compensated_humidity'],
      ),
      staticIaq: _asDouble(json['static_iaq']),
      co2Equivalent: _asDouble(json['co2_equivalent']),
      breathVocEquivalent: _asDouble(json['breath_voc_equivalent']),
      gasPercentage: _asDouble(json['gas_percentage']),
      compensatedGas: _asDouble(json['compensated_gas']),
    );
  }

  double? get temperature => sensorHeatCompensatedTemperature;

  double? get humidity => sensorHeatCompensatedHumidity;

  /// BME680 reports Pascal. Values above 2000 are converted to hPa.
  double? get pressureHpa => emsPressureHpa(rawPressure);

  int? get aqi => staticIaq?.round();

  int? get co2Ppm => co2Equivalent?.round();

  EmsAirQuality get airQuality => EmsAirQuality.fromIaq(staticIaq);

  /// Bosch stabilization flag: 0 means stabilization is still ongoing.
  bool get isStabilizing {
    final stabilization = stabilizationStatus;
    return stabilization != null && stabilization < 1;
  }

  /// Bosch run-in flag: 0 means the gas sensor is still in its run-in phase.
  bool get isRunInActive {
    final runIn = runInStatus;
    return runIn != null && runIn == 0;
  }

  String get ventilationAdvice {
    final quality = airQuality;
    final co2 = co2Ppm;
    final goodAir = quality == EmsAirQuality.excellent ||
        quality == EmsAirQuality.good;
    final co2Ok = co2 == null || co2 < 1000;
    if (goodAir && co2Ok) {
      return 'Optimale Raumluft. Keine Aktion erforderlich.';
    }
    if (quality.isCritical || (co2 != null && co2 >= 1500)) {
      return 'Bitte jetzt lüften.';
    }
    return 'Lüften empfohlen.';
  }

  String get temperatureHint {
    final value = temperature;
    if (value == null) return '—';
    if (value >= 20 && value <= 22) return 'Optimal (Soll 21 °C)';
    return 'Außerhalb des Wohlfühlbereichs';
  }

  String get humidityHint {
    final value = humidity;
    if (value == null) return '—';
    if (value >= 40 && value <= 60) return 'Idealer Bereich (40–60 %)';
    return 'Außerhalb des idealen Bereichs';
  }

  String get pressureHint {
    final value = pressureHpa;
    if (value == null) return '—';
    if (value < 980) return 'Niedrig';
    if (value > 1040) return 'Hoch';
    return 'Normal';
  }

  String get temperatureLabel => _fixed(temperature, 1);

  String get humidityLabel => _fixed(humidity, 0);

  String get pressureLabel => _fixed(pressureHpa, 0);

  String get aqiLabel => aqi?.toString() ?? '—';

  String get co2Label => co2Ppm?.toString() ?? '—';

  String get vocLabel => _decimals(breathVocEquivalent, 2);

  /// BSEC IAQ accuracy: 0 stabilizing, 1 low, 2 medium, 3 high.
  String get accuracyLabel {
    final value = accuracy;
    if (value == null) return '—';
    return switch (value.round()) {
      0 => 'Stabilisierung',
      1 => 'Niedrig',
      2 => 'Mittel',
      3 => 'Hoch',
      _ => value.round().toString(),
    };
  }

  /// Position of the IAQ marker on a 0–500 scale.
  double get airQualityFraction {
    final value = staticIaq;
    if (value == null) return 0;
    return (value / 500).clamp(0, 1);
  }
}

enum EmsAirQuality {
  unknown('Keine Daten', ''),
  excellent('Ausgezeichnet', 'Keine signifikanten Schadstoffe erkannt'),
  good('Gut', 'Luftqualität ist gut'),
  light('Leicht belastet', 'Luft ist leicht belastet'),
  moderate('Mäßig belastet', 'Luft ist mäßig belastet'),
  heavy('Stark belastet', 'Luft ist stark belastet'),
  severe('Sehr stark belastet', 'Luft ist sehr stark belastet'),
  extreme('Extrem belastet', 'Luft ist extrem belastet');

  const EmsAirQuality(this.label, this.detail);

  final String label;
  final String detail;

  /// Stark belastet and worse.
  bool get isCritical =>
      this == EmsAirQuality.heavy ||
      this == EmsAirQuality.severe ||
      this == EmsAirQuality.extreme;

  /// Uses the same rounded AQI that the cards show.
  static EmsAirQuality fromIaq(double? iaq) {
    if (iaq == null) return EmsAirQuality.unknown;
    final value = iaq.round();
    if (value <= 50) return EmsAirQuality.excellent;
    if (value <= 100) return EmsAirQuality.good;
    if (value <= 150) return EmsAirQuality.light;
    if (value <= 200) return EmsAirQuality.moderate;
    if (value <= 250) return EmsAirQuality.heavy;
    if (value <= 350) return EmsAirQuality.severe;
    return EmsAirQuality.extreme;
  }

  String get aqiCaption => this == EmsAirQuality.unknown ? '—' : label;
}

/// BME680 raw pressure is Pascal when the value is above 2000.
double? emsPressureHpa(double? raw) {
  if (raw == null) return null;
  if (raw > 2000) return raw / 100;
  return raw;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

String _fixed(double? value, int digits) {
  if (value == null) return '—';
  return value.toStringAsFixed(digits);
}

/// Up to [digits] decimal places, without trailing zeros.
String _decimals(double? value, int digits) {
  if (value == null) return '—';
  var text = value.toStringAsFixed(digits);
  if (!text.contains('.')) return text;
  text = text.replaceFirst(RegExp(r'0+$'), '');
  return text.replaceFirst(RegExp(r'\.$'), '');
}
