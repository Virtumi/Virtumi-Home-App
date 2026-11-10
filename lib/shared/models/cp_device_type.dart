/// Firmware device type identifiers stored in cp_parameters.device_type.
abstract final class CpDeviceType {
  static const smartSwitch = 10;
  static const socket = 20;
  static const louver = 30;
  static const heater = 40;
  static const alarmSystem = 50;
  static const controlPanel = 60;
  static const ems = 70;
  static const smartLed = 80;

  static int fromDeviceTypeName(String? typeName) {
    if (typeName == null || typeName.isEmpty) return 0;
    final lower = typeName.toLowerCase();

    if (lower.contains('smart') && lower.contains('led')) return smartLed;
    if (lower.contains('smart') && lower.contains('switch')) return smartSwitch;
    if (lower.contains('socket') || lower.contains('steckdose')) return socket;
    if (lower.contains('louver') ||
        lower.contains('jalousie') ||
        lower.contains('blind')) {
      return louver;
    }
    if (lower.contains('heater') || lower.contains('heiz')) return heater;
    if (lower.contains('alarm')) return alarmSystem;
    if (lower.contains('control panel')) return controlPanel;
    if (lower.contains('ems') ||
        lower.contains('environment monitoring')) {
      return ems;
    }

    return 0;
  }

  static bool isSmartLed(int deviceType) => deviceType == smartLed;
}
