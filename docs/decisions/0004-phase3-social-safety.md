# ADR 0004 — Phase 3 social/PvP/trading: build the safety foundation first

- **Status:** Accepted
- **Date:** 2026-07-20
- **Relates to:** [Roadmap](../product/03-roadmap.md) Phase 3,
  [Game Systems](../product/04-game-systems.md),
  [Ethics, Privacy & Safety](../08-ethics-privacy-safety.md),
  [Child-safety strategy (ADR 0003)](0003-child-safety-strategy.md),
  [Data Model](../architecture/06-data-model.md),
  [Risks & Open Questions](../10-risks-and-open-questions.md) (R7, R9)

## Context

Phase 3 adds the first user-to-user features — friendly PvP (p3a/b), a social
hub (p3c), and cosmetic trading (p3d). Social was deferred to this phase
*precisely because* it engages COPPA / GDPR-K / UK-AADC (ADR 0003), and the
roadmap makes "moderation tooling ready enough for user-to-user interaction" a
hard **entry criterion**. Building the flashy surfaces before the safety
substrate would invert that order and put minors at risk.

This ADR records how we build the **groundwork** so the regulation and
safe-play rules are enforced structurally — in schema, code, and tests — before
any live social surface opens.

## Decision

**Safety foundation first; live user-to-user interaction stays behind an
age gate and a master switch that defaults off.**

1. **Neutral age gate → reduced-data minor mode (the keystone).** Onboarding
   captures a coarse, self-declared age band (never a birthday) into
   `profiles.age_bracket`. `SocialCapabilities.forBracket` derives what a player
   may do:
   - **under-13 / unknown** → no social at all (reduced-data mode).
   - **13–17** → friends allowed, showcase **forced private**, no trading.
   - **18+** → may opt into every surface, still gated by the master switch.

2. **Trust & Safety substrate before interaction (R9).** `blocks` and `reports`
   tables (owner-scoped RLS) plus a reusable report/block sheet ship *now*, so
   reporting/blocking exist the moment any surface goes live. There is **no
   in-app moderation console** — that is Phase 5 ops tooling; reports are read
   out-of-band with the service role.

3. **Friends-only, code-based graph — no public directory.** A `friendships`
   table with either-party RLS. Friends are added by a short, rotatable code
   (`profiles.settings.friend_code`); the `friend_request_by_code` and
   `list_friends` RPCs are `SECURITY DEFINER` **by necessity** (they must look
   past self-only profile RLS to resolve a code / read a friend's display name)
   and are internally guarded by `auth.uid()`, exposing no other profile data.
   There is no stranger discovery or global feed (protects minors; honors
   data-minimization).

4. **Opt-in, friends-only showcase — never a location registry.** A cat becomes
   readable by another player only when its owner turns on
   `settings.showcase_to_friends` **and** the viewer is an accepted friend
   (additive RLS policy; cats are private by default). Coordinates are coarse by
   construction (ADR 0001) and `SafePlay.showcaseIsLocationSafe` guards it.

5. **No pay-to-win, proven structurally.** `CatStats.derive` takes only care
   wellbeing, bond, growth stage, and personality — there is **no item /
   currency / purchase parameter anywhere in the signature**, and
   `test/pvp/cat_stats_test.dart` guards it. A read-only "Play stats" preview
   shows a cat's friendly-contest profile; contests themselves are not live.

6. **Cosmetic-only, no-real-money trading.** `SafePlay.itemIsTradable` allows
   only `is_cosmetic` items and rejects any food/power/consumable/currency type.
   The `trades` table exists as substrate; live execution is **not** built.

7. **No open chat.** Only a fixed `SafePlay.kSafeReactions` vocabulary — no
   free-text user-to-user messaging until moderation is staffed.

8. **Master switch `kSocialLive` defaults `false`.** Live trading and contests
   render an honest "coming when we can host it safely" explainer (with the
   safeguards) rather than a simulated experience.

9. **Moderation + anti-abuse floor (migration 0009).** The report system runs
   through a single hardened `submit_report` RPC — rate-limited (10/hour),
   de-duplicated per open target, and closed to restricted accounts — so the
   report channel itself cannot be weaponised. A service-role-only
   `moderation_actions` log and a `restrictions` table (mute/suspend/ban, which a
   player may read only for their own account) give moderation something to
   *enact*, and `is_restricted` (internal-only) makes it bite: a suspended or
   banned account is refused new friend requests and reports server-side.
   Outbound friend requests are rate-limited (20/hour). None of this flips
   `kSocialLive`; it is the moderation floor the roadmap names as the Phase 3
   entry criterion, now standing under the live surfaces before they open.

## What this groundwork does NOT build (and why)

- **Live PvP matchmaking / real-time matches** — needs backend realtime,
  anti-abuse, and fairness proving at scale (04 §PvP). Stat logic is built and
  tested; matches are not.
- **Live trade execution** — now BUILT but gated (migration 0010): the atomic,
  cosmetic-only-re-validating `propose_trade` / `execute_trade` /
  `set_trade_status` RPCs move inventory ownership all-or-nothing, and the raw
  `trades` insert/update policies are dropped so nothing can mark a trade
  completed without performing the swap. Supabase Realtime is enabled on
  `trades` (RLS still scopes delivery to the two parties). It stays behind
  `kSocialLive=false` and has no live UI; still owed before flipping it on: a
  seeded catalogue of *tradable* cosmetic items (today's cosmetics unlock by
  bond and aren't ownable instances), a full multi-profile staging test of the
  swap, moderation staffing, and the legal review below.
- **In-app moderation console / staffing** — an ops function (R9, Phase 5).
- **Cross-user feed / stranger discovery** — intentionally friends-only.
- **Any donation / real-money surface** — Phase 4, legally gated (R10).

## Consequences / still owed

- **Server-side re-validation** of `itemIsTradable` and reward rules is required
  before any live trade/contest ships — client guards are necessary but not
  sufficient.
- **Moderation staffing + an ops console** remain prerequisites before flipping
  `kSocialLive` on. Migration 0009 builds the *substrate* moderators act through
  (reports queue, `moderation_actions`, `restrictions`, enforcement in the
  friend/report RPCs); the human review workflow and the console that writes to
  `moderation_actions` with the service role are still owed. A **pre-launch
  legal/privacy review** (ADR 0003, R7) also remains.
- The two `SECURITY DEFINER` RPCs are intentional and minimal; the Supabase
  advisor's 0029 warning for them is expected and accepted (they are meant to be
  called by signed-in players and guard themselves by `auth.uid()`).
- Age gates are bypassable; per ADR 0003, data-minimization is the real
  protection and the gate is a supporting control.
- **Every remaining Phase 3 surface now has an honest, gated preview** in the
  social hub — trading, friendly contests (plus a live solo Practice ground),
  visiting friends' cats, shared photo albums, and clubs + cooperative
  challenges. These describe what's coming and the safeguards (friends-only, no
  chat, no location, cosmetic-only, moderated, minors protected); none render a
  simulated feed and none are live. Their live implementations remain owed and
  gated on the same moderation-staffing + realtime prerequisites above.
