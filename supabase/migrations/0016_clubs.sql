-- Cat-ch — Phase 3 (p3c): clubs + cooperative challenges, done safely.
--
-- A club is a small, kind group that works toward gentle *shared* goals — caring
-- together, never competing to spend. Safety-critical design (this is the most
-- exposure-prone surface: group contact for a general audience that includes
-- minors), so it is built conservatively:
--
--   * NO stranger contact. You can only be *invited* to a club by an accepted
--     friend (checked server-side), so nobody is ever pulled into a group by a
--     stranger. There is no club discovery / directory.
--   * NO stranger identity leak. The roster RPC reveals a co-member's display
--     name ONLY when they are the caller's accepted friend (or the caller
--     themself); everyone else appears anonymously as a "club friend". A minor
--     therefore never learns a stranger's handle even inside a shared club.
--   * NO chat. Cooperation is structural (a shared progress bar), not messaging.
--     The only free text is a club name (UGC) — which is reportable (target type
--     'club' added below).
--   * NO pay-to-win. `club_contribute` takes no purchase input; progress comes
--     from care actions only, and completing a challenge grants a celebratory
--     completed state — never an ownable/tradable item, never power.
--   * Age-gated. Every mutating RPC re-checks `social_allowed(me)` (server-side
--     under-13 ban, migration 0013) and refuses restricted (muted/banned)
--     accounts, mirroring the rest of the social write RPCs.
--
-- Access model: like `moderation_actions`, these tables carry RLS with NO client
-- policies — every read and write flows through the guarded SECURITY DEFINER RPCs
-- below (which, as the definer, bypass RLS but enforce membership + friendship +
-- age + block checks themselves). This avoids recursive-RLS pitfalls and keeps
-- all safety logic in one auditable place. The client role can reach the data
-- only through these functions.

-- ---------------------------------------------------------------------------
-- Tables (RLS on, RPC-only access)
-- ---------------------------------------------------------------------------
create table if not exists public.clubs (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.clubs enable row level security;

create table if not exists public.club_members (
  club_id    uuid not null references public.clubs (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  role       text not null default 'member' check (role in ('owner','member')),
  status     text not null default 'invited'
               check (status in ('invited','active','left')),
  invited_by uuid references public.profiles (id) on delete set null,
  joined_at  timestamptz not null default now(),
  primary key (club_id, profile_id)
);
alter table public.club_members enable row level security;
create index if not exists club_members_profile_idx
  on public.club_members (profile_id);

create table if not exists public.club_challenges (
  id           uuid primary key default gen_random_uuid(),
  club_id      uuid not null references public.clubs (id) on delete cascade,
  kind         text not null default 'care' check (kind in ('care','play','groom')),
  goal         int not null check (goal > 0),
  progress     int not null default 0 check (progress >= 0),
  status       text not null default 'active' check (status in ('active','completed')),
  created_at   timestamptz not null default now(),
  completed_at timestamptz
);
alter table public.club_challenges enable row level security;
create index if not exists club_challenges_club_idx
  on public.club_challenges (club_id, status);

-- ---------------------------------------------------------------------------
-- Internal helper: active-membership test (revoked from every client role)
-- ---------------------------------------------------------------------------
create or replace function public.is_active_club_member(p_club uuid, p_uid uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.club_members m
    where m.club_id = p_club and m.profile_id = p_uid and m.status = 'active'
  );
$$;
revoke execute on function public.is_active_club_member(uuid, uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- create_club(name): make a club; the caller becomes its active owner.
-- ---------------------------------------------------------------------------
create or replace function public.create_club(p_name text)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  nm text := nullif(trim(p_name), '');
  new_id uuid;
begin
  if me is null then return 'unauthenticated'; end if;
  if not public.social_allowed(me) then return 'age_restricted'; end if;
  if public.is_restricted(me, array['suspend','ban']) then return 'restricted'; end if;
  if nm is null then return 'bad_name'; end if;
  if char_length(nm) > 40 then nm := substr(nm, 1, 40); end if;
  if (select count(*) from public.clubs where created_by = me) >= 10 then
    return 'too_many';
  end if;
  insert into public.clubs (name, created_by) values (nm, me) returning id into new_id;
  insert into public.club_members (club_id, profile_id, role, status, invited_by)
    values (new_id, me, 'owner', 'active', me);
  return new_id::text;
end;
$$;

-- ---------------------------------------------------------------------------
-- invite_to_club(club, friend): an active member invites one of their accepted
-- friends. Friends-only + block-checked + age-checked + size-capped.
-- ---------------------------------------------------------------------------
create or replace function public.invite_to_club(p_club uuid, p_friend uuid)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  n int;
begin
  if me is null then return 'unauthenticated'; end if;
  if not public.social_allowed(me) then return 'age_restricted'; end if;
  if public.is_restricted(me, array['suspend','ban']) then return 'restricted'; end if;
  if p_friend is null or p_friend = me then return 'bad_target'; end if;
  if not public.is_active_club_member(p_club, me) then return 'not_member'; end if;
  if not exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = me and f.addressee_id = p_friend)
        or (f.addressee_id = me and f.requester_id = p_friend))
  ) then
    return 'not_friends';
  end if;
  if not public.social_allowed(p_friend) then return 'target_age'; end if;
  if exists (
    select 1 from public.blocks
    where (blocker_id = me and blocked_id = p_friend)
       or (blocker_id = p_friend and blocked_id = me)
  ) then
    return 'blocked';
  end if;
  select count(*) into n from public.club_members
    where club_id = p_club and status in ('active','invited');
  if n >= 8 then return 'full'; end if;
  if exists (
    select 1 from public.club_members
    where club_id = p_club and profile_id = p_friend and status in ('active','invited')
  ) then
    return 'exists';
  end if;
  insert into public.club_members (club_id, profile_id, role, status, invited_by)
    values (p_club, p_friend, 'member', 'invited', me)
  on conflict (club_id, profile_id)
    do update set status = 'invited', invited_by = me;
  return 'ok';
