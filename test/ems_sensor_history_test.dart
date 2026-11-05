import 'package:flutter_test/flutter_test.dart';
import 'package:virtumi_home/shared/models/ems_sensor_history.dart';

void main() {
  test('reads compensated climate values and keeps hPa pressure', () {
    final point = EmsHistoryPoint.fromJson({
      'logged_at': '2026-11-02T19:40:59.2859',
      'iaq': 10,
      'static_iaq': 62.0542,
      'raw_temperature': 30,
      'raw_humidity': 20,
      'sensor_heat_compensated_temperature': 20.83488,
      'sensor_heat_compensated_humidity': 62.06077,
      'raw_pressure': 986.8304,
    });

    expect(point, isNotNull);
    final utc = point!.loggedAt.toUtc();
    expect(utc.year, 2026);
    expect(utc.month, 11);
    expect(utc.day, 2);
    expect(utc.hour, 19);
    expect(utc.minute, 40);
    expect(point.valueFor(EmsHistoryMetric.aqi), closeTo(62.05, 0.01));
    expect(point.valueFor(EmsHistoryMetric.temperature), closeTo(20.83, 0.01));
    expect(point.valueFor(EmsHistoryMetric.humidity), closeTo(62.06, 0.01));
    expect(point.valueFor(EmsHistoryMetric.pressure), closeTo(986.83, 0.01));
  });

  test('converts Pascal pressure and keeps an explicit UTC timestamp', () {
    final point = EmsHistoryPoint.fromJson({
      'logged_at': '2026-11-02T19:40:59Z',
      'raw_pressure': 101400,
    });

    expect(point!.loggedAt.toUtc().hour, 19);
    expect(point.valueFor(EmsHistoryMetric.pressure), 1014);
  });

  test('finds the minimum and maximum inside a window', () {
    final early = DateTime.utc(2026, 11, 2, 10);
    final mid = DateTime.utc(2026, 11, 2, 12);
    final late = DateTime.utc(2026, 11, 2, 18);
    final points = [
      EmsHistoryPoint(loggedAt: early, compensatedTemperature: 22),
      EmsHistoryPoint(loggedAt: mid, compensatedTemperature: 18.5),
      EmsHistoryPoint(loggedAt: late, compensatedTemperature: 25),
    ];

    expect(
      extremeEmsPoint(points, EmsHistoryMetric.temperature, minimum: true)
          ?.loggedAt,
      mid,
    );
    expect(
      extremeEmsPoint(
        points,
        EmsHistoryMetric.temperature,
        minimum: false,
        start: early,
        end: mid,
      )?.compensatedTemperature,
      22,
    );
    expect(
      latestEmsPoint(points, EmsHistoryMetric.temperature)?.loggedAt,
      late,
    );
    expect(
      latestEmsPoint(
        points,
        EmsHistoryMetric.temperature,
        start: early,
        end: mid,
      )?.compensatedTemperature,
      18.5,
    );
    expect(formatEmsHistoryValue(EmsHistoryMetric.temperature, 21.36), '21.4 °C');
    expect(formatEmsHistoryValue(EmsHistoryMetric.aqi, 50), '50');
  });
}
