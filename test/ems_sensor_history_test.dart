import 'package:flutter_test/flutter_test.dart';
import 'package:virtumi_home/shared/models/ems_sensor_history.dart';

void main() {
  test('reads raw climate values and keeps hPa pressure', () {
    final point = EmsHistoryPoint.fromJson({
      'logged_at': '2026-11-02T19:40:59.2859',
      'iaq': 62.0542,
      'raw_temperature': 20.83488,
      'raw_humidity': 62.06077,
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
      EmsHistoryPoint(loggedAt: early, rawTemperature: 22),
      EmsHistoryPoint(loggedAt: mid, rawTemperature: 18.5),
      EmsHistoryPoint(loggedAt: late, rawTemperature: 25),
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
      )?.rawTemperature,
      22,
    );
  });
}
