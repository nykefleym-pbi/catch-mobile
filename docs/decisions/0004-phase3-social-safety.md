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
  `kSocialLive=false`. The **tradable-cosmetic catalogue is now seeded**
  (migration 0017): eight cosmetic "charms" — ownable `inventory` instances,
  `is_cosmetic`, granting no affection and touching no cat stat — with every
  player given a *varied* deterministic starter set (no purchase, no random
  loot-box, no scarcity/FOMO), so the loop is "complete your set by trading
  with friends". A gated **client** now exists too (`TradingScreen` /
  `ProposeTradeScreen`): a charm collection view, incoming/outgoing proposals
  with accept/decline/cancel, and a two-sided offer builder that never sees a
  friend's inventory (a request is built from the public catalogue and validated
  against the recipient's stock only at accept time). Still owed before flipping
  it on: a full multi-profile staging test of the swap, moderation staffing, and
  the legal review below.
- **In-app moderation console / staffing** — an ops function (R9, Phase 5).
- **Cross-user feed / stranger discovery** — intentionally friends-only.
- **Any donation / real-money surface** — Phase 4, legally gated (R10).

## Consequences / still owed

- **Server-side re-validation** of `itemIsTradable` and reward rules is required
  before any live trade/contest ships — client guards are necessary but not
  sufficient.
- **Moderation staffing + an ops console UI** remain prerequisites before flipping
  `kSocialLive` on. Migration 0009 builds the *substrate* moderators act through
  (reports queue, `moderation_actions`, `restrictions`, enforcement in the
  friend/report RPCs); **migration 0011 adds the operable service-role action layer**
  a console drives — `mod_queue`, `mod_claim_report`, `mod_resolve_report`,
  `mod_issue_restriction`, `mod_lift_restriction` (all revoked from every client
  role, granted only to `service_role`). Still owed: the console **UI** and the
  **humans** (an ops function, not code).
- **Realtime substrate for friendly PvP** is built (migration 0012): a `matches`
  table (RLS both-parties-read) with guarded `propose_match` / `respond_match` /
  `cancel_match` / `set_match_result` RPCs, Realtime enabled for live sync.
  Deliberately **friends-only — no stranger matchmaking queue** — so the realtime
  surface can't introduce a minor to an unknown adult. Records a result only, no
  power reward (no pay-to-win). The **client** now exists too — a `MatchRepository`
  (challenge / respond / cancel / record-result) and a `MatchesScreen` reached
  from the social hub — but every method short-circuits with `restricted` and the
  screen shows an honest gated state while `kSocialLive` is off; the age gate
  (teen + adult, enforced server-side by migration 0013) means a child can never
  enter even when the switch flips.
- **Visiting a friend's showcase** is built too (migration 0014): a guarded
  `list_friend_showcase` RPC that, as the definer, checks the accepted friendship,
  block state, the viewer's age, and the owner's adult-only showcase flag, then
  returns only safe cosmetic fields — **never `location_label`**, so visiting can
  never reveal where a real cat was met. This also fixes a latent bug: the 0008
  cross-user showcase RLS policy never functioned (its `profiles` subquery ran
  under the viewer's self-access RLS, so a friend's profile row was invisible and
  the policy could never match); it is dropped and `cats` is back to strictly
  owner-only, with visiting reads flowing through the RPC. A `VisitScreen` reached
  from each accepted friend's row renders it, still gated by `kSocialLive`.
