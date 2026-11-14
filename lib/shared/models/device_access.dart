import 'package:flutter/foundation.dart';

import 'device_share.dart';

/// Result of `find_device_owner`: the account a discovered device already
/// belongs to.
@immutable
class DeviceOwnerInfo {
  const DeviceOwnerInfo({
    required this.deviceId,
    required this.deviceName,
    required this.ownerUserId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.isSelf,
    required this.alreadyShared,
    required this.hasPendingRequest,
  });

  final String deviceId;
  final String deviceName;
  final String ownerUserId;
  final String firstName;
  final String lastName;
  final String email;

  /// The device already belongs to the signed-in user.
  final bool isSelf;

  /// The signed-in user already has access through a share.
  final bool alreadyShared;

  /// The signed-in user already asked for access and is waiting.
  final bool hasPendingRequest;

  /// "Nachname, Vorname" if available, otherwise the e-mail address.
  String get ownerDisplayName {
    final last = lastName.trim();
    final first = firstName.trim();
    if (last.isNotEmpty && first.isNotEmpty) return '$last, $first';
    if (last.isNotEmpty || first.isNotEmpty) return '$last$first';
    return email;
  }
}

/// Decision state of a [DeviceAccessRequest].
enum DeviceAccessStatus {
  pending('pending', 'Offen'),
  approved('approved', 'Genehmigt'),
  declined('declined', 'Abgelehnt');

  const DeviceAccessStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static DeviceAccessStatus fromDb(String? value) {
    return DeviceAccessStatus.values.firstWhere(
      (status) => status.dbValue == value,
      orElse: () => DeviceAccessStatus.pending,
    );
  }
}

/// A request of [requester] for access to a single device of the owner.
@immutable
class DeviceAccessRequest {
  const DeviceAccessRequest({
    required this.id,
    required this.status,
    required this.deviceId,
    required this.deviceName,
    required this.ownerId,
    required this.requester,
    this.devicePath,
    this.createdAt,
    this.respondedAt,
  });

  final String id;
  final DeviceAccessStatus status;
  final String deviceId;
  final String deviceName;

  /// Location of the device, e.g. "Haus / Etage / Raum".
  final String? devicePath;
  final String ownerId;
  final UserSearchResult requester;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  bool get isPending => status == DeviceAccessStatus.pending;
}

/// Business errors raised by the access-request RPCs.
enum DeviceAccessError {
  deviceNotFound('device_not_found', 'Gerät wurde nicht gefunden.'),
  alreadyOwner('already_owner', 'Dieses Gerät gehört bereits zu deinem Konto.'),
  alreadyShared('already_shared', 'Du hast bereits Zugriff auf dieses Gerät.'),
  requestPending(
    'request_pending',
    'Deine Anfrage für dieses Gerät ist noch offen.',
  ),
  requestNotFound('request_not_found', 'Anfrage wurde nicht gefunden.'),
  requestAlreadyAnswered(
    'request_already_answered',
    'Diese Anfrage wurde bereits beantwortet.',
  ),
  notDeviceOwner(
    'not_device_owner',
    'Du bist nicht mehr Besitzer dieses Geräts.',
  ),
  unknown('', 'Aktion fehlgeschlagen. Bitte später erneut versuchen.');

  const DeviceAccessError(this.code, this.message);

  final String code;
  final String message;

  static DeviceAccessError fromMessage(String? message) {
    final text = message ?? '';
    return DeviceAccessError.values.firstWhere(
      (error) => error.code.isNotEmpty && text.contains(error.code),
      orElse: () => DeviceAccessError.unknown,
    );
  }
}

class DeviceAccessException implements Exception {
  const DeviceAccessException(this.error);

  final DeviceAccessError error;

  String get message => error.message;

  @override
  String toString() => message;
}
