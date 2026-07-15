# ADR 0001 — Free-first image generation & source-photo deletion

- **Status:** Accepted
- **Date:** 2026-07-15
- **Relates to:** [AI Pipeline](../architecture/07-ai-pipeline.md),
  [Ethics, Privacy & Safety](../08-ethics-privacy-safety.md),
  [Risks & Open Questions](../10-risks-and-open-questions.md) (R4)

## Context

Companion generation is the "magic moment" of Cat-ch and the only meaningful
variable cost in the stack. Cat-ch is a **side project expecting a small
audience**, so the maintainer's priority is to keep generation **as close to free
as possible**, accepting some quality/latency trade-offs. The model must accept the
**real cat photo as input** (image-to-image / editing) so the companion echoes the
real cat's colours, pattern, and features — text-only generation would produce a
generic cat and break the core promise. Output must end up as a **transparent-
background PNG sprite**.

## Decision

**Free-first, hosted, image-conditioned generation, kept swappable behind the
Supabase Edge Function.**

- **Primary generator:** **Google Gemini "2.5 Flash Image" via the AI Studio free
  tier.** Strong at identity-preserving stylization; a genuine free tier
  (rate-limited) that can cost ~$0 at small volume, with a pennies-per-image paid
  tier if we outgrow it — no rewrite needed to scale.
- **Transparency:** free models generally output on a solid background, so we
  produce the transparent sprite ourselves with **`rembg`** (open-source, MIT/
  server-side) — or on-device subject segmentation — as a post-step. Flow:
  photo → Gemini stylize → background removal → transparent PNG.
- **Fallback generator:** **Cloudflare Workers AI** (free daily allowance,
  image-to-image models) if we hit Gemini rate limits or want a single ecosystem.
- **Not now:** paid-only APIs (e.g. gpt-image-1) and self-hosted GPU pipelines.
  Self-hosting only makes sense at high, steady volume; revisit then.
- **Swappable:** all generation stays behind the `generate-companion` Edge
  Function so the provider can change without touching the client.

**Source-photo retention:** the raw captured photo is **deleted immediately after
generation succeeds** — we keep only the generated sprite plus non-identifying
`generation_meta`. (Confirmed maintainer decision; supersedes the earlier
"favor deletion" default.)

## Consequences / caveats

- **Free tiers typically train on submitted data.** During generation the provider
  still receives the user's photo, even though *we* delete our copy. Accepted for
  the free MVP and **must be disclosed in the privacy policy**. Revisit if the
  audience grows or skews heavily toward minors; the cheap escape hatch is Gemini's
  paid tier (does not train on your data) or a retention-controlled provider.
- **Identity fidelity is best-effort**, not guaranteed — consistent with the
  style-conditioning caveat in the [AI Pipeline](../architecture/07-ai-pipeline.md).
- **Deleting source photos limits post-hoc moderation.** If a generated sprite is
  later reported, we won't have the original to review. Acceptable given on-device
  detection + pre-generation moderation run *before* deletion; note it in the
  moderation policy.
- **Rate limits** on the free tier bound throughput; the Edge Function's per-user
  and global caps should be set to stay within them.

## Your-side items (maintainer)

- [ ] Create a free **Google AI Studio** account and generate a **Gemini API key**
      (stored server-side in Supabase, never in the client).
- [ ] Confirm the **free-tier-trains-on-data** stance: accept-and-disclose (chosen
      default) vs. pay pennies to avoid — decision recorded as accept-and-disclose
      unless changed.
- [ ] (When we reach it) decide the background-removal location: server-side
      `rembg` vs. on-device segmentation — eng call, no maintainer action needed
      yet.
