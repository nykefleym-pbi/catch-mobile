# Pre-launch Compliance-Readiness Dossier

> **This is an engineering self-assessment, NOT legal advice.** It exists to give
> a qualified privacy/child-safety attorney (or a legal-review tool such as the
> org's `regulatory-legal` / `privacy-legal` plugins) a complete, accurate picture
> of what Cat-ch collects, stores, and exposes, so their review is fast and
> grounded. Nothing here is a sign-off. Per [ADR 0003](../decisions/0003-child-safety-strategy.md)
> and [Risks R7](../10-risks-and-open-questions.md), a **one-time human
> legal/privacy review is required before public launch**, and again **before
> flipping `kSocialLive` on** for any live user-to-user surface.

- **Product:** Cat-ch — a cozy mobile game (Flutter client + Supabase backend).
- **Audience:** general audience that **will include children under 13**. This is
  the governing assumption; we design to the strictest applicable regime.
- **Regimes in scope:** COPPA (US, 16 CFR Part 312); GDPR incl. Art. 8 child
  consent ("GDPR-K", EU); UK Age-Appropriate Design Code ("AADC" / Children's
  Code); plus general GDPR/UK-GDPR and CCPA/CPRA as the market expands.
- **Reviewed source docs:** [`08-ethics-privacy-safety.md`](../08-ethics-privacy-safety.md),
  [ADR 0003](../decisions/0003-child-safety-strategy.md),
  [ADR 0004](../decisions/0004-phase3-social-safety.md),
  [`09-monetization-and-impact.md`](../09-monetization-and-impact.md),
  [`06-data-model.md`](../architecture/06-data-model.md),
  [`07-ai-pipeline.md`](../architecture/07-ai-pipeline.md).

---

## 1. Data inventory (what we actually collect)

| Data | Collected? | Purpose | Retention | Notes |
|------|-----------|---------|-----------|-------|
| Camera image (a cat photo) | Yes, just-in-time | on-device detection + cloud sprite generation | **Deleted immediately after generation** (ADR 0001) | Never shown to other users; never stored long-term. |
| Precise GPS coordinates | **No (not persisted)** | — | — | Fuzzed to coarse region **on-device before upload**; precise value discarded. |
| Coarse region / neighbourhood label | Yes | map/exploration framing | with the cat row | e.g. "Downtown"; never a pin on a home. |
| Age bracket (`under13`/`teen`/`adult`) | Yes | drive reduced-data + social gating | profile | **Band only — never a birth date.** |
| Display name (optional, self-chosen) | Optional | Guardian identity | profile | Free-text, user-set; not verified; no real-name requirement. |
| Auth identity | Yes | account | Supabase Auth | **Anonymous by default**; email only if an adult opts into cloud backup. |
| Care/collection state, cosmetics | Yes | gameplay | owner row (RLS) | No special-category data. |
| Social graph (friends, blocks, reports) | Phase 3 | friends-only social + safety | RLS, owner/party-scoped | Friend code only — no directory, no contact-list upload. |
| Analytics events | Yes | product analytics | per `AnalyticsSanitizer` | PII/location-stripped; **empty for minors** (reduced-data). |
| Behavioural ad profiles | **No** | — | — | No ad SDKs, no third-party ad targeting. |

**Data-minimisation posture (ADR 0003):** the strategy is to *avoid* the heaviest
COPPA/GDPR-K/AADC triggers by **not collecting** the data that demands them
(no precise location, no retained photos, no real names, no ad profiling, no open
chat), rather than building heavy consent machinery to manage collected data.

## 2. Sub-processors (third parties that touch data)

| Processor | Role | Data seen | Review need |
|-----------|------|-----------|-------------|
| Supabase | Auth, Postgres, Storage, Edge, Realtime | all persisted app data | DPA in place? hosting region vs EU/UK data-transfer basis? |
| Image-generation provider (Cloudflare Workers AI default; Gemini switchable — ADR 0001) | sprite generation | **the source photo, transiently** | contractual no-training/no-retention terms; sub-processor disclosure. |

**Counsel action:** confirm signed DPAs, sub-processor lists, transfer mechanisms
(SCCs/UK IDTA), and no-training/no-retention terms for any image provider that
receives a child's photo — even transiently.

## 3. Regulatory mapping (control present ✔ / gap = "GAP")

### COPPA (US)
- ✔ Data minimisation: no persistent precise location; photos deleted post-gen.
- ✔ No behavioural advertising to children.
- ✔ Neutral age gate + reduced-data mode for under-13.
- ✔ Reporting/blocking + moderation floor before any user-to-user surface (ADR 0004; migrations 0009/0011).
- **GAP** — **Verifiable Parental Consent (VPC):** currently none. Defensible *only*
  while under-13 collect essentially no personal information. **Any** under-13 PII
  collection, or letting under-13 into social, requires VPC or a firm under-13
  social ban. Decision needed (see §5).
- **GAP** — **Direct notice + Privacy Policy** meeting §312.4 content rules: not drafted.

### GDPR / GDPR-K (EU, Art. 8)
- ✔ Privacy-by-design/default (Art. 25): RLS owner-only default, fuzzing, deletion.
- ✔ Purpose limitation + minimisation for the data listed above.
- **GAP** — **Lawful basis** per processing purpose, documented (Art. 6) — not written.
- **GAP** — **Art. 8 child consent / parental authorisation** where consent is the
  basis and the user is under the member-state digital-consent age (13–16).
- **GAP** — **Records of Processing (Art. 30)** and a formal **DPIA (Art. 35)** —
  this dossier is the input, not the DPIA itself.
- **GAP** — **Data-subject rights flow** (access/erasure/portability) — no in-app path.

### UK Age-Appropriate Design Code (15 standards)
- ✔ Best interests of the child; data minimisation; no nudge toward weaker privacy.
- ✔ "High privacy by default" for minors: showcase forced private for teens,
  no social for under-13, conservative defaults (ADR 0004).
- ✔ No detrimental use; no profiling on by default; transparent, kind copy.
- ~ **Partial — Age assurance:** a self-declared neutral gate is the *input*, but
  the declared band is now **enforced at the trust boundary**, not just in the UI:
  migration 0013 makes every social write RPC (`friend_request_by_code`,
  `propose_match` / `respond_match`, `propose_trade` / `execute_trade`) re-check
  `profiles.age_bracket` in the database, and the client makes the under-13
  declaration a one-way ratchet (`age_gate.dart`). This is proportionate assurance,
  not birth-date verification; whether it is *sufficient* for the live-social risk
  tier remains a counsel + design call. See §7.
- **GAP** — **Published, child-friendly privacy information** and a **Data
  Protection Impact Assessment** formally recorded.

## 4. What's technically enforced already (evidence for the review)

- **Location:** fuzzed on-device, precise coords never persisted (`08` §Location; data model).
- **Photos:** deleted immediately after successful generation (ADR 0001); moderation runs *before* deletion (`07`).
- **Minor mode:** age bracket → `SocialCapabilities`; under-13 = no social, teen = friends-only + forced-private showcase; analytics sanitiser emits nothing for minors.
- **Moderation floor:** hardened rate-limited `submit_report`, service-role-only `moderation_actions`, `restrictions`, and the operable moderator RPCs (migrations 0009 + 0011).
- **Social is friends-only + code-based:** no public directory, no stranger pairing (friendships, matches, trades all require an accepted friendship).
- **No pay-to-win / no real-money trade:** structural — `CatStats.derive` takes no purchase input; only `is_cosmetic` items are tradable (safe_play + 0010).
- **`kSocialLive = false`:** the master switch keeps every live user-to-user surface off until this review clears.

## 5. Must-resolve before flipping `kSocialLive` (escalate to counsel)

1. **Under-13 social decision (highest priority).** Either (a) **hard-ban under-13
   from all social** (simplest COPPA/AADC posture — the current gate already routes
   them out), or (b) build **VPC / verifiable parental consent** + parental controls.
   Recommend (a) for launch. Counsel to confirm the ban is sufficient and correctly
   implemented.
2. **Draft & publish Privacy Policy + Terms of Service** (child-friendly versions),
   meeting COPPA §312.4 direct-notice content and AADC transparency.
3. **Formal DPIA (Art. 35)** and **Records of Processing (Art. 30)**, using §1–§4 here.
4. **Lawful-basis register** per processing purpose (Art. 6), incl. the analytics basis.
5. **Sub-processor / DPA confirmation** (Supabase + image provider), transfer
   mechanism (SCCs/UK IDTA), and no-training/no-retention terms for photo processing.
6. **Data-subject-rights path** (access/delete/export) — at minimum an email route,
   ideally in-app.
7. **Age-assurance sufficiency** for the live-social risk tier (AADC proportionality).
8. **Retention schedule** written down (photos = ephemeral; report/moderation logs;
   account deletion cascade — cascades exist in schema, need a documented policy).

## 6. Go / no-go gate

`kSocialLive` stays **false** until the go-live items below are resolved. This
dossier was handed to a review (see `child-privacy-review` output) which confirmed
the central correction: **data-minimisation never shielded the MVP** — collecting a
child's camera image + coarse location already engages COPPA/GDPR-K, so a Privacy
Policy, notice, lawful-basis register, DPIA, and retention schedule are **public-launch
blockers for the MVP itself**, not just for social.

## 7. Status update — 2026-07-21 (operator decisions)

The operator elected to proceed pre-launch treating the self-prepared legal artifacts
as adopted v1.0 (app is **not yet publicly live**; a professional review remains
recommended before wide launch — not a lawyer sign-off), and to act as the **sole
interim moderator**.

**Now in place (this branch):**
- [Privacy Policy](privacy-policy.md) v1.0 — covers camera + location handling,
  children's section, parental rights (COPPA §312.4 / GDPR Art. 12–14 shape).
- [Terms of Service](terms-of-service.md) v1.0 — eligibility/age, kindness rules,
  cosmetic-only economy, social rules, moderation/termination.
- [Parental Consent Form](parental-consent-form.md) v1.0 — VPC notice + form for
  under-13 (verification method still to finalise).
- [Data Handling](data-handling.md) v1.0 — camera/location data flows, **retention
  schedule**, **lawful-basis register**, sub-processors.
- [Moderation Runbook](../ops/moderation-runbook.md) — solo-moderator workflow over
  the `mod_*` RPCs with a 24–48h SLA (satisfies "a human reads reports").

**Still blocking a real `kSocialLive` flip (technical + decision):**
1. ~~**Age assurance** stronger than pure self-declaration~~ **— substantially
   addressed (2026-07-22).** The under-13 social ban is no longer cosmetic:
   migration 0013 enforces the age band **server-side** in every social write RPC
   (a modified client can no longer reach trading/matching/friend-requests around
   the ban), and the client declaration is a one-way ratchet that cannot be
   re-rolled to unlock social (`age_gate.dart`). Residual: this is proportionate
   assurance over a **self-declared** band, not birth-date verification — counsel
   still confirms sufficiency for the live-social risk tier (AADC proportionality),
   and any move to admit under-13 into social would require VPC instead of the ban.
2. ~~**Client social UIs**~~ **— built (2026-07-22).** Every Phase 3 social
   surface now has a real, gated client (rendering honest gated states while
   `kSocialLive` is off): friendly contests/matches, visiting a friend's
   showcase, shared photo albums, clubs + cooperative challenges, and **cosmetic
   trading** — the last one unblocked by seeding a tradable-cosmetic charm
   catalogue (migration 0017). Still owed before the flip: a full multi-profile
   staging test of the trade swap, and the moderation-staffing + realtime
   prerequisites below (these are ops/decision items, not client code).
3. ~~**DPIA** written up from §1–§4~~ **— drafted (2026-07-22):**
   [dpia.md](dpia.md) (self-prepared v1.0). Residual open items it carries:
   sub-processor DPAs + transfer basis (R8), and age-assurance sufficiency for the
   live-social tier. Must be revisited before `kSocialLive` flips.
4. **Store privacy declarations** + geo-gating the actual launch market.
5. Fill remaining `[PLACEHOLDER]` business/jurisdiction facts; finalise the consent
   verification method; confirm sub-processor DPAs + transfer basis.

## 8. Status update — 2026-07-21 (`kSocialLive` flipped ON for this build)

The operator — treating Cat-ch as a **personal, not-yet-publicly-live side
project** — elected to **flip `kSocialLive` on by default** (`--dart-define=SOCIAL_LIVE=false`
forces it back off), explicitly accepting the residual legal/ops risk catalogued in
[OPEN-ITEMS.md](OPEN-ITEMS.md). This is a documented risk-acceptance for a private
build, **not** a determination that the go-live gate in §6 is cleared. Should this
project ever move toward a real public launch, the §5/§7 counsel + contract items
must be resolved first.

The safety controls that sit **in series with** the flag remain fully in force and
are unaffected by it:
- **Server-enforced age band** (migration 0013): under-13 can never reach
  trading/matching/friend-requests regardless of client build — verified during a
  staging swap test (a non-adult proposer was rejected with `age_restricted`).
- **Launch-market geo-gate** (new): `SocialLaunchGate` + the `LAUNCH_MARKETS`
  dart-define keep live social off outside cleared markets; unknown region fails
  closed. Empty allowlist = unrestricted (the current single-region default).
- **Cosmetic-only + atomic swap** (migration 0010): re-validated server-side; a
  2-profile `execute_trade` round-trip was verified end-to-end (rolled back, no
  production mutation).

_Last updated: 2026-07-21. Owner: operator (also interim moderator). Status:
**legal artifacts adopted v1.0 pre-launch; under-13 social ban server-enforced
(migration 0013); geo-gate scaffolded; `kSocialLive` flipped ON by default for
this private side-project build under documented risk-acceptance — public-launch
go-live items in §5/§7 remain open.**_
