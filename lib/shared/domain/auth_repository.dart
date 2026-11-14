import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstraction over Supabase Auth (email/password).
abstract interface class AuthRepository {
  Stream<AuthState> authStateChanges();

  Session? get currentSession;

  Future<void> signIn({required String email, required String password});

  /// Registers a new user. [firstName] and [lastName] are required; the
  /// remaining profile fields are optional and stored as user metadata, from
  /// which a DB trigger creates the `user_profiles` row.
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
  });

  Future<void> signOut();
}
