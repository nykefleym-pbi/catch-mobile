# Legal / launch open-items checklist

> One place that lists **every unresolved fill-in and blocker** across the legal
> docs, so they can be closed fast. Generated from a sweep of `docs/legal/**`.
> Nothing here is legal advice. `kSocialLive` and the live-social surfaces stay
> gated until the **counsel** + **ops** rows below are closed (pre-launch dossier
> §5–§7).
>
> _Last swept: 2026-07-21._
>
> **⚠️ Status note (2026-07-21):** `kSocialLive` has been **flipped ON by default**
> for this private, not-yet-publicly-live side-project build under the operator's
> documented risk-acceptance (see [pre-launch §8](pre-launch-review.md#8-status-update--2026-07-21-ksociallive-flipped-on-for-this-build)).
> The rows below are therefore **still open** and would need to be closed before any
> real public launch — flipping the flag did not resolve them. The server age gate
> (migration 0013) and the launch-market geo-gate remain in force regardless.

## Legend — who can close it

- **operator** — a business/jurisdiction fact only you have (entity name, address, venue).
- **counsel** — needs a qualified privacy/child-safety attorney's confirmation.
- **contract** — a signed agreement with a third party (DPA / transfer basis).
- **engineer** — verifiable from the codebase or Supabase project; I can fill it on request.
- **decision** — a product/business choice (a retention window, a response SLA).

---

## 1. Business identity (blocks store submission)

| Token | Where | Owner |
|-------|-------|-------|
| `[LEGAL ENTITY / OPERATOR NAME]` | privacy-policy.md:17 · terms-of-service.md:14 · parental-consent-form.md:20 | operator |
| `[OPERATOR NAME]` | privacy-policy.md:155 · terms-of-service.md:110 | operator |
| `[REGISTERED ADDRESS]` | privacy-policy.md:17, 155 | operator |
| `[DPO / RESPONSIBLE PERSON, if applicable]` | privacy-policy.md:20 | operator / counsel |
| Dedicated role email (replace personal `nykefleym@gmail.com`) | privacy-policy.md:155 · terms-of-service.md:110 · parental-consent-form.md:20 | operator / decision |

## 2. Dates & versioning

| Token | Where | Owner |
|-------|-------|-------|
| `[DATE]` effective date (set on public launch) | privacy-policy.md:11 · terms-of-service.md:9 | operator (at launch) |

## 3. Jurisdiction & governing law

| Token | Where | Owner |
|-------|-------|-------|
| `[GOVERNING LAW / VENUE — to finalize]` | terms-of-service.md:105 | counsel |
| `[JURISDICTION-SPECIFIC CONSUMER TERMS to be confirmed before launch]` | terms-of-service.md:99 | counsel |

## 4. Sub-processors, hosting & cross-border transfer (DPIA R8 — flip blocker)

| Token | Where | Owner |
|-------|-------|-------|
| `[HOSTING REGION]` | privacy-policy.md:97 | engineer (Supabase project region) |
| Supabase DPA `[confirm]`; region `[confirm]` | data-handling.md:79 | contract / engineer |
| Image provider DPA + no-training/no-retention `[confirm]` | data-handling.md:80 · dpia.md:76 (R1) | contract |
| `[CONFIRM CONTRACTUAL TERMS]` (provider) | privacy-policy.md:101 | contract |
| `[TRANSFER MECHANISM — SCCs / UK IDTA + TIA]` | privacy-policy.md:104 · data-handling.md:80 · dpia.md:83 (R8) | counsel / contract |

## 5. Retention & rights specifics (decisions to record)

| Token | Where | Owner |
|-------|-------|-------|
| `[confirm cascade coverage in schema]` (account-deletion cascade) | data-handling.md:49 | engineer |
| `[e.g. 14 months]` analytics retention window | data-handling.md:51 | decision |
| `[e.g. 12 months]` consent-record retention after withdrawal | data-handling.md:53 | decision / counsel |
| `[RETENTION PERIOD]` (moderation/safety logs) | privacy-policy.md:112 | decision |
| `[RESPONSE WINDOW, e.g. 30 days]` data-subject-request SLA | privacy-policy.md:125 | decision |
| `[LINK / appendix]` lawful-basis register | data-handling.md:72 | engineer (link the existing register) |

## 6. Consent mechanics (under-13 — flip blocker if under-13 ever admitted to social)

| Item | Where | Owner |
|------|-------|-------|
| Verifiable parental-consent **verification method** to finalise | parental-consent-form.md:84 | counsel / decision |

## 7. Non-token blockers (no fill-in; a human act) — gate `kSocialLive`

1. **Counsel sign-off** — age-assurance sufficiency for the live-social risk tier; confirm the under-13 ban is the chosen posture vs. building VPC. _(counsel)_
2. **Signed DPAs + transfer basis** — Supabase + image provider; rows in §4. _(contract)_
3. **Professional review** of Privacy Policy / ToS / DPIA (self-prepared v1.0). _(counsel)_
4. **Store privacy declarations + geo-gate the launch market.** Geo-gate mechanism now scaffolded (`SocialLaunchGate` + `LAUNCH_MARKETS` dart-define); the *market decision* + store data-safety forms remain. _(operator / decision)_
5. **Moderation staffing** — a human on the `mod_*` RPCs per the runbook. Substrate + runbook exist; the person is the open item. _(operator)_
6. **Multi-profile staging swap test** — 2-account `execute_trade` round-trip before turning trading on live. _(engineer)_

---

### Notes

- Items marked **engineer** I can close now on request (hosting region, cascade
  coverage, lawful-basis link) — say the word and I'll fill them in the docs.
- Everything else needs a fact, a signature, a decision, or counsel — none are code.
