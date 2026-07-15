# ADR 0002 — Phase 0 tech: state management, crash reporting, CI

- **Status:** Accepted
- **Date:** 2026-07-15
- **Relates to:** [Technical Architecture](../architecture/05-technical-architecture.md),
  [Roadmap](../product/03-roadmap.md) (Phase 0),
  [Risks & Open Questions](../10-risks-and-open-questions.md)

## Context

Phase 0 needs a few foundational engineering choices settled before code starts.
Cat-ch is a **small side project**, so the bias is toward **low-boilerplate,
free, and few moving parts** — avoid infrastructure the project won't use.

## Decision

- **State management: Riverpod.** Compile-safe, low-boilerplate, and async-friendly
  — a natural fit for the loading/error/data states throughout capture →
  generation → CatDex. Chosen over Bloc (more ceremony than needed) and plain
  `setState` (doesn't scale past a couple of screens). Applied consistently across
  feature modules.
- **Crash reporting: Sentry (free tier).** Keeps the backend **Supabase-only** and
  avoids pulling in the Firebase SDK just for crash reporting. Free tier is ample
  for a small audience.
- **Product analytics: minimal for the MVP.** Instrument only the core-loop events
  named as success metrics in [MVP Scope](../product/02-mvp-scope.md) (activation,
  captures/week, generation success + cost, detection accuracy, crash-free rate).
  No heavyweight analytics SDK for v1.
- **CI: GitHub Actions, minimal.** One workflow running `flutter analyze` +
  `flutter test` on pull requests. Expand only when the project warrants it.

## Consequences / caveats

- Sentry means one extra third-party account/DSN (free) held server/app-side; the
  DSN is not a secret but keep it in config, not hard-coded ad hoc.
- Minimal analytics means limited product insight at launch — acceptable trade for
  a side project; revisit if we want funnel data later.
- Riverpod is a firm convention: mixing in other state approaches later creates
  inconsistency, so new modules should follow it.

## Your-side items (maintainer)

- [ ] Create a free **Sentry** account and project; you'll hold the DSN (added to
      app/server config, not pasted into chat).
- [ ] No other maintainer action — Riverpod and GitHub Actions need no accounts.
