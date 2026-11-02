import '../../../models/device.dart';
import '../../../models/ems_device.dart';

bool isSmartLedTypeName(String? typeName) {
  if (typeName == null || typeName.isEmpty) return false;
  final lower = typeName.toLowerCase();
  return lower.contains('smart') && lower.contains('led');
}

DeviceType mapDeviceType(String? typeName) {
  if (isSmartLedTypeName(typeName)) return DeviceType.light;
  if (isEmsTypeName(typeName)) return DeviceType.environmentMonitor;
  if (typeName != null && typeName.toLowerCase().contains('control panel')) {
    return DeviceType.controlPanel;
  }
  return DeviceType.controlPanel;
}

Device mapDeviceRow(
  Map<String, dynamic> row, {
  required String roomId,
  DeviceConnectivity connectivity = DeviceConnectivity.offline,
}) {
  final typeName = row['device_types'] is Map<String, dynamic>
      ? row['device_types']['name'] as String?
      : null;

  final status = row['status'] as String? ?? 'offline';
  final isOn = status == 'online';

  return Device(
    id: row['id'] as String,
    roomId: roomId,
    name: (row['name'] as String?)?.trim().isNotEmpty == true
        ? row['name'] as String
        : (row['devicename'] as String?) ?? 'Gerät',
    type: mapDeviceType(typeName),
    isOn: isOn,
    connectivity: connectivity,
    summary: row['description'] as String? ?? '',
    firmwareVersion: (row['current_version'] as String?)?.trim() ?? '',
    model: typeName ?? 'Virtumi Device',
    serialNumber: row['device_code'] as String? ?? '',
    hardwareSerial: (row['serial_number'] as String?)?.trim() ?? '',
    ipAddress: row['ip_address'] as String? ?? '',
    macAddress: row['mac_address'] as String? ?? '',
    hostname: row['hostname'] as String? ?? '',
  );
}

String? deviceCodeFromRow(Map<String, dynamic> row) =>
    row['device_code'] as String?;

String? macAddressFromRow(Map<String, dynamic> row) =>
    row['mac_address'] as String?;
