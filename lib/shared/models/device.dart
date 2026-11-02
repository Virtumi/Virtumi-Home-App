import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// High-level category of a smart device, used for iconography and grouping.
enum DeviceType {
  controlPanel(Symbols.tablet, 'Control Panel'),
  environmentMonitor(Symbols.air, 'Environment Monitoring System'),
  light(Symbols.lightbulb, 'Licht'),
  thermostat(Symbols.thermostat, 'Thermostat'),
  sensor(Symbols.sensors, 'Sensor'),
  socket(Symbols.power, 'Steckdose'),
  lock(Symbols.lock, 'Schloss'),
  camera(Symbols.videocam, 'Kamera'),
  speaker(Symbols.speaker, 'Lautsprecher');

  const DeviceType(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// Online / connectivity state of a device.
enum DeviceConnectivity {
  online('Online'),
  offline('Offline'),
  updating('Aktualisiert');

  const DeviceConnectivity(this.label);
  final String label;
}

/// Active panel zone on a control panel device card.
enum ControlPanelPosition {
  left('Links', 2),
  center('Mitte', 0),
  right('Rechts', 1);

  const ControlPanelPosition(this.label, this.command);
  final String label;
  final int command;
}

/// A single, immutable smart device entity.
@immutable
class Device {
  const Device({
    required this.id,
    required this.roomId,
    required this.name,
    required this.type,
    this.isOn = false,
    this.connectivity = DeviceConnectivity.online,
    this.summary = '',
    this.temperature,
    this.firmwareVersion = '1.0.0',
    this.model = 'Virtumi Device',
    this.serialNumber = '',
    this.hardwareSerial = '',
    this.ipAddress = '',
    this.macAddress = '',
    this.hostname = '',
  });

  final String id;
  final String roomId;
  final String name;
  final DeviceType type;
  final bool isOn;
  final DeviceConnectivity connectivity;
  final String summary;
  final double? temperature;
  final String firmwareVersion;
  final String model;

  /// Device password stored in `devices.device_code`.
  final String serialNumber;

  /// Hardware serial stored in `devices.serial_number`.
  final String hardwareSerial;
  final String ipAddress;
  final String macAddress;
  final String hostname;

  String get statusLabel => isOn ? 'An' : 'Aus';

  Device copyWith({
    String? name,
    bool? isOn,
    DeviceConnectivity? connectivity,
    String? summary,
    double? temperature,
  }) {
    return Device(
      id: id,
      roomId: roomId,
      name: name ?? this.name,
      type: type,
      isOn: isOn ?? this.isOn,
      connectivity: connectivity ?? this.connectivity,
      summary: summary ?? this.summary,
      temperature: temperature ?? this.temperature,
      firmwareVersion: firmwareVersion,
      model: model,
      serialNumber: serialNumber,
      hardwareSerial: hardwareSerial,
      ipAddress: ipAddress,
      macAddress: macAddress,
      hostname: hostname,
    );
  }
}
