-- Cat-ch — Phase 3 (p3c): visiting a friend's cats, done safely.
--
-- The 0008 cross-user showcase policy ("cats are visible to accepted friends when
-- showcased") never actually functioned: its `select 1 from profiles p where
-- p.id = cats.profile_id ...` subquery runs under the *viewer's* RLS, and
-- `profiles` is self-access, so a friend's profile row is invisible to the viewer
-- and the policy could never match. Rather than widen `profiles` reads (which
-- would leak profile data), visiting goes through one guarded SECURITY DEFINER
-- RPC that, as the definer, checks the friendship + block + age + showcase flag
-- and returns ONLY safe, non-location cat fields. `cats` stays self-access.
--
-- Privacy: `location_label` is deliberately NOT returned — visiting never reveals
-- where a real cat was met (08-ethics R6). No precise or coarse location leaves
-- the owner's own view.

-- Drop the dead (non-functional) cross-user policy; the RPC replaces it.
drop policy if exists "cats are visible to accepted friends when showcased"
  on public.cats;

-- list_friend_showcase(p_friend): the caller may see p_friend's showcased cats
-- only when (a) the caller is old enough for social, (b) they are accepted
-- friends, (c) neither has blocked the other, and (d) the owner is an adult who
-- has switched showcase on (showcase is adult-only, mirroring
-- SocialCapabilities.canShowcaseToFriends). Returns an empty set otherwise — it
-- never errors and never leaks why.
create or replace function public.list_friend_showcase(p_friend uuid)
returns table (
  id           uuid,
  name         text,
  nickname     text,
  sprite_url   text,
  growth_stage text,
  trait_id     text
)
language plpgsql
security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then return; end if;
  if p_friend is null or p_friend = me then return; end if;
  -- Viewer age gate: a child never visits.
  if not public.social_allowed(me) then return; end if;
  -- No visiting across a block, either direction.
  if exists (
    select 1 from public.blocks
    where (blocker_id = me and blocked_id = p_friend)
       or (blocker_id = p_friend and blocked_id = me)
  ) then return; end if;
  -- Must be accepted friends.
  if not exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = me and f.addressee_id = p_friend)
        or (f.addressee_id = me and f.requester_id = p_friend))
  ) then return; end if;
  -- Owner must be an adult with showcase switched on.
  if not exists (
    select 1 from public.profiles p
    where p.id = p_friend
      and p.age_bracket = 'adult'
      and coalesce((p.settings ->> 'showcase_to_friends')::boolean, false)
  ) then return; end if;

  return query
    select c.id, c.name, c.nickname, c.sprite_url, c.growth_stage, c.trait_id
    from public.cats c
    where c.profile_id = p_friend
    order by c.friendship_level desc, c.discovered_at desc;
end;
$$;

revoke execute on function public.list_friend_showcase(uuid) from public, anon;
grant execute on function public.list_friend_showcase(uuid) to authenticated;
