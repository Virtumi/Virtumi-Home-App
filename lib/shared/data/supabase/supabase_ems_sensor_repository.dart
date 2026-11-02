import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/ems_sensor_repository.dart';
import '../../models/ems_sensor_reading.dart';

class SupabaseEmsSensorRepository implements EmsSensorRepository {
  SupabaseEmsSensorRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<EmsSensorReading?> getReading(String deviceId) async {
    final row = await _client
        .from('ems_sensordata')
        .select()
        .eq('device_id', deviceId)
        .maybeSingle();
    if (row == null) return null;
    return EmsSensorReading.fromJson(row);
  }
}
