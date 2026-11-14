import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../shared/models/models.dart';
import '../models/wizard_found_device.dart';
import '../models/wizard_step.dart';
import '../services/ble_device_service.dart';

@immutable
class NewDeviceWizardState {
  const NewDeviceWizardState({
    this.step = WizardStep.password,
    this.devicePassword = '',
    this.selectedDevice,
    this.deviceLocation,
    this.targetPort = 6000,
    this.localIp,
    this.broadcastIp,
    this.discoveredDevices = const [],
    this.flashingDeviceKeys = const {},
    this.dateTimeConfig,
    this.generalConfig,
    this.updateConfig,
    this.changeDevicePassword = false,
    this.newDevicePassword = '',
    this.confirmDevicePassword = '',
    this.savedDeviceId,
    this.bleConnection,
    this.scanResults = const [],
    this.isBusy = false,
    this.error,
    this.usedLanPath = true,
    this.locationPreviousStep = WizardStep.lanScan,
    this.ownerInfo,
    this.claimPreviousStep = WizardStep.lanScan,
    this.accessRequestSent = false,
  });

  final WizardStep step;
  final String devicePassword;
  final WizardFoundDevice? selectedDevice;
  final DeviceLocation? deviceLocation;
  final int targetPort;
  final String? localIp;
  final String? broadcastIp;
  final List<WizardFoundDevice> discoveredDevices;
  final Set<String> flashingDeviceKeys;
  final DateTimeConfig? dateTimeConfig;
  final GeneralConfig? generalConfig;
  final UpdateConfig? updateConfig;
  final bool changeDevicePassword;
  final String newDevicePassword;
  final String confirmDevicePassword;
  final String? savedDeviceId;
  final BleConnection? bleConnection;
  final List<ScanResult> scanResults;
  final bool isBusy;
  final String? error;
  final bool usedLanPath;
  final WizardStep locationPreviousStep;

  /// Account the selected device already belongs to (set on the
  /// [WizardStep.deviceClaimed] step).
  final DeviceOwnerInfo? ownerInfo;

  /// Step the back button of [WizardStep.deviceClaimed] returns to.
  final WizardStep claimPreviousStep;

  /// True once an access request for [ownerInfo] was sent in this session.
  final bool accessRequestSent;

  String get targetIp => selectedDevice?.ipAddress ?? '';

  NewDeviceWizardState copyWith({
    WizardStep? step,
    String? devicePassword,
    WizardFoundDevice? selectedDevice,
    DeviceLocation? deviceLocation,
    int? targetPort,
    String? localIp,
    String? broadcastIp,
    List<WizardFoundDevice>? discoveredDevices,
    Set<String>? flashingDeviceKeys,
    DateTimeConfig? dateTimeConfig,
    GeneralConfig? generalConfig,
    UpdateConfig? updateConfig,
    bool? changeDevicePassword,
    String? newDevicePassword,
    String? confirmDevicePassword,
    String? savedDeviceId,
    BleConnection? bleConnection,
    List<ScanResult>? scanResults,
    bool? isBusy,
    String? error,
    bool clearError = false,
    bool? usedLanPath,
    WizardStep? locationPreviousStep,
    bool clearBleConnection = false,
    DeviceOwnerInfo? ownerInfo,
    bool clearOwnerInfo = false,
    WizardStep? claimPreviousStep,
    bool? accessRequestSent,
  }) {
    return NewDeviceWizardState(
      step: step ?? this.step,
      devicePassword: devicePassword ?? this.devicePassword,
      selectedDevice: selectedDevice ?? this.selectedDevice,
      deviceLocation: deviceLocation ?? this.deviceLocation,
      targetPort: targetPort ?? this.targetPort,
      localIp: localIp ?? this.localIp,
      broadcastIp: broadcastIp ?? this.broadcastIp,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      flashingDeviceKeys: flashingDeviceKeys ?? this.flashingDeviceKeys,
      dateTimeConfig: dateTimeConfig ?? this.dateTimeConfig,
      generalConfig: generalConfig ?? this.generalConfig,
      updateConfig: updateConfig ?? this.updateConfig,
      changeDevicePassword: changeDevicePassword ?? this.changeDevicePassword,
      newDevicePassword: newDevicePassword ?? this.newDevicePassword,
      confirmDevicePassword:
          confirmDevicePassword ?? this.confirmDevicePassword,
      savedDeviceId: savedDeviceId ?? this.savedDeviceId,
      bleConnection: clearBleConnection
          ? null
          : (bleConnection ?? this.bleConnection),
      scanResults: scanResults ?? this.scanResults,
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : (error ?? this.error),
      usedLanPath: usedLanPath ?? this.usedLanPath,
      locationPreviousStep: locationPreviousStep ?? this.locationPreviousStep,
      ownerInfo: clearOwnerInfo ? null : (ownerInfo ?? this.ownerInfo),
      claimPreviousStep: claimPreviousStep ?? this.claimPreviousStep,
      accessRequestSent: accessRequestSent ?? this.accessRequestSent,
    );
  }
}
