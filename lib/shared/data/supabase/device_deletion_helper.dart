import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase tables keyed by [device_id] that must be removed before deleting
/// the device row itself.
const deviceIdTables = [
  'cp_parameters',
  'device_mqtt_settings',
  'device_location_settings',
  'cp_general_settings',
  'ems_general_settings',
  'ems_sensordata',
  'device_datetime_settings',
  'device_network_settings',
  'device_softap_details',
  'device_station_details',
  'device_data',
  'device_softap_settings',
  'device_station_settings',
  'device_virtumi_cloud_settings',
  'matter_settings',
  'update_settings',
  'smart_led_general_settings',
  'smart_led_settings',
  'smart_led_triggers',
  'device_update_status',
  'device_secret',
  'cp_btn_requests',
  'matter_requests',
  'update_requests',
];

class DeviceHierarchyIds {
  const DeviceHierarchyIds({
    this.deviceTypeId,
    this.roomId,
    this.floorId,
    this.homeId,
  });

  final String? deviceTypeId;
  final String? roomId;
  final String? floorId;
  final String? homeId;
}

DeviceHierarchyIds parseDeviceHierarchy(Map<String, dynamic> row) {
  final deviceTypeId = row['device_type_id'] as String?;
  final types = row['device_types'];
  if (types is! Map<String, dynamic>) {
    return DeviceHierarchyIds(deviceTypeId: deviceTypeId);
  }

  final roomId = types['room_id'] as String?;
  final rooms = types['rooms'];
  if (rooms is! Map<String, dynamic>) {
    return DeviceHierarchyIds(
      deviceTypeId: deviceTypeId ?? types['id'] as String?,
      roomId: roomId,
    );
  }

  final floorId = rooms['floor_id'] as String?;
  final floors = rooms['floors'];
  if (floors is! Map<String, dynamic>) {
    return DeviceHierarchyIds(
      deviceTypeId: deviceTypeId ?? types['id'] as String?,
      roomId: roomId ?? rooms['id'] as String?,
      floorId: floorId,
    );
  }

  return DeviceHierarchyIds(
    deviceTypeId: deviceTypeId ?? types['id'] as String?,
    roomId: roomId ?? rooms['id'] as String?,
    floorId: floorId ?? floors['id'] as String?,
    homeId: floors['home_id'] as String?,
  );
}

Future<void> deleteDeviceRelatedRows(
  SupabaseClient client,
  String deviceId,
) async {
  await Future.wait([
    for (final table in deviceIdTables)
      _deleteFromTable(client, table, deviceId),
  ]);
}

Future<void> deleteLivecomRows(
  SupabaseClient client, {
  String? deviceCode,
  String? macAddress,
}) async {
  final filters = <String>[];
  if (deviceCode != null && deviceCode.isNotEmpty) {
    filters.add('device_id.eq.$deviceCode');
  }
  if (macAddress != null && macAddress.isNotEmpty) {
    filters.add('mac_address.eq.$macAddress');
  }
  if (filters.isEmpty) return;

  try {
    await client.from('livecom').delete().or(filters.join(','));
  } catch (e, st) {
    developer.log('livecom delete failed: $e', stackTrace: st);
  }
}

Future<void> cleanupDeviceHierarchy(
  SupabaseClient client,
  DeviceHierarchyIds ids,
) async {
  if (ids.deviceTypeId == null) return;

  try {
    final devicesInType = await client
        .from('devices')
        .select('id')
        .eq('device_type_id', ids.deviceTypeId!);

    if ((devicesInType as List).isNotEmpty) return;

    await client.from('device_types').delete().eq('id', ids.deviceTypeId!);

    final roomId = ids.roomId;
    if (roomId == null) return;

    final typesInRoom = await client
        .from('device_types')
        .select('id')
        .eq('room_id', roomId);

    if ((typesInRoom as List).isNotEmpty) return;

    await client.from('rooms').delete().eq('id', roomId);

    final floorId = ids.floorId;
    if (floorId == null) return;

    final roomsInFloor = await client
        .from('rooms')
        .select('id')
        .eq('floor_id', floorId);

    if ((roomsInFloor as List).isNotEmpty) return;

    await client.from('floors').delete().eq('id', floorId);

    final homeId = ids.homeId;
    if (homeId == null) return;

    final floorsInHome = await client
        .from('floors')
        .select('id')
        .eq('home_id', homeId);

    if ((floorsInHome as List).isNotEmpty) return;

    await client.from('homes').delete().eq('id', homeId);
  } catch (e, st) {
    developer.log('Hierarchy cleanup failed: $e', stackTrace: st);
  }
}

Future<void> _deleteFromTable(
  SupabaseClient client,
  String table,
  String deviceId,
) async {
  try {
    await client.from(table).delete().eq('device_id', deviceId);
  } catch (e, st) {
    developer.log('$table delete failed: $e', stackTrace: st);
  }
}

bool nestedRowHasDevices(dynamic deviceTypes) {
  if (deviceTypes is! List) return false;
  for (final type in deviceTypes) {
    if (type is! Map) continue;
    final devices = type['devices'];
    if (devices is List && devices.isNotEmpty) return true;
  }
  return false;
}

bool roomRowHasDevices(Map<String, dynamic> row) =>
    nestedRowHasDevices(row['device_types']);

bool floorRowHasDevices(Map<String, dynamic> row) {
  final rooms = row['rooms'];
  if (rooms is! List) return false;
  for (final room in rooms) {
    if (room is Map<String, dynamic> && roomRowHasDevices(room)) return true;
  }
  return false;
}

bool houseRowHasDevices(Map<String, dynamic> row) {
  final floors = row['floors'];
  if (floors is! List) return false;
  for (final floor in floors) {
    if (floor is Map<String, dynamic> && floorRowHasDevices(floor)) return true;
  }
  return false;
}
