import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_helpers.dart';
import '../../domain/device_request_repository.dart';

class SupabaseDeviceRequestRepository implements DeviceRequestRepository {
  SupabaseDeviceRequestRepository(this._client);

  final SupabaseClient _client;

  /// Written into `user_id`; for shared devices the database trigger replaces
  /// it with the original owner id (target devices filter on that id).
  String get _userId => requireUserId(_client);

  @override
  Future<void> sendButtonPress(String deviceId, int command) async {
    final userId = _userId;
    final now = DateTime.now().toUtc().toIso8601String();

    final rows = await _client
        .from('cp_btn_requests')
        .select('id')
        .eq('device_id', deviceId)
        .order('updated_at', ascending: false);

    if (rows.isNotEmpty) {
      final keepId = rows.first['id'] as String;

      await _client.from('cp_btn_requests').update({
        'command': command,
        'status': 'pending',
        'updated_at': now,
        'completed_at': null,
        'error_message': null,
      }).eq('id', keepId);

      if (rows.length > 1) {
        final duplicateIds =
            rows.skip(1).map((row) => row['id'] as String).toList();
        await _client.from('cp_btn_requests').delete().inFilter('id', duplicateIds);
      }
      return;
    }

    await _client.from('cp_btn_requests').insert({
      'device_id': deviceId,
      'user_id': userId,
      'command': command,
      'status': 'pending',
    });
  }

  @override
  Future<void> sendMatterPairingRequest(String deviceId) async {
    await _upsertDeviceUserRequest(
      table: 'matter_requests',
      deviceId: deviceId,
      payload: {'command': 2, 'status': 'pending'},
    );
  }

  @override
  Future<void> sendUpdateRequest(String deviceId) async {
    await _upsertDeviceUserRequest(
      table: 'update_requests',
      deviceId: deviceId,
      payload: {'command': 2, 'status': 'pending'},
    );
  }

  Future<void> _upsertDeviceUserRequest({
    required String table,
    required String deviceId,
    required Map<String, dynamic> payload,
  }) async {
    final userId = _userId;
    final now = DateTime.now().toUtc().toIso8601String();

    final rows = await _client
        .from(table)
        .select('id')
        .eq('device_id', deviceId)
        .order('updated_at', ascending: false);

    if (rows.isNotEmpty) {
      final keepId = rows.first['id'] as String;
      await _client.from(table).update({
        ...payload,
        'updated_at': now,
      }).eq('id', keepId);
      return;
    }

    await _client.from(table).insert({
      'device_id': deviceId,
      'user_id': userId,
      ...payload,
    });
  }

  @override
  Future<void> requestPasswordChange({
    required String deviceId,
    required String currentCode,
    required String newCode,
  }) async {
    await _client.from('device_secret').upsert({
      'device_id': deviceId,
      'user_id': _userId,
      'device_code': currentCode,
      'device_code_new': newCode,
      'change_status': 1,
    }, onConflict: 'device_id');
  }

  @override
  Future<String?> pollRequestStatus({
    required String table,
    required String deviceId,
    Duration timeout = const Duration(seconds: 30),
    Duration interval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final rows = await _client
          .from(table)
          .select('status, error_message')
          .eq('device_id', deviceId)
          .order('updated_at', ascending: false)
          .limit(1);

      if (rows.isNotEmpty) {
        final row = rows.first;
        final status = row['status'] as String?;
        if (status == 'completed') return null;
        if (status == 'failed') {
          return row['error_message'] as String? ?? 'Anfrage fehlgeschlagen';
        }
      }

      await Future<void>.delayed(interval);
    }

    return 'Zeitüberschreitung – Gerät hat nicht reagiert';
  }
}
