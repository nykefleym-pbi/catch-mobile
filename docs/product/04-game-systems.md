# 04 — Game Systems (Design Specs)

Mechanics-level design for the systems Cat-ch will grow into. This is the
**design intent**, not implementation — code lives later. Systems here are mostly
**post-MVP** (Phases 2–4 in the [Roadmap](03-roadmap.md)); the MVP ships only a
personality *trait label* and a two-need care loop (see
[MVP Scope](02-mvp-scope.md)).

Everything below must honor the [Vision](01-vision.md) pillars: cozy (no harsh
punishment), compassionate (never encourages disturbing real animals), and
never pay-to-win.

---

## Personality system

Every captured cat receives **procedural personality traits** drawn from a pool
such as: Curious, Brave, Lazy, Foodie, Mischievous, Elegant, Playful, Protective,
Explorer, Shy.

- **v1:** one trait, cosmetic/flavor only.
- **Later:** 1–2 traits that *modulate* other systems — e.g. a **Foodie** gains
  more affection from feeding; a **Lazy** cat has slower play-need decay; an
  **Explorer** performs better in treasure-hunt PvP.
- **Assignment:** seeded so a given real cat feels consistent, with light
  influence from capture context where appropriate. Keep the generator legible —
  players should feel traits are *fair*, not random noise.
- **Design caution:** personality must never become a power axis you can buy.
  Traits create *variety and flavor*, not a stat ladder (see PvP below).

---

## Tamagotchi-style care

Players build a relationship through gentle daily care. Needs:

| Need | v1? | Notes |
|------|-----|-------|
| Hunger | ✅ | Fed with food items |
| Happiness | ✅ | Raised by feeding, play, interaction |
| Hygiene | ➖ later | Raised by grooming |
| Sleep | ➖ later | Restored by rest; ties to idle "sleeping" animation |
| Affection | ➖ later (friendship exists in v1) | Long-term bond level |
| Play | ➖ later | Raised by toys / mini-interactions |

**Core coziness rule:** ignoring a companion **shifts its mood** (a sad idle,
softer colors, a gentle prompt) — it **never** inflicts damage, hunger "death,"
permanent loss, or punishing debt. Decay is slow and forgiving. The player can
always recover a mood with a little attention. The experience must stay relaxing.

---

## Feeding

Food is collected through exploration (not primarily bought). Starter set:
Tuna, Salmon, Chicken, Premium Treats, Catnip.

- Different foods grant **temporary buffs** and varying **affection** gains.
- Favorite foods (tied to personality, e.g. Foodie) grant bonus affection.
- **No pay-to-win:** premium foods may be cosmetic-flavored or mild, never a
  gating power source. Buffs are gentle and optional.

---

## Grooming (cosmetic only)

Actions: brush fur, bathe, trim claws, clean ears, change collars, equip
accessories. All customization is **purely cosmetic** — it changes appearance and
raises hygiene/happiness, never combat/PvP power. Grooming is a Phase 2 system.

---

## Home decoration

Each companion has a customizable home. Furniture includes beds, scratching posts,
cat trees, sofas, windows, plants, rugs, toys, aquariums. Decorations unlock over
time through play; premium decor is cosmetic. Phase 2.

---

## Friendly PvP (playful, never violent)

Competition is optional and gentle. Formats: zoomie races, toy competitions, paw
wrestling, obstacle courses, agility contests, treasure hunts.

**Stats** (examples): Agility, Speed, Confidence, Curiosity, Energy, Cuteness.

**Abilities** (examples): Zoomie Rush, Tail Swipe, Fluffy Shield, Meow Burst,
Nap Recovery, Laser Chase.

**Non-negotiable design constraint:** *skill, preparation, and personality must
matter more than spending.* Concretely:

- Stats derive from care, growth stage, personality, and player choices — **not**
  from purchasable power.
- Matchmaking and format design reward preparation and timing over grind or wallet.
- Rewards are cosmetic/progression, never power that snowballs.
- "Losing" stays friendly — playful outcomes, no humiliation, no stat loss.

PvP is Phase 3 and should be prototyped carefully to prove the no-pay-to-win claim
before wide release.

---

## Growth

Cats mature through stages: **Kitten → Young → Adult → Senior**. Appearance
gradually changes while **identity persists** (same markings, same personality,
same CatDex entry). Growth is time/care-based and unlocks nothing purchasable.
Phase 2.

---

## Social features

Visiting friends, cosmetic trading, CatDex showcases, shared photo albums, clubs,
seasonal events, cooperative challenges. Designed to **encourage kindness, not
toxicity**: every social surface needs moderation and reporting (see
[Ethics, Privacy & Safety](../08-ethics-privacy-safety.md)). Phase 3.

---

## Cat Guardian system

Every player is a **Cat Guardian**. Progression represents **positive real-world
impact**, not combat strength. Ranks (examples): New Friend → Neighborhood Helper
→ Shelter Supporter → Community Protector → Legendary Guardian.

Guardian levels unlock **cosmetics, titles, badges, and decorations only** — never
power. Phase 4.

### Guardian Missions (optional, real-world, safe)

Examples: responsibly feed a community cat, provide fresh water where appropriate,
visit partner shelters, volunteer at adoption events, donate to accredited
welfare organizations, support rescue campaigns, learn responsible cat care.

**Safety-first design:** missions must **never** encourage unsafe, disruptive, or
disrespectful behavior toward animals, people, or property. Framed around
observation, respect, and legitimate support. Verification for real-world actions
is a hard design problem — see [Risks](../10-risks-and-open-questions.md).

---

## Community goals

Worldwide collaborative objectives (e.g. one million community meals provided,
global adoption-awareness campaigns, shelter fundraising milestones, seasonal
charity events). Rewards are **shared** and celebrate collective achievement, not
individual competition. Tied to the real impact pipeline in
[Monetization & Impact](../09-monetization-and-impact.md). Phase 4.