end;
$$;

-- ---------------------------------------------------------------------------
-- respond_club_invite(club, accept): accept or decline a pending invite.
-- ---------------------------------------------------------------------------
create or replace function public.respond_club_invite(p_club uuid, p_accept boolean)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then return 'unauthenticated'; end if;
  if not exists (
    select 1 from public.club_members
    where club_id = p_club and profile_id = me and status = 'invited'
  ) then
    return 'no_invite';
  end if;
  if p_accept then
    if not public.social_allowed(me) then return 'age_restricted'; end if;
    update public.club_members set status = 'active', joined_at = now()
      where club_id = p_club and profile_id = me;
    return 'ok';
  else
    update public.club_members set status = 'left'
      where club_id = p_club and profile_id = me;
    return 'declined';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- leave_club(club): a member leaves; an owner leaving dissolves the small club.
-- ---------------------------------------------------------------------------
create or replace function public.leave_club(p_club uuid)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  myrole text;
begin
  if me is null then return 'unauthenticated'; end if;
  select role into myrole from public.club_members
    where club_id = p_club and profile_id = me and status = 'active';
  if myrole is null then return 'not_member'; end if;
  if myrole = 'owner' then
    delete from public.clubs where id = p_club and created_by = me;
    return 'dissolved';
  end if;
  update public.club_members set status = 'left'
    where club_id = p_club and profile_id = me;
  return 'ok';
end;
$$;

-- ---------------------------------------------------------------------------
-- start_club_challenge(club, kind, goal): the owner sets one active shared goal.
-- ---------------------------------------------------------------------------
create or replace function public.start_club_challenge(
  p_club uuid, p_kind text, p_goal int)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then return 'unauthenticated'; end if;
  if not public.social_allowed(me) then return 'age_restricted'; end if;
  if not exists (
    select 1 from public.club_members
    where club_id = p_club and profile_id = me and role = 'owner' and status = 'active'
  ) then
    return 'not_owner';
  end if;
  if p_kind not in ('care','play','groom') then return 'bad_kind'; end if;
  if p_goal is null or p_goal < 1 or p_goal > 1000 then return 'bad_goal'; end if;
  if exists (
    select 1 from public.club_challenges where club_id = p_club and status = 'active'
  ) then
    return 'active_exists';
  end if;
  insert into public.club_challenges (club_id, kind, goal)
    values (p_club, p_kind, p_goal);
  return 'ok';
end;
$$;

-- ---------------------------------------------------------------------------
-- club_contribute(club): add one unit of shared progress to the active
-- challenge. NO purchase input — progress is care-driven; completing grants a
-- celebratory state only (no ownable/tradable reward, no power).
-- ---------------------------------------------------------------------------
create or replace function public.club_contribute(p_club uuid)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  ch public.club_challenges%rowtype;
begin
  if me is null then return 'unauthenticated'; end if;
  if not public.social_allowed(me) then return 'age_restricted'; end if;
  if public.is_restricted(me, array['suspend','ban']) then return 'restricted'; end if;
  if not public.is_active_club_member(p_club, me) then return 'not_member'; end if;
  select * into ch from public.club_challenges
    where club_id = p_club and status = 'active' limit 1;
  if ch.id is null then return 'no_challenge'; end if;
  update public.club_challenges
    set progress = least(progress + 1, goal),
        status = case when progress + 1 >= goal then 'completed' else 'active' end,
        completed_at = case when progress + 1 >= goal then now() else completed_at end
    where id = ch.id;
  return case when ch.progress + 1 >= ch.goal then 'completed' else 'ok' end;
