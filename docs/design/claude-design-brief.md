# Cat-ch — Claude Design Brief

A **paste-ready prompt pack** for generating reference UI designs in Claude
(Design / Artifacts). The goal: get every screen and component of Cat-ch —
**both what's shipped and everything on the [Roadmap](../product/03-roadmap.md)** —
designed to a consistent, cozy standard, so those mockups become the reference we
build the Flutter UI against.

Grounded in the product plan: [Vision](../product/01-vision.md),
[MVP Scope](../product/02-mvp-scope.md), [Roadmap](../product/03-roadmap.md),
[Game Systems](../product/04-game-systems.md),
[Ethics, Privacy & Safety](../08-ethics-privacy-safety.md).

---

## How to use this brief

1. **Open a new Claude conversation** (or an Artifact-capable session).
2. **Paste [§1 Master context](#1-master-context) first.** It sets brand, tone,
   palette, type, platform, and the non-negotiable "cozy, never dark-pattern"
   rules. Every screen prompt assumes it.
3. Then paste **one screen prompt at a time** from §3 (shipped) or §4 (future).
   Ask for a mobile mockup in light **and** dark. Iterate in that thread until it
   feels right.
4. For a system-wide pass, paste **[§2 Component system](#2-component-system)** and
   ask for a single component sheet.
5. **Save the results as reference.** We implement in Flutter/Material 3 to match;
   these mockups are the source of truth for layout, spacing, color, and mood — not
   for production code.

> Tip: keep one Claude thread per screen so its context stays focused, and start
> each with "Using the Cat-ch master context I gave you, design …".

---

## 1. Master context

> **Paste this block first, verbatim, before any screen prompt.**

```
You are designing the mobile UI for "Cat-ch", a cozy, location-based cat-collecting
game with a real animal-welfare mission. Tagline: "Every Cat Has a Story. Every
Player Can Make a Difference."

THE FEELING (most important): the pleasant surprise of turning a corner and meeting
a cat sunning itself on a wall, plus the quiet satisfaction of a well-tended
collection. Cozy, wholesome, relaxing, rewarding, community-driven. NOT a race, a
fight, or a slot machine. Think Neko Atsume + Animal Crossing warmth, with a gentle
Pokédex-style collection.

DESIGN PILLARS (every screen must serve at least one): Discovery, Compassion,
Coziness, Uniqueness, Transparency.

AUDIENCE: casual cozy-game and collector players, cat lovers, broad age range
INCLUDING MINORS. The app uses camera + location, so safety, privacy, and clear
consent are first-class — never buried, never manipulative.

HARD "NEVER" RULES (reflect these in the design):
- No dark patterns, no guilt loops, no punishing streaks, no manipulative FOMO.
- Never pay-to-win — any shop is cosmetic and clearly optional.
- Neglecting a cat only shifts its MOOD (a soft, sad idle) — never damage, death,
  or loss. Copy is gentle and encouraging, never nagging or fear-based.
- Location is shown at neighborhood level only; never expose a precise cat location.

BRAND & ART DIRECTION:
- Warm, rounded, hand-illustrated "cozy" aesthetic. Soft palettes, generous
  rounding, gentle shadows, lots of breathing room.
- Signature color is a warm sunlit apricot. Palette:
  - Primary apricot         #F6A96A
  - Deep terracotta accent  #E07A5F
  - Warm cream surface       #FFF7EF (light bg)
  - Soft sage secondary      #A7C4A0
  - Warm brown text          #3E2F26
  - Muted sand / borders     #EBDdCB
  - Dark theme: warm charcoal surfaces #201A16 / #2B2420, apricot primary kept,
    cream text #F3E9DF. Never a cold pure-black/blue dark theme — keep it warm.
- Typography: friendly rounded sans. Display/headings in a soft rounded face
  (Nunito, Quicksand, or Fredoka); body in a clean humanist sans (Nunito Sans or
  Inter). Comfortable sizes, relaxed line height.
- Shape: large corner radii (cards ~20px, buttons ~16px, sheets ~28px top).
  Pill-shaped primary buttons. Soft, low, warm shadows — never harsh.
- Iconography: rounded, friendly, slightly chunky line/duotone icons. Paw motifs
  used sparingly as a signature.
- Illustration & the cat sprites: stylized and CUTE, not photoreal — chibi
  storybook cats with big friendly eyes, thick soft outlines, flat matte cel
  shading, derived from a real cat's actual colors and markings.
- Motion (describe, don't over-animate): gentle, springy, low-stakes — soft
  fade/scale reveals, a breathing/blink idle on cats, no aggressive flashing.

PLATFORM & CONSTRAINTS:
- Native mobile app (Flutter, Material 3), primarily portrait phone. Design at a
  ~390x844 frame.
- Provide LIGHT and DARK versions of every screen.
- Accessibility: AA contrast, min 44x44 touch targets, support large text, clear
  focus/selected states, never rely on color alone.
- Primary navigation is a bottom nav bar with three destinations: Explore (map),
  CatDex (collection), Guardian (profile). A central camera/capture action is the
  hero. (More destinations may appear as the app grows — see roadmap screens.)
```

---

## 2. Component system

> Paste after the master context to get a single, reusable component sheet.

```
Using the Cat-ch master context, design a cohesive component & style sheet
(light + dark) covering:

TOKENS: color roles (primary/secondary/surface/on-surface/success/warning/error
in the cozy palette), type scale (display, headline, title, body, label), spacing
scale (4/8/12/16/24/32), corner radii, and the soft-shadow elevation set.

CORE COMPONENTS with all relevant states (default / pressed / disabled / loading /
selected / error / empty):
- Buttons: primary (pill), secondary/tonal, text, icon button, and the hero
  circular capture FAB.
- App bar (centered title) and the bottom navigation bar (Explore / CatDex /
  Guardian + central camera hero).
- Cards: the CatDex cat card (sprite + name + trait chip + mood), a generic
  info/list card, and a large feature/reveal card.
- List tile / selectable row (used by the treat picker) with leading emoji/icon,
  title, subtitle, trailing chevron, and a "+N bond" value.
- Chips & badges: personality-trait chip, mood badge, "new" badge, Guardian-rank
  badge, count badge.
- Meters: gentle rounded progress bars for needs (Hunger, Happiness) and a
  friendship/bond meter with hearts — soft, non-alarming even when low.
- Banners / hint cards (the cozy tip banner over the map), snackbars, and gentle
  empty-state blocks with a friendly illustration + one line of encouragement.
- Bottom sheet (the treat picker), dialog, and a permission-priming card (explains
  WHY camera/location is needed, warm and honest).
- Map pin: a circular "photo pin" holding a cat sprite with a small pointer, plus
  the player's own location dot.
- Avatar / cat portrait frame, and a skeleton/loading shimmer for the sprite while
  it generates.

Show each component in light and dark, and note the token used for each color.
```

---

## 3. Screens — shipped in the MVP

These exist in the app today; we want elevated reference designs.

### 3.1 Onboarding, auth & permission priming
```
Using the Cat-ch master context, design the first-run onboarding flow (3–4 screens):
1) A warm welcome that sells the feeling (meet real cats on your walks, adopt them
   as unique companions, help real cats). 2) A lightweight, low-friction sign-in
   (anonymous "start playing" primary; optional account). 3) A gentle age-gate /
   consent step appropriate for a minor-inclusive audience. 4) Camera & location
   permission PRIMING cards that honestly explain why each is needed and reassure
   about privacy (location is only ever neighborhood-level), each with a clear
   "why" and an easy skip/allow. Cozy illustrations, encouraging copy, no pressure.
```

### 3.2 Explore map (the "memory map")
```
Using the Cat-ch master context, design the Explore map screen. A cozy, warm-toned
street map centered on the player. Every cat you've caught appears as a circular
"photo pin" (its sprite) at the neighborhood-level place you met it; tapping a pin
opens that cat. Include: the player's location dot, a floating "locate me" button, a
gentle hint banner ("You've met 3 cats here — tap a pin to visit"), an
empty/first-run state ("Walk your neighborhood to meet cats — each one pins here"),
and the bottom nav with the central camera hero. Emphasize that this is a private
journal of memories, not a live tracker of real cats. Light + dark.
```

### 3.3 Camera capture
```
Using the Cat-ch master context, design the in-game camera capture screen. A calm,
uncluttered live-camera view with a friendly framing hint ("Point at a cat"), a
large circular shutter, and reassuring microcopy. Show the on-device detection
feedback states: checking, "That's a cat! ✨", and a kind non-punitive rejection
for non-cats ("Hmm, we couldn't find a cat — try again?"). Nothing scary or
technical. Light + dark.
```

### 3.4 The "Caught!" reveal
```
Using the Cat-ch master context, design the capture-result / "Caught!" celebration
that plays after a real cat is photographed and its companion sprite is generated.
Show: a delightful reveal of the new chibi cat sprite, its auto-given name, its
personality-trait chip, a one-line blurb, and where/when it was met. Include the
"generating your companion…" loading state (a cozy shimmer, not a spinner-of-doom)
and the Keep/Retake choice. Joyful but gentle — a warm surprise, not a jackpot.
```

### 3.5 CatDex (collection grid)
```
Using the Cat-ch master context, design the CatDex — the player's growing collection
and journal. A warm grid of cat cards (sprite, name, trait chip, small mood
indicator). Include a header with a collection count, light sort/filter affordances
(by trait, by date, by place), a search field, and a friendly empty state for new
players. Tapping a card opens the cat detail. It should feel like a treasured
scrapbook of real cats met on real walks. Light + dark.
```

### 3.6 Cat detail & care
```
Using the Cat-ch master context, design the cat detail + care screen for one
companion. Top: a large hero of the cat sprite with a subtle idle feel. Below, in a
rounded sheet: name (editable), personality-trait chip, coat/pattern/eye details,
date discovered and neighborhood met, and gentle Hunger + Happiness meters plus a
friendship/bond meter. A primary "Feed" action opens a "Pick a treat" bottom sheet
listing foods (Chicken +1 bond, Tuna +2, Salmon +2, Catnip +1, Premium Treats +3)
with emoji/icons. Mood is shown softly; a low mood is a slightly sad idle, never an
alarm. Cozy, tactile, rewarding. Light + dark.
```

### 3.7 Guardian profile (basic)
```
Using the Cat-ch master context, design the Guardian (player profile) screen in its
basic v1 form: player display name and avatar, a warm summary of their journey (cats
met, places explored), their current Guardian identity, and simple settings entry
(privacy toggles, notifications, permissions). Set the stage for the richer Guardian
progression shown in the roadmap screens, but keep v1 calm and uncluttered.
```

---

## 4. Screens — future / roadmap (not yet in the APK)

Design these now so we have a consistent visual target to build toward. Grouped by
[Roadmap](../product/03-roadmap.md) phase. All obey the same "cozy, never
pay-to-win, never dark-pattern, compassion-first" rules.

### Phase 2 — Deeper care & companionship

**4.1 Expanded needs & mood**
```
Using the Cat-ch master context, expand the cat detail screen with the full gentle
needs model: Hunger, Happiness, Hygiene, Sleep, Play, plus a long-term Affection/
bond track. All meters are soft and forgiving — even at their lowest they read as
"could use a little love," never as danger. Include a derived MOOD label with matching
idle expression, and a "last cared for" gentle nudge. Light + dark.
```

**4.2 Grooming (cosmetic)**
```
Using the Cat-ch master context, design a grooming screen: brush fur, bathe, trim
claws, clean ears, and change collars/accessories. Purely cosmetic + hygiene/
happiness — never power. A tactile, satisfying, relaxing mini-interaction with the
cat sprite front and center, and a wardrobe/accessory tray. Light + dark.
```

**4.3 Home decoration**
```
Using the Cat-ch master context, design a customizable cat "home" screen: a cozy room
the player decorates with beds, scratching posts, cat trees, sofas, windows, plants,
rugs, toys. Include a furniture/decor tray, drag-to-place editing, and the cat living
in the space. Decor unlocks through play; premium decor is cosmetic only. Warm, doll-
house charm. Light + dark.
```

**4.4 Growth stages**
```
Using the Cat-ch master context, design a "growth" view showing a cat maturing across
Kitten → Young → Adult → Senior, where appearance gradually changes but IDENTITY
persists (same markings, same personality, same CatDex entry). A gentle timeline/
milestone treatment celebrating the passage of time together. Light + dark.
```

**4.5 Richer CatDex entry**
```
Using the Cat-ch master context, design the full CatDex entry (Phase 2 fields): breed
estimate, estimated age & weight, favorite food, achievement badges, and multiple
idle animations, layered onto the v1 detail screen without clutter. A collectible
"card back" full of a cat's story. Light + dark.
```

### Phase 3 — Play together & community

**4.6 Friendly PvP**
```
Using the Cat-ch master context, design the friendly, NON-violent PvP experience:
a lobby to choose a format (zoomie race, agility contest, treasure hunt, paw
wrestling), a cat "roster" showing playful stats (Agility, Speed, Confidence,
Curiosity, Energy, Cuteness) and abilities (Zoomie Rush, Fluffy Shield, Meow Burst,
Nap Recovery), a lighthearted match screen, and a results screen that celebrates both
players — no humiliation, no stat loss, cosmetic/progression rewards only. Make it
unmistakably playful, never aggressive. Light + dark.
```

**4.7 Social — friends, visiting, showcases**
```
Using the Cat-ch master context, design the social hub: a friends list, visiting a
friend's home/cats, a CatDex "showcase" a player curates to share, shared photo
albums, and clubs. Every social surface must show clear, easy reporting/blocking and
read as kind and safe (this audience includes minors). Warm and welcoming, moderation
built in, never toxic or competitive-ranking-driven. Light + dark.
```

**4.8 Cosmetic trading**
```
Using the Cat-ch master context, design a cosmetic-only trading screen (accessories/
decor, never cats-as-power, never real money): a safe, clear offer/confirm flow with
strong anti-scam clarity and easy cancel. Light + dark.
```

**4.9 Seasonal events**
```
Using the Cat-ch master context, design a seasonal/live-event surface: a cozy event
banner and hub (e.g. a "cozy autumn" theme) with limited-time cosmetic decor and
gentle cooperative goals — celebratory, never FOMO-manipulative or countdown-anxious.
Light + dark.
```

### Phase 4 — Real-world impact (the mission)

**4.10 Guardian ranks & progression**
```
Using the Cat-ch master context, design the full Guardian progression: ranks (New
Friend → Neighborhood Helper → Shelter Supporter → Community Protector → Legendary
Guardian) that represent POSITIVE REAL-WORLD IMPACT, not combat power. Unlocks are
cosmetics, titles, badges, decorations only. A warm, proud "impact journey" with
badges earned and titles held. Light + dark.
```

**4.11 Guardian Missions (real-world, safe)**
```
Using the Cat-ch master context, design the Guardian Missions screen: optional, safe,
real-world good deeds (responsibly feed a community cat, provide fresh water where
appropriate, visit a partner shelter, volunteer at an adoption event, learn
responsible cat care, support a rescue campaign). Every mission is framed around
observation, respect, and legitimate support — the UI must actively discourage unsafe,
disruptive, or disrespectful behavior toward animals, people, or property. Include a
clear safety note and a gentle completion flow. Light + dark.
```

**4.12 Community goals**
```
Using the Cat-ch master context, design a worldwide community-goals screen:
collaborative objectives (e.g. one million community meals provided, a global
adoption-awareness push) with SHARED progress and rewards that celebrate collective
achievement, not individual competition. Uplifting and communal. Light + dark.
```

**4.13 Shelter partnerships & adoptable cats**
```
Using the Cat-ch master context, design a shelter/partnership surface: featured
accredited partner shelters, real adoptable cats (respectful, honest presentation,
clear "learn more / how to adopt" — never gamified pressure), and shelter campaigns
players can support. Trustworthy and warm. Light + dark.
```

**4.14 Impact transparency & (cosmetic) shop**
```
Using the Cat-ch master context, design two linked surfaces: (a) an honest IMPACT
TRANSPARENCY report — cats discovered, adoptions driven via partners, meals funded,
treatments sponsored, money donated — presented as earned, audited numbers, not
hype; and (b) a clearly-optional COSMETIC shop (decor, accessories, themes) that is
never pay-to-win, with honest pricing and no manipulative urgency. Trust is the
feature. Light + dark.
```

---

## 5. Companion sprite art direction

The generated cat sprites are the emotional core. When asking Claude Design for
sprite reference or a style frame, use:

```
Design the reference art style for Cat-ch companion cats: an adorable CHIBI storybook
cat — big friendly eyes, soft rounded body, thick soft outlines, flat matte cel
shading, warm and huggable. It must stay recognizably derived from a REAL cat's actual
coat color, fur pattern, eye color, and distinctive markings (this is the "uniqueness"
pillar — each cat is a memento of a specific real animal). Full body, sitting,
centered, facing viewer, on a clean soft background, ideally a transparent cutout for
in-app use. NOT photoreal, NOT a fantasy/neon creature — a believable, cozy, cute
cat. Show a small sheet of 4–6 varied examples (different coats: tabby, tuxedo, calico,
ginger, grey, black-and-white) to prove the range.
```

This mirrors what the generation pipeline targets today
([AI pipeline](../architecture/07-ai-pipeline.md),
[ADR 0001](../decisions/0001-image-generation.md)); the reference frames help us
tune prompts and pick a provider.

---

## 6. What to hand back

For each screen, aim to capture from Claude Design:
- The **light and dark** mockup at phone size.
- Notable **component states** (empty, loading, error, selected).
- A short note on **which palette/type tokens** were used, so we can wire the same
  values into the Flutter `AppTheme`.

We then treat these as the visual reference and implement to match. Keep the winning
mockups in `docs/design/reference/` (add as you go) so the whole team designs and
builds against one source of truth.
