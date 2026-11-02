import 'cp_device_type.dart';
import 'device.dart';

/// Value stored in `devices.name`, `devices.devicename` and `device_types.name`.
const emsStoredName = 'EMS';

/// Name shown everywhere in the app.
const emsDisplayName = 'Environment Monitoring System';

/// Short category under the device name on climate cards.
const emsCategoryLabel = 'Raumklima';

/// Firmware type string is exactly `EMS` or an environment-monitoring label.
bool isEmsTypeName(String? typeName) {
  if (typeName == null) return false;
  final n = typeName.trim().toLowerCase();
  if (n.isEmpty) return false;
  return n == 'ems' || n.contains('environment monitoring');
}

bool isEmsStoredName(String? name) {
  return (name ?? '').trim().toLowerCase() == emsStoredName.toLowerCase();
}

extension EmsDeviceLabel on Device {
  /// User-facing name. The database value stays [emsStoredName].
  String get displayName =>
      type == DeviceType.environmentMonitor ? emsDisplayName : name;
}

/// Shows the long EMS name when a stored name or firmware type is EMS.
String visibleStoredDeviceName(String? name, {int? firmwareType}) {
  if (firmwareType == CpDeviceType.ems ||
      isEmsStoredName(name) ||
      isEmsTypeName(name)) {
    return emsDisplayName;
  }
  return (name ?? '').trim();
}
