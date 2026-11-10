import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/preferences_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../application/direct_device_link.dart';
import '../application/recent_device_activity.dart';
import '../data/activity_tracking/activity_tracking_device_request_repository.dart';
import '../data/activity_tracking/activity_tracking_smart_home_repository.dart';
import '../data/activity_tracking/activity_tracking_smart_led_repository.dart';
import '../data/csv_location_repository.dart';
import '../data/local_app_settings_repository.dart';
import '../data/mock_app_settings_repository.dart';
import '../data/mock_cp_settings_repository.dart';
import '../data/mock_device_config_repository.dart';
import '../data/mock_device_data_repository.dart';
import '../data/mock_device_discovery_repository.dart';
import '../data/mock_seed.dart';
import '../data/mock_smart_home_repository.dart';
import '../data/mock_smart_led_repository.dart';
import '../data/mock_user_repository.dart';
import '../data/supabase/supabase_cp_settings_repository.dart';
import '../data/supabase/supabase_device_config_repository.dart';
import '../data/supabase/supabase_device_data_repository.dart';
import '../data/supabase/supabase_device_request_repository.dart';
import '../data/supabase/supabase_ems_history_repository.dart';
import '../data/supabase/supabase_ems_sensor_repository.dart';
import '../data/supabase/supabase_smart_home_repository.dart';
import '../data/supabase/supabase_smart_led_repository.dart';
import '../data/supabase/supabase_user_repository.dart';
import '../data/connection_aware/connection_aware_repositories.dart';
import '../data/udp/device_endpoint_resolver.dart';
import '../data/udp/repositories/udp_cp_settings_repository.dart';
import '../data/udp/repositories/udp_device_config_repository.dart';
import '../data/udp/repositories/udp_device_request_repository.dart';
import '../data/udp/repositories/udp_ems_sensor_repository.dart';
import '../data/udp/repositories/udp_smart_led_repository.dart';
import '../data/udp/udp_device_service.dart';
import '../data/udp_device_discovery_repository.dart';
import '../domain/app_settings_repository.dart';
import '../domain/cp_settings_repository.dart';
import '../domain/device_config_repository.dart';
import '../domain/device_data_repository.dart';
import '../domain/device_discovery_repository.dart';
import '../domain/device_request_repository.dart';
import '../domain/ems_sensor_repository.dart';
import '../domain/location_repository.dart';
import '../domain/smart_home_repository.dart';
import '../domain/smart_led_repository.dart';
import '../domain/user_repository.dart';

/// Single shared in-memory store seed instance (tests / dev override).
final mockStoreProvider = Provider<MockStore>((ref) => MockStore.instance);

void _recordDeviceActivity(Ref ref, String deviceId) {
  ref.read(recentDeviceActivityProvider.notifier).record(deviceId);
}

void _reportDirectLink(Ref ref, String deviceId, bool online) {
  final link = ref.read(directDeviceLinkProvider.notifier);
  if (online) {
    link.markOnline(deviceId);
  } else {
    link.markOffline(deviceId);
  }
}

/// Location hierarchy repository.
final smartHomeRepositoryProvider = Provider<SmartHomeRepository>((ref) {
  final inner = SupabaseSmartHomeRepository(ref.watch(supabaseClientProvider));
  return ActivityTrackingSmartHomeRepository(
    inner,
    (deviceId) => _recordDeviceActivity(ref, deviceId),
  );
});

/// Current user repository.
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return SupabaseUserRepository(ref.watch(supabaseClientProvider));
});

/// App settings repository (Einstellungen).
final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return LocalAppSettingsRepository(ref.watch(preferencesServiceProvider));
});

/// Native UDP device communication service.
final udpDeviceServiceProvider = Provider<UdpDeviceService>((ref) {
  return UdpDeviceService();
});

/// Resolves device IP/code from Supabase registry for UDP.
final deviceEndpointResolverProvider = Provider<DeviceEndpointResolver>((ref) {
  return DeviceEndpointResolver(ref.watch(smartHomeRepositoryProvider));
});

/// Per-device configuration repository.
final deviceConfigRepositoryProvider = Provider<DeviceConfigRepository>((ref) {
  final cloud = SupabaseDeviceConfigRepository(ref.watch(supabaseClientProvider));
  final direct = UdpDeviceConfigRepository(
    ref.watch(udpDeviceServiceProvider),
    ref.watch(deviceEndpointResolverProvider),
    ref.watch(supabaseClientProvider),
  );
  return connectionAwareDeviceConfigRepository(
    ref,
    cloud: cloud,
    direct: direct,
  );
});

