-- Cat-ch — Phase 3 blocker #1: the moderation + anti-abuse substrate that the
-- roadmap names as the ENTRY CRITERION for any user-to-user interaction
-- ("moderation tooling ready enough for user-to-user interaction",
-- docs/product/03-roadmap.md Phase 3; docs/08-ethics-privacy-safety.md
-- §Content moderation; R9 in docs/10-risks-and-open-questions.md). See ADR 0004.
--
-- What this adds, all RLS-on and default-deny to clients:
--   1. moderation_actions  — the ops-side action log (service-role only; no
--      client policy = clients can neither read nor write it).
--   2. restrictions        — enforcement primitives (mute/suspend/ban) a
--      moderator applies out-of-band; the restricted player may read ONLY their
--      own so the client can show "your account is limited", never anyone else's.
--   3. submit_report(...)   — the hardened, RATE-LIMITED, de-duplicated report
--      intake that replaces the raw insert policy (anti-abuse of the report
--      system itself), so a bad actor can't spam-flag a victim.
--   4. is_restricted(uid)   — a reusable enforcement check.
--   5. friend_request_by_code — re-defined to REJECT restricted senders and to
--      rate-limit outbound requests (friend-request spam is a real vector,
--      especially toward minors).
--
-- Nothing here flips kSocialLive. Live trading/matches stay gated (ADR 0004);
-- this is the moderation floor those features must stand on before going live.

-- ---------------------------------------------------------------------------
-- moderation_actions: append-only log of what a moderator did about a target.
-- RLS is ON with NO policy, so no authenticated/anon client can see or write it;
-- moderation happens out-of-band with the service role (which bypasses RLS).
-- ---------------------------------------------------------------------------
create table if not exists public.moderation_actions (
  id           uuid primary key default gen_random_uuid(),
  target_type  text not null check (target_type in ('profile','cat','trade','message')),
  target_id    text not null,
  action       text not null
                 check (action in ('dismiss','warn','restrict','remove_content','ban')),
  reason       text,
  note         text,
  report_id    uuid references public.reports (id) on delete set null,
  created_at   timestamptz not null default now()
);

alter table public.moderation_actions enable row level security;
-- (intentionally no policy — service-role-only)

create index if not exists moderation_actions_target_idx
  on public.moderation_actions (target_type, target_id, created_at);

-- ---------------------------------------------------------------------------
-- restrictions: an active limitation on a player's account. Written only by the
-- service role (moderation). The player may read their OWN active restriction so
-- the client can gently explain a limitation; they can never see anyone else's.
-- ---------------------------------------------------------------------------
create table if not exists public.restrictions (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references public.profiles (id) on delete cascade,
  kind        text not null check (kind in ('mute','suspend','ban')),
  reason      text,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz -- null = indefinite
);

alter table public.restrictions enable row level security;

create policy "players read their own restriction"
  on public.restrictions for select
  to authenticated
  using (auth.uid() = profile_id);
-- (no insert/update/delete policy — service-role-only)

create index if not exists restrictions_active_idx
  on public.restrictions (profile_id, expires_at);

-- ---------------------------------------------------------------------------
-- is_restricted(uid, kinds): true when the player currently has an active
-- restriction of one of the given kinds (unexpired). SECURITY DEFINER so any
-- guarded RPC can consult it regardless of the caller's RLS view.
-- ---------------------------------------------------------------------------
create or replace function public.is_restricted(uid uuid, kinds text[])
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.restrictions r
    where r.profile_id = uid
      and r.kind = any(kinds)
      and (r.expires_at is null or r.expires_at > now())
  );
$$;

