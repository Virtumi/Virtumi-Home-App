import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType;

import '../../features/rooms/application/room_devices_controller.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/services/local_notification_service.dart';
import '../../core/supabase/realtime_guard.dart';
import '../../core/supabase/realtime_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../application/favorite_devices.dart';
import '../application/recent_device_activity.dart';
import '../application/recent_house_activity.dart';
import '../domain/device_config_repository.dart';
import '../domain/smart_home_repository.dart';
import '../models/models.dart';
import 'repository_providers.dart';

/// Refreshes Home tab lists (houses grid + recent activity).
void refreshHomeScreenData(WidgetRef ref) {
  ref.invalidate(housesProvider);
  ref.invalidate(recentHomesProvider);
  ref.invalidate(recentActivityDevicesProvider);
  ref.invalidate(favoriteDevicesEntriesProvider);
  ref.invalidate(notificationsProvider);
}

/// Invalidates all location-related providers so Home, floors, rooms and
/// device lists refresh after hierarchy changes (e.g. device deletion).
void invalidateLocationHierarchy(WidgetRef ref, {String? deviceId}) {
  ref.invalidate(housesProvider);
  ref.invalidate(floorsProvider);
  ref.invalidate(roomsProvider);
  ref.invalidate(devicesProvider);
  ref.invalidate(houseProvider);
  ref.invalidate(floorProvider);
  ref.invalidate(roomProvider);
  ref.invalidate(roomDevicesControllerProvider);
  ref.invalidate(shareableTargetsProvider);
  ref.invalidate(ownedLocationIdsProvider);
  ref.invalidate(recentActivityDevicesProvider);
  ref.invalidate(favoriteDevicesEntriesProvider);
  if (deviceId != null) {
    ref.invalidate(deviceProvider(deviceId));
  }
}

/// Shares the current user granted to other users.
final mySharesProvider = FutureProvider<List<DeviceShare>>((ref) {
  return ref.watch(sharingRepositoryProvider).listMyShares();
});

/// Shares other users granted to the current user.
final sharedWithMeProvider = FutureProvider<List<DeviceShare>>((ref) {
  return ref.watch(sharingRepositoryProvider).listSharedWithMe();
});

/// Notification inbox of the signed-in user (bell icon on the Home screen).
///
/// Refreshes itself when Supabase Realtime reports a change of the user's own
/// `app_notifications` rows. The unread counter is NOT a derived provider on
/// purpose: widgets select it directly (see [unreadNotificationCount]) so a
/// burst of events can never rebuild a derived provider twice in one frame.
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const <AppNotification>[];

  if (useSupabaseRealtimeRef(ref)) {
    final localNotifications = ref.read(localNotificationServiceProvider);
    unawaited(localNotifications.ensureInitialized());

    final channel = client
        .channel('app-notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (!ref.mounted) return;
            if (payload.eventType == PostgresChangeEvent.insert) {
              final row = payload.newRecord;
              unawaited(
                localNotifications.showInboxEntry(
                  type: AppNotificationType.fromDb(row['type'] as String?),
                  deviceName: (row['device_name'] as String?) ?? 'ein Gerät',
                  notificationId: row['id'] as String?,
                ),
              );
            }
            ref.invalidateSelf();
          },
        )
        .subscribe();
    ref.onDispose(() => client.removeChannel(channel));
  }

  return ref.watch(deviceAccessRepositoryProvider).listNotifications();
});

