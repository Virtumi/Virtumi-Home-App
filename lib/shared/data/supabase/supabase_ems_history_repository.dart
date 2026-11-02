import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/ems_sensor_history.dart';

/// Climate history. Always read from Supabase, in cloud and direct mode.
class SupabaseEmsHistoryRepository {
  SupabaseEmsHistoryRepository(this._client);

  final SupabaseClient _client;

  static const maxPoints = 5000;

  Future<List<EmsHistoryPoint>> getLast24Hours(String deviceId) async {
    final end = DateTime.now();
    final start = end.subtract(const Duration(hours: 24));
    final range = await getRange(deviceId, start: start, end: end);
    return range.points;
  }

  /// Inclusive window. When more than [maxPoints] rows exist, the newest are kept.
  Future<EmsHistoryRange> getRange(
    String deviceId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await _client
        .from('ems_sensordata_history')
        .select('logged_at, iaq, raw_temperature, raw_humidity, raw_pressure')
        .eq('device_id', deviceId)
        .neq('operation', 'DELETE')
        .gte('logged_at', _utcTimestamp(start))
        .lte('logged_at', _utcTimestamp(end))
        .order('logged_at', ascending: false)
        .limit(maxPoints + 1);

    final truncated = rows.length > maxPoints;
    final kept = truncated ? rows.take(maxPoints) : rows;
    final points = <EmsHistoryPoint>[];
    for (final row in kept) {
      final point = EmsHistoryPoint.fromJson(Map<String, dynamic>.from(row));
      if (point != null) points.add(point);
    }
    points.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return EmsHistoryRange(points: points, truncated: truncated);
  }
}

String _utcTimestamp(DateTime utc) {
  final time = utc.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}
