-- Cat-ch — in-app moderation console access layer.
--
-- Migration 0011 built the moderator API (mod_queue / mod_claim_report /
-- mod_resolve_report / mod_issue_restriction / mod_lift_restriction) but locked
-- every function to service_role ONLY — correct for an out-of-band operator
-- holding the service key, but unreachable from the app's authenticated client,
-- and we must never ship the service key in the client.
--
-- This migration adds the missing piece for an IN-APP console: a moderator
-- registry + `authenticated`-callable wrappers that (a) verify the caller is a
-- registered moderator and (b) delegate to the 0011 functions. The wrappers are
-- SECURITY DEFINER (owned by the migration role), so inside them the effective
-- user can execute the service-role-only 0011 functions; a non-moderator caller
-- gets 'forbidden' (or an empty queue) and never reaches them.
--
-- The registry itself is service-role managed (no client write policy): a normal
-- user cannot make themselves a moderator. Authorization is a real trust
-- boundary in the database, not a client-side check.

-- ---------------------------------------------------------------------------
-- moderators: the allowlist. A row here means this profile may use the console.
-- ---------------------------------------------------------------------------
create table if not exists public.moderators (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  added_at   timestamptz not null default now()
);

alter table public.moderators enable row level security;

-- Only a moderator may read the roster; there is intentionally no client
-- insert/update/delete policy (the roster is managed with the service role).
drop policy if exists "moderators can read the roster" on public.moderators;
create policy "moderators can read the roster"
  on public.moderators for select
  to authenticated
  using (exists (
    select 1 from public.moderators m where m.profile_id = auth.uid()
  ));

-- ---------------------------------------------------------------------------
-- is_moderator(uid): internal predicate. Revoked from every client role; only
-- the SECURITY DEFINER wrappers below call it.
-- ---------------------------------------------------------------------------
create or replace function public.is_moderator(p_uid uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (select 1 from public.moderators where profile_id = p_uid);
$$;

-- ---------------------------------------------------------------------------
-- mod_am_i_moderator(): lets the client decide whether to show the console entry.
-- ---------------------------------------------------------------------------
create or replace function public.mod_am_i_moderator()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select public.is_moderator(auth.uid());
$$;

-- ---------------------------------------------------------------------------
-- mod_queue_v2: the review queue for a signed-in moderator. Non-moderators get
-- an empty result (never an error, never data).
-- ---------------------------------------------------------------------------
create or replace function public.mod_queue_v2(p_limit int default 100)
returns table (
  report_id     uuid,
  reporter_id   uuid,
  target_type   text,
  target_id     text,
  reason        text,
  detail        text,
  status        text,
  created_at    timestamptz,
  reports_total bigint,
  reports_open  bigint
)
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_moderator(auth.uid()) then
    return;
  end if;
  return query select * from public.mod_queue(p_limit);
end;
$$;

-- ---------------------------------------------------------------------------
-- mod_active_restrictions_v2: current (unexpired) restrictions on a profile, so
-- the console can offer a "lift" action. Moderator-guarded.
-- ---------------------------------------------------------------------------
create or replace function public.mod_active_restrictions_v2(p_profile uuid)
returns table (
  restriction_id uuid,
  kind           text,
  reason         text,
  created_at     timestamptz,
  expires_at     timestamptz
)
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_moderator(auth.uid()) then
    return;
  end if;
  return query
    select r.id, r.kind, r.reason, r.created_at, r.expires_at
    from public.restrictions r
    where r.profile_id = p_profile
      and (r.expires_at is null or r.expires_at > now())
    order by r.created_at desc;
end;
$$;

-- ---------------------------------------------------------------------------
-- Guarded action wrappers. Each returns 'forbidden' for a non-moderator, else
-- delegates to the 0011 function (which the wrapper can execute as definer).
-- ---------------------------------------------------------------------------
create or replace function public.mod_claim_v2(p_report_id uuid)
returns text
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_moderator(auth.uid()) then return 'forbidden'; end if;
  return public.mod_claim_report(p_report_id);
end;
$$;

create or replace function public.mod_resolve_v2(
  p_report_id        uuid,
  p_action           text,
  p_reason           text default null,
  p_note             text default null,
  p_restriction_kind text default null,
  p_restriction_days int  default null
)
returns text
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_moderator(auth.uid()) then return 'forbidden'; end if;
  return public.mod_resolve_report(
    p_report_id, p_action, p_reason, p_note, p_restriction_kind, p_restriction_days
  );
end;
$$;

create or replace function public.mod_issue_restriction_v2(
  p_profile_id uuid,
  p_kind       text,
  p_reason     text default null,
  p_days       int  default null
)
returns text
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_moderator(auth.uid()) then return 'forbidden'; end if;
  return public.mod_issue_restriction(p_profile_id, p_kind, p_reason, p_days);
end;
$$;

create or replace function public.mod_lift_v2(
  p_restriction_id uuid,
  p_reason         text default null
)
returns text
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_moderator(auth.uid()) then return 'forbidden'; end if;
  return public.mod_lift_restriction(p_restriction_id, p_reason);
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants. Internal predicate revoked from all client roles; the v2 surface is
-- callable by any authenticated user but self-guards to moderators inside.
-- ---------------------------------------------------------------------------
revoke execute on function public.is_moderator(uuid) from public, anon, authenticated;

revoke execute on function public.mod_am_i_moderator()                 from public, anon;
revoke execute on function public.mod_queue_v2(int)                    from public, anon;
revoke execute on function public.mod_active_restrictions_v2(uuid)     from public, anon;
revoke execute on function public.mod_claim_v2(uuid)                   from public, anon;
revoke execute on function public.mod_resolve_v2(uuid, text, text, text, text, int)
                                                                       from public, anon;
revoke execute on function public.mod_issue_restriction_v2(uuid, text, text, int)
                                                                       from public, anon;
revoke execute on function public.mod_lift_v2(uuid, text)              from public, anon;

grant execute on function public.mod_am_i_moderator()                  to authenticated;
grant execute on function public.mod_queue_v2(int)                     to authenticated;
grant execute on function public.mod_active_restrictions_v2(uuid)      to authenticated;
grant execute on function public.mod_claim_v2(uuid)                    to authenticated;
grant execute on function public.mod_resolve_v2(uuid, text, text, text, text, int)
                                                                       to authenticated;
grant execute on function public.mod_issue_restriction_v2(uuid, text, text, int)
                                                                       to authenticated;
grant execute on function public.mod_lift_v2(uuid, text)               to authenticated;
