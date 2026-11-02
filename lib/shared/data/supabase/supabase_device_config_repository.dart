import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_helpers.dart';
import '../../domain/device_config_repository.dart';
import '../../models/models.dart';
import 'mappers/config_mappers.dart';
import 'mappers/device_mapper.dart';
import 'mappers/network_config_mapper.dart';

class SupabaseDeviceConfigRepository implements DeviceConfigRepository {
  SupabaseDeviceConfigRepository(this._client);

  final SupabaseClient _client;

  Future<String?> _deviceTypeName(String deviceId) async {
    final row = await _client
        .from('devices')
        .select('device_types(name)')
        .eq('id', deviceId)
        .maybeSingle();

    if (row == null) return null;
    final types = row['device_types'];
    if (types is! Map<String, dynamic>) return null;
    return types['name'] as String?;
  }

  Future<String> _generalSettingsTable(String deviceId) async {
    final typeName = await _deviceTypeName(deviceId);
    if (isSmartLedTypeName(typeName)) return 'smart_led_general_settings';
    if (isEmsTypeName(typeName)) return 'ems_general_settings';
    return 'cp_general_settings';
  }

  Future<Map<String, dynamic>?> _row(
    String table,
    String deviceId,
  ) async {
    return _client
        .from(table)
        .select()
        .eq('device_id', deviceId)
        .maybeSingle();
  }

  Future<void> _upsert(String table, Map<String, dynamic> payload) async {
    await _client.from(table).upsert(payload, onConflict: 'device_id');
  }

  @override
  Future<NetworkConfig> getNetworkConfig(String deviceId) async {
    final network = await _row('device_network_settings', deviceId);
    final softAp = await _row('device_softap_settings', deviceId);
    final softApDetails = await _row('device_softap_details', deviceId);
    final station = await _row('device_station_settings', deviceId);
    final stationDetails = await _row('device_station_details', deviceId);

    return mapNetworkConfig(
      network: network,
      softAp: softAp,
      softApDetails: softApDetails,
      station: station,
      stationDetails: stationDetails,
    );
  }

  @override
  Future<void> saveNetworkConfig(String deviceId, NetworkConfig config) async {
    final userId = requireUserId(_client);
    await _upsert(
      'device_network_settings',
      networkSettingsPayload(deviceId, userId, config),
    );
    await _upsert(
      'device_softap_settings',
      softApSettingsPayload(deviceId, userId, config),
    );
    await _upsert(
      'device_softap_details',
      softApDetailsPayload(deviceId, userId, config),
    );
    await _upsert(
      'device_station_settings',
      stationSettingsPayload(deviceId, userId, config),
    );
    await _upsert(
      'device_station_details',
      stationDetailsPayload(deviceId, userId, config),
    );
  }

  @override
  Future<CloudConfig> getCloudConfig(String deviceId) async {
    final virtumi = await _row('device_virtumi_cloud_settings', deviceId);
    final mqttRows = await _client
        .from('device_mqtt_settings')
        .select()
        .eq('device_id', deviceId)
        .limit(1);
    final mqtt = mqttRows.isNotEmpty ? mqttRows.first : null;

    return mapCloudConfig(virtumi: virtumi, mqtt: mqtt);
  }

  @override
  Future<void> saveMqttCloud(String deviceId, MqttCloudConfig config) async {
    final userId = requireUserId(_client);
    final mqttPayload = mqttCloudPayload(deviceId, userId, config);
    final existing = await _client
        .from('device_mqtt_settings')
        .select('id')
        .eq('device_id', deviceId)
        .maybeSingle();

    if (existing == null) {
      await _client.from('device_mqtt_settings').insert(mqttPayload);
    } else {
      await _client
          .from('device_mqtt_settings')
          .update(mqttPayload)
          .eq('device_id', deviceId);
    }
  }

  @override
  Future<void> saveVirtumiCloud(
    String deviceId,
    VirtumiCloudConfig config,
  ) async {
    final userId = requireUserId(_client);
    await _upsert(
      'device_virtumi_cloud_settings',
      virtumiCloudPayload(deviceId, userId, config),
    );
  }

