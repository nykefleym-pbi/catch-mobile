# ADR 0005 — Launch-readiness: accessibility, localization & experience polish

**Status:** Accepted · **Date:** 2026-07-22

## Context

The Phase 1–3 surfaces are built and CI-green. Before a first real market (the
Philippines — `LAUNCH_MARKETS=PH`), the roadmap adds a cross-phase
["Launch-readiness"](../product/03-roadmap.md) block of nine experience,
accessibility, and localization enhancements. Several of them make **structural**
choices that outlive any single ticket and touch the binding pillars
(privacy/data-minimization per [ADR 0003](0003-child-safety-strategy.md), owner-only
RLS and no-dark-patterns per [ADR 0004](0004-phase3-social-safety.md), and the
honest-impact rule from [Monetization & Impact](../09-monetization-and-impact.md)).
This ADR records those durable decisions so the per-item build work stays inside
the guardrails.

## Decision

1. **i18n is a scaffold, Tagalog-first, migrated incrementally.** UI copy is
   externalized behind an `AppLocalizations` layer (`lib/l10n/`) with per-locale
   string tables; English is the template/fallback, **`fil`** (Filipino) is the
   launch locale. `flutter_localizations` supplies Material/Cupertino strings and
   the locale is a **device-only** preference (never persisted server-side). The
   first slice ships a hand-rolled delegate (the CI box can't run `flutter
   gen-l10n`); **migrating the tables to `.arb` + `flutter gen-l10n` is the
   follow-up** once codegen can run locally — the getter surface is designed so
   that migration is mechanical. Modules are localized incrementally; never
   migrate all screens in one PR.

2. **Notifications are local-only, opt-in, and off for minors.** Reminders are
   scheduled **on-device** from the client's own care model — **no FCM, no push
   token, no server-side scheduling or targeting.** They are opt-in, off by
   default, frequency-capped, and **structurally forced off in reduced-data/minor
   mode**. Content carries no urgency/streak/FOMO framing (the reminder-policy
   function takes no urgency input by construction).

3. **Owner-only free text (diary notes, personal tags) is on-device for minors,
   server-synced for adults.** Both are owner-only (RLS `profile_id = auth.uid()`,
   no shared-read policy, never a cross-user surface, so no moderation debt).
   Because minor-authored free text persisted server-side brushes the ADR 0003
   minimization posture, minors keep this content **on-device only**; adults get
   server sync. Minimization is thus enforced by construction, not intention. If
   either ever becomes shareable, it must route through the Trust & Safety
   substrate first.

4. **"Impact so far" is own-data-honest only.** The impact surface shows only
   truthful aggregates of the player's own data (cats met, places explored, bond,
   lessons learned, care given). It **must never show fabricated donation,
   "cats helped", fundraising, or partner numbers** — those fields do not exist in
   the client pre-Phase 4 and stay gated on the Phase 4 legitimacy criteria. A
   unit test asserts the impact model has no such field.

5. **Diary stores no precise location.** Diary entries snapshot only a coarse
   `location_label`, never `geo_lat/geo_lng` — enforced by column omission, same
   bright line as the rest of the app.

## Consequences / Caveats

- **Sequencing.** Two keystones come first: **K1** an app-preferences store
  (SharedPreferences + a Profile → Settings entry) and **K2** the i18n scaffold.
  K2 unblocks localized copy everywhere; K1 unblocks the locale override, tutorial
  reset, notification prefs, and reachability toggle. The recommended slice order
  is A (foundations) → B (reachability harness, tags, impact) → C (diary, woven
  lessons) → D (tutorial) → E (notifications, sprite tracks); localization threads
  through B–E.
- **Native setup risk.** Notifications need `flutter_local_notifications` + Android
  13 `POST_NOTIFICATIONS` runtime permission and a channel — the highest-risk item
  for the APK build; prototype behind the opt-in gate.
- **Deprecation watch.** Text-scaling work must use `TextScaler`, not the
  deprecated `textScaleFactor`, or `flutter analyze` fails.
- **Human sign-off required before shipping** items that touch child-safety/legal
  (see Your-side items). Items 1, 2 (tutorial), 6, 7, 9 carry no legal gate.

## Your-side items (a human must do these)

- **Confirm the minor free-text posture** (decision 3 — diary/tags on-device for
  minors) in the pre-launch legal review; tracked in
  [`docs/legal/OPEN-ITEMS.md`](../legal/OPEN-ITEMS.md).
- **Review notification copy + the minor-off default** with product/legal before
  enabling item 3 for real.
- **Sign off "Impact so far" copy** so it never drifts toward implying real-world
  impact numbers before Phase 4.
