import '../models/models.dart';

/// Sharing of houses, floors, rooms and devices with other users.
abstract class SharingRepository {
  /// Partial search (name, first name, e-mail); needs at least 3 characters.
  Future<List<UserSearchResult>> searchUsers(String query);

  /// Shares created by the current user (counterpart = recipient).
  Future<List<DeviceShare>> listMyShares();

  /// Shares granted to the current user (counterpart = owner).
  Future<List<DeviceShare>> listSharedWithMe();

  /// Grants [userId] access to every scope in [scopes]. Existing grants are
  /// kept (idempotent).
  Future<void> addShares(String userId, Iterable<ShareScope> scopes);

  /// Removes a single grant (owner: revoke, recipient: leave).
  Future<void> removeShare(String shareId);

  /// Removes several grants at once.
  Future<void> removeShares(Iterable<String> shareIds);

  /// Own houses with floors, rooms and devices that can be shared.
  Future<List<ShareTarget>> listShareableTargets();
}
