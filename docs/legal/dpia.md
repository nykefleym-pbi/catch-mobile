# Cat-ch — Data Protection Impact Assessment (DPIA)

> **Version 1.0 — self-prepared, adopted pre-launch (2026-07-22).** A DPIA is
> mandatory here because the processing is likely to result in a high risk to a
> vulnerable group: the service is a general-audience game that **will include
> children under 13**, and it processes a camera image and (coarse) location
> (UK-GDPR Art. 35; EDPB high-risk criteria: *vulnerable data subjects* +
> *innovative technology* + *data concerning children*). This is an engineering
> DPIA built from the [pre-launch dossier](pre-launch-review.md) §1–§4 and the
> adopted [Privacy Policy](privacy-policy.md) / [Data Handling](data-handling.md).
> It is **not legal advice**; a professional review is recommended before wide
> public launch, and this DPIA must be revisited **before `kSocialLive` is
> flipped on** (see §8).

## 1. Purpose and need for the processing

Cat-ch lets a player photograph a real cat, turns it into a cartoon companion
sprite, and lets them care for it. The processing exists to deliver that core
loop and to keep players (especially children) safe while doing so. Processing is
minimised to what the loop needs — the design choice throughout is to **not
collect** the data that would raise the risk rather than to collect it and manage
it (ADR 0003).

## 2. Description of the processing

Full detail: dossier §1 (data inventory), §2 (sub-processors), and
[Data Handling](data-handling.md) (camera + location flow diagrams). In summary:

| Processing | Personal data | Nature | Retention |
|-----------|---------------|--------|-----------|
| Detect a cat + generate a sprite | camera photo (transient) | on-device detection, then one TLS call to an image provider | **deleted immediately after generation** |
| Frame the map / "where we met" | coarse region label only | precise GPS fuzzed **on device**, precise value discarded | with the cat row until deletion |
| Age-appropriate handling | coarse age band (`under13`/`teen`/`adult`) | self-declared, no birth date | profile |
| Run + save the game | account (anonymous by default), gameplay | owner-scoped (RLS) | until account deletion |
| Keep the community safe | reports, blocks, restrictions | friends-only social + moderation | 12 months after resolution |
| Product analytics | sanitised events | PII/location stripped; **none for under-13** | rolling window |

- **Scope:** general audience, worldwide, explicitly assumed to include under-13s.
- **Context:** a cozy game; no behavioural advertising; no real-money economy; no
  open chat; social is friends-only and off by default for minors.
- **Special-category data:** none intended. Faces are not collected (the subject is
  a *cat*); the on-device detector rejects non-cat images before upload.

## 3. Necessity and proportionality

- **Lawful bases** are recorded per purpose in the
  [lawful-basis register](data-handling.md#lawful-basis-register) (contract for the
  game; consent via OS permission for camera/location; legitimate interests for
  analytics + safety; **verifiable parental consent / Art. 8 authorisation** for
  any under-13 personal data).
- **Minimisation:** no persistent precise location, no retained photos, no real
  names, no contact-list upload, no ad profiling, no biometric identification.
- **Purpose limitation:** each datum is used only for the purpose in §2; the photo
  is never repurposed (it is deleted).
- **Proportionality:** the least-intrusive design that still delivers the loop was
  chosen (e.g. coarse-on-device fuzzing instead of server-side location; ephemeral
  photo instead of a stored gallery).

## 4. Consultation

