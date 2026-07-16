# Development

Phase 0 scaffold for Cat-ch (see [docs/product/03-roadmap.md](docs/product/03-roadmap.md)).
This sets up the Flutter app skeleton, Riverpod + Sentry + Supabase wiring, the
v1 database schema, and the `generate-companion` Edge Function boundary. Feature
bodies (camera, map, detection, generation) land in Phase 1.

> ⚠️ This scaffold was authored without a local Flutter toolchain, so it has not
> been compiled here — **CI (`flutter analyze` + `flutter test`) is the first
> real verification.** Expect to run `flutter pub get` / `flutter pub upgrade`
> once and adjust dependency versions if resolution complains.

## Prerequisites

- Flutter (stable channel), Dart SDK ≥ 3.5
- A Supabase project (free tier)
- Accounts noted in the ADRs: Google AI Studio (Gemini key), Sentry (DSN)

## First-time setup

1. **Generate the native platform folders** (not committed — they're created by
   Flutter tooling):

   ```bash
   flutter create . --org com.example --platforms=android,ios
   ```

   > Not developing locally? You don't need this — the **Build Android APK**
   > GitHub Actions workflow generates the platform folder and produces an
   > installable `app-debug.apk` artifact you can download and sideload.

   This adds `android/` and `ios/` without touching `lib/`, `pubspec.yaml`, or
   the tests.

2. **Install dependencies:**

   ```bash
   flutter pub get
   ```

3. **Apply the database schema** to your Supabase project (via the Supabase CLI
   or dashboard SQL editor), in order:
   - `supabase/migrations/0001_init.sql`
   - `supabase/migrations/0002_seed_reference_data.sql`

4. **Run the app** with configuration passed as `--dart-define` (no secrets in
   source — see `lib/core/config/env.dart`):

   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
     --dart-define=SENTRY_DSN=YOUR_SENTRY_DSN   # optional
   ```

   The app also boots with no defines (backend/crash-reporting simply disabled),
   so UI work doesn't require a backend.

## Edge Function

The `generate-companion` function holds the provider key and enforces auth,
rate-limits, moderation, and source-photo deletion (ADR 0001). Local dev:

```bash
cp supabase/.env.example supabase/.env   # fill in GEMINI_API_KEY (git-ignored)
supabase functions serve generate-companion --env-file supabase/.env
```

## Project layout

```
lib/
  main.dart                     # bootstrap: Supabase + Sentry + ProviderScope
  app.dart                      # MaterialApp.router + theme
  core/
    config/env.dart             # --dart-define config (no secrets)
    theme/app_theme.dart        # cozy Material 3 theme
    router/app_router.dart      # go_router routes
    widgets/                     # shared widgets (PlaceholderScaffold)
  data/supabase/                # Supabase client + auth providers
  features/                     # feature-first modules
    home/                       # bottom-nav shell
    map/ catdex/ capture/ profile/
    capture/domain/cat_detector.dart   # on-device detection contract
  services/generation/          # generate-companion client (behind Edge Function)
supabase/
  migrations/                   # v1 schema + seed
  functions/generate-companion/ # Edge Function (Phase 1 body)
test/                           # widget test
```

## Conventions

- **State:** Riverpod everywhere (ADR 0002).
- **Secrets:** never in the client. Provider keys live only in the Edge Function.
- **Privacy:** location fuzzed before upload; source photos deleted after
  generation (ADR 0001, docs/08-ethics-privacy-safety.md).
