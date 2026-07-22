# 03 — Roadmap

A **phased**, capability-driven plan. Phases are ordered by dependency and value,
**not** locked to calendar dates — each lists entry criteria (what must be true to
start) and the systems it unlocks. Ship, learn, and re-sequence as real usage data
arrives.

Design and technical detail for the systems named here lives in
[Game Systems](04-game-systems.md),
[Technical Architecture](../architecture/05-technical-architecture.md),
[Data Model](../architecture/06-data-model.md), and
[AI Pipeline](../architecture/07-ai-pipeline.md).

---

## Phase 0 — Foundations

**Goal:** a healthy skeleton to build on; no player-facing features yet.

- Flutter project scaffold (feature-first structure), CI (lint, test, build),
  code style, and branch conventions.
- Supabase project: auth, database, storage, and environment/secret management.
- Cloud generation service contract stubbed (interface, not implementation).
- Design system foundations: color, type, spacing, core components, and the cozy
  art direction from [Vision](01-vision.md).
- Analytics and crash reporting wired.

**Entry criteria:** approved plan (this documentation set).
**Unlocks:** everything below.

---

## Phase 1 — MVP: the Capture → CatDex core loop

**Goal:** ship and validate the emotional core. Scope is defined in full in
[MVP Scope](02-mvp-scope.md).

- Onboarding/auth, permission priming, age-appropriate consent.
- Cozy map & exploration framing.
- In-game camera → **on-device detection** (accept real cats; reject
  drawings/toys/screens; quality gate).
- **Cloud companion generation** → transparent sprite.
- CatDex with v1 fields; privacy-fuzzed capture location.
- Basic care: hunger + happiness + feeding; simple idle presentation.
- Core-loop analytics.

**Entry criteria:** Phase 0 complete.
**Unlocks:** a validated loop and real data on generation quality, detection
accuracy, and retention — the evidence base for investing in everything after.

---

## Phase 2 — Care & collection depth

**Goal:** deepen the single-player cozy experience so companions feel alive and
worth returning to.

- Full **Tamagotchi needs** model: hunger, happiness, hygiene, sleep, affection,
  play — with gentle, non-punitive decay (mood shifts, no loss).
- **Grooming** (cosmetic): brushing, bathing, claw trimming, ear cleaning,
  collars, accessories.
- **Home decoration**: beds, scratching posts, cat trees, plants, rugs, toys, etc.
- **Personality effects**: traits meaningfully modulate interactions and care.
- **Growth stages**: kitten → young → adult → senior, appearance maturing while
  identity persists.
- Richer CatDex fields (breed/age/weight estimates, favorite food, idle-animation
  variety, achievement badges) and skeletal/frame idle animations.

**Entry criteria:** MVP retention and generation quality clear an agreed bar.
**Unlocks:** enough depth to sustain daily engagement and justify social/live-ops.

---

## Phase 3 — Social & friendly PvP

**Goal:** connect players kindly; add optional, playful competition.

- Friends, visiting, cosmetic trading, CatDex showcases, shared photo albums.
- Clubs and cooperative challenges.
- **Friendly PvP**: zoomie races, agility/obstacle courses, toy competitions,
  paw wrestling, treasure hunts — using stats and abilities from
  [Game Systems](04-game-systems.md), designed so **skill and preparation beat
  spending**.
- Community-kindness guardrails and moderation for all social surfaces.

The **safety foundation** for this phase (age gate + reduced-data minor mode,
report/block substrate, friends-only graph, opt-in showcase, structural
no-pay-to-win stats, cosmetic-only trading rules) is designed in
[ADR 0004](../decisions/0004-phase3-social-safety.md); live matchmaking/trading
stay gated off until moderation + realtime are ready.

**Entry criteria:** stable core + care depth; moderation tooling ready enough for
user-to-user interaction.
**Unlocks:** network effects and community identity.

---

## Launch-readiness — experience, accessibility & localization (cross-phase)

**Goal:** harden the already-shipped experience for a real first market (PH) —
easier to understand, kinder to return to, reachable by more people. These run
**alongside** Phase 2–3 work rather than after it; each preserves the pillars
(cozy, cosmetic-only, welfare-wins, no dark patterns, privacy).

1. **Localization — Tagalog (first locale).** Externalize all UI strings behind
   an i18n layer (`intl` / `flutter gen-l10n`) and ship **Tagalog + English**.
   Pulls the Phase 5 localization work forward for the launch market; the
   scaffold makes later locales additive. No hardcoded copy in widgets.
