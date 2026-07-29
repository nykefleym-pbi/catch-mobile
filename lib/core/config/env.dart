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

  /// Comma-separated ISO 3166-1 alpha-2 country codes where **live** social is
  /// permitted — i.e. the markets whose store privacy declarations / legal
  /// review have cleared (pre-launch dossier §5.4, §7.4). Empty means *no geo
  /// restriction* (dev / single-region default); set it to gate live social to
  /// specific launch markets without touching code. Passed at build time, e.g.
  /// `--dart-define=LAUNCH_MARKETS=US,CA`.
  static const String _launchMarketsRaw =
      String.fromEnvironment('LAUNCH_MARKETS');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasSentry => sentryDsn.isNotEmpty;

  /// The parsed launch-market allowlist (upper-cased, blanks dropped). An empty
  /// set means live social is not geo-restricted.
  static Set<String> get launchMarkets => _launchMarketsRaw
      .split(',')
      .map((code) => code.trim().toUpperCase())
      .where((code) => code.isNotEmpty)
      .toSet();
}
