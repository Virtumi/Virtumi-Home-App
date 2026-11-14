import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtumi_home/shared/models/models.dart';
import 'package:virtumi_home/shared/providers/data_providers.dart';

DeviceOwnerInfo _owner({String first = 'Max', String last = 'Muster'}) {
  return DeviceOwnerInfo(
    deviceId: 'd1',
    deviceName: 'Wohnzimmer LED',
    ownerUserId: 'u1',
    firstName: first,
    lastName: last,
    email: 'max@example.com',
    isSelf: false,
    alreadyShared: false,
    hasPendingRequest: false,
  );
}

AppNotification _notification({
  required AppNotificationType type,
  DateTime? readAt,
}) {
  return AppNotification(
    id: 'n-${type.dbValue}-${readAt != null}',
    type: type,
    deviceName: 'Lampe',
    createdAt: DateTime(2026, 11, 15),
    readAt: readAt,
  );
}

void main() {
  group('DeviceOwnerInfo.ownerDisplayName', () {
    test('formats "Nachname, Vorname"', () {
      expect(_owner().ownerDisplayName, 'Muster, Max');
    });

    test('falls back to single name or e-mail', () {
      expect(_owner(first: '').ownerDisplayName, 'Muster');
      expect(_owner(last: '').ownerDisplayName, 'Max');
      expect(_owner(first: ' ', last: '').ownerDisplayName, 'max@example.com');
    });
  });

  group('DeviceAccessError.fromMessage', () {
    test('maps RPC error codes to known errors', () {
      expect(
        DeviceAccessError.fromMessage('P0001: already_shared'),
        DeviceAccessError.alreadyShared,
      );
      expect(
        DeviceAccessError.fromMessage('request_pending'),
        DeviceAccessError.requestPending,
      );
      expect(
        DeviceAccessError.fromMessage('something else'),
        DeviceAccessError.unknown,
      );
      expect(DeviceAccessError.fromMessage(null), DeviceAccessError.unknown);
    });
  });

  group('status and type mapping', () {
    test('unknown values fall back to defaults', () {
      expect(
        DeviceAccessStatus.fromDb('approved'),
        DeviceAccessStatus.approved,
      );
      expect(DeviceAccessStatus.fromDb('???'), DeviceAccessStatus.pending);
      expect(
        AppNotificationType.fromDb('device_access_declined'),
        AppNotificationType.deviceAccessDeclined,
      );
      expect(
        AppNotificationType.fromDb(null),
        AppNotificationType.deviceAccessRequest,
      );
    });
  });

  group('unreadNotificationCount', () {
    test('counts only unread entries', () {
      final items = [
        _notification(type: AppNotificationType.deviceAccessRequest),
        _notification(type: AppNotificationType.deviceAccessApproved),
        _notification(
          type: AppNotificationType.deviceAccessDeclined,
          readAt: DateTime(2026, 11, 16),
        ),
      ];
      expect(unreadNotificationCount(AsyncData(items)), 2);
    });

    test('is zero while loading or on error', () {
      expect(unreadNotificationCount(const AsyncLoading()), 0);
      expect(
        unreadNotificationCount(AsyncError(Exception('x'), StackTrace.empty)),
        0,
      );
    });
  });

  group('AppNotification', () {
    test('needsAnswer only for pending incoming requests', () {
      final pending = AppNotification(
        id: '1',
        type: AppNotificationType.deviceAccessRequest,
        deviceName: 'Lampe',
        createdAt: DateTime(2026, 11, 15),
        requestStatus: DeviceAccessStatus.pending,
      );
      final answered = AppNotification(
        id: '2',
        type: AppNotificationType.deviceAccessRequest,
        deviceName: 'Lampe',
        createdAt: DateTime(2026, 11, 15),
        requestStatus: DeviceAccessStatus.approved,
      );
      expect(pending.needsAnswer, isTrue);
      expect(answered.needsAnswer, isFalse);
      expect(pending.message, contains('Lampe'));
    });
  });
}
