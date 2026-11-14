import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/data/supabase/supabase_auth_repository.dart';
import '../../shared/domain/auth_repository.dart';
import '../supabase/supabase_client.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (state) => state.session != null,
    orElse: () => ref.watch(authRepositoryProvider).currentSession != null,
  );
});

/// Holds the id of the signed-in user (null when signed out).
///
/// Per-user providers watch [authUserIdProvider] so they are rebuilt on login,
/// logout and account switch. A plain `auth.currentUser` read inside a
/// provider is evaluated only once and would keep a stale (null) value from
/// the login screen until the app is restarted.
///
/// Implemented as a [Notifier] that listens to the auth stream itself instead
/// of watching a StreamProvider: stream events arrive outside the build phase,
/// so dependent providers are never invalidated while widgets are building.
/// Token refreshes keep the same id and do not notify listeners.
class AuthUserId extends Notifier<String?> {
  @override
  String? build() {
    final client = ref.watch(supabaseClientProvider);
    final subscription = client.auth.onAuthStateChange.listen((data) {
      final id = data.session?.user.id;
      if (id != state) state = id;
    });
    ref.onDispose(subscription.cancel);
    return client.auth.currentUser?.id;
  }
}

final authUserIdProvider =
    NotifierProvider<AuthUserId, String?>(AuthUserId.new);