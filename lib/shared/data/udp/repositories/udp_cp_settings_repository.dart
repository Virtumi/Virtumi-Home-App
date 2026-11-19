import '../../../domain/cp_settings_repository.dart';
import '../../../models/cp_parameter.dart';
import '../../../models/cp_parameter_device_option.dart';
import '../../supabase/supabase_cp_settings_repository.dart';
import '../device_endpoint_resolver.dart';
import '../udp_device_service.dart';
import '../udp_mappers.dart';

class UdpCpSettingsRepository implements CpSettingsRepository {
  UdpCpSettingsRepository(
    this._udp,
    this._endpoints,
    this._supabaseFallback,
  );

  final UdpDeviceService _udp;
  final DeviceEndpointResolver _endpoints;
  final SupabaseCpSettingsRepository _supabaseFallback;

  @override
  Future<List<CpParameter>> getParameters(String deviceId) async {
    final ep = await _endpoints.resolve(deviceId);

    return Future.wait([
      for (var i = 0; i < 10; i++)
        _readParameterOrDefault(ep.ipAddress, ep.port, ep.deviceCode, i),
    ]);
  }

  Future<CpParameter> _readParameterOrDefault(
    String ip,
    int port,
    String deviceCode,
    int index,
  ) async {
    try {
      final json = await _udp.readCpParameter(
        targetIp: ip,
        port: port,
        deviceCode: deviceCode,
        slotCommand: index,
      );
      return mapCpParameterFromUdp(json, index);
    } catch (_) {
      return CpParameter(parameterIndex: index);
    }
  }

  @override
  Future<List<CpParameter>> getActiveParameters(String deviceId) async {
    final all = await getParameters(deviceId);
    return all.where((p) => p.active == 1).toList();
  }

  @override
  Future<int?> nextFreeParameterIndex(String deviceId) async {
    final all = await getParameters(deviceId);
    for (final parameter in all) {
      if (parameter.active != 1) return parameter.parameterIndex;
    }
    return null;
  }

  @override
  Future<void> saveParameter(String deviceId, CpParameter parameter) async {
    final ep = await _endpoints.resolve(deviceId);
    await _udp.writeCpParameter(
      targetIp: ep.ipAddress,
      port: ep.port,
      payload: cpParameterUdpWritePayload(ep.deviceCode, parameter),
    );
  }

  @override
  Future<void> deactivateParameter(
    String deviceId,
    int parameterIndex,
  ) async {
    final ep = await _endpoints.resolve(deviceId);
    await _udp.writeCpParameter(
      targetIp: ep.ipAddress,
      port: ep.port,
      payload: {
        'protocol_nr': 13,
        'reply_protocol': 13,
        'code': ep.deviceCode,
        'command': parameterIndex,
        'active': 0,
      },
    );
  }

  @override
  Future<List<CpParameterDeviceOption>> getSelectableDevices({
    required String excludeDeviceId,
  }) {
    return _supabaseFallback.getSelectableDevices(
      excludeDeviceId: excludeDeviceId,
    );
  }
}
