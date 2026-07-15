# 10 — Risks & Open Questions

A consolidated register of the things most likely to hurt Cat-ch, and the
decisions still owed. Each item has an **impact** and either a **mitigation** or
the **decision** that must be made. Review this list at each phase gate in the
[Roadmap](product/03-roadmap.md).

## Legend

- **Impact:** how bad it is if unaddressed (Low / Med / High).
- **Owner:** the discipline that must resolve it (eng, design, legal, ops).

---

## Product & AI risks

### R1 — AI generation fidelity ("does it look like my cat?")
- **Impact:** High. The magic moment is the transformation; if companions don't
  feel like the real cat, the core loop under-delivers.
- **Mitigation:** frame identity preservation as best-effort **style conditioning**
  with a stated caveat (see [AI Pipeline](architecture/07-ai-pipeline.md)); persist
  extracted attributes; measure player-rated satisfaction; iterate on
  model/prompt/conditioning.
- **Owner:** eng + design.

### R2 — AI generation cost & abuse
- **Impact:** High. Generation is the main variable cost and a prime abuse vector.
- **Mitigation:** server-side Edge Function with auth, rate limits, per-user/day
  cost caps, image moderation, and per-user perceptual-hash dedupe. Cheap on-device
  detection filters non-cats *before* paying for generation.
- **Owner:** eng.

### R3 — Detection accuracy (false accepts / false rejects)
- **Impact:** Med. False accepts waste cost and produce junk companions; false
  rejects frustrate players photographing real cats.
- **Mitigation:** tune thresholds against both error rates; friendly non-punitive
  rejection UX; server moderation as backstop.
- **Owner:** eng.

### R4 — Generation provider choice — ✅ DECIDED ([ADR 0001](decisions/0001-image-generation.md))
- **Impact:** Med. Hosted image API vs. self-hosted pipeline.
- **Decision:** free-first — **Gemini "2.5 Flash Image" (AI Studio free tier)** as
  primary + **`rembg`** for transparency; **Cloudflare Workers AI** fallback; kept
  swappable behind the Edge Function. Revisit provider on cost/quality data.
- **Residual risk:** free tiers train on submitted data (disclose in privacy
  policy; escape hatch = cheap paid tier). Free-tier rate limits bound throughput.
- **Owner:** eng.

### R5 — Animation tech (Rive vs Spine 2D vs Live2D)
- **Impact:** Low for v1 (minimal idle only), Med later.
- **Decision owed:** evaluate **Rive** (lighter, Flutter-friendly) against Spine/
  Live2D on quality, licensing, and runtime cost before Phase 2 animation work.
- **Owner:** eng + design.

## Privacy, safety & compliance risks

### R6 — Location privacy for real (often owned/vulnerable) cats
- **Impact:** High. Revealing where a specific cat lives is a real-world safety
  harm and a reputational catastrophe.
- **Mitigation:** fuzz-early/discard-precise; no individual-cat location registry;
  per-user-only dedupe. Enforced as a hard rule in
  [Ethics, Privacy & Safety](08-ethics-privacy-safety.md).
- **Owner:** eng + design.

### R7 — Minors, camera & location (COPPA / GDPR-K / AADC) — ◑ STRATEGY DECIDED ([ADR 0003](decisions/0003-child-safety-strategy.md))
- **Impact:** High. A minor-inclusive app collecting camera + location has serious
  regulatory exposure.
- **Strategy:** data-minimization to *avoid* the heavy triggers — delete source
  photos, fuzz location, no real names / precise-location storage / behavioral
  profiling, no open chat in v1; neutral age gate + reduced-data mode for under-age
  users; launch narrow in home market first.
- **Residual (owed):** (a) a **one-time legal/privacy review before public launch**,
  and (b) confirming the specific home-market obligations once the launch country is
  fixed. This doc is privacy-by-design, **not legal advice**.
- **Owner:** legal + design.

### R8 — App Store / Play Store policy
- **Impact:** High. Location games, AI-generated content, in-app charitable
  donations, and apps used by minors each carry specific store rules; a rejection
  blocks launch.
- **Decision owed:** review Apple/Google policies for each of these areas early;
  design the donation flow to comply with platform charitable-giving rules.
- **Owner:** eng + legal.

### R9 — Moderation load
- **Impact:** Med–High. User photos and (later) social features need moderation to
  stay safe and kind; under-resourcing it invites harm.
- **Mitigation:** server-side image moderation from day one; reporting/blocking on
  every shared surface; build moderation tooling before wide social release
  (Phase 5).
- **Owner:** ops + eng.

## Mission & business risks

### R10 — Donation model legal/financial feasibility
- **Impact:** High. The 60/30/10 promise is a legal, tax, and accounting
  commitment, not a code change; getting it wrong is a trust and legal failure.
- **Mitigation / decision owed:** establish the giving structure (registered
  nonprofit / fiscal sponsor / benefit corp), partner vetting, audited
  reconciliation, and platform-fee-aware accounting **before** any public claim.
  Treat percentages as targets to validate. See
  [Monetization & Impact](09-monetization-and-impact.md).
- **Owner:** legal + finance + ops.

### R11 — Real-world Guardian Mission safety & verification
- **Impact:** Med–High. Encouraging real-world actions risks unsafe behavior toward
  animals/people/property, and verifying completion is hard.
- **Mitigation:** favor low-risk, education-and-support, self-reported missions;
  never ask players to approach/handle unfamiliar animals; design verification
  conservatively. See [Game Systems](product/04-game-systems.md) and the ethics doc.
- **Owner:** design + ops.

### R12 — Animal-welfare liability & reputation
- **Impact:** Med. A game about real animals will be judged on whether it actually
  helps them and never harms them.
- **Mitigation:** welfare-first design rules, transparency reporting, accredited-
  partners-only, and conservative real-world mechanics.
- **Owner:** design + ops + legal.

## Unresolved decisions (quick list)

- ~~v1 image-generation provider (R4).~~ ✅ Decided — [ADR 0001](decisions/0001-image-generation.md).
- ~~Raw source-photo retention.~~ ✅ Decided — delete immediately after generation ([ADR 0001](decisions/0001-image-generation.md)).
- ~~Flutter state-management library (Phase 0).~~ ✅ Decided — Riverpod ([ADR 0002](decisions/0002-tech-stack-phase0.md)).
- ~~Analytics/crash provider (Phase 0).~~ ✅ Decided — Sentry + minimal event logging ([ADR 0002](decisions/0002-tech-stack-phase0.md)).
- ◑ Child-safety: strategy decided ([ADR 0003](decisions/0003-child-safety-strategy.md)); **owed** — pick the specific home market + a pre-launch legal review (R7).
- Animation runtime (R5).
- Legal giving structure for donations (R10).
