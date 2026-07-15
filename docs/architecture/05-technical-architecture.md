# 05 — Technical Architecture

High-level system design. Detailed data structures are in
[Data Model](06-data-model.md); the capture/generation flow is in
[AI Pipeline](07-ai-pipeline.md).

## Guiding principles

- **Scalable, modular, maintainable** — feature-first structure so systems from
  the [Roadmap](../product/03-roadmap.md) can be added without churn.
- **Privacy-first** — the client does as much as it can locally (detection); the
  server never stores precise cat locations for display. See
  [Ethics, Privacy & Safety](../08-ethics-privacy-safety.md).
- **Cost-aware** — cloud image generation is the main variable cost; the
  architecture must gate, rate-limit, and cache it.

## Stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Client framework | **Flutter** | Single codebase for iOS + Android |
| Backend / BaaS | **Supabase** | Postgres, Auth, Storage, Edge Functions, Realtime |
| Maps | **Google Maps SDK** (via Flutter plugin) | Cozy map + exploration |
| Camera | **Flutter camera plugin** | In-game capture |
| On-device AI | **Google ML Kit** and/or **TensorFlow Lite** | "Is this a real cat?" + quality gate |
| Companion generation | **Cloud image API** (e.g. OpenAI Images) or self-hosted pipeline | Behind our own Edge Function, never called directly from the client |
| Animation | **Rive** (evaluate) or **Spine 2D / Live2D** | See note below |
| Realtime | **Supabase Realtime** | Social, community goals, events (post-MVP) |
| Analytics / crash | TBD (privacy-respecting) | Wired in Phase 0 |

### Animation note

The brief suggests **Spine 2D** or **Live2D**. Both are capable but carry runtime
licensing/integration weight. **Rive** is worth evaluating as a lighter-weight,
Flutter-friendly alternative for idle animations (blink, ear twitch, tail sway,
sit, stretch, sleep). Decision tracked in
[Risks & Open Questions](../10-risks-and-open-questions.md); v1 needs only a
minimal idle (static sprite + subtle loop), so this decision can wait.

## System overview

```
                         ┌─────────────────────────────────────────────┐
                         │                  Flutter app                 │
                         │                                              │
  Camera ──► capture ──► │  On-device AI (ML Kit / TFLite)              │
                         │   • is-a-real-cat classifier                 │
                         │   • quality gate, reject drawings/toys/screens│
                         │                                              │
                         │  Feature modules: map · capture · catdex ·   │
                         │  care · profile · (later: social, pvp, ...)  │
                         └───────────────┬──────────────────────────────┘
                                         │ HTTPS (authenticated)
                                         ▼
                         ┌──────────────────────────────────────────────┐
                         │                  Supabase                     │
                         │  Auth · Postgres (+ RLS) · Storage · Realtime │
                         │                                              │
                         │  Edge Function: generate-companion            │
                         │   • auth + rate-limit + cost cap              │
                         │   • image moderation                          │
                         │   • per-user duplicate heuristic (pHash)      │
                         └───────────────┬──────────────────────────────┘
                                         │ server-to-server (keys never on client)
                                         ▼
                         ┌──────────────────────────────────────────────┐
                         │   Cloud image generation service / pipeline   │
                         │   → stylized transparent sprite (+ later anim) │
                         └──────────────────────────────────────────────┘
                                         │
                                         ▼
                              Storage/CDN for generated sprites
```

Key rule: **the client never talks to the generation provider directly.** All
generation goes through a Supabase **Edge Function** so we can authenticate,
rate-limit, moderate, cap cost, and keep provider API keys server-side.

## Client module breakdown (feature-first)

Suggested top-level feature modules, each self-contained (UI + state + data
access):

- `auth` — sign-in/up, session, age-gate/consent.
- `map` — cozy map, exploration framing, location permission handling.
- `capture` — camera, on-device detection, quality gate, submission to backend.
- `catdex` — collection list/detail, entry fields, sprites.
- `care` — needs, feeding, mood/idle presentation (grows in Phase 2).
- `profile` — player identity, settings, privacy controls.
- *(later)* `social`, `pvp`, `home`, `guardian`, `impact`.

Shared layers: `core` (theming/design system, routing, config), `data`
(Supabase client, models, repositories), `services` (analytics, permissions,
generation-client wrapper).

## State management

Choose one idiomatic Flutter approach (e.g. Riverpod or Bloc) in Phase 0 and apply
it consistently. Decision deferred to implementation, but it should support
testable, feature-scoped state.

## Offline & resilience

- Exploration and CatDex browsing should degrade gracefully offline; captures
  queue and sync when connectivity returns.
- Generation is asynchronous and can fail: the capture flow must handle pending /
  retry / failed states without losing the player's capture, and without charging
  the cost cap twice.

## Security & config

- Provider API keys and secrets live only in Edge Functions / server config, never
  in the client bundle.
- Postgres **Row-Level Security** enforces per-user data isolation (see
  [Data Model](06-data-model.md)).
- Camera/location permissions are requested with clear, just-in-time rationale.
