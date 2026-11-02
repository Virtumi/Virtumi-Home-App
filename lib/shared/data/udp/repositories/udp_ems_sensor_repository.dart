import '../../../domain/ems_sensor_repository.dart';
import '../../../models/ems_sensor_reading.dart';
import '../device_endpoint_resolver.dart';
import '../udp_device_service.dart';

class UdpEmsSensorRepository implements EmsSensorRepository {
  UdpEmsSensorRepository(this._udp, this._endpoints);

  final UdpDeviceService _udp;
  final DeviceEndpointResolver _endpoints;

  static const _readTimeout = Duration(seconds: 3);

  @override
  Future<EmsSensorReading?> getReading(String deviceId) async {
    final ep = await _endpoints.resolve(deviceId);
    final json = await _udp.readEmsSensor(
      targetIp: ep.ipAddress,
      port: ep.port,
      deviceCode: ep.deviceCode,
      timeout: _readTimeout,
    );
    return EmsSensorReading.fromJson(json);
  }
}
