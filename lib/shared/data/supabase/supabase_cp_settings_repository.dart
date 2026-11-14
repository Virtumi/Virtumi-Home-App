import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_helpers.dart';
import '../../domain/cp_settings_repository.dart';
import '../../models/cp_device_type.dart';
import '../../models/cp_parameter.dart';
import '../../models/cp_parameter_device_option.dart';
import 'mappers/extended_mappers.dart';

class SupabaseCpSettingsRepository implements CpSettingsRepository {
  SupabaseCpSettingsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CpParameter>> getParameters(String deviceId) async {
    final rows = await _client
        .from('cp_parameters')
        .select()
        .eq('device_id', deviceId)
        .order('parameter_index');

    if (rows.isEmpty) return defaultCpParameters();

    final byIndex = {
      for (final row in rows)
        row['parameter_index'] as int: mapCpParameter(row),
    };

    return List.generate(
      10,
      (i) => byIndex[i] ?? CpParameter(parameterIndex: i),
    );
  }

  @override
  Future<List<CpParameter>> getActiveParameters(String deviceId) async {
    final rows = await _client
        .from('cp_parameters')
        .select()
        .eq('device_id', deviceId)
        .eq('active', 1)
        .order('parameter_index');

    return [for (final row in rows) mapCpParameter(row)];
  }

  @override
  Future<int?> nextFreeParameterIndex(String deviceId) async {
    final all = await getParameters(deviceId);
    for (final parameter in all) {
      if (parameter.active != 1) return parameter.parameterIndex;
    }
    return null;
  }

  @override
  Future<void> saveParameter(String deviceId, CpParameter parameter) async {
    final userId = requireUserId(_client);
    await _client.from('cp_parameters').upsert(
      cpParameterPayload(deviceId, userId, parameter),
      onConflict: 'device_id,parameter_index',
    );
  }

  @override
  Future<void> deactivateParameter(
    String deviceId,
    int parameterIndex,
  ) async {
    final userId = requireUserId(_client);
    await _client.from('cp_parameters').upsert(
      {
        'device_id': deviceId,
        'user_id': userId,
        'parameter_index': parameterIndex,
        'active': 0,
      },
      onConflict: 'device_id,parameter_index',
    );
  }

  @override
  Future<List<CpParameterDeviceOption>> getSelectableDevices({
    required String excludeDeviceId,
  }) async {
    // No user_id filter: RLS returns the user's own devices plus devices that
    // other users shared with them.
    requireUserId(_client);

    final rows = await _client.from('devices').select(
          'id, name, devicename, device_code, espnow_mac, ip_address, port, '
          'device_types!inner(name, room_id, '
          'rooms!inner(name, floor_id, '
          'floors!inner(name, home_id, '
          'homes!inner(name, user_id))))',
        );

    final options = <CpParameterDeviceOption>[];

    for (final row in rows) {
      final deviceId = row['id'] as String;
      if (deviceId == excludeDeviceId) continue;

      final typeData = row['device_types'];
      if (typeData is! Map<String, dynamic>) continue;

      final typeName = typeData['name'] as String? ?? '';
      if (typeName.toLowerCase().contains('control panel')) continue;

      final rooms = typeData['rooms'];
      if (rooms is! Map<String, dynamic>) continue;

      final floors = rooms['floors'];
      if (floors is! Map<String, dynamic>) continue;

      final homes = floors['homes'];
      if (homes is! Map<String, dynamic>) continue;

      final homeName = homes['name'] as String? ?? 'Haus';
      final floorName = floors['name'] as String? ?? 'Etage';
      final roomName = rooms['name'] as String? ?? 'Raum';
      final displayName = _deviceDisplayName(row);

      options.add(
        CpParameterDeviceOption(
          deviceId: deviceId,
          name: displayName,
          code: row['device_code'] as String? ?? '',
          espnowMac: row['espnow_mac'] as String? ?? '',
          ipAddress: row['ip_address'] as String? ?? '',
          port: _devicePort(row['port']),
          deviceType: CpDeviceType.fromDeviceTypeName(typeName),
          deviceTypeName: typeName,
          locationPath: '$homeName / $floorName / $roomName',
        ),
      );
    }

    options.sort((a, b) => a.locationPath.compareTo(b.locationPath));
    return options;
  }

  int? _devicePort(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  String _deviceDisplayName(Map<String, dynamic> row) {
    final name = row['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final deviceName = row['devicename'] as String?;
    if (deviceName != null && deviceName.trim().isNotEmpty) {
      return deviceName.trim();
    }
    return 'Gerät';
  }
}