/// Number of unread notifications in [notifications] (0 while loading).
int unreadNotificationCount(AsyncValue<List<AppNotification>> notifications) {
  return notifications.maybeWhen(
    data: (items) => items.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
}

/// A single access request (owner decision page).
final deviceAccessRequestProvider =
    FutureProvider.family<DeviceAccessRequest?, String>((ref, requestId) {
  return ref.watch(deviceAccessRepositoryProvider).getRequest(requestId);
});

/// Own houses/floors/rooms/devices that can be shared.
final shareableTargetsProvider = FutureProvider<List<ShareTarget>>((ref) {
  return ref.watch(sharingRepositoryProvider).listShareableTargets();
});

/// Ids of all houses, floors, rooms and devices the current user owns.
final ownedLocationIdsProvider = FutureProvider<Set<String>>((ref) async {
  final targets = await ref.watch(shareableTargetsProvider.future);
  final ids = <String>{};
  void walk(ShareTarget node) {
    ids.add(node.id);
    node.children.forEach(walk);
  }

  targets.forEach(walk);
  return ids;
});

/// Whether the current user owns the house/floor/room [id] (and may therefore
/// rename, re-icon or restructure it). False while unknown.
final isLocationOwnerProvider = Provider.family<bool, String>((ref, id) {
  if (id.startsWith('syn:')) return true;
  return ref.watch(ownedLocationIdsProvider).maybeWhen(
        data: (ids) => ids.contains(id),
        orElse: () => false,
      );
});

/// Whether the current user is the original owner of the device [deviceId]
/// (may delete it). False while the device is loading.
final isDeviceOwnerProvider = Provider.family<bool, String>((ref, deviceId) {
  final device = ref.watch(deviceProvider(deviceId)).value;
  if (device == null) return false;
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  return device.isOwnedBy(userId);
});

/// All houses for the current account.
final housesProvider = FutureProvider<List<House>>((ref) {
  return ref.watch(smartHomeRepositoryProvider).getHouses();
});

/// Houses for the Home tab grid. Recently opened homes come first, then every
/// other home of the account so none are hidden behind the "Alle" page.
final recentHomesProvider = FutureProvider<List<House>>((ref) async {
  final allHouses = await ref.watch(housesProvider.future);
  if (allHouses.isEmpty) return const [];

  final ids = ref.watch(recentHouseActivityProvider);
  final byId = {for (final house in allHouses) house.id: house};

  final ordered = <House>[];
  final seen = <String>{};
  final validIds = <String>[];
  for (final id in ids) {
    final house = byId[id];
    if (house != null && seen.add(house.id)) {
      ordered.add(house);
      validIds.add(id);
    }
  }

  if (validIds.length != ids.length) {
    await ref.read(recentHouseActivityProvider.notifier).syncStored(validIds);
  }

  for (final house in allHouses) {
    if (seen.add(house.id)) ordered.add(house);
  }

  return ordered;
});

/// A single house by id.
final houseProvider = FutureProvider.family<House?, String>((ref, id) {
  return ref.watch(smartHomeRepositoryProvider).getHouse(id);
});

/// Floors within a house.
final floorsProvider = FutureProvider.family<List<Floor>, String>((ref, houseId) {
  return ref.watch(smartHomeRepositoryProvider).getFloors(houseId);
});

/// A single floor by id.
final floorProvider = FutureProvider.family<Floor?, String>((ref, id) {
  return ref.watch(smartHomeRepositoryProvider).getFloor(id);
});

/// Rooms within a floor.
final roomsProvider = FutureProvider.family<List<Room>, String>((ref, floorId) {
  return ref.watch(smartHomeRepositoryProvider).getRooms(floorId);
});

/// A single room by id.
final roomProvider = FutureProvider.family<Room?, String>((ref, id) {
  return ref.watch(smartHomeRepositoryProvider).getRoom(id);
});

/// Devices within a room.
final devicesProvider =
    FutureProvider.family<List<Device>, String>((ref, roomId) async {
  final devices =
      await ref.watch(smartHomeRepositoryProvider).getDevices(roomId);
  final resolver = ref.read(deviceEndpointResolverProvider);
  for (final device in devices) {
    resolver.cacheFromDevice(device);
  }
  return devices;
});

/// A single device by id.
final deviceProvider = FutureProvider.family<Device?, String>((ref, id) async {
  final device = await ref.watch(smartHomeRepositoryProvider).getDevice(id);
  if (device != null) {
    ref.read(deviceEndpointResolverProvider).cacheFromDevice(device);
  }
  return device;
});

/// Live device info from UDP protocol 1 (direct mode only).
final deviceUdpLiveInfoProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, deviceId) async {
  if (ref.watch(appSettingsProvider).value?.connectionMode != 'direct') {
    return null;
  }
  final device = await ref.watch(deviceProvider(deviceId).future);
  final resolver = ref.watch(deviceEndpointResolverProvider);
  if (device != null) resolver.cacheFromDevice(device);
  final udp = ref.watch(udpDeviceServiceProvider);
  final ep = await resolver.resolve(deviceId);
  return udp.readDeviceInfo(
    targetIp: ep.ipAddress,
    port: ep.port,
    deviceCode: ep.deviceCode,
  );
});