end;
$$;

-- ---------------------------------------------------------------------------
-- list_my_clubs(): the caller's clubs (active or invited), each with the active
-- challenge (if any) and the active-member count.
-- ---------------------------------------------------------------------------
create or replace function public.list_my_clubs()
returns table (
  club_id            uuid,
  name               text,
  my_role            text,
  my_status          text,
  member_count       int,
  challenge_kind     text,
  challenge_goal     int,
  challenge_progress int,
  challenge_status   text
)
language sql stable security definer set search_path = public
as $$
  select
    c.id, c.name, me.role, me.status,
    (select count(*)::int from public.club_members m2
       where m2.club_id = c.id and m2.status = 'active'),
    ch.kind, ch.goal, ch.progress, ch.status
  from public.club_members me
  join public.clubs c on c.id = me.club_id
  left join lateral (
    select kind, goal, progress, status
    from public.club_challenges
    where club_id = c.id and status = 'active'
    order by created_at desc limit 1
  ) ch on true
  where me.profile_id = auth.uid() and me.status in ('active','invited')
  order by c.created_at desc;
$$;

-- ---------------------------------------------------------------------------
-- list_club_members(club): the roster for an active member. A co-member's
-- display name is revealed ONLY to their accepted friend (or to themselves);
-- everyone else is anonymous — a minor never learns a stranger's handle.
-- ---------------------------------------------------------------------------
create or replace function public.list_club_members(p_club uuid)
returns table (
  profile_id   uuid,
  role         text,
  status       text,
  display_name text,
  is_friend    boolean
)
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then return; end if;
  if not public.is_active_club_member(p_club, me) then return; end if;
  return query
    select
      m.profile_id, m.role, m.status,
      case when m.profile_id = me or fr.ok then p.display_name else null end,
      coalesce(fr.ok, false)
    from public.club_members m
    join public.profiles p on p.id = m.profile_id
    left join lateral (
      select true as ok
      from public.friendships f
      where f.status = 'accepted'
        and ((f.requester_id = me and f.addressee_id = m.profile_id)
          or (f.addressee_id = me and f.requester_id = m.profile_id))
      limit 1
    ) fr on true
    where m.club_id = p_club and m.status in ('active','invited')
    order by m.role desc, m.joined_at asc;
end;
$$;

-- Player RPCs: revoked from public/anon, granted to authenticated.
revoke execute on function public.create_club(text) from public, anon;
revoke execute on function public.invite_to_club(uuid, uuid) from public, anon;
revoke execute on function public.respond_club_invite(uuid, boolean) from public, anon;
revoke execute on function public.leave_club(uuid) from public, anon;
revoke execute on function public.start_club_challenge(uuid, text, int) from public, anon;
revoke execute on function public.club_contribute(uuid) from public, anon;
revoke execute on function public.list_my_clubs() from public, anon;
revoke execute on function public.list_club_members(uuid) from public, anon;
grant execute on function public.create_club(text) to authenticated;
grant execute on function public.invite_to_club(uuid, uuid) to authenticated;
grant execute on function public.respond_club_invite(uuid, boolean) to authenticated;
grant execute on function public.leave_club(uuid) to authenticated;
grant execute on function public.start_club_challenge(uuid, text, int) to authenticated;
grant execute on function public.club_contribute(uuid) to authenticated;
grant execute on function public.list_my_clubs() to authenticated;
grant execute on function public.list_club_members(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- A club name is user-generated content visible to co-members, so it must be
-- reportable. Add 'club' to the report + moderation target types and to the
-- submit_report validation (re-created verbatim with the one extra value).
-- ---------------------------------------------------------------------------
alter table public.reports drop constraint if exists reports_target_type_check;
alter table public.reports add constraint reports_target_type_check
  check (target_type in ('profile','cat','trade','message','club'));
alter table public.moderation_actions
  drop constraint if exists moderation_actions_target_type_check;
alter table public.moderation_actions add constraint moderation_actions_target_type_check
  check (target_type in ('profile','cat','trade','message','club'));

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
  if p_target_type not in ('profile','cat','trade','message','club') then
    return 'bad_target';
  end if;
  if p_reason not in ('harassment','inappropriate','spam','other') then
    return 'bad_reason';
  end if;
  if public.is_restricted(me, array['suspend','ban']) then
    return 'restricted';
  end if;
  if (
    select count(*) from public.reports
    where reporter_id = me and created_at > now() - interval '1 hour'
  ) >= 10 then
    return 'rate_limited';
  end if;
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
