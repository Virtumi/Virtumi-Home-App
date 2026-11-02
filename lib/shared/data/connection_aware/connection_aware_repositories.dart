import '../../providers/connection_mode_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/cp_settings_repository.dart';
import '../../domain/device_config_repository.dart';
import '../../domain/device_request_repository.dart';
import '../../domain/ems_sensor_repository.dart';
import '../../domain/smart_led_repository.dart';
import '../../models/models.dart';

DeviceConfigRepository connectionAwareDeviceConfigRepository(
  Ref ref, {
  required DeviceConfigRepository cloud,
  required DeviceConfigRepository direct,
}) {
  return _ConnectionAwareDeviceConfigRepository(
    isDirect: () => ref.read(isDirectConnectionProvider),
    cloud: cloud,
    direct: direct,
  );
}

DeviceRequestRepository connectionAwareDeviceRequestRepository(
  Ref ref, {
  required DeviceRequestRepository cloud,
  required DeviceRequestRepository direct,
}) {
  return _ConnectionAwareDeviceRequestRepository(
    isDirect: () => ref.read(isDirectConnectionProvider),
    cloud: cloud,
    direct: direct,
  );
}

CpSettingsRepository connectionAwareCpSettingsRepository(
  Ref ref, {
  required CpSettingsRepository cloud,
  required CpSettingsRepository direct,
}) {
  return _ConnectionAwareCpSettingsRepository(
    isDirect: () => ref.read(isDirectConnectionProvider),
    cloud: cloud,
    direct: direct,
  );
}

SmartLedRepository connectionAwareSmartLedRepository(
  Ref ref, {
  required SmartLedRepository cloud,
  required SmartLedRepository direct,
}) {
  return _ConnectionAwareSmartLedRepository(
    isDirect: () => ref.read(isDirectConnectionProvider),
    cloud: cloud,
    direct: direct,
  );
}

EmsSensorRepository connectionAwareEmsSensorRepository(
  Ref ref, {
  required EmsSensorRepository cloud,
  required EmsSensorRepository direct,
}) {
  return _ConnectionAwareEmsSensorRepository(
    isDirect: () => ref.read(isDirectConnectionProvider),
    cloud: cloud,
    direct: direct,
  );
}

class _ConnectionAwareDeviceConfigRepository implements DeviceConfigRepository {
  _ConnectionAwareDeviceConfigRepository({
    required bool Function() isDirect,
    required this.cloud,
    required this.direct,
  }) : _isDirect = isDirect;

  final bool Function() _isDirect;
  final DeviceConfigRepository cloud;
  final DeviceConfigRepository direct;

  DeviceConfigRepository get _repo => _isDirect() ? direct : cloud;

  @override
  Future<NetworkConfig> getNetworkConfig(String deviceId) =>
      _repo.getNetworkConfig(deviceId);

  @override
  Future<void> saveNetworkConfig(String deviceId, NetworkConfig config) =>
      _repo.saveNetworkConfig(deviceId, config);

  @override
  Future<CloudConfig> getCloudConfig(String deviceId) =>
      _repo.getCloudConfig(deviceId);

  @override
  Future<void> saveMqttCloud(String deviceId, MqttCloudConfig config) =>
      _repo.saveMqttCloud(deviceId, config);

  @override
  Future<void> saveVirtumiCloud(String deviceId, VirtumiCloudConfig config) =>
      _repo.saveVirtumiCloud(deviceId, config);

  @override
  Future<void> resendVirtumiCloud(
    String deviceId,
    VirtumiCloudConfig config,
  ) =>
      _repo.resendVirtumiCloud(deviceId, config);

  @override
  Future<DateTimeConfig> getDateTimeConfig(String deviceId) =>
      _repo.getDateTimeConfig(deviceId);

  @override
  Future<void> saveDateTimeConfig(String deviceId, DateTimeConfig config) =>
      _repo.saveDateTimeConfig(deviceId, config);

  @override
  Future<MatterConfig> getMatterConfig(String deviceId) =>
      _repo.getMatterConfig(deviceId);

  @override
  Future<void> saveMatterConfig(String deviceId, MatterConfig config) =>
      _repo.saveMatterConfig(deviceId, config);

  @override
  Future<DeviceLocation> getDeviceLocation(String deviceId) =>
      _repo.getDeviceLocation(deviceId);

  @override
  Future<void> saveDeviceLocation(String deviceId, DeviceLocation location) =>
      _repo.saveDeviceLocation(deviceId, location);

  @override
  Future<UpdateConfig> getUpdateConfig(String deviceId) =>
      _repo.getUpdateConfig(deviceId);

  @override
  Future<void> saveUpdateConfig(String deviceId, UpdateConfig config) =>
      _repo.saveUpdateConfig(deviceId, config);

  @override
  Future<GeneralConfig> getGeneralConfig(String deviceId) =>
      _repo.getGeneralConfig(deviceId);

