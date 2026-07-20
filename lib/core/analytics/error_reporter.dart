import 'package:flutter/foundation.dart';

import 'analytics_service.dart';

/// Installs Flutter's two global error hooks so uncaught errors are forwarded to
/// [service]. This is the FALLBACK crash path used only when Sentry is not
/// configured (ADR 0002) — when a Sentry DSN is present, Sentry owns these hooks
/// and we must not clobber them, so `main` calls this only in the no-Sentry
/// branch.
///
/// Both hooks chain to whatever handler was already installed, so Flutter's
/// default error presentation still runs.
void installAnalyticsCrashHandlers(AnalyticsService service) {
  final priorFlutterOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    service.recordError(details.exception, details.stack, fatal: false);
    priorFlutterOnError?.call(details);
  };

  final priorPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    service.recordError(error, stack, fatal: true);
    // Preserve any previously-registered handler's verdict; default to "handled"
    // so an isolated async error never hard-crashes the cozy app.
    return priorPlatformOnError?.call(error, stack) ?? true;
  };
}
