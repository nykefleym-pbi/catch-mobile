-- Cat-ch — Phase 3 go-live blocker #1: SERVER-AUTHORITATIVE age enforcement.
--
-- Until now the under-13 social ban lived only in the client: SocialCapabilities
-- (age_bracket.dart) hid the surfaces, but the SECURITY DEFINER social RPCs never
-- consulted profiles.age_bracket. A modified client, a hand-crafted /rest/v1/rpc
-- call, or an edited local age band could reach propose_trade / propose_match /
-- friend_request_by_code directly and the server would comply. That makes the ban
-- COSMETIC. This migration makes it REAL: every social write RPC now checks the
-- caller's (and, where relevant, the counterpart's) age band in the database, and
-- the last raw client-insert path into the social graph is closed so friend
-- creation must pass through the age-checked RPC.
--
-- This is the "age assurance stronger than pure self-declaration" item from the
-- pre-launch dossier §7. It does NOT claim to verify a birth date — self-declared
-- banding stays the input (data-minimization, ADR 0003). What it adds is that the
-- declared band is now enforced by the trust boundary (the DB), not by UI that a
-- determined client can bypass, and the band is made non-trivially re-rollable on
-- the client (see age_gate.dart). Bands:
--   under13 / unknown / null -> NO social of any kind (reduced-data mode).
--   teen (13-17)             -> friends + friendly contests; NO trading.
--   adult (18+)              -> all social surfaces (still gated by kSocialLive).
-- These mirror SocialCapabilities.forBracket exactly, so client and server agree.

-- ---------------------------------------------------------------------------
-- age band helpers. INTERNAL only (like is_restricted): revoked from every client
-- role so they can't be used to probe another player's age band, but callable by
-- the SECURITY DEFINER social RPCs, which run as the definer.
--
-- Conservative on absence: a NULL / 'unknown' band is treated as under-13, so a
-- profile that predates the age gate, or a race before the band mirrors, gets the
-- strictest posture rather than the most permissive.
-- ---------------------------------------------------------------------------
create or replace function public.social_allowed(uid uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select coalesce(
    (select p.age_bracket in ('teen', 'adult')
       from public.profiles p where p.id = uid),
    false
  );
$$;

create or replace function public.trade_allowed(uid uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select coalesce(
    (select p.age_bracket = 'adult'
       from public.profiles p where p.id = uid),
    false
  );
$$;

revoke execute on function public.social_allowed(uuid) from public, anon, authenticated;
revoke execute on function public.trade_allowed(uuid)  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- friend_request_by_code: re-defined (supersedes 0009) to refuse a caller who is
-- not old enough for social, and to refuse befriending a target who is not either
-- (a child is never a friendable target). The age check comes first so an under-13
-- caller learns nothing about whether a code exists. Everything else is unchanged.
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

  -- Age gate: under-13 / unknown may not use social at all.
  if not public.social_allowed(me) then
    return 'age_restricted';
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
  -- A child is never a friendable target (defence in depth: they can't send
  -- requests either, but never expose one as befriendable).
  if not public.social_allowed(target) then
    return 'not_found';
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

-- Close the last raw client path into the social graph. In 0008 an authenticated
-- user could INSERT their own friendship row directly, bypassing
-- friend_request_by_code entirely (and therefore its age gate). Drop that policy
-- so ALL friend creation flows through the age-checked SECURITY DEFINER RPC, the
-- same way 0010 forced every trade write through its RPCs. SELECT / UPDATE /
-- DELETE by a party stay (accept / decline / unfriend need no new edge).
drop policy if exists "friendship requests are created by the requester" on public.friendships;

-- ---------------------------------------------------------------------------
-- propose_match: re-defined (supersedes 0012) so neither the challenger nor the
-- opponent can be a child. teen + adult may run friendly contests.
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
  -- Age gate: both players must be old enough for social.
  if not public.social_allowed(me) or not public.social_allowed(p_opponent) then
    return 'age_restricted';
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

revoke execute on function public.propose_match(uuid, text) from public, anon;
grant execute on function public.propose_match(uuid, text)  to authenticated;

-- ---------------------------------------------------------------------------
-- respond_match: re-defined (supersedes 0012) so a child can't accept into a live
-- contest (belt-and-braces: an invite could only reach them if propose_match were
-- bypassed, but the acceptor is re-checked anyway).
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
  if p_accept and not public.social_allowed(me) then
    return 'age_restricted';
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

revoke execute on function public.respond_match(uuid, boolean) from public, anon;
grant execute on function public.respond_match(uuid, boolean)  to authenticated;

-- ---------------------------------------------------------------------------
-- propose_trade: re-defined (supersedes 0010) so only ADULTS trade (teens may be
-- social but trading is adult-only, mirroring SocialCapabilities.canTrade).
-- ---------------------------------------------------------------------------
create or replace function public.propose_trade(p_to uuid, p_offer jsonb)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  me       uuid := auth.uid();
  offer_ok text;
begin
  if me is null then
    return 'unauthenticated';
  end if;
  if p_to is null or p_to = me then
    return 'bad_target';
  end if;
  -- Age gate: trading is adult-only, both sides.
  if not public.trade_allowed(me) or not public.trade_allowed(p_to) then
    return 'age_restricted';
  end if;
  if public.is_restricted(me, array['mute','suspend','ban'])
     or public.is_restricted(p_to, array['ban']) then
    return 'restricted';
  end if;
  if exists (
    select 1 from public.blocks
    where (blocker_id = me and blocked_id = p_to)
       or (blocker_id = p_to and blocked_id = me)
  ) then
    return 'blocked';
  end if;
  if not exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = me and f.addressee_id = p_to)
        or (f.addressee_id = me and f.requester_id = p_to))
  ) then
    return 'not_friends';
  end if;

  offer_ok := public._trade_offer_ok(p_offer);
  if offer_ok <> 'ok' then
    return offer_ok;
  end if;

  -- Anti-abuse: cap outstanding + hourly proposals.
  if (
    select count(*) from public.trades
    where from_id = me and created_at > now() - interval '1 hour'
  ) >= 20 then
    return 'rate_limited';
  end if;

  insert into public.trades (from_id, to_id, offer, status)
  values (me, p_to, p_offer, 'proposed');
  return 'ok';
