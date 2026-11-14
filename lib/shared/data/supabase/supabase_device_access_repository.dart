import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_helpers.dart';
import '../../domain/device_access_repository.dart';
import '../../models/models.dart';

/// Supabase implementation backed by `device_access_requests`,
/// `app_notifications` and the RPCs `find_device_owner`,
/// `request_device_access`, `get_device_access_request`,
/// `respond_device_access_request` and `list_notifications`.
class SupabaseDeviceAccessRepository implements DeviceAccessRepository {
  SupabaseDeviceAccessRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<DeviceOwnerInfo?> findDeviceOwner({
    required String macAddress,
    required String deviceCode,
  }) async {
    final mac = macAddress.trim();
    if (mac.isEmpty || deviceCode.isEmpty) return null;

    final rows = await _client.rpc(
      'find_device_owner',
      params: {'p_mac': mac, 'p_device_code': deviceCode},
    );
    final list = rows as List;
    if (list.isEmpty) return null;
    final row = Map<String, dynamic>.from(list.first as Map);

    return DeviceOwnerInfo(
      deviceId: row['device_id'] as String,
      deviceName: (row['device_name'] as String?) ?? '',
      ownerUserId: row['owner_user_id'] as String,
      firstName: (row['first_name'] as String?) ?? '',
      lastName: (row['last_name'] as String?) ?? '',
      email: (row['email'] as String?) ?? '',
      isSelf: row['is_self'] == true,
      alreadyShared: row['already_shared'] == true,
      hasPendingRequest: row['has_pending_request'] == true,
    );
  }

  @override
  Future<String> requestAccess(String deviceId) async {
    requireUserId(_client);
    try {
      final id = await _client.rpc(
        'request_device_access',
        params: {'p_device_id': deviceId},
      );
      return id as String;
    } on PostgrestException catch (e) {
      throw DeviceAccessException(DeviceAccessError.fromMessage(e.message));
    }
  }

  @override
  Future<DeviceAccessRequest?> getRequest(String requestId) async {
    final rows = await _client.rpc(
      'get_device_access_request',
      params: {'p_id': requestId},
    );
    final list = rows as List;
    if (list.isEmpty) return null;
    final row = Map<String, dynamic>.from(list.first as Map);

    final created = row['created_at'] as String?;
    final responded = row['responded_at'] as String?;
    return DeviceAccessRequest(
      id: row['id'] as String,
      status: DeviceAccessStatus.fromDb(row['status'] as String?),
      deviceId: row['device_id'] as String,
      deviceName: (row['device_name'] as String?) ?? '',
      devicePath: row['device_path'] as String?,
      ownerId: row['owner_id'] as String,
      requester: UserSearchResult(
        userId: row['requester_id'] as String,
        firstName: (row['requester_first_name'] as String?) ?? '',
        lastName: (row['requester_last_name'] as String?) ?? '',
        email: (row['requester_email'] as String?) ?? '',
      ),
      createdAt: created == null ? null : DateTime.tryParse(created),
      respondedAt: responded == null ? null : DateTime.tryParse(responded),
    );
  }

  @override
  Future<DeviceAccessStatus> respond(
    String requestId, {
    required bool approve,
  }) async {
    try {
      final status = await _client.rpc(
        'respond_device_access_request',
        params: {'p_id': requestId, 'p_approve': approve},
      );
      return DeviceAccessStatus.fromDb(status as String?);
    } on PostgrestException catch (e) {
      throw DeviceAccessException(DeviceAccessError.fromMessage(e.message));
    }
  }

  @override
  Future<List<AppNotification>> listNotifications() async {
    if (currentUserId(_client) == null) return const [];

    final rows = await _client.rpc('list_notifications');
    return [
      for (final raw in rows as List)
        _mapNotification(Map<String, dynamic>.from(raw as Map)),
    ];
  }

  @override
  Future<void> markRead(Iterable<String> notificationIds) async {
    final ids = notificationIds.toList();
    if (ids.isEmpty) return;
    await _client
        .from('app_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .inFilter('id', ids)
        .isFilter('read_at', null);
  }

  AppNotification _mapNotification(Map<String, dynamic> row) {
    final actorId = row['actor_user_id'] as String?;
    final readAt = row['read_at'] as String?;
    final status = row['request_status'] as String?;
    return AppNotification(
      id: row['id'] as String,
      type: AppNotificationType.fromDb(row['type'] as String?),
      requestId: row['request_id'] as String?,
      deviceName: (row['device_name'] as String?) ?? '',
      actor: actorId == null
          ? null
          : UserSearchResult(
              userId: actorId,
              firstName: (row['actor_first_name'] as String?) ?? '',
              lastName: (row['actor_last_name'] as String?) ?? '',
              email: (row['actor_email'] as String?) ?? '',
            ),
      requestStatus: status == null ? null : DeviceAccessStatus.fromDb(status),
      readAt: readAt == null ? null : DateTime.tryParse(readAt)?.toLocal(),
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}