/// Cloud request channel (button press, matter, OTA, password).
final deviceRequestRepositoryProvider = Provider<DeviceRequestRepository>((ref) {
  final cloudInner =
      SupabaseDeviceRequestRepository(ref.watch(supabaseClientProvider));
  final direct = UdpDeviceRequestRepository(
    ref.watch(udpDeviceServiceProvider),
    ref.watch(deviceEndpointResolverProvider),
  );
  final inner = connectionAwareDeviceRequestRepository(
    ref,
    cloud: cloudInner,
    direct: direct,
  );
  return ActivityTrackingDeviceRequestRepository(
    inner,
    (deviceId) => _recordDeviceActivity(ref, deviceId),
  );
});

/// Control Panel parameters (cp_parameters).
final cpSettingsRepositoryProvider = Provider<CpSettingsRepository>((ref) {
  final cloud = SupabaseCpSettingsRepository(ref.watch(supabaseClientProvider));
  final direct = UdpCpSettingsRepository(
    ref.watch(udpDeviceServiceProvider),
    ref.watch(deviceEndpointResolverProvider),
    cloud,
  );
  return connectionAwareCpSettingsRepository(
    ref,
    cloud: cloud,
    direct: direct,
  );
});

/// Smart LED strips and triggers.
final smartLedRepositoryProvider = Provider<SmartLedRepository>((ref) {
  final cloudInner =
      SupabaseSmartLedRepository(ref.watch(supabaseClientProvider));
  final direct = UdpSmartLedRepository(
    ref.watch(udpDeviceServiceProvider),
    ref.watch(deviceEndpointResolverProvider),
    onLink: (deviceId, online) => _reportDirectLink(ref, deviceId, online),
  );
  final inner = connectionAwareSmartLedRepository(
    ref,
    cloud: cloudInner,
    direct: direct,
  );
  return ActivityTrackingSmartLedRepository(
    inner,
    (deviceId) => _recordDeviceActivity(ref, deviceId),
  );
});

/// Environment Monitoring System climate samples.
final emsSensorRepositoryProvider = Provider<EmsSensorRepository>((ref) {
  final cloud =
      SupabaseEmsSensorRepository(ref.watch(supabaseClientProvider));
  final direct = UdpEmsSensorRepository(
    ref.watch(udpDeviceServiceProvider),
    ref.watch(deviceEndpointResolverProvider),
    onLink: (deviceId, online) => _reportDirectLink(ref, deviceId, online),
  );
  return connectionAwareEmsSensorRepository(
    ref,
    cloud: cloud,
    direct: direct,
  );
});

/// 24-hour EMS history. Supabase in both cloud and direct mode.
final emsHistoryRepositoryProvider = Provider<SupabaseEmsHistoryRepository>((
  ref,
) {
  return SupabaseEmsHistoryRepository(ref.watch(supabaseClientProvider));
});

/// Device sensor data and update status.
final deviceDataRepositoryProvider = Provider<DeviceDataRepository>((ref) {
  return SupabaseDeviceDataRepository(ref.watch(supabaseClientProvider));
});

/// UDP device discovery.
final deviceDiscoveryRepositoryProvider = Provider<DeviceDiscoveryRepository>((ref) {
  return UdpDeviceDiscoveryRepository();
});

/// Searchable location database (bundled CSV asset).
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return CsvLocationRepository();
});
/// Mock overrides for local development without Supabase.
final mockSmartHomeRepositoryProvider = Provider<SmartHomeRepository>((ref) {
  return MockSmartHomeRepository(ref.watch(mockStoreProvider));
});

final mockUserRepositoryProvider = Provider<UserRepository>((ref) {
  return MockUserRepository(ref.watch(mockStoreProvider));
});

final mockAppSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return MockAppSettingsRepository();
});

final mockDeviceConfigRepositoryProvider =
    Provider<DeviceConfigRepository>((ref) {
  return MockDeviceConfigRepository(ref.watch(mockStoreProvider));
});

final mockCpSettingsRepositoryProvider = Provider<CpSettingsRepository>((ref) {
  return MockCpSettingsRepository();
});

final mockSmartLedRepositoryProvider = Provider<SmartLedRepository>((ref) {
  return MockSmartLedRepository();
});

final mockDeviceDataRepositoryProvider = Provider<DeviceDataRepository>((ref) {
  return MockDeviceDataRepository();
});

final mockDeviceDiscoveryRepositoryProvider =
    Provider<DeviceDiscoveryRepository>((ref) {
  return MockDeviceDiscoveryRepository();
});