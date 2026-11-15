import 'package:flutter/foundation.dart';

/// Home / floor / room of a device.
@immutable
class DevicePlace {
  const DevicePlace({this.home = '', this.floor = '', this.room = ''});

  final String home;
  final String floor;
  final String room;

  /// True when none of the three names is known.
  bool get isEmpty =>
      home.trim().isEmpty && floor.trim().isEmpty && room.trim().isEmpty;

  /// "Home / Etage / Raum" for messages.
  String get label {
    final parts = [home, floor, room]
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    return parts.isEmpty ? '-' : parts.join(' / ');
  }

  /// Case- and whitespace-insensitive comparison.
  bool sameAs(DevicePlace other) {
    String n(String v) => v.trim().toLowerCase();
    return n(home) == n(other.home) &&
        n(floor) == n(other.floor) &&
        n(room) == n(other.room);
  }
}

/// What differs between a discovered device that already belongs to the
/// signed-in account and the data stored in Supabase.
@immutable
class ExistingDeviceChange {
  const ExistingDeviceChange({
    required this.deviceId,
    required this.deviceName,
    required this.storedIp,
    required this.foundIp,
    required this.storedPlace,
    required this.foundPlace,
    this.storedPort,
    this.foundPort,
  });

  final String deviceId;
  final String deviceName;
  final String storedIp;
  final String foundIp;
  final DevicePlace storedPlace;
  final DevicePlace foundPlace;
  final int? storedPort;
  final int? foundPort;

  /// The IP address changed. An unknown IP never counts as a change.
  bool get ipChanged {
    final found = foundIp.trim();
    return found.isNotEmpty && found != storedIp.trim();
  }

  /// The place changed. A place the device does not report (all names empty)
  /// never counts as a change, so no false prompt appears.
  bool get locationChanged =>
      !foundPlace.isEmpty && !foundPlace.sameAs(storedPlace);

  bool get hasChanges => ipChanged || locationChanged;
}