/// The current signed-in user.
final currentUserProvider = FutureProvider<User>((ref) {
  return ref.watch(userRepositoryProvider).getCurrentUser();
});

/// App settings for the signed-in user.
final appSettingsProvider = FutureProvider<AppSettings?>((ref) async {
  // Not watched on purpose: [AppSettingsBootstrap] invalidates this provider
  // when the signed-in user changes (watching would rebuild it mid-build).
  final userId = ref.read(authUserIdProvider);
  if (userId == null) return null;
  return ref.watch(appSettingsRepositoryProvider).getSettings(userId);
});

// --- Per-device configuration sections ---

final networkConfigProvider =
    FutureProvider.family<NetworkConfig, String>((ref, deviceId) {
  return ref.watch(deviceConfigRepositoryProvider).getNetworkConfig(deviceId);
});

final cloudConfigProvider =
    FutureProvider.family<CloudConfig, String>((ref, deviceId) {
  return ref.watch(deviceConfigRepositoryProvider).getCloudConfig(deviceId);
});

final dateTimeConfigProvider =
    FutureProvider.family<DateTimeConfig, String>((ref, deviceId) {
  return ref.watch(deviceConfigRepositoryProvider).getDateTimeConfig(deviceId);
});

final matterConfigProvider =
    FutureProvider.family<MatterConfig, String>((ref, deviceId) {
  return ref.watch(deviceConfigRepositoryProvider).getMatterConfig(deviceId);
});

final deviceLocationProvider =
    FutureProvider.family<DeviceLocation, String>((ref, deviceId) {
  return ref.watch(deviceConfigRepositoryProvider).getDeviceLocation(deviceId);
});

final updateConfigProvider =
    FutureProvider.family<UpdateConfig, String>((ref, deviceId) {
  return ref.watch(deviceConfigRepositoryProvider).getUpdateConfig(deviceId);
});

final generalConfigProvider =
    FutureProvider.family<GeneralConfig, String>((ref, deviceId) {
  return ref.watch(deviceConfigRepositoryProvider).getGeneralConfig(deviceId);
});

/// Current EMS climate sample. Cloud mode also listens to `ems_sensordata`.
final emsSensorProvider =
    FutureProvider.family<EmsSensorReading?, String>((ref, deviceId) {
  if (useSupabaseRealtimeRef(ref)) {
    final service = RealtimeService(ref.watch(supabaseClientProvider));
    service.subscribeToDeviceTable(
      deviceId: deviceId,
      table: 'ems_sensordata',
      onChange: () {
        if (ref.mounted) ref.invalidateSelf();
      },
    );
    ref.onDispose(service.unsubscribeAll);
  }
  return ref.watch(emsSensorRepositoryProvider).getReading(deviceId);
});

/// Last 24 hours from `ems_sensordata_history`, independent of connection mode.
final emsSensorHistoryProvider =
    FutureProvider.family<List<EmsHistoryPoint>, String>((ref, deviceId) {
  return ref.watch(emsHistoryRepositoryProvider).getLast24Hours(deviceId);
});

/// One chosen window from `ems_sensordata_history`, independent of connection mode.
final emsSensorHistoryRangeProvider =
    FutureProvider.family<EmsHistoryRange, EmsHistoryQuery>((ref, query) {
  return ref.watch(emsHistoryRepositoryProvider).getRange(
        query.deviceId,
        start: query.start,
        end: query.end,
      );
});

final cpParametersProvider =
    FutureProvider.family<List<CpParameter>, String>((ref, deviceId) {
  return ref.watch(cpSettingsRepositoryProvider).getParameters(deviceId);
});

final cpActiveParametersProvider =
    FutureProvider.family<List<CpParameter>, String>((ref, deviceId) {
  return ref.watch(cpSettingsRepositoryProvider).getActiveParameters(deviceId);
});

final cpSelectableDevicesProvider =
    FutureProvider.family<List<CpParameterDeviceOption>, String>(
        (ref, excludeDeviceId) {
  return ref
      .watch(cpSettingsRepositoryProvider)
      .getSelectableDevices(excludeDeviceId: excludeDeviceId);
});

