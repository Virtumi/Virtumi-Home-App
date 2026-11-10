import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_helpers.dart';
import '../../domain/smart_home_repository.dart';
import '../../models/models.dart';
import 'device_deletion_helper.dart';
import 'mappers/device_mapper.dart';

/// Cached synthetic hierarchy built from [device_location_settings] when no
/// [homes] rows exist for the current user.
class _SyntheticTree {
  _SyntheticTree({
    required this.houses,
    required this.floorsByHouse,
    required this.roomsByFloor,
    required this.devicesByRoom,
  });

  final List<House> houses;
  final Map<String, List<Floor>> floorsByHouse;
  final Map<String, List<Room>> roomsByFloor;
  final Map<String, List<Device>> devicesByRoom;
}

/// Supabase-backed [SmartHomeRepository] with fallback synthetic hierarchy.
class SupabaseSmartHomeRepository implements SmartHomeRepository {
  SupabaseSmartHomeRepository(this._client);

  final SupabaseClient _client;
  _SyntheticTree? _syntheticTree;
  bool _useSynthetic = false;

  static const _onlineThreshold = Duration(minutes: 3);

  @override
  Future<List<House>> getHouses() async {
    final userId = requireUserId(_client);

    final rows = await _client
        .from('homes')
        .select(
          'id, name, description, floors(rooms(device_types(devices(id))))',
        )
        .eq('user_id', userId)
        .order('name');

    if (rows.isNotEmpty) {
      _useSynthetic = false;
      _syntheticTree = null;
      return [
        for (final row in rows)
          if (houseRowHasDevices(Map<String, dynamic>.from(row as Map)))
            _mapHouseRow(Map<String, dynamic>.from(row as Map)),
      ];
    }

    await _buildSyntheticTree(userId);
    _useSynthetic = true;
    return _syntheticTree!.houses;
  }

  Future<void> _buildSyntheticTree(String userId) async {
    final deviceRows = await _client
        .from('devices')
        .select('*, device_types(name, room_id), device_location_settings(*)')
        .eq('user_id', userId);

    final houses = <String, House>{};
    final floorsByHouse = <String, Map<String, Floor>>{};
    final roomsByFloor = <String, Map<String, Room>>{};
    final devicesByRoom = <String, List<Device>>{};
    final livecom = await _latestLivecomByDevice(userId);

    for (final row in deviceRows) {
      final locationList = row['device_location_settings'];
      Map<String, dynamic>? location;
      if (locationList is List && locationList.isNotEmpty) {
        location = Map<String, dynamic>.from(locationList.first as Map);
      }

      final homeName =
          location?['home'] as String? ?? 'Meine Geräte';
      final floorName =
          location?['floor'] as String? ?? 'Erdgeschoss';
      final roomName = location?['room'] as String? ?? 'Allgemein';

      final homeId = syntheticHomeId(homeName);
      final floorId = syntheticFloorId(homeName, floorName);
      final roomId = syntheticRoomId(homeName, floorName, roomName);

      houses.putIfAbsent(
        homeId,
        () => House(id: homeId, name: homeName),
      );

      floorsByHouse.putIfAbsent(homeId, () => {});
      floorsByHouse[homeId]!.putIfAbsent(
        floorId,
        () => Floor(id: floorId, houseId: homeId, name: floorName),
      );

      roomsByFloor.putIfAbsent(floorId, () => {});
      roomsByFloor[floorId]!.putIfAbsent(
        roomId,
        () => Room(id: roomId, floorId: floorId, name: roomName),
      );

      final deviceId = row['id'] as String;
      final device = mapDeviceRow(
        Map<String, dynamic>.from(row),
        roomId: roomId,
        connectivity: _connectivityFrom(livecom[deviceId]),
      );

      devicesByRoom.putIfAbsent(roomId, () => []).add(device);
    }

    final roomsWithCounts = <String, List<Room>>{
      for (final entry in roomsByFloor.entries)
        entry.key: [
          for (final room in entry.value.values)
            Room(
              id: room.id,
              floorId: room.floorId,
              name: room.name,
              iconKey: room.iconKey,
              icon: room.icon,
              accentKey: room.accentKey,
              deviceCount: devicesByRoom[room.id]?.length ?? 0,
            ),
        ],
    };
    final floorsWithCounts = <String, List<Floor>>{
      for (final entry in floorsByHouse.entries)
        entry.key: [
          for (final floor in entry.value.values)
            Floor(
              id: floor.id,
              houseId: floor.houseId,
              name: floor.name,
              iconKey: floor.iconKey,
              icon: floor.icon,
              accentKey: floor.accentKey,
              roomCount: roomsWithCounts[floor.id]?.length ?? 0,
              deviceCount: (roomsWithCounts[floor.id] ?? const <Room>[])
                  .fold(0, (sum, room) => sum + room.deviceCount),
            ),
        ],
    };

    _syntheticTree = _SyntheticTree(
      houses: [
        for (final house in houses.values)
          House(
            id: house.id,
            name: house.name,
            iconKey: house.iconKey,
            icon: house.icon,
            floorCount: floorsWithCounts[house.id]?.length ?? 0,
            roomCount: (floorsWithCounts[house.id] ?? const <Floor>[])
                .fold(0, (sum, floor) => sum + floor.roomCount),
            deviceCount: (floorsWithCounts[house.id] ?? const <Floor>[])
                .fold(0, (sum, floor) => sum + floor.deviceCount),
          ),
      ],
      floorsByHouse: floorsWithCounts,
      roomsByFloor: roomsWithCounts,
      devicesByRoom: devicesByRoom,
    );
  }

