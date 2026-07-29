-- Cat-ch — Phase 3 blocker #2: the SECURE, atomic trade-execution backend.
-- Cosmetic trading (roadmap p3d) needs a server that (a) re-validates the
-- cosmetic-only rule regardless of what the client claims, (b) moves ownership
-- atomically so a trade can never half-complete or duplicate an item, and
-- (c) enforces friends-only + moderation gating. ADR 0004 named live execution
-- as "not built"; this builds it — still behind kSocialLive=false client-side,
-- but real and safe for when the flag flips.
--
-- Design: every trade state change flows through a SECURITY DEFINER RPC. The raw
-- client insert/update policies on `trades` are dropped so nothing can mark a
-- trade 'completed' without actually performing the swap, and so cosmetic-only
-- is re-checked server-side (mirroring SafePlay.itemIsTradable and 0009's
-- hardened report intake).
--
-- Offer shape (jsonb):
--   { "from": [{"item_id":"x","qty":1}, ...],   -- items the proposer gives
--     "to":   [{"item_id":"y","qty":2}, ...] }  -- items the recipient gives
-- Empty on a side is allowed (a gift); both-empty is rejected.

-- ---------------------------------------------------------------------------
-- _trade_offer_ok(offer): structural + cosmetic-only validation of an offer.
-- Returns 'ok' or a reason. Cosmetic-only is the safety re-check: every item
-- referenced must exist, be is_cosmetic, and NOT be a power/consumable/currency
-- type (kept in lockstep with lib/features/social/domain/safe_play.dart).
-- ---------------------------------------------------------------------------
create or replace function public._trade_offer_ok(offer jsonb)
returns text
language plpgsql
stable
security definer set search_path = public
as $$
declare
  side text;
  elem jsonb;
  iid  text;
  q    int;
  seen text[] := array[]::text[];
  it   record;
begin
  if offer is null
     or jsonb_typeof(offer -> 'from') <> 'array'
     or jsonb_typeof(offer -> 'to') <> 'array' then
    return 'bad_offer';
  end if;
  if jsonb_array_length(offer -> 'from') = 0
     and jsonb_array_length(offer -> 'to') = 0 then
    return 'bad_offer';
  end if;

  foreach side in array array['from','to'] loop
    for elem in select * from jsonb_array_elements(offer -> side) loop
      iid := elem ->> 'item_id';
      begin
        q := (elem ->> 'qty')::int;
      exception when others then
        return 'bad_offer';
      end;
      if iid is null or q is null or q <= 0 then
        return 'bad_offer';
      end if;
      -- No item may appear more than once across the whole offer.
      if iid = any(seen) then
        return 'bad_offer';
      end if;
      seen := seen || iid;

      select is_cosmetic, type into it from public.items where id = iid;
      if not found then
        return 'not_cosmetic';
      end if;
      if not it.is_cosmetic
         or lower(it.type) in ('food','consumable','currency','buff','power') then
        return 'not_cosmetic';
      end if;
    end loop;
  end loop;

  return 'ok';
end;
$$;

-- ---------------------------------------------------------------------------
-- propose_trade(p_to, p_offer): create a 'proposed' trade after checking the
-- moderation gate, friends-only rule, block state, cosmetic-only offer, and a
-- rate limit. Returns 'ok' or a reason string.
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

-- ---------------------------------------------------------------------------
-- execute_trade(p_trade_id): the recipient accepts a proposed trade. Re-checks
-- everything at execution time (state can have changed since proposal), then
-- swaps inventory ownership ATOMICALLY inside this one function call, and marks
-- the trade 'completed'. Never moves anything unless the whole swap is valid.
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

-- ---------------------------------------------------------------------------
-- set_trade_status(p_trade_id, p_status): the ONLY way a party changes a trade's
-- state without executing it — decline (recipient) or cancel (proposer), from a
-- 'proposed' trade only. Never allows 'completed' (that is execute_trade's job).
-- ---------------------------------------------------------------------------
create or replace function public.set_trade_status(p_trade_id uuid, p_status text)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  t  record;
begin
  if me is null then
    return 'unauthenticated';
  end if;
  if p_status not in ('declined','cancelled') then
    return 'bad_status';
  end if;
  select * into t from public.trades where id = p_trade_id for update;
  if not found then
    return 'not_found';
  end if;
  if t.status <> 'proposed' then
    return 'not_proposed';
  end if;
  -- Only the recipient may decline; only the proposer may cancel.
  if p_status = 'declined' and t.to_id <> me then
    return 'not_party';
  end if;
  if p_status = 'cancelled' and t.from_id <> me then
    return 'not_party';
  end if;

  update public.trades set status = p_status where id = p_trade_id;
  return 'ok';
end;
$$;

-- Force all trade writes through the RPCs above: drop the raw insert/update
-- policies. SELECT (either party reads their own trade) stays.
drop policy if exists "trades are proposed by the sender" on public.trades;
drop policy if exists "trades are updated by either party" on public.trades;

revoke execute on function public._trade_offer_ok(jsonb)
  from public, anon, authenticated;
revoke execute on function public.propose_trade(uuid, jsonb) from public, anon;
revoke execute on function public.execute_trade(uuid) from public, anon;
revoke execute on function public.set_trade_status(uuid, text) from public, anon;
grant execute on function public.propose_trade(uuid, jsonb) to authenticated;
grant execute on function public.execute_trade(uuid) to authenticated;
grant execute on function public.set_trade_status(uuid, text) to authenticated;

-- Realtime: let a recipient's client learn about a new/updated trade without
-- polling (the "realtime" half of this blocker). RLS still scopes what each
-- client actually receives to trades they are a party to.
alter publication supabase_realtime add table public.trades;
