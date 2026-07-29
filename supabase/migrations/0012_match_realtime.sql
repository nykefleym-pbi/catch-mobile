-- Cat-ch — Phase 3 gate #2 (realtime substrate for friendly PvP): the tables +
-- RPCs a live, friendly contest is built on, with Supabase Realtime enabled so
-- both players see invite/accept/result transitions live. Mirrors the trade
-- execution model (0010): all writes go through guarded SECURITY DEFINER RPCs,
-- reads are limited to the two participants by RLS.
--
-- SAFETY-BY-DESIGN — deliberately NOT open matchmaking:
--   A match can only exist between two players who are already ACCEPTED FRIENDS.
--   There is no queue that pairs strangers, so the realtime surface can never
--   introduce a minor to an unknown adult — the friends-only graph is the
--   safeguard, exactly as for trading. Presence ("who's online") is a client-side
--   Supabase Realtime *presence channel*, not a stored table, so no
--   online/location signal is ever persisted.
--
-- NO PAY-TO-WIN stays structural: a match records only who took part and an
-- optional winner. It grants NO reward here — cosmetic rewards, when they come,
-- flow through the same cosmetic-only rules as trading (safe_play), never power.
--
-- Nothing here flips kSocialLive. The client match repository stays gated off;
-- live matchmaking also waits on the moderation console (0011) + a pre-launch
-- review (ADR 0004).

create table if not exists public.matches (
  id            uuid primary key default gen_random_uuid(),
  mode          text not null
                  check (mode in ('zoomies','agility','treasure','toy')),
  challenger_id uuid not null references public.profiles (id) on delete cascade,
  opponent_id   uuid not null references public.profiles (id) on delete cascade,
  status        text not null default 'invited'
                  check (status in ('invited','accepted','declined','cancelled','completed')),
  winner_id     uuid references public.profiles (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint matches_distinct_players check (challenger_id <> opponent_id)
);

alter table public.matches enable row level security;

-- Only the two participants can read a match. All writes are via the RPCs below
-- (SECURITY DEFINER), so there is intentionally no client insert/update policy.
create policy "matches are visible to either player"
  on public.matches for select
  to authenticated
  using (auth.uid() = challenger_id or auth.uid() = opponent_id);

create index if not exists matches_opponent_idx
  on public.matches (opponent_id, status, created_at);
create index if not exists matches_challenger_idx
  on public.matches (challenger_id, created_at);

-- ---------------------------------------------------------------------------
-- propose_match: challenge an accepted friend to a friendly contest. Enforces
-- the same moderation + friends-only + block + rate-limit gates as propose_trade.
-- ---------------------------------------------------------------------------
create or replace function public.propose_match(p_opponent uuid, p_mode text)
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
  if p_opponent is null or p_opponent = me then
    return 'bad_target';
  end if;
  if p_mode not in ('zoomies','agility','treasure','toy') then
    return 'bad_mode';
  end if;
  if public.is_restricted(me, array['mute','suspend','ban'])
     or public.is_restricted(p_opponent, array['ban']) then
    return 'restricted';
  end if;
  if exists (
    select 1 from public.blocks
    where (blocker_id = me and blocked_id = p_opponent)
       or (blocker_id = p_opponent and blocked_id = me)
  ) then
    return 'blocked';
  end if;
  if not exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = me and f.addressee_id = p_opponent)
        or (f.addressee_id = me and f.requester_id = p_opponent))
  ) then
    return 'not_friends';
  end if;
  -- Anti-abuse: cap invites per rolling hour.
  if (
    select count(*) from public.matches
    where challenger_id = me and created_at > now() - interval '1 hour'
  ) >= 20 then
    return 'rate_limited';
  end if;

  insert into public.matches (mode, challenger_id, opponent_id, status)
  values (p_mode, me, p_opponent, 'invited');
  return 'ok';
end;
$$;

-- ---------------------------------------------------------------------------
-- respond_match: the opponent accepts or declines an open invite. Re-checks the
-- moderation gate so a just-restricted account can't enter a live match.
-- ---------------------------------------------------------------------------
create or replace function public.respond_match(p_match_id uuid, p_accept boolean)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  m  public.matches%rowtype;
begin
  if me is null then
    return 'unauthenticated';
  end if;
  select * into m from public.matches where id = p_match_id;
  if not found then
    return 'not_found';
  end if;
  if m.opponent_id <> me then
    return 'forbidden';
  end if;
  if m.status <> 'invited' then
    return 'closed';
  end if;
  if p_accept and public.is_restricted(me, array['mute','suspend','ban']) then
    return 'restricted';
  end if;

  update public.matches
     set status = case when p_accept then 'accepted' else 'declined' end,
         updated_at = now()
   where id = p_match_id;
  return 'ok';
end;
$$;

-- ---------------------------------------------------------------------------
-- cancel_match: the challenger withdraws an invite that hasn't been answered.
-- ---------------------------------------------------------------------------
create or replace function public.cancel_match(p_match_id uuid)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  m  public.matches%rowtype;
begin
  if me is null then
    return 'unauthenticated';
  end if;
  select * into m from public.matches where id = p_match_id;
  if not found then
    return 'not_found';
  end if;
  if m.challenger_id <> me then
    return 'forbidden';
  end if;
  if m.status <> 'invited' then
    return 'closed';
  end if;

  update public.matches set status = 'cancelled', updated_at = now()
   where id = p_match_id;
  return 'ok';
end;
$$;

-- ---------------------------------------------------------------------------
-- set_match_result: either participant records the outcome of an accepted match.
-- p_winner must be one of the two players, or null for a friendly draw. Grants
-- NO reward — the result is a keepsake, not a power lever (no pay-to-win).
-- ---------------------------------------------------------------------------
create or replace function public.set_match_result(p_match_id uuid, p_winner uuid)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  m  public.matches%rowtype;
begin
  if me is null then
    return 'unauthenticated';
  end if;
  select * into m from public.matches where id = p_match_id;
  if not found then
    return 'not_found';
  end if;
  if me <> m.challenger_id and me <> m.opponent_id then
    return 'forbidden';
  end if;
  if m.status <> 'accepted' then
    return 'closed';
  end if;
  if p_winner is not null
     and p_winner <> m.challenger_id and p_winner <> m.opponent_id then
    return 'bad_winner';
  end if;

  update public.matches
     set status = 'completed', winner_id = p_winner, updated_at = now()
   where id = p_match_id;
  return 'ok';
end;
$$;

-- Client RPCs are player-callable (further gated client-side by kSocialLive).
revoke execute on function public.propose_match(uuid, text)      from public, anon;
revoke execute on function public.respond_match(uuid, boolean)   from public, anon;
revoke execute on function public.cancel_match(uuid)             from public, anon;
revoke execute on function public.set_match_result(uuid, uuid)   from public, anon;
grant execute on function public.propose_match(uuid, text)       to authenticated;
grant execute on function public.respond_match(uuid, boolean)    to authenticated;
grant execute on function public.cancel_match(uuid)              to authenticated;
grant execute on function public.set_match_result(uuid, uuid)    to authenticated;

-- Live sync: broadcast match-row changes so both clients update in realtime.
alter publication supabase_realtime add table public.matches;
