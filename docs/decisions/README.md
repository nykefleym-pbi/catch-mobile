# Architecture Decision Records (ADRs)

Short, dated records of decisions that shape Cat-ch — one file per decision. Each
captures the context, the decision, and its consequences/caveats so we (and future
contributors) know *why* things are the way they are. When a decision changes, we
supersede the old ADR with a new one rather than rewriting history.

| # | Decision | Status | Date |
|---|----------|--------|------|
| [0001](0001-image-generation.md) | Free-first image generation (Gemini AI Studio + rembg) & source-photo deletion | Accepted | 2026-07-15 |
| [0002](0002-tech-stack-phase0.md) | Phase 0 tech: Riverpod, Sentry, minimal GitHub Actions CI | Accepted | 2026-07-15 |
| [0003](0003-child-safety-strategy.md) | Child-safety: minimize data to avoid triggers, launch narrow, pre-launch legal review | Accepted | 2026-07-15 |
| [0004](0004-phase3-social-safety.md) | Phase 3 social/PvP/trading: safety foundation first, age gate + minor mode, no-P2W by construction, live surfaces gated off | Accepted | 2026-07-20 |
| [0005](0005-launch-readiness-accessibility-localization.md) | Launch-readiness: Tagalog-first i18n scaffold, local-only/minor-off notifications, minor free-text on-device, own-data-honest impact | Accepted | 2026-07-22 |

## Format

Each ADR uses: **Context → Decision → Consequences / Caveats → Your-side items**
(the last section lists real-world actions the maintainer must take that code
can't).
