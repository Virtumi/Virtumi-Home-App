import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/services/preferences_service.dart';
import '../data/local_app_settings_repository.dart';
import '../models/app_settings.dart';

final connectionAppSettingsProvider = FutureProvider<AppSettings?>((ref) async {
  // Invalidated by [AppSettingsBootstrap] when the signed-in user changes.
  final userId = ref.read(authUserIdProvider);
  if (userId == null) return null;
  final repo = LocalAppSettingsRepository(
    ref.watch(preferencesServiceProvider),
  );
  return repo.getSettings(userId);
});

/// Current connection mode: `cloud` or `direct`.
final connectionModeProvider = Provider<String>((ref) {
  return ref.watch(connectionAppSettingsProvider).value?.connectionMode ??
      'cloud';
});

/// True when the app uses local UDP instead of Supabase for device I/O.
final isDirectConnectionProvider = Provider<bool>((ref) {
  return ref.watch(connectionModeProvider) == 'direct';
});
