import '../models/models.dart';

/// Access requests for devices that belong to another account, plus the
/// in-app notification inbox they feed.
abstract class DeviceAccessRepository {
  /// Account the device with [macAddress] already belongs to, or null when it
  /// is not linked to any account. [deviceCode] is the device password the
  /// device was discovered with.
  Future<DeviceOwnerInfo?> findDeviceOwner({
    required String macAddress,
    required String deviceCode,
  });

  /// Asks the owner for access to [deviceId]; returns the request id.
  /// Throws [DeviceAccessException] on business errors.
  Future<String> requestAccess(String deviceId);

  /// Details of a request (owner or requester only).
  Future<DeviceAccessRequest?> getRequest(String requestId);

  /// Owner decision. Approving shares exactly this device with the requester.
  Future<DeviceAccessStatus> respond(String requestId, {required bool approve});

  /// Inbox of the signed-in user, newest first.
  Future<List<AppNotification>> listNotifications();

  /// Marks notifications as read.
  Future<void> markRead(Iterable<String> notificationIds);
}