2. **Per-screen first-run tutorial.** Lightweight, contextual coach-marks the
   first time each screen is opened (camera, map, CatDex, care, social). Always
   skippable, never blocking, shown once, and **resettable in Settings** — a
   guide, not a gate (no dark patterns). Honours reduce-motion and screen
   readers.
3. **Mobile notifications.** Gentle, **opt-in**, minor-aware (off by default in
   reduced-data mode) reminders — a cat enjoying a sunbeam, a need easing — with
   frequency caps and one-tap off. Never FOMO, streak-shame, or manipulative
   timing.
4. **Per-cat diary.** An owner-only timeline of little moments, notes, and where
   each cat was met (coarse location only), deepening attachment. RLS
   owner-scoped; no precise coordinates; not a shared surface.
5. **Personal tagging.** Player-defined, **private** free-text tags on any cat,
   used to filter/sort the CatDex (replaces fixed "themes" with the player's own
   organisation). Owner-only — tags are never shown to other players, so no
   moderation surface is introduced. (If tags ever become shareable, they must
   route through the Trust & Safety substrate first.)
6. **Text scaling & one-handed reachability.** Respect the OS text-size setting
   with layouts that reflow (no clipping/overflow), and keep primary actions
   within thumb reach on tall devices. Part of the broader accessibility pass
   (with the existing reduce-motion support).
7. **Academy lessons woven into actions.** Surface the relevant welfare lesson at
   the moment it matters (e.g. a hydration tip when hygiene/thirst is low),
   linking in-game care to real-world kindness. Welfare-wins, never nagging.
8. **"Impact so far."** A gentle, **honest** surface of the good done. Pre-Phase-4
   it shows only truthful, own-data kindness (cats met, lessons learned, care
   given) — **never fabricated donation or "cats helped" numbers**. Real impact
   figures stay gated on the Phase 4 legitimacy criteria.
9. **Sprite consistency.** A post-generation normalisation pass (uniform
   scale/padding, palette/level nudge) plus a curated fallback set, so generated
   companions read as one cohesive art set despite provider variance. Quality/
   perceived-polish, no gameplay effect.

The durable architecture choices for this section (Tagalog-first i18n scaffold,
local-only/minor-off notifications, minor free-text kept on-device, own-data-honest
impact, coarse-only diary location) are recorded in
[ADR 0005](../decisions/0005-launch-readiness-accessibility-localization.md).

**Entry criteria:** none beyond the shipped Phase 1–3 surfaces; item 8's real
impact figures wait on Phase 4, item 1 unblocks localized copy everywhere.
**Unlocks:** a launch-ready, accessible, localized experience for the first
market — better comprehension, kinder retention, wider reach.

---

## Phase 4 — Impact & guardianship

**Goal:** deliver on the mission — the reason Cat-ch exists.

- **Cat Guardian** progression (New Friend → … → Legendary Guardian), unlocking
  cosmetics/titles/badges only.
- **Guardian Missions**: optional, safe, responsible real-world actions
  (responsibly feeding a community cat, supporting partner shelters, learning
  responsible care) — designed to never encourage unsafe or disruptive behavior.
- **Shelter partnerships**: featured shelters, adoptable cats, rescue stories,
  supply wishlists, donation campaigns, volunteer opportunities.
- **Community goals**: worldwide collaborative objectives (meals funded, adoption
  awareness, fundraising milestones).
- **Transparency reporting** pipeline (revenue, donations, partners, cats helped).

**Entry criteria:** the legal/financial and partner-vetting scaffolding from
[Monetization & Impact](../09-monetization-and-impact.md) is in place. This phase
is **gated on real-world legitimacy**, not just engineering.
**Unlocks:** the movement — and the honest annual report the vision describes.

---

## Phase 5 — Live-ops & scale

**Goal:** keep the world fresh and run it responsibly at scale.

- Seasonal and charity events.
- Mature moderation, trust & safety, and customer-support tooling.
- Internationalization and localization — broadened beyond the launch-readiness
  Tagalog-first locale (see cross-phase section) to additional markets.
- Performance, cost, and reliability hardening for the generation pipeline and
  realtime features.

**Entry criteria:** a live community large enough to warrant ongoing events and
dedicated ops.
**Unlocks:** longevity.

---

## Sequencing principles

- **Validate before you scale.** No phase starts until the previous one clears its
  bar; the MVP is a genuine go/no-go gate.
- **Mission features are gated on legitimacy.** Donation, shelter, and impact
  features do not ship until they can be delivered honestly and legally.
- **Every phase preserves the pillars.** New systems must not introduce
  pay-to-win, dark patterns, or incentives to disturb animals — see
  [Vision](01-vision.md) and [Ethics, Privacy & Safety](../08-ethics-privacy-safety.md).
