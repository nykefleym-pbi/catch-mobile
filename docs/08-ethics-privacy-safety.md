# 08 — Ethics, Privacy & Safety

The brief states strong ethical principles. This document turns them into
**enforceable design rules** — the kind you can review a feature against. When
gameplay and animal welfare conflict, **welfare wins**. These rules are binding on
every phase of the [Roadmap](product/03-roadmap.md).

## Principle → rule

| Principle (from brief) | Enforceable rule |
|------------------------|------------------|
| Never encourage chasing or disturbing cats | No mechanic rewards chasing, luring, cornering, touching, or startling an animal. Capture rewards **observation** (photographing a cat that is present), never interaction. No time-pressure or "act fast" framing at the moment of capture. |
| Respect private property | No mechanic incentivizes entering private property, trespassing, or lingering. No spawn/reward is placed to lure players onto private or restricted land. |
| Avoid revealing precise locations of privately owned or vulnerable animals | Locations are **fuzzed to region/neighborhood level before upload**; precise coordinates are never persisted for display or shared. No public map of "where this cat lives." (See Location Privacy below.) |
| Promote observation over interaction | UI copy, missions, and tutorials consistently model respectful observation; missions never ask players to make contact with unfamiliar animals. |
| Reward kindness instead of exploitation | Progression (esp. the Guardian system) rewards positive real-world impact, not extraction. See [Game Systems](product/04-game-systems.md). |
| Never create pay-to-win mechanics | Monetization is cosmetic and optional; power is never for sale. See [Monetization & Impact](09-monetization-and-impact.md). |
| Keep monetization cosmetic and optional | Same. Enforced at item-catalog design time (`items` cannot grant power). |

## Location privacy (hard requirement)

The single highest-risk area. Rules:

1. **Fuzz early, discard precise.** The player's precise coordinates are reduced to
   a coarse region (e.g. neighborhood-level geohash or rounded coordinate)
   **on-device before upload**, and the precise value is **not persisted** for
   display. See [Data Model](architecture/06-data-model.md).
2. **No individual-cat location registry.** We never build or expose a map that
   lets anyone locate a specific real cat. Duplicate detection is **per-user only**
   (see [AI Pipeline](architecture/07-ai-pipeline.md)); cross-user "same cat"
   matching is intentionally not built.
3. **Human-readable labels only.** CatDex shows something like "Downtown," never
   a pin on a house.
4. **Player location minimization.** Collect and retain the minimum location data
   needed for exploration; be explicit about it in the privacy policy.

## Data & media handling

- **Source photos** are used for detection and generation, then **deleted
  immediately after generation succeeds** — we keep only the generated sprite and
  non-identifying `generation_meta`. (Confirmed decision, see
  [ADR 0001](decisions/0001-image-generation.md).) Note the trade-off: with no
  retained original, a later report on a generated sprite can't be checked against
  the source, so moderation must run **before** deletion (it does — see the
  [AI Pipeline](architecture/07-ai-pipeline.md)).
- **Camera and location permissions** are requested **just-in-time** with plain
  rationale, and the app degrades gracefully if declined.
- **Row-Level Security** isolates each player's data by default; sharing is
  explicit and revocable.

## Minors, consent & regulation

Cat-ch will attract **children and teens**, and it uses **camera + location** —
two of the most sensitive data types. Treated as a first-class constraint:

- **Age-appropriate design.** Follow child-safety expectations (e.g. COPPA in the
  US, UK Age-Appropriate Design Code, GDPR/GDPR-K in the EU). Confirm exact
  obligations with counsel before launch — flagged in
  [Risks & Open Questions](10-risks-and-open-questions.md).
- **Age gate & appropriate consent** at onboarding; reduced data collection and no
  behavioral profiling for younger users.
- **No precise-location sharing** for anyone, and extra conservatism for minors.
- **Safe social surfaces.** Any user-to-user feature (Phase 3+) ships with
  moderation, reporting, blocking, and default-conservative privacy for minors.

## Content moderation

- **Server-side image moderation** screens submitted and shared photos before
  generation and before any social display (see [AI Pipeline](architecture/07-ai-pipeline.md)).
- **User reporting & blocking** on every shared surface.
- **Community-kindness guardrails** in social design (Phase 3) — the goal is
  kindness, not virality at the cost of safety.

## Real-world mission safety (Phase 4)

Guardian Missions must **never** encourage unsafe, disruptive, or disrespectful
behavior. Missions are framed around observation, respect, legitimate support of
accredited organizations, and learning — never approaching, feeding
irresponsibly, or handling unfamiliar animals. Verification of real-world actions
is an open design problem (see [Risks](10-risks-and-open-questions.md)); until
solved safely, missions favor low-risk, self-reported, education-and-support
actions over anything that puts a player or an animal at risk.

## Review checklist (apply to every feature)

- Does it reward observation, never disturbance?
- Could it reveal a specific cat's location? If so, redesign.
- Could it incentivize trespassing or unsafe real-world behavior?
- Does it sell power, or only cosmetics?
- Is it safe and appropriate for a minor?
- Does it collect the minimum data necessary, with clear consent?
