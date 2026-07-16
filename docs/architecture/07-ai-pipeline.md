# 07 — AI Pipeline

How a photographed real cat becomes a unique virtual companion. The chosen
approach is **on-device detection + cloud generation**: the phone decides *whether*
it's a real cat (fast, free, private); a server-side service decides *what the
companion looks like* (higher quality, cost-controlled).

## End-to-end flow

```
[1] Camera capture (Flutter camera)
        │
        ▼
[2] On-device detection  (ML Kit / TFLite)
    • Is this a REAL cat?  (reject drawings, plush toys, TV/monitor screens, fake images)
    • Image quality gate   (blur, exposure, subject size)
        │  reject → friendly, non-punitive feedback ("Hmm, we couldn't find a cat — try again!")
        │  accept
        ▼
[3] Fuzz location on-device  → coarse region only; discard precise coords
        │
        ▼
[4] Submit to Supabase Edge Function `generate-companion`
    • authenticate the user
    • rate-limit + enforce per-user/day cost cap
    • server-side image moderation (safety)
    • per-user duplicate heuristic (perceptual hash vs this user's prior captures)
        │
        ▼
[5] Call cloud generation service (keys server-side only)
    • produce a STYLIZED, cute companion
    • transparent-background PNG sprite
    • conditioned on the source photo to echo identity (see fidelity caveat)
        │
        ▼
[6] Store sprite in Storage/CDN; extract descriptive metadata
    (coat color, pattern, eye color, tail shape, distinctive markings)
        │
        ▼
[7] Create `cats` + `catdex_entry` + `care_state`; return to client
        │
        ▼
[8] Companion appears in the CatDex with a simple idle presentation
```

Statuses (`captures.status`): `pending → generating → complete | failed |
rejected`. Generation is **asynchronous**; the client shows pending/retry/failed
states and never loses the capture.

## Stage 2 — On-device detection (the gate)

**Goal:** cheap, private, fast filtering so we only spend generation cost on real
cats.

- **Is-a-real-cat classifier:** ML Kit image labeling / object detection or a
  bundled TFLite model. Must accept genuine cats and reject the brief's named
  failure cases: drawings, toys, television/monitor screens, and other obvious
  fakes.
- **Quality gate:** reject blurry, too-dark, or subject-too-small photos with
  kind guidance.
- **Metrics to watch:** false-accept rate (fakes slipping through → wasted cost +
  bad companions) and false-reject rate (real cats blocked → player frustration).
  Tune the confidence threshold against both. Tracked in
  [MVP Scope](../product/02-mvp-scope.md).
- **Anti-spoofing is imperfect.** On-device screening will not catch every staged
  fake; server-side moderation and rate limits are the backstop, not the client
  alone.

## Stage 5 — Cloud generation (the transformation)

**Goal:** a delightful, cute, **unique** companion that a player recognizes as
*their* cat.

### The identity-fidelity caveat (important, honest framing)

The brief asks that generation **preserve** the cat's fur color, patterns, eye
color, tail shape, distinctive markings, and personality. Stylized generative
models **approximate** these features via **style conditioning** — they do not
guarantee pixel-faithful reproduction of unique markings. We therefore treat
identity preservation as a **best-effort goal with a stated caveat**, not a
guarantee:

- Condition generation on the source image and/or extracted attributes so output
  echoes the real cat's dominant colors, pattern family, and features.
- Persist the extracted attributes as `generation_meta` so the CatDex can describe
  the cat accurately even where the sprite stylizes details.
- Measure player-rated "does this look like the cat?" satisfaction and iterate on
  prompt/conditioning/model choice.
- Every generated cat should still be **visually unique**.

**Provider (pluggable — free-first, [ADR 0001](../decisions/0001-image-generation.md)):**
the Edge Function selects a backend at runtime via the `IMAGE_PROVIDER` env var,
so the provider is swappable without a client change:

- **`cloudflare` (current default)** — **Cloudflare Workers AI** Stable-Diffusion
  **img2img** (`@cf/bytedance/stable-diffusion-xl-lightning`, overridable via
  `CLOUDFLARE_IMAGE_MODEL`). Genuinely free within a daily allowance. The source
  photo is passed as `image_b64` at `strength ~0.6` so coat colour and markings
  carry through while the model restyles. Metadata (name + trait) is generated
  locally, since SD can't read the photo into attributes.
- **`gemini` (switchable)** — **Google Gemini "2.5 Flash Image"** ("nano-banana")
  for the sprite plus Gemini structured-JSON for descriptive metadata. Kept fully
  wired; requires Gemini API billing (its free tier yields effectively no image
  quota). Set `IMAGE_PROVIDER=gemini` to switch back.

Free/SD image models generally output on a solid background, and SD img2img is
lower and less consistent in quality than nano-banana. Producing a truly
transparent sprite via **`rembg`** (open-source) or on-device subject segmentation
(`photo → stylize → background removal → transparent PNG`) remains a hardening
follow-up.

### Animation (later)

v1 ships a static sprite plus a minimal idle (e.g. breathing/blink). Richer idle
animations — blink, ear twitch, tail sway, sit, stretch, sleep — come in Phase 2
via lightweight skeletal or generated-frame animation (Rive/Spine/Live2D
evaluation in [Technical Architecture](05-technical-architecture.md)).

## Anti-abuse & cost control (server-side, non-negotiable)

Generation is the primary variable cost and the primary abuse vector. The Edge
Function enforces:

- **Authentication** — no anonymous generation.
- **Rate limiting** — per-user and global ceilings.
- **Cost caps** — per-user/day generation budget; fail gracefully at the cap
  without double-charging on retries.
- **Image moderation** — screen submissions for unsafe/abusive content before
  generation and before any social surface can show them.
- **Duplicate detection, done privately** — the brief asks to "detect duplicate
  captures." We do this **per user** using a **perceptual hash** compared against
  that user's own prior captures — *not* by building a global registry of which
  real cat lives where. A global registry would create exactly the location-privacy
  and animal-safety harms the [ethics rules](../08-ethics-privacy-safety.md)
  forbid. Cross-user "same cat" detection is deliberately **not** a goal.

## Privacy summary

- Location is fuzzed **before** upload; precise coordinates are never persisted for
  display.
- Raw source photos are used for detection/generation, then **deleted immediately
  after generation succeeds** — only the sprite and non-identifying
  `generation_meta` are kept ([ADR 0001](../decisions/0001-image-generation.md)).
  Moderation runs *before* deletion.
- Generation runs behind our server; provider keys never ship in the client.
