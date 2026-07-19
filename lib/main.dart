import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'features/onboarding/data/onboarding_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolve persisted preferences up front so the router can decide the
  // first-launch onboarding gate synchronously.
  final prefs = await SharedPreferences.getInstance();

  // Initialize Supabase if configured. The app still boots without it so the
  // UI/scaffold can be worked on before a backend exists.
  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // Supabase renamed the client-side key "anon" -> "publishable"; same value,
      // safe to ship (RLS enforces access).
      publishableKey: Env.supabaseAnonKey,
    );

    // Cozy, no-signup entry: give every install an anonymous session so captures
    // can persist under RLS (the auth trigger creates the profile row). If
    // anonymous sign-ins aren't enabled on the project yet, don't crash — the
    // capture + detection UI works locally; only persistence needs a session.
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) {
      try {
        await auth.signInAnonymously();
      } catch (error) {
        // Sentry isn't initialized yet at this point, so just log.
        debugPrint('Anonymous sign-in unavailable: $error');
      }
    }
  }

  Widget appRoot() => ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const CatchApp(),
      );

  // Wrap in Sentry only when a DSN is supplied (ADR 0002); otherwise run plain.
  if (Env.hasSentry) {
    await SentryFlutter.init(
      (options) => options.dsn = Env.sentryDsn,
      appRunner: () => runApp(appRoot()),
    );
  } else {
    runApp(appRoot());
  }
}
