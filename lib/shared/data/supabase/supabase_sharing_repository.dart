import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_helpers.dart';
import '../../domain/sharing_repository.dart';
import '../../models/models.dart';

/// Supabase implementation backed by `device_shares` and the RPCs
/// `search_users`, `list_my_shares` and `list_shares_with_me`.
class SupabaseSharingRepository implements SharingRepository {
  SupabaseSharingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<UserSearchResult>> searchUsers(String query) async {
    final term = query.trim();
    if (term.isEmpty) return const [];

    final rows = await _client.rpc('search_users', params: {'p_query': term});
    return [
      for (final raw in rows as List)
        _mapUser(Map<String, dynamic>.from(raw as Map), idKey: 'user_id'),
    ];
  }

  @override
  Future<List<DeviceShare>> listMyShares() => _listShares('list_my_shares');

  @override
  Future<List<DeviceShare>> listSharedWithMe() =>
      _listShares('list_shares_with_me');

  Future<List<DeviceShare>> _listShares(String rpc) async {
    final rows = await _client.rpc(rpc);
    return [
      for (final raw in rows as List)
        _mapShare(Map<String, dynamic>.from(raw as Map)),
    ];
  }

  @override
  Future<void> addShares(String userId, Iterable<ShareScope> scopes) async {
    final ownerId = requireUserId(_client);
    final rows = [
      for (final scope in scopes.toSet())
        {
          'owner_id': ownerId,
          'shared_with_user_id': userId,
          'scope_type': scope.type.dbValue,
          'scope_id': scope.id,
        },
    ];
    if (rows.isEmpty) return;

    await _client.from('device_shares').upsert(
          rows,
          onConflict: 'shared_with_user_id,scope_type,scope_id',
          ignoreDuplicates: true,
        );
  }

  @override
  Future<void> removeShare(String shareId) async {
    await _client.from('device_shares').delete().eq('id', shareId);
  }

  @override
  Future<void> removeShares(Iterable<String> shareIds) async {
    final ids = shareIds.toList();
    if (ids.isEmpty) return;
    await _client.from('device_shares').delete().inFilter('id', ids);
  }

  @override
  Future<List<ShareTarget>> listShareableTargets() async {
    final userId = requireUserId(_client);

    final rows = await _client
        .from('homes')
        .select(
          'id, name, floors(id, name, floor_number, '
          'rooms(id, name, device_types(devices(id, name, devicename))))',
        )
        .eq('user_id', userId)
        .order('name');

    return [
      for (final raw in rows as List)
        _mapHome(Map<String, dynamic>.from(raw as Map)),
    ];
  }

  ShareTarget _mapHome(Map<String, dynamic> home) {
    final floors = _rows(home['floors']).toList()
      ..sort((a, b) {
        final byNumber = ((a['floor_number'] as num?) ?? 0)
            .compareTo((b['floor_number'] as num?) ?? 0);
        return byNumber != 0 ? byNumber : _name(a).compareTo(_name(b));
      });

    return ShareTarget(
      type: ShareScopeType.home,
      id: home['id'] as String,
      name: _name(home),
      children: [for (final floor in floors) _mapFloor(floor)],
    );
  }

  ShareTarget _mapFloor(Map<String, dynamic> floor) {
    final rooms = _rows(floor['rooms']).toList()
      ..sort((a, b) => _name(a).compareTo(_name(b)));

    return ShareTarget(
      type: ShareScopeType.floor,
      id: floor['id'] as String,
      name: _name(floor),
      children: [for (final room in rooms) _mapRoom(room)],
    );
  }

  ShareTarget _mapRoom(Map<String, dynamic> room) {
    final devices = <Map<String, dynamic>>[
      for (final type in _rows(room['device_types'])) ..._rows(type['devices']),
    ]..sort((a, b) => _deviceName(a).compareTo(_deviceName(b)));

    return ShareTarget(
      type: ShareScopeType.room,
      id: room['id'] as String,
      name: _name(room),
      children: [
        for (final device in devices)
          ShareTarget(
            type: ShareScopeType.device,
            id: device['id'] as String,
            name: _deviceName(device),
          ),
      ],
    );
  }

  Iterable<Map<String, dynamic>> _rows(Object? value) sync* {
    if (value is! List) return;
    for (final item in value) {
      if (item is Map) yield Map<String, dynamic>.from(item);
    }
  }

  String _name(Map<String, dynamic> row) =>
      (row['name'] as String?)?.trim() ?? '';

  String _deviceName(Map<String, dynamic> row) {
    final name = (row['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    return (row['devicename'] as String?)?.trim() ?? 'Gerät';
  }

  UserSearchResult _mapUser(
    Map<String, dynamic> row, {
    required String idKey,
  }) {
    return UserSearchResult(
      userId: row[idKey] as String,
      firstName: (row['first_name'] as String?) ?? '',
      lastName: (row['last_name'] as String?) ?? '',
      email: (row['email'] as String?) ?? '',
      avatarUrl: row['avatar_url'] as String?,
    );
  }

  DeviceShare _mapShare(Map<String, dynamic> row) {
    final created = row['created_at'] as String?;
    return DeviceShare(
      id: row['id'] as String,
      user: _mapUser(row, idKey: 'counterpart_user_id'),
      scopeType: ShareScopeType.fromDb(row['scope_type'] as String?),
      scopeId: row['scope_id'] as String,
      scopeName: (row['scope_name'] as String?) ?? '',
      scopePath: row['scope_path'] as String?,
      createdAt: created == null ? null : DateTime.tryParse(created),
    );
  }
}
