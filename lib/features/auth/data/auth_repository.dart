import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/supabase/supabase_providers.dart';

/// Cloud account for grown-ups: link the cozy anonymous guest to an email +
/// password so their CatDex syncs across devices, and sign back in elsewhere.
///
/// Linking uses [GoTrueClient.updateUser] on the *current* anonymous user, so
/// the user id — and therefore every caught cat and profile row (all scoped by
/// `profile_id` under RLS) — carries straight over. No data migration needed.
class AuthRepository {
  AuthRepository(this._ref);

  final Ref _ref;

  GoTrueClient get _auth => _ref.read(supabaseClientProvider).auth;

  User? get currentUser => _auth.currentUser;

  /// Whether the guardian is on a real (email) cloud account rather than the
  /// device-only anonymous guest.
  bool get isCloudAccount {
    final user = currentUser;
    return user != null && user.isAnonymous == false && user.email != null;
  }

  String? get email => currentUser?.email;

  /// Backs the current guest up to the cloud by attaching an email + password.
  /// Same user id, so caught cats are preserved. If the project requires email
  /// confirmation, Supabase emails a link the guardian must click to finish.
  Future<void> linkEmail({
    required String email,
    required String password,
  }) async {
    await _auth.updateUser(
      UserAttributes(email: email, password: password),
    );
  }

  /// Signs into an existing cloud account (e.g. on a new device), swapping the
  /// current session for the account's — their synced cats then load.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  /// Signs out and returns to a fresh anonymous guest so the app stays usable
  /// (the cozy no-signup default). The cloud account's data remains in the
  /// cloud, ready for the next sign-in.
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _auth.signInAnonymously();
    } catch (_) {
      // Anonymous sign-in may be disabled on the project; the UI still renders,
      // it just can't persist until the guardian signs in again.
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref);
});
