# Cat-ch — Data Handling (camera, location, retention & lawful basis)

> **Version 1.0 — adopted (pre-launch).** The operational companion to the
> [Privacy Policy](privacy-policy.md): exactly how camera and location data flow
> through the system, how long each data type is kept, and the lawful basis for each
> purpose. Self-prepared by the operator; a professional review is recommended
> before wide public launch.

## 1. Camera data flow (photo of a cat)

```
Player taps capture
  → Camera permission requested just-in-time (with plain rationale)
  → Photo captured on device
  → ON-DEVICE: ML Kit detection checks it shows a real cat (reject drawings/toys/screens)
  → Photo sent over TLS to the generate-companion Edge Function
  → Edge Function calls the image provider (Cloudflare Workers AI default / Gemini)
     to produce a stylised sprite  [provider receives the photo TRANSIENTLY]
  → Sprite stored in the `sprites` bucket; non-identifying generation_meta saved
  → SOURCE PHOTO DELETED immediately after successful generation (ADR 0001)
```

- The original photo is **never** shown to other users, never persisted long-term,
  and never used for advertising or person-identification.
- Server-side moderation screens the image **before** any use and before deletion.
- If the player declines camera access, the app degrades gracefully.

## 2. Location data flow (coarse only)

```
Player enables location (optional, just-in-time)
  → ON-DEVICE: precise coordinates reduced to a coarse area (~neighbourhood)
  → PRECISE COORDINATES DISCARDED on device — never transmitted or stored
  → Only the coarse area / human label (e.g. "Downtown") is sent and stored
```

- We never store precise coordinates and never publish a map of where a specific
  real cat lives. Duplicate detection is per-user only; cross-user "same cat"
  matching is intentionally not built.
- If the player declines location access, the app works with reduced map features.

## 3. Retention schedule

| Data | Retention | Trigger / notes |
|------|-----------|-----------------|
| Source capture photo | **Ephemeral** — deleted immediately after sprite generation | Automatic on generation success; screened by moderation first |
| Generated sprite + `generation_meta` | Until the companion or account is deleted | Non-identifying |
| Coarse location label | Until the companion or account is deleted | No precise coordinates ever held |
| Age band, display name, gameplay data | Until account deletion (cascade) | `[confirm cascade coverage in schema]` |
| Account / auth | Until account deletion | Anonymous by default |
| Analytics events | Rolling `[e.g. 14 months]`; none collected for under-13 reduced-data mode | PII/location stripped by `AnalyticsSanitizer` |
| Reports, restrictions, moderation actions | **12 months** after resolution (community-safety + legal obligation), then deleted or anonymised | May be kept longer if needed for an ongoing safety matter |
| Parental-consent records (under-13) | Kept while consent is relied upon + `[e.g. 12 months]` after withdrawal/account deletion, as evidence of consent | COPPA record-keeping |

Deletion is implemented through database cascades keyed to the account; a player can
trigger account deletion in-app or by emailing nykefleym@gmail.com.

## 4. Lawful-basis register

Per GDPR/UK-GDPR Art. 6 (and, for children, parental consent/authorisation).

| Purpose | Personal data | Lawful basis |
|---------|---------------|--------------|
| Run the game & save progress | account, gameplay data | **Contract** |
| Detect a cat + generate a sprite | capture photo (transient) | **Consent** (camera permission) + **contract** |
| Frame exploration / map | coarse location label | **Consent** (location permission) + **legitimate interests** (a working map) |
| Product analytics | sanitised event data | **Legitimate interests** (improve the game); off for minors |
| Keep the community safe | reports, restrictions, moderation actions | **Legitimate interests** + **legal obligation** |
| Collect any personal data from a child under 13 | as above | **Verifiable parental consent** (COPPA) / **parental authorisation** (GDPR-K Art. 8) |

Where we rely on legitimate interests, a Legitimate Interests Assessment is recorded
at `[LINK / appendix]`; where we rely on consent, it is freely given via the OS
permission prompt and withdrawable by revoking the permission or deleting the account.

## 5. Sub-processors

| Processor | Role | Data seen | Safeguards |
|-----------|------|-----------|------------|
| `[Supabase]` | auth, DB, storage, realtime | account + gameplay data | DPA `[confirm]`; region `[confirm]` |
| `[Image provider — Cloudflare Workers AI / Gemini]` | sprite generation | capture photo (transient) | DPA + no-training/no-retention `[confirm]`; transfer basis `[SCCs/IDTA + TIA if applicable]` |

---

_Version 1.0, self-prepared by the operator and adopted pre-launch. Confirm the
bracketed processor, region, and transfer facts before store submission._