- **Shared photo albums** are built too (migration 0015): there are no real photos
  to share (a camera image is deleted immediately after generation, ADR 0001), so
  an "album" is a curated, captioned selection of the owner's OWN cat sprites.
  Two owner-scoped tables (`albums`, `album_entries`) hold them; the
  `album_entries` WITH CHECK proves the added cat is the caller's own, so a
  modified client can't slip another user's cat id in. A friend reads only an
  owner's *shared* albums through the guarded `list_friend_albums` RPC, which — as
  the definer — re-checks the accepted friendship, block state, the viewer's age,
  and the owner being an adult (sharing cats is adult-only, mirroring the
  showcase), and returns only safe cat fields plus caption/title — **never
  `location_label`**. The client (`AlbumsScreen` to manage, `FriendAlbumsScreen`
  to view) is reached from the hub and from a visited friend, still gated by
  `kSocialLive`; sharing is disabled in the UI for non-adults as well.
- **Clubs + cooperative challenges** are built too (migration 0016) — the most
  exposure-prone surface, so built the most conservatively. Three tables
  (`clubs`, `club_members`, `club_challenges`) carry RLS with **no client
  policies**: like `moderation_actions`, every read and write goes through
  guarded SECURITY DEFINER RPCs (`create_club`, `invite_to_club`,
  `respond_club_invite`, `leave_club`, `start_club_challenge`,
  `club_contribute`, `list_my_clubs`, `list_club_members`), which enforce the
  safety rules in one auditable place and sidestep recursive-RLS pitfalls. The
  rules: **invite-only between accepted friends** (no stranger ever pulls you
  into a group; no club discovery/directory); **no stranger-identity leak** —
  the roster RPC reveals a co-member's display name only to their accepted
  friend (or the viewer themself), so a minor never learns a stranger's handle
  even inside a shared club; **no chat** (cooperation is a shared progress bar,
  not messaging); **no pay-to-win** — `club_contribute` takes no purchase input
  and completing a goal grants only a celebratory state, never an ownable /
  tradable reward; and every mutating RPC re-checks `social_allowed` (the 0013
  under-13 ban) and refuses restricted accounts. A club name is user-generated
  content, so `'club'` was added as a reportable target type (reports /
  moderation constraints + `submit_report`). The client (`ClubsScreen`,
  `ClubDetailScreen`) is reached from the hub, still gated by `kSocialLive`.
- A **pre-launch legal/privacy review** (ADR 0003, R7) remains. The
  engineering-side input for it — a data-inventory + COPPA/GDPR-K/AADC control map
  with gaps flagged — is drafted in
  [`docs/legal/pre-launch-review.md`](../legal/pre-launch-review.md); it needs a
  qualified attorney's sign-off (and a Privacy Policy/ToS + a consent decision)
  before the switch flips.
- The two `SECURITY DEFINER` RPCs are intentional and minimal; the Supabase
  advisor's 0029 warning for them is expected and accepted (they are meant to be
  called by signed-in players and guard themselves by `auth.uid()`).
- **Age band enforcement is now server-authoritative (migration 0013).** The
  self-declared band was previously enforced only in the client UI, which a
  modified client could bypass — the under-13 social ban was effectively cosmetic.
  0013 adds `social_allowed()` / `trade_allowed()` (internal, revoked from every
  client role) and re-checks the caller's — and counterpart's — band inside every
  social write RPC (`friend_request_by_code`, `propose_match`, `respond_match`,
  `propose_trade`, `execute_trade`), and drops the last raw client insert into
  `friendships` so friend creation must pass the age-checked RPC. The client makes
  the under-13 declaration a one-way ratchet (`age_gate.dart`) so it can't be
  re-rolled to unlock social. The band is still a **self-declared** input (no
  birth-date; data-minimization per ADR 0003) — this is proportionate assurance
  enforced at the trust boundary, not identity verification.
- **Every remaining Phase 3 surface now has an honest, gated preview** in the
  social hub — trading, friendly contests (plus a live solo Practice ground),
  visiting friends' cats, shared photo albums, and clubs + cooperative
  challenges. These describe what's coming and the safeguards (friends-only, no
  chat, no location, cosmetic-only, moderated, minors protected); none render a
  simulated feed and none are live. Their live implementations remain owed and
  gated on the same moderation-staffing + realtime prerequisites above.