final smartLedStripsProvider =
    FutureProvider.family<List<SmartLedStrip>, String>((ref, deviceId) {
  return ref.watch(smartLedRepositoryProvider).getStrips(deviceId);
});

final smartLedTriggersProvider =
    FutureProvider.family<List<SmartLedTrigger>, String>((ref, deviceId) {
  return ref.watch(smartLedRepositoryProvider).getTriggers(deviceId);
});

final smartLedActiveTriggersProvider =
    FutureProvider.family<List<SmartLedTrigger>, String>((ref, deviceId) {
  return ref.watch(smartLedRepositoryProvider).getActiveTriggers(deviceId);
});

final deviceDataProvider =
    FutureProvider.family<List<DeviceDataEntry>, String>((ref, deviceId) {
  return ref.watch(deviceDataRepositoryProvider).getDeviceData(deviceId);
});

final deviceUpdateStatusProvider =
    FutureProvider.family<DeviceUpdateStatus, String>((ref, deviceId) {
  return ref.watch(deviceDataRepositoryProvider).getUpdateStatus(deviceId);
});

/// Location search results for the given query.
final locationSearchProvider =
    FutureProvider.family<List<Location>, String>((ref, query) {
  return ref.watch(locationRepositoryProvider).search(query);
});

/// Recently controlled devices for the Home activity section.
final recentActivityDevicesProvider =
    FutureProvider<List<RecentActivityEntry>>((ref) async {
  final ids = ref.watch(recentDeviceActivityProvider);
  if (ids.isEmpty) return const [];

  final repo = ref.read(smartHomeRepositoryProvider);
  final configRepo = ref.read(deviceConfigRepositoryProvider);
  final devices = <RecentActivityEntry>[];
  final validIds = <String>[];

  for (final id in ids) {
    final device = await repo.getDevice(id);
    if (device != null) {
      final locationPath = await _deviceLocationPath(
        repo: repo,
        configRepo: configRepo,
        device: device,
      );
      devices.add(RecentActivityEntry(
        device: device,
        locationPath: locationPath,
      ));
      validIds.add(id);
    }
  }

  if (validIds.length != ids.length) {
    await ref.read(recentDeviceActivityProvider.notifier).syncStored(validIds);
  }

  return devices;
});

/// Favorite devices for the Home section, newest mark first.
final favoriteDevicesEntriesProvider =
    FutureProvider<List<RecentActivityEntry>>((ref) async {
  final ids = ref.watch(favoriteDevicesProvider);
  if (ids.isEmpty) return const [];

  final repo = ref.read(smartHomeRepositoryProvider);
  final configRepo = ref.read(deviceConfigRepositoryProvider);
  final devices = <RecentActivityEntry>[];
  final validIds = <String>[];

  for (final id in ids) {
    final device = await repo.getDevice(id);
    if (device != null) {
      final locationPath = await _deviceLocationPath(
        repo: repo,
        configRepo: configRepo,
        device: device,
      );
      devices.add(RecentActivityEntry(
        device: device,
        locationPath: locationPath,
      ));
      validIds.add(id);
    }
  }

  if (validIds.length != ids.length) {
    await ref.read(favoriteDevicesProvider.notifier).syncStored(validIds);
  }

  return devices;
});

@immutable
class RecentActivityEntry {
  const RecentActivityEntry({
    required this.device,
    required this.locationPath,
  });

  final Device device;
  final String locationPath;
}

Future<String> _deviceLocationPath({
  required SmartHomeRepository repo,
  required DeviceConfigRepository configRepo,
  required Device device,
}) async {
  final location = await configRepo.getDeviceLocation(device.id);
  final fromSettings = _joinLocationPath([
    location.houseName,
    location.floorName,
    location.roomName,
  ]);
  if (fromSettings.isNotEmpty) return fromSettings;

  final room = await repo.getRoom(device.roomId);
  if (room == null) return '';

  final floor = await repo.getFloor(room.floorId);
  if (floor == null) return room.name;

  final house = await repo.getHouse(floor.houseId);
  return _joinLocationPath([
    house?.name ?? '',
    floor.name,
    room.name,
  ]);
}

String _joinLocationPath(List<String> parts) {
  return parts
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(r'\');
}
