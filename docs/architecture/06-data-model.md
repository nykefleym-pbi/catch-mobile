# 06 — Data Model

Conceptual data model with **representative** Supabase/Postgres tables. This is a
design sketch to align on entities and relationships — exact columns, types,
indexes, and migrations are settled during implementation. **v1** needs only the
tables marked *(v1)*; the rest are shown so the schema grows coherently.

Guiding constraints:

- **Row-Level Security (RLS) everywhere** — a player can only read/write their own
  rows unless a feature explicitly opts into sharing (e.g. showcases).
- **Location is privacy-fuzzed at write time** — precise coordinates are never
  stored for display. See [Ethics, Privacy & Safety](../08-ethics-privacy-safety.md).

## Entity overview

```
profiles (1) ──< captures (1) ──< cats (1) ──1 care_state
   │                                   │
   │                                   ├──< cat_personality_traits >── personality_traits
   │                                   └──1 catdex_entry
   │
   ├──< inventory >── items (foods, cosmetics, decor)
   └──1 guardian_progress            (Phase 4)
```

## Core tables

### `profiles` *(v1)*
One row per player, linked to Supabase Auth user.
- `id` (uuid, = auth user id)
- `display_name`
- `created_at`
- `birthdate` or `age_bracket` — for age-appropriate handling / consent
- `settings` (jsonb) — privacy toggles, notifications
- RLS: owner-only, except explicitly shared profile fields.

### `captures` *(v1)*
The raw discovery event — the "I met this cat here" record.
- `id` (uuid)
- `profile_id` (uuid → profiles)
- `created_at`
- `location_fuzzed` — region/neighborhood-level only (e.g. coarse geohash or
  rounded coords). **No precise coordinates persisted for display.**
- `source_image_ref` — storage reference to the captured photo (retention &
  moderation policy per the ethics doc; consider deleting or short-retaining raw
  photos after generation).
- `detection_result` (jsonb) — classifier confidence, quality-gate outcome.
- `perceptual_hash` — for **per-user** duplicate detection (see AI Pipeline).
- `status` — pending / generating / complete / failed / rejected.
- RLS: owner-only.

### `cats` *(v1)*
A player's companion generated from a successful capture.
- `id` (uuid)
- `capture_id` (uuid → captures)
- `profile_id` (uuid → profiles)  *(denormalized for RLS/queries)*
- `name`, `nickname`
- `sprite_ref` — storage/CDN reference to the transparent PNG sprite
- `generation_meta` (jsonb) — coat color, fur pattern, eye color, tail shape,
  distinctive markings as extracted/asserted by the pipeline
- `friendship_level` *(v1: basic)*
- `growth_stage` — kitten/young/adult/senior *(Phase 2; default kitten in v1)*
- `discovered_at`
- RLS: owner-only (shared read for showcases in Phase 3).

### `catdex_entries` *(v1, may be merged into `cats` initially)*
The journal-facing view of a cat. Kept conceptually separate because the CatDex
accrues descriptive/estimated fields over time.
- `cat_id` (uuid → cats)
- `breed_estimate`, `age_estimate`, `weight_estimate` *(Phase 2)*
- `favorite_food` *(Phase 2)*
- `badges` (jsonb) *(Phase 2)*
- `location_label` — human-readable, privacy-safe (e.g. "Downtown")
- v1 populates: name/nickname, coat color, fur pattern, one personality trait,
  date discovered, fuzzed location, friendship, sprite.

### `care_state` *(v1: hunger + happiness only)*
Mutable needs for a companion.
- `cat_id` (uuid → cats, 1:1)
- `hunger`, `happiness` *(v1)*
- `hygiene`, `sleep`, `affection`, `play` *(Phase 2)*
- `mood` — derived label for idle presentation
- `last_updated` — decay computed from elapsed time (gentle, non-punitive)
- RLS: owner-only.

### `personality_traits` + `cat_personality_traits`
- `personality_traits`: reference table of trait definitions (Curious, Brave,
  Lazy, Foodie, …).
- `cat_personality_traits`: join table (a cat has 1 trait in v1, 1–2 later),
  with any per-cat modifiers.

### `items` + `inventory`
- `items`: reference catalog — foods (Tuna, Salmon, Chicken, Premium Treats,
  Catnip), and later cosmetics, grooming tools, decor. Includes `type`, buffs,
  cosmetic flags. **No item grants purchasable power** (see
  [Game Systems](../product/04-game-systems.md)).
- `inventory`: player-owned quantities. RLS: owner-only. *(v1: foods only.)*

## Post-MVP tables (sketched, Phases 2–4)

- `homes`, `home_placements` — decoration.
- `friendships`, `visits`, `trades`, `clubs`, `club_members`, `showcases` — social
  (Phase 3); these introduce **shared-read** RLS policies and need moderation
  hooks.
- `pvp_matches`, `pvp_results` — friendly PvP (Phase 3).
- `guardian_progress`, `guardian_missions`, `mission_completions` — impact
  (Phase 4).
- `community_goals`, `community_contributions` — collaborative objectives (Phase 4).
- `shelters`, `shelter_campaigns`, `adoptable_cats` — partnerships (Phase 4).
- `donations`, `impact_reports` — transparency pipeline (Phase 4); see
  [Monetization & Impact](../09-monetization-and-impact.md). Financial tables must
  be built with audit and reconciliation in mind.

## Storage

- **Source photos:** short-lived / policy-bound; used for detection + generation,
  then handled per the retention rules in the ethics doc.
- **Generated sprites (+ later animations):** durable, served via CDN, owner-scoped
  access (public read only where a feature like showcases requires it).

## Notes on location privacy (critical)

`captures.location_fuzzed` and `catdex_entries.location_label` must **never** allow
reconstruction of a precise location for an individual (often owned or vulnerable)
cat. Fuzzing happens as early as possible — ideally on-device before upload — and
the precise coordinate is not persisted. This is a hard requirement, detailed in
[Ethics, Privacy & Safety](../08-ethics-privacy-safety.md).
