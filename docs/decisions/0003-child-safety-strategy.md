# ADR 0003 — Child-safety strategy: minimize data, launch narrow

- **Status:** Accepted
- **Date:** 2026-07-15
- **Relates to:** [Ethics, Privacy & Safety](../08-ethics-privacy-safety.md),
  [MVP Scope](../product/02-mvp-scope.md),
  [Risks & Open Questions](../10-risks-and-open-questions.md) (R7)

## Context

Cat-ch is a cat game — plausibly "directed to children" in regulators' eyes — that
uses **camera + location**, two of the most sensitive data categories. Regimes like
COPPA (US), GDPR-K (EU), and the UK Age-Appropriate Design Code impose heavy
obligations (verifiable parental consent, DPIAs, etc.) when you *collect* personal
data from minors. For a **small side project**, building that machinery is out of
proportion — and the far cheaper path is to **not collect the data that triggers
it**.

## Decision

**Compliance-by-minimization, plus a narrow initial launch.**

- **Minimize data so the heavy triggers don't fire.** No real names; precise
  location is never stored (fuzzed on-device); source photos are deleted after
  generation ([ADR 0001](0001-image-generation.md)); no behavioral ad profiling;
  no open chat in v1 (social is deferred to Phase 3). What we don't collect, we
  don't have to protect or seek consent for.
- **Neutral age gate at onboarding** with a **reduced-data mode** for under-age
  users — no personal-data collection, no profiling. No parental-consent flow is
  built for the MVP because the data that would require it isn't collected.
- **Launch narrow: the maintainer's home market first**, then expand. Each region
  layers on its own rules; a single-market launch keeps the compliance surface
  small for a side project.
- **Pre-launch legal/privacy review.** This documentation is privacy-by-design but
  **not legal advice**. A one-time review by someone familiar with kids' apps is
  required before public launch (not before building/testing).

## Consequences / caveats

- Reduced-data mode and "no personal data from kids" are **product constraints**:
  future features must not quietly start collecting names, precise location, or
  building profiles without revisiting this ADR.
- Age gates are easily bypassed by users; minimization is the real protection, the
  gate is a supporting control, not the whole strategy.
- Narrow launch limits reach — an accepted trade for lower risk; expansion is a
  later, deliberate step with its own compliance check per new market.
- Not a legal guarantee. The pre-launch review may surface market-specific
  obligations we must still meet.

## Your-side items (maintainer)

- [ ] **Pick the specific home/launch market** (country). The exact obligations and
      store settings depend on it; tell me and I'll tailor the notes.
- [ ] **Budget a one-time legal/privacy review** before public launch.
- [ ] At store submission: complete the **Apple App Privacy** label and **Google
      Play Data Safety** form — I can draft the answers from the
      [Data Model](../architecture/06-data-model.md).
