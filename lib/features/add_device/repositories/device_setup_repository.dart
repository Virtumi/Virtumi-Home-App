import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_helpers.dart';
import '../../../shared/models/models.dart';
import '../models/wizard_found_device.dart';

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
