import '../models/ems_sensor_reading.dart';

/// Current climate sample for an Environment Monitoring System.
abstract class EmsSensorRepository {
  Future<EmsSensorReading?> getReading(String deviceId);
}
