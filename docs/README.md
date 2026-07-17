# Cat-ch — Documentation

This directory turns the original Cat-ch product brief into a structured,
decision-ready plan. Each document is single-purpose so it can be read and
updated in isolation.

## Suggested reading order

| # | Document | What it covers |
|---|----------|----------------|
| 1 | [product/01-vision.md](product/01-vision.md) | Vision, design pillars, audience, tone, non-goals |
| 2 | [product/02-mvp-scope.md](product/02-mvp-scope.md) | The v1 slice we build first, in/out of scope, success metrics |
| 3 | [product/03-roadmap.md](product/03-roadmap.md) | Phased plan from foundations to live-ops |
| 4 | [product/04-game-systems.md](product/04-game-systems.md) | Design specs for care, personality, PvP, growth, guardianship |
| 5 | [architecture/05-technical-architecture.md](architecture/05-technical-architecture.md) | Stack, system overview, client/server modules |
| 6 | [architecture/06-data-model.md](architecture/06-data-model.md) | Core entities, relationships, representative tables |
| 7 | [architecture/07-ai-pipeline.md](architecture/07-ai-pipeline.md) | Capture → detect → generate flow and anti-abuse |
| 8 | [08-ethics-privacy-safety.md](08-ethics-privacy-safety.md) | Enforceable ethical rules, location privacy, moderation, minors |
| 9 | [09-monetization-and-impact.md](09-monetization-and-impact.md) | Revenue model, donation structure, transparency reporting |
| 10 | [10-risks-and-open-questions.md](10-risks-and-open-questions.md) | Risk register and unresolved decisions |
| — | [design/claude-design-brief.md](design/claude-design-brief.md) | Paste-ready prompt pack for generating reference UI designs (shipped + roadmap screens) in Claude Design |
| — | [decisions/](decisions/README.md) | Architecture Decision Records (ADRs) — dated log of decisions as we make them |

## Key decisions already made

These are baked into the documents above and should be treated as current
direction until revisited:

- **Deliverable of this planning pass:** documentation only — no app code yet.
- **MVP (v1):** the *Capture → CatDex core loop* (see
  [MVP Scope](product/02-mvp-scope.md)). PvP, social, home decoration, and
  shelter/impact systems are specified but deferred.
- **AI approach:** *on-device detection + cloud generation* — the phone verifies
  "is this a real cat?" locally; a cloud service generates the stylized companion
  (see [AI Pipeline](architecture/07-ai-pipeline.md)).

## How this maps to the original brief

Every section of the source brief is represented here:

| Brief topic | Where it lives |
|-------------|----------------|
| Core gameplay loop, capture system | [MVP Scope](product/02-mvp-scope.md), [AI Pipeline](architecture/07-ai-pipeline.md) |
| AI companion generation | [AI Pipeline](architecture/07-ai-pipeline.md) |
| CatDex | [MVP Scope](product/02-mvp-scope.md), [Data Model](architecture/06-data-model.md) |
| Personality, care, feeding, grooming, home | [Game Systems](product/04-game-systems.md) |
| Friendly PvP, growth, social | [Game Systems](product/04-game-systems.md), [Roadmap](product/03-roadmap.md) |
| Guardian system, missions, community goals, shelters | [Game Systems](product/04-game-systems.md), [Monetization & Impact](09-monetization-and-impact.md) |
| Revenue philosophy | [Monetization & Impact](09-monetization-and-impact.md) |
| Ethical design principles | [Ethics, Privacy & Safety](08-ethics-privacy-safety.md) |
| Technical direction | [Technical Architecture](architecture/05-technical-architecture.md) |
| Long-term dream | [Vision](product/01-vision.md) |
