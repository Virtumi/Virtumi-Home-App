import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/services/preferences_service.dart';

/// Persists the last controlled device ids (max. 3) for the Home activity
/// list, stored per signed-in user.
class RecentDeviceActivityNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final userId = ref.watch(authUserIdProvider);
    if (userId == null) return const [];
    return ref.read(preferencesServiceProvider).recentDeviceIds(userId);
  }

  Future<void> record(String deviceId) async {
    final userId = ref.read(authUserIdProvider);
    if (userId == null) return;
    final updated = [
      deviceId,
      ...state.where((id) => id != deviceId),
    ].take(PreferencesService.maxRecentDevices).toList();

    state = updated;
    await ref.read(preferencesServiceProvider).setRecentDeviceIds(userId, updated);
  }

  Future<void> syncStored(List<String> ids) async {
    final userId = ref.read(authUserIdProvider);
    if (userId == null || listEquals(state, ids)) return;
    state = ids;
    await ref.read(preferencesServiceProvider).setRecentDeviceIds(userId, ids);
  }
}

final recentDeviceActivityProvider =
    NotifierProvider<RecentDeviceActivityNotifier, List<String>>(
  RecentDeviceActivityNotifier.new,
);
