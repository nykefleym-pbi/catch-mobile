# 09 — Monetization & Impact

Cat-ch is designed with social impact at its center. This document restates the
brief's revenue philosophy and adds the **real-world scaffolding** it needs to be
delivered **honestly and legally** — because an impact promise you can't verify is
worse than no promise at all.

## Monetization principles (from the pillars)

- **Cosmetic and optional only.** Players buy appearance and flair — cosmetics,
  decor, titles, accessories — never power. Enforced in the item catalog (see
  [Data Model](architecture/06-data-model.md) and
  [Game Systems](product/04-game-systems.md)).
- **Never pay-to-win.** No purchasable stat, ability strength, PvP advantage, or
  care shortcut that creates an unfair edge. Skill, preparation, and personality
  matter more than spending.
- **No dark patterns.** No manipulative FOMO, no predatory loot mechanics, no
  guilt-based retention.

## Revenue allocation (aspirational model)

The brief proposes:

- **60%** donated to accredited cat/animal welfare organizations.
- **30%** to servers, AI generation, development, moderation, customer support,
  and ongoing maintenance.
- **10%** to future development, educational initiatives, and emergency rescue
  campaigns.

This is a **north-star commitment, not a shippable feature on its own.** Publishing
a "60% to charity" claim creates legal, tax, accounting, and consumer-protection
obligations. Treat the specific percentages as a **target to validate**, not a
guarantee to print, until the structure below exists.

> **⚠️ Requires legal/financial validation.** The donation model must be reviewed
> by qualified legal and financial counsel before any public commitment or
> marketing claim. See [Risks & Open Questions](10-risks-and-open-questions.md).

## What the donation model actually requires

Before Cat-ch can honestly route money to charity at scale, it needs:

1. **A legal/operational structure** for handling and disbursing donations —
   e.g. partnering with a registered nonprofit or fiscal sponsor, or operating as
   a benefit corporation with audited giving. (Decision owed; needs counsel.)
2. **Partner vetting.** Only **accredited** shelters and rescue organizations,
   verified against recognized charity/registration standards, with documented
   due diligence.
3. **Fund handling & reconciliation.** Clear separation of donated funds,
   auditable ledgers, and reconciliation between revenue collected and donations
   disbursed (the `donations` / `impact_reports` tables in
   [Data Model](architecture/06-data-model.md) are built with audit in mind).
4. **Platform-fee reality.** App Store / Play Store take a cut, and platforms have
   **specific rules for charitable donations** inside apps. The 60/30/10 split
   must be computed on the correct base and comply with those rules (open item in
   Risks).
5. **Tax & jurisdiction handling** for cross-border giving.

## Transparency reporting

Transparency is a **defining value**, so reporting is a product feature, not an
afterthought. Published reports should show:

- Revenue
- Donations disbursed
- Partner organizations
- Cats helped (meals funded, treatments sponsored, adoptions supported)
- Community impact / collective milestones

Design principles for reports:

- **Only report what is measured and verifiable.** Numbers come from the audited
  `donations` / `impact_reports` pipeline, not estimates dressed as facts.
- **Regular cadence** (e.g. an honest annual report, echoing the vision) plus
  in-app running community-goal progress.
- **No vanity inflation.** If a number can't be verified with a partner, it isn't
  published.

## Sequencing

Per the [Roadmap](product/03-roadmap.md), monetization and the impact pipeline are
**Phase 4** and are **gated on real-world legitimacy** — the legal/financial
scaffolding above must exist first. The MVP (Phase 1) intentionally ships **no**
purchases and **no** donation claims; it validates the game loop before any money
or promises enter the picture.
