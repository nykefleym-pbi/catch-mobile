import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exposes the initialized Supabase client to the Riverpod graph.
///
/// `Supabase.initialize(...)` runs once in `main()`; this provider simply hands
/// the singleton client to features. Overridden in tests with a fake.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// The current auth session as a reactive stream (null when signed out).
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});
