# Cat-ch — Agent Guide

Cat-ch is a cozy Flutter + Supabase app: discover real cats on a walk, adopt them
as unique virtual companions, and do measurable good for real cats. Feature-first
Flutter (Riverpod, Material 3, go_router); Supabase (Postgres + RLS, Edge
Functions, Storage). The binding product, privacy, and safety rules live in
`docs/` — especially `docs/08-ethics-privacy-safety.md` and `docs/decisions/`.
When gameplay and animal welfare conflict, **welfare wins**.

Non-negotiables for every change:
- **RLS everywhere**; owner-only by default, shared-read only where a feature opts
  in. Location is coarse/fuzzed only — never persist precise coordinates.
- **Cosmetic-only, never pay-to-win**; no dark patterns; kindness over competition.
- **CI is the verification** (Flutter can't run locally here): `flutter analyze`
  fails on info-level lints, `flutter test`, and a Debug APK build must all be green.
- Secrets stay server-side (Supabase secrets); never in the client, chat, or git.

---

## Delegation

The higher your tier, the more you delegate. Push the work down, keep your own
context for judgment. Brief every child: the context, the why, what done looks
like. It starts blank and inherits nothing.

| Model     | Best for          | Delegate?         | Effort |
|-----------|-------------------|-------------------|--------|
| Haiku     | bulk mechanical   | never             | low    |
| Sonnet    | scoped research   | when it helps     | medium |
| Opus 4.8  | multi-step reasoning | on clear benefit | xhigh  |
| Fable 5   | judgment, taste   | by default        | medium |

Fable goes xhigh only for the hardest calls. Skip high.

## Escalation

The parent doesn't have to be the top model. An Opus parent spawns a Fable child
for the one hard call. The child answers and returns. Work above your tier?
Return it, don't burn tokens on it.
