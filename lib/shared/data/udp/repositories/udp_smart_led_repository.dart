import '../../../domain/smart_led_repository.dart';
import '../../../models/smart_led_strip.dart';
import '../../../models/smart_led_trigger.dart';
import '../device_endpoint_resolver.dart';
import '../udp_device_service.dart';
import '../udp_mappers.dart';

class UdpSmartLedRepository implements SmartLedRepository {
  UdpSmartLedRepository(
    this._udp,
    this._endpoints, {
    this.onLink,
  });

  final UdpDeviceService _udp;
  final DeviceEndpointResolver _endpoints;

  /// Reports whether the device answered a UDP read.
  final void Function(String deviceId, bool online)? onLink;

  static const _readTimeout = Duration(seconds: 2);

  void _report(String deviceId, bool online) => onLink?.call(deviceId, online);

  @override
  Future<List<SmartLedStrip>> getStrips(String deviceId) async {
    try {
      final ep = await _endpoints.resolve(deviceId);
      final results = await Future.wait([
        for (final ledIndex in [1, 2, 3])
          _readStripOrDefault(
            ep.ipAddress,
            ep.port,
            ep.deviceCode,
            ledIndex,
          ),
      ]);
      _report(deviceId, results.any((result) => result.ok));
      return [for (final result in results) result.strip];
    } catch (_) {
      _report(deviceId, false);
      rethrow;
    }
  }

  Future<({bool ok, SmartLedStrip strip})> _readStripOrDefault(
    String ip,
    int port,
    String deviceCode,
    int ledIndex,
  ) async {
    try {
      final json = await _udp.readLedStrip(
        targetIp: ip,
        port: port,
        deviceCode: deviceCode,
        ledIndex: ledIndex,
        timeout: _readTimeout,
      );
      return (ok: true, strip: mapSmartLedStripFromUdp(json));
    } catch (_) {
      return (ok: false, strip: SmartLedStrip(ledIndex: ledIndex));
    }
  }

  @override
  Future<void> saveStrip(
    String deviceId,
    SmartLedStrip strip, {
    bool quickControl = false,
  }) async {
    final ep = await _endpoints.resolve(deviceId);
    // Always fire-and-forget in direct mode so UI controls stay snappy.
    await _udp.sendFireAndForget(
      targetIp: ep.ipAddress,
      port: ep.port,
      message: smartLedStripUdpWritePayload(
        ep.deviceCode,
        strip,
        quickControl: quickControl,
      ),
    );
  }

  @override
  Future<List<SmartLedTrigger>> getTriggers(String deviceId) async {
    try {
      final ep = await _endpoints.resolve(deviceId);
      final results = await Future.wait([
        for (var i = 0; i < 10; i++)
          _readTriggerOrDefault(ep.ipAddress, ep.port, ep.deviceCode, i),
      ]);
      _report(deviceId, results.any((result) => result.ok));
      return [for (final result in results) result.trigger];
    } catch (_) {
      _report(deviceId, false);
      rethrow;
    }
  }

  Future<({bool ok, SmartLedTrigger trigger})> _readTriggerOrDefault(
    String ip,
    int port,
    String deviceCode,
    int index,
  ) async {
    try {
      final json = await _udp.readSmartLedTrigger(
        targetIp: ip,
        port: port,
        deviceCode: deviceCode,
        triggerIndex: index,
      );
      return (ok: true, trigger: mapSmartLedTriggerFromUdp(json, index));
    } catch (_) {
      return (ok: false, trigger: SmartLedTrigger(parameterIndex: index));
    }
  }

  @override
  Future<List<SmartLedTrigger>> getActiveTriggers(String deviceId) async {
    final all = await getTriggers(deviceId);
    return all.where((t) => t.active == 1).toList();
  }

  @override
  Future<int?> nextFreeTriggerIndex(String deviceId) async {
    final all = await getTriggers(deviceId);
    for (final trigger in all) {
      if (trigger.active != 1) return trigger.parameterIndex;
    }
    return null;
  }

  @override
  Future<void> saveTrigger(String deviceId, SmartLedTrigger trigger) async {
    final ep = await _endpoints.resolve(deviceId);
    await _udp.writeSmartLedTrigger(
      targetIp: ep.ipAddress,
      port: ep.port,
      payload: smartLedTriggerUdpWritePayload(ep.deviceCode, trigger),
    );
  }

  @override
  Future<void> deactivateTrigger(
    String deviceId,
    int parameterIndex,
  ) async {
    final ep = await _endpoints.resolve(deviceId);
    await _udp.writeSmartLedTrigger(
      targetIp: ep.ipAddress,
      port: ep.port,
      payload: {
        'protocol_nr': 13,
        'reply_protocol': 13,
        'code': ep.deviceCode,
        'command': parameterIndex,
        'parameter_index': parameterIndex,
        'active': 0,
      },
    );
  }
}
