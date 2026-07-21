-- Cat-ch — deepen anti-abuse on friend requests.
--
-- 0013's friend_request_by_code already enforces: age gate, moderation gate, a
-- 20/hour outbound velocity cap, self/block/dedup checks. This adds two more
-- limits that blunt burst-spam and slow, persistent nagging without changing any
-- client contract (both reuse the existing 'rate_limited' token, so the client's
-- friend-outcome handling needs no change):
--
--   * OUTSTANDING PENDING CAP — at most 25 un-answered outbound requests at once.
--     A burst can no longer fan a request into dozens of strangers' inboxes and
--     sit there; the sender must let some resolve first. (Friends-only still
--     means these can only reach people whose friend code the sender has, but a
--     leaked/guessed code shouldn't enable inbox-flooding.)
--   * ROLLING DAILY CAP — at most 60 outbound requests per 24h, so the 20/hour
--     limit can't be sustained around the clock into a much larger daily total.
--
-- Everything else in the function is preserved verbatim from 0013.

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

  -- Anti-abuse: cap outbound requests per rolling 24 hours (the hourly cap alone
  -- would otherwise allow a much larger sustained daily total).
  if (
    select count(*) from public.friendships
    where requester_id = me and created_at > now() - interval '24 hours'
  ) >= 60 then
    return 'rate_limited';
  end if;

  -- Anti-abuse: cap how many outbound requests may sit un-answered at once, so a
  -- burst can't fan out into many inboxes and linger.
  if (
    select count(*) from public.friendships
    where requester_id = me and status = 'pending'
  ) >= 25 then
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
