import 'package:flutter/foundation.dart';

import 'device_access.dart';
import 'device_share.dart';

/// Kinds of entries in the in-app inbox (`app_notifications.type`).
enum AppNotificationType {
  deviceAccessRequest('device_access_request'),
  deviceAccessApproved('device_access_approved'),
  deviceAccessDeclined('device_access_declined');

  const AppNotificationType(this.dbValue);

  final String dbValue;

  static AppNotificationType fromDb(String? value) {
    return AppNotificationType.values.firstWhere(
      (type) => type.dbValue == value,
      orElse: () => AppNotificationType.deviceAccessRequest,
    );
  }
}

/// One entry of the notification inbox (bell icon on the Home screen).
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.deviceName,
    required this.createdAt,
    this.requestId,
    this.actor,
    this.requestStatus,
    this.readAt,
  });

  final String id;
  final AppNotificationType type;
  final String? requestId;
  final String deviceName;

  /// The other party: requester for incoming requests, owner for answers.
  final UserSearchResult? actor;

  /// Current status of the linked request (null when none).
  final DeviceAccessStatus? requestStatus;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  /// True while the owner still has to decide on this request.
  bool get needsAnswer =>
      type == AppNotificationType.deviceAccessRequest &&
      requestStatus == DeviceAccessStatus.pending;

  String get actorLabel => actor?.displayName ?? 'Unbekannt';

  String get title => switch (type) {
    AppNotificationType.deviceAccessRequest => 'Freigabeanfrage',
    AppNotificationType.deviceAccessApproved => 'Freigabe genehmigt',
    AppNotificationType.deviceAccessDeclined => 'Freigabe abgelehnt',
  };

  String get message => switch (type) {
    AppNotificationType.deviceAccessRequest =>
      '$actorLabel möchte Zugriff auf „$deviceName“.',
    AppNotificationType.deviceAccessApproved =>
      '$actorLabel hat dir Zugriff auf „$deviceName“ gegeben.',
    AppNotificationType.deviceAccessDeclined =>
      '$actorLabel hat deine Anfrage für „$deviceName“ abgelehnt.',
  };
}