  @override
  Future<void> resendVirtumiCloud(
    String deviceId,
    VirtumiCloudConfig config,
  ) =>
      saveVirtumiCloud(deviceId, config);

  @override
  Future<DateTimeConfig> getDateTimeConfig(String deviceId) async {
    final row = await _row('device_datetime_settings', deviceId);
    return mapDateTimeConfig(row);
  }

  @override
  Future<void> saveDateTimeConfig(
    String deviceId,
    DateTimeConfig config,
  ) async {
    final userId = requireUserId(_client);
    await _upsert(
      'device_datetime_settings',
      dateTimePayload(deviceId, userId, config),
    );
  }

  @override
  Future<MatterConfig> getMatterConfig(String deviceId) async {
    final row = await _row('matter_settings', deviceId);
    return mapMatterConfig(row);
  }

  @override
  Future<void> saveMatterConfig(String deviceId, MatterConfig config) async {
    final userId = requireUserId(_client);
    final existing = await _row('matter_settings', deviceId);
    if (existing == null) {
      await _client.from('matter_settings').insert({
        ...matterPayload(deviceId, userId, config),
        'is_commissioned': config.paired,
        'setup_passcode': config.setupCode,
        'qr_code': config.qrPayload,
      });
    } else {
      await _client
          .from('matter_settings')
          .update(matterPayload(deviceId, userId, config))
          .eq('device_id', deviceId);
    }
  }

  @override
  Future<DeviceLocation> getDeviceLocation(String deviceId) async {
    final rows = await _client
        .from('device_location_settings')
        .select()
        .eq('device_id', deviceId)
        .limit(1);
    final row = rows.isNotEmpty ? rows.first : null;
    return mapDeviceLocation(row);
  }

  @override
  Future<void> saveDeviceLocation(
    String deviceId,
    DeviceLocation location,
  ) async {
    final userId = requireUserId(_client);
    final stored = isEmsTypeName(await _deviceTypeName(deviceId))
        ? location.copyWith(deviceName: emsStoredName)
        : location;
    await _client.from('device_location_settings').upsert(
      deviceLocationPayload(deviceId, userId, stored),
    );
  }

  @override
  Future<UpdateConfig> getUpdateConfig(String deviceId) async {
    final settingsRows = await _client
        .from('update_settings')
        .select()
        .eq('device_id', deviceId)
        .limit(1);
    final settings = settingsRows.isNotEmpty ? settingsRows.first : null;

    final deviceRow = await _client
        .from('devices')
        .select('device_types(name)')
        .eq('id', deviceId)
        .maybeSingle();

    String? deviceTypeName;
    if (deviceRow?['device_types'] is Map<String, dynamic>) {
      deviceTypeName =
          deviceRow!['device_types']['name'] as String? ?? 'Control Panel';
    }

    Map<String, dynamic>? ota;
    if (deviceTypeName != null) {
      ota = await _client
          .from('otadata')
          .select()
          .eq('device_type', deviceTypeName)
          .limit(1)
          .maybeSingle();
    }

    return mapUpdateConfig(settings: settings, ota: ota);
  }

  @override
  Future<void> saveUpdateConfig(String deviceId, UpdateConfig config) async {
    final userId = requireUserId(_client);
    final payload = updateSettingsPayload(deviceId, userId, config);
    final existing = await _client
        .from('update_settings')
        .select('id')
        .eq('device_id', deviceId)
        .maybeSingle();

    if (existing == null) {
      await _client.from('update_settings').insert(payload);
    } else {
      await _client
          .from('update_settings')
          .update(payload)
          .eq('device_id', deviceId);
    }
  }

  @override
  Future<GeneralConfig> getGeneralConfig(String deviceId) async {
    final table = await _generalSettingsTable(deviceId);
    final row = await _row(table, deviceId);
    return mapGeneralConfig(row);
  }

  @override
  Future<void> saveGeneralConfig(String deviceId, GeneralConfig config) async {
    final userId = requireUserId(_client);
    final table = await _generalSettingsTable(deviceId);
    await _upsert(
      table,
      generalConfigPayload(
        deviceId,
        userId,
        config,
        includeMode: table != 'smart_led_general_settings',
      ),
    );
  }
}