The processing was reviewed against a child-privacy assessment (the
[`child-privacy-review`](pre-launch-review.md#6-go--no-go-gate) input), whose
central correction is reflected here: **minimisation never removed the MVP from
COPPA/GDPR-K scope** — collecting a child's camera image and coarse location
already engages those regimes — so notice, consent, a lawful-basis register, this
DPIA, and a retention schedule are treated as **launch blockers for the MVP
itself**, not only for social. Data-subject / parent views will be gathered via
the published Privacy Policy + the parental-consent flow before wide launch.

## 5. Risk assessment

Likelihood (L) and Severity (S) on Low / Med / High, after the controls in §6.

| # | Risk to the individual | Inherent | Controls (see §6) | Residual (L×S) |
|---|------------------------|----------|-------------------|----------------|
| R1 | A child's photo is retained or leaked | High | on-device cat-detection gate; single transient TLS send; **deleted immediately after generation**; no-training/no-retention provider terms `[confirm]` | Low × High |
| R2 | A real cat's / child's **location** is exposed | High | precise GPS fuzzed on device and discarded; only a coarse label stored; never a map pin; not shown when visiting | Low × High |
| R3 | An under-13 is drawn into social contact with a stranger | High | under-13 social ban **enforced server-side** (migration 0013); friends-only graph, no stranger queue; no public directory | Low × High |
| R4 | An adult contacts / grooms a minor | High | friends-only + code-based (no discovery); report/block on every surface; moderation floor (0009) + operable console (0011) + interim moderator SLA | Low × High |
| R5 | Processing a child's data without a valid basis | Med | neutral age gate; reduced-data mode for under-13; VPC flow for any under-13 PII; lawful-basis register | Low × Med |
| R6 | Profiling / dark patterns pressure a child | Med | no ad SDKs; analytics off for minors; cosmetic-only, no pay-to-win, no FOMO/countdowns; conservative minor defaults (AADC) | Low × Low |
| R7 | A player cannot exercise their rights | Med | in-app account deletion (cascade) + email route; retention schedule documented | Low × Med |
| R8 | A sub-processor mishandles data / cross-border transfer | Med | Supabase + image provider only; DPAs + transfer basis (SCCs/UK IDTA) `[confirm before launch]` | Med × Med `[open]` |

## 6. Measures to reduce risk (controls)

Technical and organisational measures already in place (evidence: dossier §4):

- **Location:** fuzzed on device; precise coordinates never transmitted or stored.
- **Photos:** screened by moderation, used once, deleted immediately after
  generation; never shown to other users.
- **Minor mode:** age band → `SocialCapabilities`; under-13 = no social (now
  **server-enforced**, migration 0013), teen = friends-only + forced-private
  showcase; analytics sanitiser emits nothing for minors.
- **RLS everywhere:** owner-only by default; the only cross-user reads are
  friends-only, opt-in, adult-only, and routed through guarded SECURITY DEFINER
  RPCs that re-check friendship + block + age (migrations 0010/0012/0014/0015),
  and never return a cat's location.
- **Safety substrate before surfaces:** reports/blocks/restrictions with a hardened
  `submit_report`, a service-role-only moderation action log, and an interim
  moderator [runbook](../ops/moderation-runbook.md) with an SLA.
- **No pay-to-win / no real-money trade:** structural (the stat function takes no
  purchase input; only cosmetics are tradable).
- **Master switch:** `kSocialLive = false` keeps every live user-to-user surface
  off until this DPIA and the pre-launch review clear.

## 7. Residual risk and outcome

After the §6 controls, most risks fall to **Low × High** or lower — acceptable to
operate **pre-launch, with `kSocialLive` off**. Two items remain **open** and are
carried to the go-live gate:

- **R8** (sub-processor DPAs + transfer basis + no-training/no-retention terms) —
  must be confirmed in writing before store submission.
- **Age-assurance sufficiency for the live-social tier** — the ban is now
  server-enforced over a self-declared band; whether that is *sufficient* once
  social is live is a counsel + design decision (AADC proportionality).

## 8. Sign-off and review triggers

- **Owner:** operator (also interim moderator). **Status:** self-prepared v1.0,
  adopted pre-launch; professional review recommended before wide launch.
- **This DPIA must be revisited before any of:** flipping `kSocialLive` on;
  admitting under-13s into any social feature (would require VPC, not the ban);
  adding a new sub-processor or a new data type; introducing any donation /
  real-money surface (Phase 4); or a change in the launch market's jurisdiction.

_Version 1.0 — self-prepared by the operator, adopted pre-launch. Not legal
advice. Inputs: dossier §1–§4, Privacy Policy, Data Handling, ADR 0003/0004._
