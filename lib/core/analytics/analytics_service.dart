import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_event.dart';

/// A privacy-safe analytics + error sink. The interface is deliberately tiny —
/// a fixed set of named events plus error reporting — so every measurement
/// point in the app routes through one auditable seam. Parameters are always
/// run through [AnalyticsSanitizer] before they reach a sink, and the caller
/// passes [reducedData] (true for minors) so the data-minimization rule is
/// applied at the source (docs/08-ethics-privacy-safety.md; ADR 0003).
///
/// The default binding is [NoopAnalytics] — the app ships measuring nothing
/// until a real, reviewed sink is wired. Crash reporting is handled by Sentry
/// when a DSN is configured (ADR 0002); this seam adds the *product* analytics
/// layer and a fallback error path when Sentry is absent.
abstract class AnalyticsService {
  void log(
    AnalyticsEventName name, {
    Map<String, Object?> params,
    bool reducedData,
  });

  void recordError(Object error, StackTrace? stack, {bool fatal});
}

/// The safe default: measures nothing, sends nothing. In debug builds it prints
/// the sanitized event so wiring can be eyeballed locally; in release it is a
/// pure no-op.
class NoopAnalytics implements AnalyticsService {
  const NoopAnalytics();

  @override
  void log(
    AnalyticsEventName name, {
    Map<String, Object?> params = const {},
    bool reducedData = false,
  }) {
    if (kDebugMode) {
      final clean = AnalyticsSanitizer.clean(params, reducedData: reducedData);
      debugPrint('[analytics] ${name.token} $clean');
    }
  }

  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    if (kDebugMode) {
      debugPrint('[analytics] error (fatal=$fatal): $error');
    }
  }
}

/// The app's analytics sink. Overridable in tests and swappable for a real,
/// reviewed implementation later without touching any call site.
final analyticsProvider = Provider<AnalyticsService>(
  (ref) => const NoopAnalytics(),
);
