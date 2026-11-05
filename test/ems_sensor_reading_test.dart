import 'package:flutter_test/flutter_test.dart';
import 'package:virtumi_home/shared/models/ems_device.dart';
import 'package:virtumi_home/shared/models/ems_sensor_reading.dart';

void main() {
  test('maps compensated climate values and Pascal pressure', () {
    final reading = EmsSensorReading.fromJson({
      'iaq': 180,
      'static_iaq': 18,
      'accuracy': 3,
      'raw_pressure': 101400,
      'raw_temperature': 25,
      'raw_humidity': 20,
      'sensor_heat_compensated_temperature': 21.4,
      'sensor_heat_compensated_humidity': 46,
      'co2_equivalent': 412,
      'breath_voc_equivalent': 0.6,
      'stabilization_status': 1,
      'run_in_status': 1,
    });

    expect(reading.temperatureLabel, '21.4');
    expect(reading.humidityLabel, '46');
    expect(reading.pressureLabel, '1014');
    expect(reading.aqiLabel, '18');
    expect(reading.vocLabel, '0.6');
    expect(const EmsSensorReading(breathVocEquivalent: 1.256).vocLabel, '1.26');
    expect(const EmsSensorReading(breathVocEquivalent: 2).vocLabel, '2');
    expect(reading.accuracyLabel, 'Hoch');
    expect(const EmsSensorReading(accuracy: 0).accuracyLabel, 'Stabilisierung');
    expect(const EmsSensorReading(accuracy: 1).accuracyLabel, 'Niedrig');
    expect(const EmsSensorReading(accuracy: 2).accuracyLabel, 'Mittel');
    expect(reading.co2Label, '412');
    expect(reading.airQuality, EmsAirQuality.excellent);
    expect(EmsAirQuality.fromIaq(50), EmsAirQuality.excellent);
    expect(EmsAirQuality.fromIaq(50).label, 'Ausgezeichnet');
    expect(EmsAirQuality.fromIaq(100).label, 'Gut');
    expect(EmsAirQuality.fromIaq(150).label, 'Leicht belastet');
    expect(EmsAirQuality.fromIaq(200).label, 'Mäßig belastet');
    expect(EmsAirQuality.fromIaq(250).label, 'Stark belastet');
    expect(EmsAirQuality.fromIaq(350).label, 'Sehr stark belastet');
    expect(EmsAirQuality.fromIaq(351).label, 'Extrem belastet');
    expect(
      reading.ventilationAdvice,
      'Optimale Raumluft. Keine Aktion erforderlich.',
    );
    expect(reading.isStabilizing, isFalse);
    expect(reading.isRunInActive, isFalse);
    expect(const EmsSensorReading(runInStatus: 0).isRunInActive, isTrue);
    expect(const EmsSensorReading(runInStatus: 0).isStabilizing, isFalse);
    expect(reading.temperatureHint, 'Optimal (Soll 21 °C)');
    expect(reading.humidityHint, 'Idealer Bereich (40–60 %)');
    expect(reading.pressureHint, 'Normal');
  });

  test('treats unfinished stabilization as not ready', () {
    const reading = EmsSensorReading(
      staticIaq: 180,
      co2Equivalent: 1600,
      stabilizationStatus: 0,
    );

    expect(reading.airQuality, EmsAirQuality.moderate);
    expect(reading.airQuality.label, 'Mäßig belastet');
    expect(reading.ventilationAdvice, 'Bitte jetzt lüften.');
    expect(
      const EmsSensorReading(staticIaq: 400).ventilationAdvice,
      'Bitte jetzt lüften.',
    );
    expect(reading.isStabilizing, isTrue);
  });

  test('recognizes the EMS type without using it as the visible name', () {
    expect(isEmsTypeName('EMS'), isTrue);
    expect(isEmsTypeName('Environment Monitoring System'), isTrue);
    expect(isEmsTypeName('Control Panel'), isFalse);
    expect(emsStoredName, 'EMS');
    expect(emsDisplayName, 'Environment Monitoring System');
  });
}
