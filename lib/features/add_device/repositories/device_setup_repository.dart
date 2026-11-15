import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_helpers.dart';
import '../../../shared/models/models.dart';
import '../models/existing_device_change.dart';
import '../models/wizard_found_device.dart';

/// Connection and place data of a device as stored in Supabase.
class StoredDeviceData {
  const StoredDeviceData({
    required this.ipAddress,
    required this.place,
    this.port,
  });

  final String ipAddress;
  final int? port;
  final DevicePlace place;
}

class DeviceSetupRepository {
  DeviceSetupRepository(this._client);

  final SupabaseClient _client;

  Future<String> saveUdpDevice({
    required String deviceCode,
    required WizardFoundDevice selectedDevice,
    required DeviceLocation deviceLocation,
    required String connectionMode,
  }) async {
    final userId = requireUserId(_client);

    final loc = deviceLocation.copyWith(
      deviceName: deviceLocation.deviceName.trim().isNotEmpty
          ? deviceLocation.deviceName.trim()
          : selectedDevice.devicename,
      houseName: deviceLocation.houseName.trim().isNotEmpty
          ? deviceLocation.houseName.trim()
          : (selectedDevice.home.isNotEmpty
                ? selectedDevice.home
                : 'Unbekannt'),
      floorName: deviceLocation.floorName.trim().isNotEmpty
          ? deviceLocation.floorName.trim()
          : (selectedDevice.floor.isNotEmpty
                ? selectedDevice.floor
                : 'Unbekannt'),
      roomName: deviceLocation.roomName.trim().isNotEmpty
          ? deviceLocation.roomName.trim()
          : (selectedDevice.room.isNotEmpty
                ? selectedDevice.room
                : 'Unbekannt'),
    );

    final hostTrim = selectedDevice.hostname.trim();
    final typeTrim = selectedDevice.devicetype.trim();
    final isEms = isEmsTypeName(typeTrim);
    final dnTrim = selectedDevice.devicename.trim();
    final storedName = isEms ? emsStoredName : loc.deviceName;

    final descriptionParts = connectionMode == 'direct'
        ? [
            dnTrim,
            typeTrim,
            selectedDevice.ipAddress,
          ].where((e) => e.isNotEmpty)
        : [
            dnTrim,
            typeTrim,
            hostTrim.isNotEmpty ? hostTrim : selectedDevice.ipAddress,
          ].where((e) => e.isNotEmpty);

    final inserted = await _client
        .from('devices')
        .insert({
          'user_id': userId,
          'name': storedName,
          'devicename': storedName,
          'hostname': hostTrim.isNotEmpty ? hostTrim : null,
          'ip_address': selectedDevice.ipAddress.isNotEmpty
              ? selectedDevice.ipAddress
              : null,
          'port': selectedDevice.port,
          'mac_address': selectedDevice.macAddress.isNotEmpty
              ? selectedDevice.macAddress
              : null,
          'device_code': deviceCode,
          'current_version': _nullIfEmpty(selectedDevice.currentVersion),
          'serial_number': _nullIfEmpty(selectedDevice.serialNumber),
          'device_type_id': null,
          'description': descriptionParts.isEmpty
              ? 'UDP-Gerät'
              : 'UDP-Gerät: ${descriptionParts.join(' · ')}',
          'status': 'online',
          'last_seen': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    final deviceId = inserted['id'] as String;

    try {
      final homeId = await _findOrCreateHome(userId, loc.houseName, dnTrim);
      final floorId = await _findOrCreateFloor(homeId, loc.floorName, dnTrim);
      final roomId = await _findOrCreateRoom(floorId, loc.roomName, dnTrim);

      final deviceTypeName = isEms
          ? emsStoredName
          : (typeTrim.isNotEmpty ? typeTrim : 'Control Panel');

      final deviceType = await _client
          .from('device_types')
          .insert({
            'name': deviceTypeName,
            'description':
                'Device Type: $deviceTypeName${dnTrim.isNotEmpty ? ' · $dnTrim' : ''}${hostTrim.isNotEmpty ? ' · $hostTrim' : ''} in ${loc.roomName}',
            'icon': 'device',
            'category': 'smart_device',
            'room_id': roomId,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select('id')
          .single();

      await _client
          .from('devices')
          .update({'device_type_id': deviceType['id']})
          .eq('id', deviceId);

      final dlsPayload = {
        'device_id': deviceId,
        'user_id': userId,
        'name': storedName,
        'home': loc.houseName,
        'floor': loc.floorName,
        'room': loc.roomName,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final existingDls = await _client
          .from('device_location_settings')
          .select('id')
          .eq('device_id', deviceId)
          .maybeSingle();

      if (existingDls != null) {
        await _client
            .from('device_location_settings')
            .update(dlsPayload)
            .eq('device_id', deviceId);
      } else {
        await _client.from('device_location_settings').insert(dlsPayload);
      }

      await _client
          .from('devices')
          .update({
            'name': storedName,
            'devicename': storedName,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', deviceId);
    } catch (e) {
      // Device row exists even if hierarchy fails — log but don't block.
    }

    return deviceId;
  }

  /// IP, port and place currently stored in Supabase for an own device.
  Future<StoredDeviceData> loadOwnDeviceSnapshot(String deviceId) async {
    final row = await _client
        .from('devices')
        .select(
          'ip_address, port, '
          'device_types(rooms(name, floors(name, homes(name))))',
        )
        .eq('id', deviceId)
        .maybeSingle();

    var place = const DevicePlace();
    final types = row?['device_types'];
    final type = types is Map ? types : (types is List && types.isNotEmpty ? types.first : null);
    final rooms = type is Map ? type['rooms'] : null;
    if (rooms is Map) {
      final floors = rooms['floors'];
      final homes = floors is Map ? floors['homes'] : null;
      place = DevicePlace(
        home: homes is Map ? (homes['name'] as String? ?? '') : '',
        floor: floors is Map ? (floors['name'] as String? ?? '') : '',
        room: rooms['name'] as String? ?? '',
      );
    }

    if (place.isEmpty) {
      final dls = await _client
          .from('device_location_settings')
          .select('home, floor, room')
          .eq('device_id', deviceId)
          .maybeSingle();
      if (dls != null) {
        place = DevicePlace(
          home: dls['home'] as String? ?? '',
          floor: dls['floor'] as String? ?? '',
          room: dls['room'] as String? ?? '',
        );
      }
    }

    return StoredDeviceData(
      ipAddress: (row?['ip_address'] as String?) ?? '',
      port: int.tryParse('${row?['port'] ?? ''}'),
      place: place,
    );
  }

  /// Writes the accepted changes of an already known device to Supabase.
  Future<void> applyExistingDeviceChange(
    ExistingDeviceChange change, {
    required bool updateIp,
    required bool updateLocation,
    String deviceTypeName = 'Control Panel',
  }) async {
    final userId = requireUserId(_client);
    final now = DateTime.now().toUtc().toIso8601String();
    final deviceId = change.deviceId;

    if (updateIp && change.foundIp.trim().isNotEmpty) {
      await _client.from('devices').update({
        'ip_address': change.foundIp.trim(),
        if (change.foundPort != null) 'port': change.foundPort,
        'updated_at': now,
      }).eq('id', deviceId);
    }

    if (updateLocation && !change.foundPlace.isEmpty) {
      final place = change.foundPlace;
      final home = place.home.trim().isNotEmpty ? place.home.trim() : change.storedPlace.home;
      final floor = place.floor.trim().isNotEmpty ? place.floor.trim() : change.storedPlace.floor;
      final room = place.room.trim().isNotEmpty ? place.room.trim() : change.storedPlace.room;

      final homeId = await _findOrCreateHome(userId, home, change.deviceName);
      final floorId = await _findOrCreateFloor(homeId, floor, change.deviceName);
      final roomId = await _findOrCreateRoom(floorId, room, change.deviceName);

      final device = await _client
          .from('devices')
          .select('device_type_id')
          .eq('id', deviceId)
          .maybeSingle();
      final typeId = device?['device_type_id'] as String?;

      if (typeId != null) {
        await _client
            .from('device_types')
            .update({'room_id': roomId, 'updated_at': now})
            .eq('id', typeId);
      } else {
        final created = await _client
            .from('device_types')
            .insert({
              'name': deviceTypeName,
              'description': 'Device Type: $deviceTypeName in $room',
              'icon': 'device',
              'category': 'smart_device',
              'room_id': roomId,
              'created_at': now,
              'updated_at': now,
            })
            .select('id')
            .single();
        await _client
            .from('devices')
            .update({'device_type_id': created['id'], 'updated_at': now})
            .eq('id', deviceId);
      }

      await _client.from('device_location_settings').upsert({
        'device_id': deviceId,
        'user_id': userId,
        'name': change.deviceName,
        'home': home,
        'floor': floor,
        'room': room,
        'updated_at': now,
      }, onConflict: 'device_id');
    }
  }

  Future<String> _findOrCreateHome(
    String userId,
    String homeName,
    String deviceName,
  ) async {
    final existing = await _client
        .from('homes')
        .select('id')
        .eq('name', homeName)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final inserted = await _client
        .from('homes')
        .insert({
          'user_id': userId,
          'name': homeName,
          'description': 'Home für $deviceName',
          'address': null,
        })
        .select('id')
        .single();

    return inserted['id'] as String;
  }

  Future<String> _findOrCreateFloor(
    String homeId,
    String floorName,
    String deviceName,
  ) async {
    final existing = await _client
        .from('floors')
        .select('id')
        .eq('name', floorName)
        .eq('home_id', homeId)
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final inserted = await _client
        .from('floors')
        .insert({
          'home_id': homeId,
          'name': floorName,
          'description': 'Floor für $deviceName',
          'floor_number': 1,
        })
        .select('id')
        .single();

    return inserted['id'] as String;
  }

  Future<String> _findOrCreateRoom(
    String floorId,
    String roomName,
    String deviceName,
  ) async {
    final existing = await _client
        .from('rooms')
        .select('id')
        .eq('name', roomName)
        .eq('floor_id', floorId)
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final inserted = await _client
        .from('rooms')
        .insert({
          'floor_id': floorId,
          'name': roomName,
          'description': 'Room für $deviceName',
          'room_type': 'General',
        })
        .select('id')
        .single();

    return inserted['id'] as String;
  }
}

String? _nullIfEmpty(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
