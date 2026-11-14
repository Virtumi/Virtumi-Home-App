import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String phone = '',
    String addressStreet = '',
    String addressPostalCode = '',
    String addressCity = '',
    String addressCountry = 'Deutschland',
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'full_name': '$firstName $lastName'.trim(),
        'phone': phone,
        'address_street': addressStreet,
        'address_postal_code': addressPostalCode,
        'address_city': addressCity,
        'address_country': addressCountry,
      },
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
