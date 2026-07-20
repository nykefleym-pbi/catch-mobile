/// The fixed vocabulary of product-analytics events. Keeping event names in an
/// enum (never free-form strings at call sites) means the set of things we
/// measure is auditable in one place — important for a privacy-first app where
/// "what do we collect?" must have a short, honest answer
/// (docs/08-ethics-privacy-safety.md §Data minimization).
enum AnalyticsEventName {
  appOpened('app_opened'),
  captureSucceeded('capture_succeeded'),
  captureRejected('capture_rejected'),
  generationSucceeded('generation_succeeded'),
  generationFailed('generation_failed'),
  careFed('care_fed'),
  carePlayed('care_played'),
  careGroomed('care_groomed');

  const AnalyticsEventName(this.token);

  /// The stable wire name (snake_case) sent to any analytics sink.
  final String token;
}

/// Sanitizes analytics parameters so nothing sensitive can ever ride along with
/// an event. This is the enforcement point for the product's data-minimization
/// rule (ADR 0003): analytics is aggregate and anonymous, never a channel for
/// PII or a real cat's location.
class AnalyticsSanitizer {
  const AnalyticsSanitizer._();

  /// Parameter keys (or key substrings) that must never be sent — identifiers,
  /// contact info, and anything location-shaped. Matching is case-insensitive
  /// and substring-based so `geo_lat`, `latitude`, `home_address`, etc. are all
  /// caught.
  static const List<String> _blockedKeySubstrings = [
    'lat',
    'lng',
    'lon',
    'coord',
    'location',
    'geo',
    'address',
    'email',
    'phone',
    'name',
    'token',
    'secret',
    'password',
    'id',
  ];

  static const int _maxStringLength = 64;

  static bool _keyIsBlocked(String key) {
    final k = key.toLowerCase();
    return _blockedKeySubstrings.any(k.contains);
  }

  /// Returns a clean copy of [params] safe to send with an event:
  /// - when [reducedData] is true (minor / reduced-data mode) NOTHING is kept —
  ///   only the event name itself is ever sent for minors;
  /// - blocked keys are dropped;
  /// - only primitive values (String/int/double/bool) survive — no nested
  ///   objects that could smuggle richer data through;
  /// - strings are clamped to a short length so free text can't leak in.
  static Map<String, Object> clean(
    Map<String, Object?> params, {
    required bool reducedData,
  }) {
    if (reducedData) return const {};
    final out = <String, Object>{};
    params.forEach((key, value) {
      if (_keyIsBlocked(key)) return;
      if (value is bool || value is int || value is double) {
        out[key] = value;
      } else if (value is String) {
        out[key] = value.length > _maxStringLength
            ? value.substring(0, _maxStringLength)
            : value;
      }
      // Anything else (Map/List/null/custom object) is intentionally dropped.
    });
    return out;
  }
}