  /// Newest `livecom.updated_at` per device UUID for the signed-in user.
  Future<Map<String, DateTime>> _latestLivecomByDevice(String userId) async {
    final rows = await _client
        .from('livecom')
        .select('device_id, updated_at')
        .eq('user_id', userId);

    final latest = <String, DateTime>{};
    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['device_id'] as String?;
      final stamp = row['updated_at'] as String?;
      if (id == null || stamp == null) continue;
      final at = DateTime.parse(stamp).toUtc();
      final previous = latest[id];
      if (previous == null || at.isAfter(previous)) latest[id] = at;
    }
    return latest;
  }

  DeviceConnectivity _connectivityFrom(DateTime? updatedAt) {
    if (updatedAt == null) return DeviceConnectivity.offline;
    final fresh =
        DateTime.now().toUtc().difference(updatedAt) < _onlineThreshold;
    return fresh ? DeviceConnectivity.online : DeviceConnectivity.offline;
  }

  Future<DeviceConnectivity> _connectivityForDevice(String deviceId) async {
    final userId = requireUserId(_client);
    final livecom = await _latestLivecomByDevice(userId);
    return _connectivityFrom(livecom[deviceId]);
  }

  @override
  Future<House?> getHouse(String houseId) async {
    final houses = await getHouses();
    return houses.where((h) => h.id == houseId).firstOrNull;
  }

  @override
  Future<List<Floor>> getFloors(String houseId) async {
    if (_useSynthetic || isSyntheticId(houseId)) {
      await getHouses();
      return _syntheticTree?.floorsByHouse[houseId] ?? [];
    }

    final rows = await _queryFloors(houseId);

    return [for (final row in rows) _mapFloorRow(row)];
  }

  Future<List<Map<String, dynamic>>> _queryFloors(String houseId) async {
    final rows = await _client
        .from('floors')
        .select(
          'id, home_id, name, floor_number, description, '
          'rooms(device_types(devices(id)))',
        )
        .eq('home_id', houseId)
        .order('floor_number');
    return [
      for (final row in _rowMaps(rows))
        if (floorRowHasDevices(row)) row,
    ];
  }

  Future<List<Map<String, dynamic>>> _queryRooms(String floorId) async {
    final rows = await _client
        .from('rooms')
        .select('id, floor_id, name, room_type, device_types(devices(id))')
        .eq('floor_id', floorId)
        .order('name');
    return [
      for (final row in _rowMaps(rows))
        if (roomRowHasDevices(row)) row,
    ];
  }

  List<Map<String, dynamic>> _rowMaps(dynamic rows) => [
        for (final row in rows as List) Map<String, dynamic>.from(row as Map),
      ];

  House _mapHouseRow(Map<String, dynamic> row) {
    final presets = LocationPresets.house;
    final iconKey = LocationPresets.resolveIconKey(
      row['description'] as String?,
      presets,
    );
    final totals = _countHouse(row);
    return House(
      id: row['id'] as String,
      name: row['name'] as String,
      iconKey: iconKey,
      icon: LocationPresets.iconForKey(iconKey, presets),
      floorCount: totals.floors,
      roomCount: totals.rooms,
      deviceCount: totals.devices,
    );
  }

  Floor _mapFloorRow(Map<String, dynamic> row) {
    final presets = LocationPresets.floor;
    final iconKey = LocationPresets.resolveIconKey(
      row['description'] as String?,
      presets,
    );
    final totals = _countFloor(row);
    return Floor(
      id: row['id'] as String,
      houseId: row['home_id'] as String,
      name: row['name'] as String,
      iconKey: iconKey,
      icon: LocationPresets.iconForKey(iconKey, presets),
      roomCount: totals.rooms,
      deviceCount: totals.devices,
    );
  }

  Room _mapRoomRow(Map<String, dynamic> row) {
    final presets = LocationPresets.room;
    final iconKey = LocationPresets.resolveIconKey(
      row['room_type'] as String?,
      presets,
    );
    return Room(
      id: row['id'] as String,
      floorId: row['floor_id'] as String,
      name: row['name'] as String,
      iconKey: iconKey,
      icon: LocationPresets.iconForKey(iconKey, presets),
      deviceCount: _countDevices(row['device_types']),
    );
  }

  ({int floors, int rooms, int devices}) _countHouse(Map<String, dynamic> row) {
    final floors = row['floors'];
    if (floors is! List) return (floors: 0, rooms: 0, devices: 0);
    var roomCount = 0;
    var deviceCount = 0;
    for (final floor in floors) {
      if (floor is! Map) continue;
      final totals = _countFloor(Map<String, dynamic>.from(floor));
      roomCount += totals.rooms;
      deviceCount += totals.devices;
    }
    return (floors: floors.length, rooms: roomCount, devices: deviceCount);
  }

  ({int rooms, int devices}) _countFloor(Map<String, dynamic> row) {
    final rooms = row['rooms'];
    if (rooms is! List) return (rooms: 0, devices: 0);
    var deviceCount = 0;
    for (final room in rooms) {
      if (room is! Map) continue;
      deviceCount += _countDevices(room['device_types']);
    }
    return (rooms: rooms.length, devices: deviceCount);
  }

  int _countDevices(dynamic deviceTypes) {
    if (deviceTypes is! List) return 0;
    var count = 0;
    for (final type in deviceTypes) {
      if (type is! Map) continue;
      final devices = type['devices'];
      if (devices is List) count += devices.length;
    }
    return count;
  }

  @override
  Future<Floor?> getFloor(String floorId) async {
    if (isSyntheticId(floorId)) {
      await getHouses();
      final tree = _syntheticTree;
      if (tree == null) return null;
      for (final floors in tree.floorsByHouse.values) {
        final match = floors.where((f) => f.id == floorId).firstOrNull;
        if (match != null) return match;
      }
      return null;
    }

    final row = await _client
        .from('floors')
        .select('id, home_id, name, description')
        .eq('id', floorId)
        .maybeSingle();

    if (row == null) return null;
    return _mapFloorRow(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<Room>> getRooms(String floorId) async {
    if (_useSynthetic || isSyntheticId(floorId)) {
      await getHouses();
      return _syntheticTree?.roomsByFloor[floorId] ?? [];
    }

    final rows = await _queryRooms(floorId);

    return [for (final row in rows) _mapRoomRow(row)];
  }

  @override
  Future<Room?> getRoom(String roomId) async {
    if (isSyntheticId(roomId)) {
      await getHouses();
      final tree = _syntheticTree;
      if (tree == null) return null;
      for (final rooms in tree.roomsByFloor.values) {
        final match = rooms.where((r) => r.id == roomId).firstOrNull;
        if (match != null) return match;
      }
      return null;
    }

    final row = await _client
        .from('rooms')
        .select('id, floor_id, name, room_type')
        .eq('id', roomId)
        .maybeSingle();

    if (row == null) return null;
    return _mapRoomRow(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<Device>> getDevices(String roomId) async {
    if (_useSynthetic || isSyntheticId(roomId)) {
      await getHouses();
      final cached = _syntheticTree?.devicesByRoom[roomId] ?? [];
      final livecom = await _latestLivecomByDevice(requireUserId(_client));
      return [
        for (final device in cached)
          device.copyWith(connectivity: _connectivityFrom(livecom[device.id])),
      ];
    }

    final rows = await _client
        .from('devices')
        .select('*, device_types!inner(name, room_id)')
        .eq('device_types.room_id', roomId);

    final livecom = await _latestLivecomByDevice(requireUserId(_client));
    return [
      for (final raw in rows)
        mapDeviceRow(
          Map<String, dynamic>.from(raw as Map),
          roomId: roomId,
          connectivity: _connectivityFrom(
            livecom[raw['id'] as String],
          ),
        ),
    ];
  }

  @override
  Future<Device?> getDevice(
    String deviceId, {
    bool includeConnectivity = true,
  }) async {
    final row = await _client
        .from('devices')
        .select('*, device_types(name, room_id)')
        .eq('id', deviceId)
        .maybeSingle();

    if (row == null) return null;

    final typeRoomId = row['device_types'] is Map<String, dynamic>
        ? row['device_types']['room_id'] as String?
        : null;

    String roomId = typeRoomId ?? '';
    if (roomId.isEmpty) {
      await getHouses();
      final tree = _syntheticTree;
      if (tree != null) {
        for (final entry in tree.devicesByRoom.entries) {
          if (entry.value.any((d) => d.id == deviceId)) {
            roomId = entry.key;
            break;
          }
        }
      }
    }

    final connectivity = includeConnectivity
        ? await _connectivityForDevice(deviceId)
        : DeviceConnectivity.offline;
    return mapDeviceRow(
      Map<String, dynamic>.from(row),
      roomId: roomId,
      connectivity: connectivity,
    );
  }

  @override
  Future<void> setDevicePower(String deviceId, bool isOn) async {
    final device = await getDevice(deviceId);
    if (device == null) return;

    final table = switch (device.type) {
      DeviceType.light => 'smart_led_general_settings',
      DeviceType.environmentMonitor => 'ems_general_settings',
      _ => 'cp_general_settings',
    };

    if (table == 'smart_led_general_settings') {
      await _client.from(table).upsert({
        'device_id': deviceId,
        'led_state': isOn ? 1 : 0,
        'user_id': requireUserId(_client),
      }, onConflict: 'device_id');
    } else {
      await _client.from(table).upsert({
        'device_id': deviceId,
        'led_state': isOn ? 1 : 0,
        'user_id': requireUserId(_client),
      }, onConflict: 'device_id');
    }

    await _client.from('devices').update({
      'status': isOn ? 'online' : 'offline',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', deviceId);
  }

  @override
  Future<void> updateDeviceName(String deviceId, String name) async {
    final userId = requireUserId(_client);
    final storedName = await _storedDeviceName(deviceId, name);
    await _client.from('devices').update({
      'name': storedName,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', deviceId);

    await _client.from('device_location_settings').upsert({
      'device_id': deviceId,
      'name': storedName,
      'user_id': userId,
    }, onConflict: 'device_id');
  }

  Future<String> _storedDeviceName(String deviceId, String requested) async {
    final row = await _client
        .from('devices')
        .select('device_types(name)')
        .eq('id', deviceId)
        .maybeSingle();
    final types = row?['device_types'];
    final typeName = types is Map<String, dynamic>
        ? types['name'] as String?
        : null;
    if (isEmsTypeName(typeName)) return emsStoredName;
    return requested;
  }

  @override
  Future<String> addDevice({
    required String name,
    required String deviceCode,
    String? macAddress,
    String? ipAddress,
    String? hostname,
    String? port,
    String deviceTypeName = 'Control Panel',
    String homeName = 'My Haus',
    String floorName = 'Erdgeschoss',
    String roomName = 'Buero',
  }) async {
    final userId = requireUserId(_client);

    final homeId = await _findOrCreateHome(userId, homeName);
    final floorId = await _findOrCreateFloor(homeId, floorName);
    final roomId = await _findOrCreateRoom(floorId, roomName);
    final deviceTypeId =
        await _findOrCreateDeviceType(roomId, deviceTypeName);

    final inserted = await _client
        .from('devices')
        .insert({
          'user_id': userId,
          'device_type_id': deviceTypeId,
          'name': name,
          'device_code': deviceCode,
          'mac_address': macAddress,
          'ip_address': ipAddress,
          'hostname': hostname,
          'port': port,
          'status': 'offline',
        })
        .select('id')
        .single();

    final deviceId = inserted['id'] as String;

    await _client.from('device_location_settings').upsert({
      'device_id': deviceId,
      'home': homeName,
      'floor': floorName,
      'room': roomName,
      'name': name,
      'user_id': userId,
    }, onConflict: 'device_id');

    _syntheticTree = null;
    _useSynthetic = false;
    return deviceId;
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    final row = await _client
        .from('devices')
        .select('''
          id,
          device_code,
          mac_address,
          device_type_id,
          device_types (
            id,
            room_id,
            rooms (
              id,
              floor_id,
              floors (
                id,
                home_id
              )
            )
          )
        ''')
        .eq('id', deviceId)
        .maybeSingle();

    if (row == null) return;

    final deviceRow = Map<String, dynamic>.from(row);
    final hierarchy = parseDeviceHierarchy(deviceRow);

    await deleteDeviceRelatedRows(_client, deviceId);
    await deleteLivecomRows(
      _client,
      deviceCode: deviceCodeFromRow(deviceRow),
      macAddress: macAddressFromRow(deviceRow),
    );

    await _client.from('devices').delete().eq('id', deviceId);

    await cleanupDeviceHierarchy(_client, hierarchy);

    _syntheticTree = null;
    _useSynthetic = false;
  }

  @override
  Future<House> createHome(String name, {String? description, String? address}) async {
    final userId = requireUserId(_client);
    final inserted = await _client
        .from('homes')
        .insert({
          'user_id': userId,
          'name': name,
          if (description != null) 'description': description,
          if (address != null) 'address': address,
        })
        .select('id, name')
        .single();

    _syntheticTree = null;
    _useSynthetic = false;

    return House(
      id: inserted['id'] as String,
      name: inserted['name'] as String,
    );
  }

  @override
  Future<void> updateHome(House house) async {
    await _client.from('homes').update({'name': house.name}).eq('id', house.id);
    _syntheticTree = null;
  }

  @override
  Future<void> updateHouseIcon(String houseId, String iconKey) async {
    if (isSyntheticId(houseId)) return;

    await _client.from('homes').update({
      'description': iconKey,
    }).eq('id', houseId);
  }

  @override
  Future<void> updateFloorIcon(String floorId, String iconKey) async {
    if (isSyntheticId(floorId)) return;

    await _client.from('floors').update({
      'description': iconKey,
    }).eq('id', floorId);
  }

  @override
  Future<void> updateRoomIcon(String roomId, String iconKey) async {
    if (isSyntheticId(roomId)) return;

    await _client.from('rooms').update({
      'room_type': iconKey,
    }).eq('id', roomId);
  }

  Future<String> _findOrCreateHome(String userId, String name) async {
    final existing = await _client
        .from('homes')
        .select('id')
        .eq('user_id', userId)
        .eq('name', name)
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final inserted = await _client
        .from('homes')
        .insert({'user_id': userId, 'name': name})
        .select('id')
        .single();

    return inserted['id'] as String;
  }

  Future<String> _findOrCreateFloor(String homeId, String name) async {
    final existing = await _client
        .from('floors')
        .select('id')
        .eq('home_id', homeId)
        .eq('name', name)
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final inserted = await _client
        .from('floors')
        .insert({'home_id': homeId, 'name': name})
        .select('id')
        .single();

    return inserted['id'] as String;
  }

  Future<String> _findOrCreateRoom(String floorId, String name) async {
    final existing = await _client
        .from('rooms')
        .select('id')
        .eq('floor_id', floorId)
        .eq('name', name)
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final inserted = await _client
        .from('rooms')
        .insert({'floor_id': floorId, 'name': name})
        .select('id')
        .single();

    return inserted['id'] as String;
  }

  Future<String> _findOrCreateDeviceType(String roomId, String name) async {
    final existing = await _client
        .from('device_types')
        .select('id')
        .eq('room_id', roomId)
        .eq('name', name)
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final inserted = await _client
        .from('device_types')
        .insert({'room_id': roomId, 'name': name})
        .select('id')
        .single();

    return inserted['id'] as String;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
