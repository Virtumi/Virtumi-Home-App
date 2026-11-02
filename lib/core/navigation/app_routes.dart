/// Centralized route names + path builders for GoRouter.
///
/// Use the [Paths] helpers to build concrete locations so paths are defined in
/// exactly one place.
class AppRoute {
  AppRoute._();

  // Tab roots
  static const String home = 'home';
  static const String login = 'login';
  static const String register = 'register';
  static const String scenes = 'scenes';
  static const String people = 'people';
  static const String settings = 'settings';

  // Settings sub
  static const String profile = 'profile';
  static const String startScreen = 'startScreen';

  // Home drill-down
  static const String allHouses = 'allHouses';
  static const String floors = 'floors';
  static const String rooms = 'rooms';
  static const String roomOverview = 'roomOverview';
  static const String deviceDetails = 'deviceDetails';
  static const String newDeviceWizard = 'newDeviceWizard';
  static const String deviceSettings = 'deviceSettings';

  // Device settings sub-pages
  static const String deviceInfo = 'deviceInfo';
  static const String dateTime = 'dateTime';
  static const String network = 'network';
  static const String matter = 'matter';
  static const String cloud = 'cloud';
  static const String virtumiCloud = 'virtumiCloud';
  static const String mqttCloud = 'mqttCloud';
  static const String deviceLocation = 'deviceLocation';
  static const String changePassword = 'changePassword';
  static const String updateSettings = 'updateSettings';
  static const String generalSettings = 'generalSettings';
  static const String deviceParameters = 'deviceParameters';
  static const String smartLedStrips = 'smartLedStrips';
  static const String smartLedTriggers = 'smartLedTriggers';
  static const String deviceData = 'deviceData';
  static const String ledStripSettings = 'ledStripSettings';
  static const String emsHistory = 'emsHistory';
}

/// Concrete path builders (absolute locations) for `context.go(...)`.
class Paths {
  Paths._();

  static const String home = '/home';
  static const String login = '/login';
  static const String register = '/register';
  static const String scenes = '/scenes';
  static const String people = '/people';
  static const String settings = '/settings';
  static const String profile = '/settings/profile';
  static const String startScreen = '/settings/start-screen';

  static const String allHouses = '/home/houses';
  static String floors(String houseId) => '/home/house/$houseId';
  static String rooms(String floorId) => '/home/floor/$floorId';
  static String roomOverview(String roomId) => '/home/room/$roomId';
  static String deviceDetails(String deviceId) => '/home/device/$deviceId';
  static const String newDeviceWizard = '/home/add-device';
  static String deviceSettings(String deviceId) =>
      '/home/device/$deviceId/settings';

  static String deviceInfo(String deviceId) => '/home/device/$deviceId/info';
  static String dateTime(String deviceId) => '/home/device/$deviceId/datetime';
  static String network(String deviceId) => '/home/device/$deviceId/network';
  static String matter(String deviceId) => '/home/device/$deviceId/matter';
  static String cloud(String deviceId) => '/home/device/$deviceId/cloud';
  static String virtumiCloud(String deviceId) =>
      '/home/device/$deviceId/cloud/virtumi';
  static String mqttCloud(String deviceId) =>
      '/home/device/$deviceId/cloud/mqtt';
  static String deviceLocation(String deviceId) =>
      '/home/device/$deviceId/location';
  static String changePassword(String deviceId) =>
      '/home/device/$deviceId/password';
  static String updateSettings(String deviceId) =>
      '/home/device/$deviceId/update';
  static String generalSettings(String deviceId) =>
      '/home/device/$deviceId/general';
  static String deviceParameters(String deviceId) =>
      '/home/device/$deviceId/parameters';
  static String smartLedStrips(String deviceId) =>
      '/home/device/$deviceId/led-strips';
  static String smartLedTriggers(String deviceId) =>
      '/home/device/$deviceId/led-triggers';
  static String deviceData(String deviceId) =>
      '/home/device/$deviceId/sensor-data';
  static String emsHistory(String deviceId) =>
      '/home/device/$deviceId/history';
  static String ledStripSettings(String deviceId) =>
      '/home/device/$deviceId/general/led-strip-settings';
}
