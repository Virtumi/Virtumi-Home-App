import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/services/preferences_service.dart';

/// Persists the last opened house ids (max. 2) for the Home houses grid,
/// stored per signed-in user.
class RecentHouseActivityNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final userId = ref.watch(authUserIdProvider);
    if (userId == null) return const [];
    return ref.read(preferencesServiceProvider).recentHouseIds(userId);
  }

  Future<void> record(String houseId) async {
    final userId = ref.read(authUserIdProvider);
    if (userId == null) return;
    final updated = [
      houseId,
      ...state.where((id) => id != houseId),
    ].take(PreferencesService.maxRecentHouses).toList();

    state = updated;
    await ref.read(preferencesServiceProvider).setRecentHouseIds(userId, updated);
  }

  Future<void> syncStored(List<String> ids) async {
    final userId = ref.read(authUserIdProvider);
    if (userId == null || listEquals(state, ids)) return;
    state = ids;
    await ref.read(preferencesServiceProvider).setRecentHouseIds(userId, ids);
  }
}

final recentHouseActivityProvider =
    NotifierProvider<RecentHouseActivityNotifier, List<String>>(
  RecentHouseActivityNotifier.new,
);