-- ---------------------------------------------------------------------------
-- submit_report: the hardened report intake. Replaces the raw insert policy so
-- every report flows through one anti-abuse gate:
--   * auth required;
--   * a suspended/banned account cannot file reports (stops retaliatory spam);
--   * at most 10 reports per reporter per rolling hour;
--   * one OPEN report per (reporter, target) — re-flagging is a no-op 'duplicate'.
-- Returns a short status string; never leaks other users' data.
-- ---------------------------------------------------------------------------
create or replace function public.submit_report(
  p_target_type text,
  p_target_id   text,
  p_reason      text,
  p_detail      text default null
)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    return 'unauthenticated';
  end if;
  if p_target_type not in ('profile','cat','trade','message') then
    return 'bad_target';
  end if;
  if p_reason not in ('harassment','inappropriate','spam','other') then
    return 'bad_reason';
  end if;
  -- A banned/suspended account cannot weaponise the report system.
  if public.is_restricted(me, array['suspend','ban']) then
    return 'restricted';
  end if;
  -- Rate limit: 10 reports / rolling hour.
  if (
    select count(*) from public.reports
    where reporter_id = me and created_at > now() - interval '1 hour'
  ) >= 10 then
    return 'rate_limited';
  end if;
  -- Idempotent per open target.
  if exists (
    select 1 from public.reports
    where reporter_id = me
      and target_type = p_target_type
      and target_id = p_target_id
      and status = 'open'
  ) then
    return 'duplicate';
  end if;

  insert into public.reports (reporter_id, target_type, target_id, reason, detail)
  values (me, p_target_type, p_target_id, p_reason, nullif(trim(p_detail), ''));
  return 'ok';
end;
$$;

-- Force reports through submit_report: drop the raw client insert path.
drop policy if exists "reporters insert their own reports" on public.reports;

-- is_restricted is an INTERNAL enforcement helper only: other SECURITY DEFINER
-- functions call it as the definer, so it never needs a client grant. Revoking
-- from authenticated too closes an "is profile X banned?" probe vector.
revoke execute on function public.is_restricted(uuid, text[])
  from public, anon, authenticated;
revoke execute on function public.submit_report(text, text, text, text)
  from public, anon;
grant execute on function public.submit_report(text, text, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- friend_request_by_code: re-defined to enforce moderation + anti-abuse before
-- creating an edge. New gates vs 0008: a suspended/banned sender is refused, and
-- outbound requests are rate-limited (20 / rolling hour) to blunt friend-request
-- spam. The privacy contract is unchanged — no profile data is returned.
-- ---------------------------------------------------------------------------
create or replace function public.friend_request_by_code(code text)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  target uuid;
  me     uuid := auth.uid();
begin
  if me is null then
    return 'unauthenticated';
  end if;

  -- Moderation gate: a limited account cannot initiate new social ties.
  if public.is_restricted(me, array['suspend','ban']) then
    return 'restricted';
  end if;

  -- Anti-abuse: cap outbound requests per rolling hour.
  if (
    select count(*) from public.friendships
    where requester_id = me and created_at > now() - interval '1 hour'
  ) >= 20 then
    return 'rate_limited';
  end if;

  select id into target
  from public.profiles
  where settings ->> 'friend_code' = upper(trim(code))
  limit 1;

  if target is null then
    return 'not_found';
  end if;
  if target = me then
    return 'self';
  end if;
  -- Never let a banned target be befriended around.
  if public.is_restricted(target, array['ban']) then
    return 'not_found';
  end if;
  if exists (
    select 1 from public.blocks
    where (blocker_id = target and blocked_id = me)
       or (blocker_id = me and blocked_id = target)
  ) then
    return 'blocked';
  end if;
  if exists (
    select 1 from public.friendships
    where (requester_id = me and addressee_id = target)
       or (requester_id = target and addressee_id = me)
  ) then
    return 'exists';
  end if;

  insert into public.friendships (requester_id, addressee_id, status)
  values (me, target, 'pending');
  return 'ok';
end;
$$;

revoke execute on function public.friend_request_by_code(text) from public, anon;
grant execute on function public.friend_request_by_code(text) to authenticated;