end;
$$;

revoke execute on function public.propose_trade(uuid, jsonb) from public, anon;
grant execute on function public.propose_trade(uuid, jsonb)  to authenticated;

-- ---------------------------------------------------------------------------
-- execute_trade: re-defined (supersedes 0010) with the same adult-only re-check at
-- execution time (a band could, in principle, have changed since proposal).
-- Only the age check is added; the atomic swap is byte-for-byte the 0010 body.
-- ---------------------------------------------------------------------------
create or replace function public.execute_trade(p_trade_id uuid)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  me       uuid := auth.uid();
  t        record;
  offer_ok text;
  elem     jsonb;
  iid      text;
  q        int;
  giver    uuid;
  receiver uuid;
  side     text;
  have     int;
begin
  if me is null then
    return 'unauthenticated';
  end if;

  select * into t from public.trades where id = p_trade_id for update;
  if not found then
    return 'not_found';
  end if;
  if t.status <> 'proposed' then
    return 'not_proposed';
  end if;
  if t.to_id <> me then
    return 'not_party';
  end if;
  -- Age gate: trading is adult-only, both sides, re-checked at execution.
  if not public.trade_allowed(t.from_id) or not public.trade_allowed(t.to_id) then
    return 'age_restricted';
  end if;
  if public.is_restricted(t.from_id, array['suspend','ban'])
     or public.is_restricted(t.to_id, array['suspend','ban']) then
    return 'restricted';
  end if;
  if exists (
    select 1 from public.blocks
    where (blocker_id = t.from_id and blocked_id = t.to_id)
       or (blocker_id = t.to_id and blocked_id = t.from_id)
  ) then
    return 'blocked';
  end if;
  if not exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = t.from_id and f.addressee_id = t.to_id)
        or (f.addressee_id = t.from_id and f.requester_id = t.to_id))
  ) then
    return 'not_friends';
  end if;

  offer_ok := public._trade_offer_ok(t.offer);
  if offer_ok <> 'ok' then
    return offer_ok;
  end if;

  -- First pass: verify BOTH sides can cover their side of the swap. We check all
  -- balances before moving anything so the trade is all-or-nothing.
  foreach side in array array['from','to'] loop
    giver := case when side = 'from' then t.from_id else t.to_id end;
    for elem in select * from jsonb_array_elements(t.offer -> side) loop
      iid := elem ->> 'item_id';
      q   := (elem ->> 'qty')::int;
      select quantity into have
      from public.inventory where profile_id = giver and item_id = iid;
      if coalesce(have, 0) < q then
        return 'insufficient';
      end if;
    end loop;
  end loop;

  -- Second pass: apply. (Runs in the function's single transaction — atomic.)
  foreach side in array array['from','to'] loop
    giver    := case when side = 'from' then t.from_id else t.to_id end;
    receiver := case when side = 'from' then t.to_id else t.from_id end;
    for elem in select * from jsonb_array_elements(t.offer -> side) loop
      iid := elem ->> 'item_id';
      q   := (elem ->> 'qty')::int;
      update public.inventory
        set quantity = quantity - q
        where profile_id = giver and item_id = iid;
      insert into public.inventory (profile_id, item_id, quantity)
        values (receiver, iid, q)
        on conflict (profile_id, item_id)
        do update set quantity = public.inventory.quantity + excluded.quantity;
    end loop;
  end loop;

  update public.trades set status = 'completed' where id = p_trade_id;
  return 'ok';
end;
$$;

revoke execute on function public.execute_trade(uuid) from public, anon;
grant execute on function public.execute_trade(uuid)  to authenticated;
