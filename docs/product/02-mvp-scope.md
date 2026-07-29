# 02 — MVP Scope (v1)

## Purpose of the MVP

Prove the **emotional core** of Cat-ch with the smallest coherent product: *walk,
discover a real cat, capture it, watch it transform into a unique companion,
collect it, and care for it a little.* If this loop is delightful and trustworthy,
everything else in the [Roadmap](03-roadmap.md) is worth building. If it isn't, no
amount of PvP, social, or shelter features will save it.

The MVP deliberately leads with the **Capture → CatDex core loop** and defers the
rest.

## The v1 core loop

1. Open the app and see a cozy map of the area around you.
2. Walk; the app encourages gentle exploration (no precise-location incentives —
   see privacy notes below).
3. Open the in-game **camera** and photograph a real cat you encounter.
4. **On-device AI** verifies it's a genuine cat and passes a quality check
   (rejects drawings, toys, screens, and unusable photos).
5. The accepted photo is sent to a **cloud generation** service that returns a
   stylized, transparent-background companion sprite that echoes the real cat's
   colors, patterns, eye color, and distinctive features.
6. The cat is **registered in the CatDex** with its core metadata.
7. The player can perform **basic care** — feed it and raise its happiness — and
   see a **simple idle animation**.
8. Repeat: keep exploring to discover more cats.

## In scope for v1

- **Onboarding & auth** — lightweight account creation (Supabase Auth), permission
  priming for camera and location with clear rationale, age-gate/consent flow
  appropriate for a minor-inclusive audience.
- **Map & exploration** — a cozy map centered on the player; movement-based
  discovery framing. No adversarial spawning mechanics.
- **In-game camera** — capture flow built on the device camera.
- **On-device cat detection** — "is this a real cat?" classifier plus a basic
  image-quality gate; rejects non-cats (drawings, plush toys, TV/monitor screens)
  with friendly, non-punitive feedback. See
  [AI Pipeline](../architecture/07-ai-pipeline.md).
- **Cloud companion generation** — one stylized **transparent PNG sprite** per
  captured cat, conditioned on the source photo to preserve identity as closely as
  the model allows (see the fidelity caveat in the AI Pipeline doc). Static sprite
  is sufficient for v1; animated idle is a stretch goal.
- **CatDex** — a growing collection view. v1 entry fields:
  - Name / nickname (player-set)
  - Coat color and fur pattern (from generation metadata / simple heuristics)
  - Date discovered
  - Capture location, **privacy-fuzzed** (region/neighborhood-level, never precise)
  - One assigned **personality trait** (procedural; full trait effects deferred)
  - Friendship / affection level
  - The generated companion sprite
- **Basic care loop** — two needs in v1: **hunger** and **happiness**. Feeding
  (from a small starter set of foods) raises affection and temporarily improves
  mood. Neglect gently lowers mood; it never harms or removes a companion.
- **Simple idle presentation** — at minimum a static sprite with a subtle
  animation (e.g. a breathing/blink loop). Skeletal/frame animation is a stretch
  goal, not a gate.

### v1 entry fields vs. the full CatDex

The full brief lists many more CatDex fields (breed estimation, estimated age and
weight, favorite food, achievement badges, multiple idle animations, etc.). Those
are captured in [Game Systems](04-game-systems.md) and layered in during
[Phase 2](03-roadmap.md); v1 ships the subset above.

## Explicitly out of scope for v1 (deferred, not dropped)

Documented in [Game Systems](04-game-systems.md) and sequenced in the
[Roadmap](03-roadmap.md):

- Friendly PvP (zoomie races, agility contests, abilities, stats)
- Home decoration and furniture
- Grooming (brushing, bathing, claws, ears, collars, accessories)
- Full Tamagotchi needs model (hygiene, sleep, play in addition to hunger/happiness)
- Growth stages (kitten → senior)
- Social features (friends, visiting, trading, clubs, showcases, photo albums)
- Guardian ranks and real-world Guardian Missions
- Community goals and shelter partnerships
- Seasonal/live events
- In-app purchases and the donation/impact reporting pipeline

Deferring monetization from v1 is intentional: we validate the loop first, and the
donation model needs real legal/financial scaffolding before it can ship (see
[Monetization & Impact](../09-monetization-and-impact.md)).

## Success metrics (validate the loop, honestly)

Targets to be calibrated after a soft launch; listed here so we instrument from
day one:

- **Activation:** % of new users who complete their first successful capture.
- **Core-loop engagement:** median captures per active user per week.
- **Retention:** D1 / D7 / D30 retention curves.
- **Generation quality:** player-rated satisfaction with the generated companion
  ("does this look like the cat?"), plus generation success/failure and cost per
  capture.
- **Detection accuracy:** false-accept and false-reject rates for the on-device
  classifier (are real cats accepted and non-cats rejected?).
- **Reliability:** crash-free session rate; capture-to-companion end-to-end
  latency.
- **Trust/safety:** rate of moderation flags; zero tolerance for location-privacy
  regressions.

## MVP acceptance criteria

The MVP is "done" when:

1. A new user can install, onboard, grant permissions, and reach a working map.
2. The camera captures a photo; on-device detection correctly accepts a real cat
   and rejects a drawing, a plush toy, and a photo of a screen in manual testing.
3. An accepted capture reliably produces a stylized companion sprite via the cloud
   service, with graceful failure handling and cost controls.
4. The companion appears in the CatDex with all v1 fields populated and its
   location correctly fuzzed.
5. The player can feed the companion and see happiness/affection respond, with a
   visible idle presentation.
6. Location privacy, permission clarity, and age-appropriate handling meet the
   rules in [Ethics, Privacy & Safety](../08-ethics-privacy-safety.md).
7. Core-loop analytics are instrumented and reporting.
