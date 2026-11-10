import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/services/preferences_service.dart';

/// Device ids marked as favorites, newest first, stored per signed-in user.
class FavoriteDevicesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    ref.watch(authStateProvider);
    final userId = _readUserId();
    if (userId == null) return const [];
    return ref.read(preferencesServiceProvider).favoriteDeviceIds(userId);
  }

  String? _readUserId() {
    final auth = ref.read(authStateProvider);
    return auth.maybeWhen(
      data: (state) => state.session?.user.id,
      orElse: () => ref.read(authRepositoryProvider).currentSession?.user.id,
    );
  }

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
