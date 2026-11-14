import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/services/preferences_service.dart';

/// Device ids marked as favorites, newest first, stored per signed-in user.
class FavoriteDevicesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    // Listened to (not watched): a dependency rebuild would be flushed lazily
    // by the first widget reading this provider, i.e. during build.
    ref.listen(authUserIdProvider, (previous, next) {
      if (next == previous) return;
      state = _load(next);
    });
    return _load(_readUserId());
  }

  List<String> _load(String? userId) {
    if (userId == null) return const [];
    return ref.read(preferencesServiceProvider).favoriteDeviceIds(userId);
  }

  String? _readUserId() => ref.read(authUserIdProvider);

  Future<void> toggle(String deviceId) async {
    final userId = _readUserId();
    if (userId == null) return;
    final updated = state.contains(deviceId)
        ? state.where((id) => id != deviceId).toList()
        : [deviceId, ...state.where((id) => id != deviceId)];
    state = updated;
    await ref.read(preferencesServiceProvider).setFavoriteDeviceIds(
          userId,
          updated,
        );
  }

  Future<void> syncStored(List<String> ids) async {
    final userId = _readUserId();
    if (userId == null || listEquals(state, ids)) return;
    state = ids;
    await ref.read(preferencesServiceProvider).setFavoriteDeviceIds(userId, ids);
  }
}

final favoriteDevicesProvider =
    NotifierProvider<FavoriteDevicesNotifier, List<String>>(
  FavoriteDevicesNotifier.new,
);
