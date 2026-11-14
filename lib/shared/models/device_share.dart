import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Level of the location hierarchy a share is granted on.
enum ShareScopeType {
  home('home', 'Haus', Symbols.home),
  floor('floor', 'Etage', Symbols.layers),
  room('room', 'Raum', Symbols.meeting_room),
  device('device', 'Gerät', Symbols.devices);

  const ShareScopeType(this.dbValue, this.label, this.icon);

  /// Value stored in `device_shares.scope_type`.
  final String dbValue;
  final String label;
  final IconData icon;

  static ShareScopeType fromDb(String? value) {
    return ShareScopeType.values.firstWhere(
      (type) => type.dbValue == value,
      orElse: () => ShareScopeType.device,
    );
  }
}

/// A single grant target (house, floor, room or device).
@immutable
class ShareScope {
  const ShareScope(this.type, this.id);

  final ShareScopeType type;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is ShareScope && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

/// A user found by `search_users`.
@immutable
class UserSearchResult {
  const UserSearchResult({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.avatarUrl,
  });

  final String userId;
  final String firstName;
  final String lastName;
  final String email;

  /// Profile picture URL (public `avatars` bucket), null when not set.
  final String? avatarUrl;

  String get fullName => '$firstName $lastName'.trim();

  /// Name if available, otherwise the e-mail address.
  String get displayName => fullName.isNotEmpty ? fullName : email;

  String get initials {
    final first = firstName.trim();
    final last = lastName.trim();
    if (first.isNotEmpty || last.isNotEmpty) {
      return '${first.isNotEmpty ? first[0] : ''}'
              '${last.isNotEmpty ? last[0] : ''}'
          .toUpperCase();
    }
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }
}

/// One row of `device_shares` enriched with the counterpart user.
///
/// For "shared by me" the counterpart is the recipient, for "shared with me"
/// the counterpart is the owner.
@immutable
class DeviceShare {
  const DeviceShare({
    required this.id,
    required this.user,
    required this.scopeType,
    required this.scopeId,
    required this.scopeName,
    this.scopePath,
    this.createdAt,
  });

  final String id;
  final UserSearchResult user;
  final ShareScopeType scopeType;
  final String scopeId;
  final String scopeName;

  /// Parent path, e.g. "Haus / Etage" (null for houses).
  final String? scopePath;
  final DateTime? createdAt;
}

/// Node in the tree of the owner's own houses, floors, rooms and devices.
@immutable
class ShareTarget {
  const ShareTarget({
    required this.type,
    required this.id,
    required this.name,
    this.children = const [],
  });

  final ShareScopeType type;
  final String id;
  final String name;
  final List<ShareTarget> children;

  ShareScope get scope => ShareScope(type, id);
}
