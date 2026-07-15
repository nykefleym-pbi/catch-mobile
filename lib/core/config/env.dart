/// Compile-time configuration, supplied via `--dart-define`.
///
/// Nothing secret is hard-coded. Pass values at build/run time, e.g.:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=... \
///   --dart-define=SENTRY_DSN=...
/// ```
///
/// The Supabase anon key is safe for the client (RLS enforces access). The
/// Gemini / generation provider key is NOT here — it lives only in the
/// `generate-companion` Supabase Edge Function (see ADR 0001).
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Optional — crash reporting is disabled when empty (e.g. local dev).
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasSentry => sentryDsn.isNotEmpty;
}
