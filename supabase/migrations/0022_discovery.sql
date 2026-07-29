-- Cat-ch — adults-only, mutually opt-in cat-keeper discovery.
--
-- Discovery is the ONE cross-user surface that reaches beyond an already-known
-- friend code. To keep it inside the child-safety spine (docs/08 §Minors;
-- ADR 0004 — friends-only, no public directory that could surface strangers to
-- minors) it is deliberately narrow:
--   * ADULTS ONLY on BOTH sides — a minor (or an `unknown` band) neither appears
--     nor browses. Enforced here as the definer, not merely in the client.
--   * MUTUAL OPT-IN — a profile appears only when settings.discovery_opt_in is
--     true, and browsing also requires the viewer to have opted in, so nobody
--     lurks the adult pool without joining it.
--   * BLOCK-AWARE + de-duped — never surfaces a blocked party (either way) or an
--     already-connected / pending one, and never a banned account.
--   * DATA-MINIMISED — returns only a rotatable friend code + an aggregate cat
--     count. No name, no email, no location of any precision, no free text (no
--     un-moderated stranger-authored copy), and never the cats themselves —
--     the showcase stays strictly friends-only (migration 0014).
--
-- Connecting reuses friend_request_by_code, so every existing anti-abuse cap
-- (hourly/daily/pending velocity, moderation gate, block + dedup checks) applies
-- unchanged — discovery adds NO new write path to the friend graph.

-- Eligibility: an adult who has switched discovery on. SECURITY DEFINER so it
-- can read another profile's band/settings without widening `profiles` reads.
create or replace function public.discovery_eligible(p uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles pr
    where pr.id = p
      and pr.age_bracket = 'adult'
      and coalesce((pr.settings ->> 'discovery_opt_in')::boolean, false)
  );
$$;

-- list_discovery_profiles(p_limit): the opted-in adult pool the caller may
-- browse, minus themselves, anyone blocked (either direction), anyone already
-- connected/pending, and any banned account. Returns only a friend code +
-- aggregate cat count. Empty set for an ineligible or restricted caller — it
-- never errors and never leaks why.
create or replace function public.list_discovery_profiles(p_limit int default 30)
returns table (
  id         uuid,
  handle     text,
  cats_count int
)
language plpgsql
security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then return; end if;
  -- Viewer must be an eligible (opted-in) adult — no lurking, no minors.
  if not public.discovery_eligible(me) then return; end if;
  -- A limited account cannot initiate or browse new social ties.
  if public.is_restricted(me, array['suspend', 'ban']) then return; end if;

  return query
    select
      p.id,
      p.settings ->> 'friend_code' as handle,
      (select count(*)::int from public.cats c where c.profile_id = p.id)
        as cats_count
    from public.profiles p
    where p.id <> me
      and public.discovery_eligible(p.id)
      and (p.settings ->> 'friend_code') is not null
      and not public.is_restricted(p.id, array['ban'])
      and not exists (
        select 1 from public.blocks b
        where (b.blocker_id = me and b.blocked_id = p.id)
           or (b.blocker_id = p.id and b.blocked_id = me)
      )
      and not exists (
        select 1 from public.friendships f
        where (f.requester_id = me and f.addressee_id = p.id)
           or (f.requester_id = p.id and f.addressee_id = me)
      )
    order by cats_count desc, p.id
    limit greatest(1, least(coalesce(p_limit, 30), 60));
end;
$$;

-- discovery_add(p_target): send a friend request to a discovered adult. Both
-- sides must be discovery-eligible adults; the request itself then flows through
-- friend_request_by_code, which re-checks age, moderation, blocks, dedup and the
-- full velocity caps — so this function adds eligibility on top and reuses all
-- existing protections rather than opening a second write path.
create or replace function public.discovery_add(p_target uuid)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  me   uuid := auth.uid();
  code text;
begin
  if me is null then return 'unauthenticated'; end if;
  if p_target is null or p_target = me then return 'self'; end if;
  if not public.discovery_eligible(me) then return 'not_eligible'; end if;
  if not public.discovery_eligible(p_target) then return 'not_found'; end if;
  select p.settings ->> 'friend_code' into code
  from public.profiles p
  where p.id = p_target
  limit 1;
  if code is null then return 'not_found'; end if;
  return public.friend_request_by_code(code);
end;
$$;

revoke execute on function public.discovery_eligible(uuid) from public, anon;
revoke execute on function public.list_discovery_profiles(int) from public, anon;
revoke execute on function public.discovery_add(uuid) from public, anon;
grant execute on function public.list_discovery_profiles(int) to authenticated;
grant execute on function public.discovery_add(uuid) to authenticated;
