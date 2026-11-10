import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/data_providers.dart';

/// Selected place as small header text, for example `Home / Etage 1 / Büro`.
///
/// Returns null while a needed name is still loading, so the subtitle stays
/// hidden instead of showing a partial path.
String? locationBreadcrumb(
  WidgetRef ref, {
  String? houseId,
  String? floorId,
  String? roomId,
  bool includeFloor = false,
  bool includeRoom = false,
  String? deviceName,
}) {
  var resolvedHouseId = _nonEmpty(houseId);
  var resolvedFloorId = _nonEmpty(floorId);
  String? roomName;

  final resolvedRoomId = _nonEmpty(roomId);
  if (resolvedRoomId != null) {
    final room = ref.watch(roomProvider(resolvedRoomId)).value;
    if (room == null) return null;
    roomName = room.name;
    resolvedFloorId ??= _nonEmpty(room.floorId);
  }

  String? floorName;
  if (resolvedFloorId != null) {
    final floor = ref.watch(floorProvider(resolvedFloorId)).value;
    if (floor == null) return null;
    floorName = floor.name;
    resolvedHouseId ??= _nonEmpty(floor.houseId);
  }

  if (resolvedHouseId == null) return null;
  final house = ref.watch(houseProvider(resolvedHouseId)).value;
  if (house == null) return null;

  final parts = <String>[
    house.name.trim(),
    if (includeFloor && floorName != null) floorName.trim(),
    if (includeRoom && roomName != null) roomName.trim(),
    if (deviceName != null && deviceName.trim().isNotEmpty) deviceName.trim(),
  ].where((part) => part.isNotEmpty);

  final text = parts.join(' / ');
  return text.isEmpty ? null : text;
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