  @override
  Future<void> saveGeneralConfig(String deviceId, GeneralConfig config) =>
      _repo.saveGeneralConfig(deviceId, config);
}

class _ConnectionAwareDeviceRequestRepository implements DeviceRequestRepository {
  _ConnectionAwareDeviceRequestRepository({
    required bool Function() isDirect,
    required this.cloud,
    required this.direct,
  }) : _isDirect = isDirect;

  final bool Function() _isDirect;
  final DeviceRequestRepository cloud;
  final DeviceRequestRepository direct;

  DeviceRequestRepository get _repo => _isDirect() ? direct : cloud;

  @override
  Future<void> sendButtonPress(String deviceId, int command) =>
      _repo.sendButtonPress(deviceId, command);

  @override
  Future<void> sendMatterPairingRequest(String deviceId) =>
      _repo.sendMatterPairingRequest(deviceId);

  @override
  Future<void> sendUpdateRequest(String deviceId) =>
      _repo.sendUpdateRequest(deviceId);

  @override
  Future<void> requestPasswordChange({
    required String deviceId,
    required String currentCode,
    required String newCode,
  }) =>
      _repo.requestPasswordChange(
        deviceId: deviceId,
        currentCode: currentCode,
        newCode: newCode,
      );

  @override
  Future<String?> pollRequestStatus({
    required String table,
    required String deviceId,
    Duration timeout = const Duration(seconds: 30),
    Duration interval = const Duration(seconds: 2),
  }) =>
      _repo.pollRequestStatus(
        table: table,
        deviceId: deviceId,
        timeout: timeout,
        interval: interval,
      );
}

class _ConnectionAwareCpSettingsRepository implements CpSettingsRepository {
  _ConnectionAwareCpSettingsRepository({
    required bool Function() isDirect,
    required this.cloud,
    required this.direct,
  }) : _isDirect = isDirect;

  final bool Function() _isDirect;
  final CpSettingsRepository cloud;
  final CpSettingsRepository direct;

  CpSettingsRepository get _repo => _isDirect() ? direct : cloud;

  @override
  Future<List<CpParameter>> getParameters(String deviceId) =>
      _repo.getParameters(deviceId);

  @override
  Future<List<CpParameter>> getActiveParameters(String deviceId) =>
      _repo.getActiveParameters(deviceId);

  @override
  Future<int?> nextFreeParameterIndex(String deviceId) =>
      _repo.nextFreeParameterIndex(deviceId);

  @override
  Future<void> saveParameter(String deviceId, CpParameter parameter) =>
      _repo.saveParameter(deviceId, parameter);

  @override
  Future<void> deactivateParameter(String deviceId, int parameterIndex) =>
      _repo.deactivateParameter(deviceId, parameterIndex);

  @override
  Future<List<CpParameterDeviceOption>> getSelectableDevices({
    required String excludeDeviceId,
  }) =>
      _repo.getSelectableDevices(excludeDeviceId: excludeDeviceId);
}

class _ConnectionAwareSmartLedRepository implements SmartLedRepository {
  _ConnectionAwareSmartLedRepository({
    required bool Function() isDirect,
    required this.cloud,
    required this.direct,
  }) : _isDirect = isDirect;

  final bool Function() _isDirect;
  final SmartLedRepository cloud;
  final SmartLedRepository direct;

  SmartLedRepository get _repo => _isDirect() ? direct : cloud;

  @override
  Future<List<SmartLedStrip>> getStrips(String deviceId) =>
      _repo.getStrips(deviceId);

  @override
  Future<void> saveStrip(
    String deviceId,
    SmartLedStrip strip, {
    bool quickControl = false,
  }) =>
      _repo.saveStrip(deviceId, strip, quickControl: quickControl);

  @override
  Future<List<SmartLedTrigger>> getTriggers(String deviceId) =>
      _repo.getTriggers(deviceId);

  @override
  Future<List<SmartLedTrigger>> getActiveTriggers(String deviceId) =>
      _repo.getActiveTriggers(deviceId);

  @override
  Future<int?> nextFreeTriggerIndex(String deviceId) =>
      _repo.nextFreeTriggerIndex(deviceId);

  @override
  Future<void> saveTrigger(String deviceId, SmartLedTrigger trigger) =>
      _repo.saveTrigger(deviceId, trigger);

  @override
  Future<void> deactivateTrigger(String deviceId, int parameterIndex) =>
      _repo.deactivateTrigger(deviceId, parameterIndex);
}

class _ConnectionAwareEmsSensorRepository implements EmsSensorRepository {
  _ConnectionAwareEmsSensorRepository({
    required bool Function() isDirect,
    required this.cloud,
    required this.direct,
  }) : _isDirect = isDirect;

  final bool Function() _isDirect;
  final EmsSensorRepository cloud;
  final EmsSensorRepository direct;

  EmsSensorRepository get _repo => _isDirect() ? direct : cloud;

  @override
  Future<EmsSensorReading?> getReading(String deviceId) =>
      _repo.getReading(deviceId);
}
