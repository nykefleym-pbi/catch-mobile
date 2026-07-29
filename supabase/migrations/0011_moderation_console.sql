-- Cat-ch — Phase 3 gate #1 (operable moderation): the service-role action layer a
-- moderation CONSOLE drives. Migration 0009 built the substrate (reports intake,
-- moderation_actions log, restrictions, enforcement helpers); it left the
-- *operator* side — claim a report, resolve it, issue/lift a restriction — to be
-- done "out of band with the service role". This migration turns that into a
-- small, audited, atomic RPC surface so a console (or an on-call moderator using
-- the service key) has one safe way to act, instead of hand-writing SQL.
--
-- SECURITY MODEL — read before changing:
--   * These functions are the MODERATOR API. They must never be reachable by a
--     normal player. Every one is REVOKED from public/anon/authenticated and
--     GRANTED only to service_role (the key the console holds server-side).
--   * They are SECURITY DEFINER purely so the definer's search_path is pinned;
--     the real authorization is the grant model above. service_role already
--     bypasses RLS, so these add auditing + atomicity, not new privilege.
--   * Player-facing enforcement is unchanged: restrictions are still read-only to
--     their owner, and moderation_actions is still invisible to every client.
--
-- Nothing here flips kSocialLive. This is the ops tooling the roadmap names as
-- the Phase 3 entry criterion; the human review workflow + staffing that call
-- these RPCs are an operational function, not code (see docs + ADR 0004).

-- Broaden the action vocabulary so a lift can be audited like any other action.
alter table public.moderation_actions
  drop constraint if exists moderation_actions_action_check;
alter table public.moderation_actions
  add constraint moderation_actions_action_check
  check (action in ('dismiss','warn','restrict','remove_content','ban','lift'));

-- Optional linkage so the console can show who a restriction came from.
alter table public.restrictions
  add column if not exists action_id uuid
    references public.moderation_actions (id) on delete set null;

-- ---------------------------------------------------------------------------
-- mod_queue: the review queue. Returns not-yet-resolved reports newest-first,
-- with how many total/open reports each target has drawn (so a console can
-- triage the most-flagged targets). Service-role only.
-- ---------------------------------------------------------------------------
create or replace function public.mod_queue(p_limit int default 100)
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
language sql
security definer set search_path = public
as $$
  select
    r.id, r.reporter_id, r.target_type, r.target_id, r.reason, r.detail,
    r.status, r.created_at,
    (select count(*) from public.reports x
       where x.target_type = r.target_type and x.target_id = r.target_id),
    (select count(*) from public.reports x
       where x.target_type = r.target_type and x.target_id = r.target_id
         and x.status <> 'resolved')
  from public.reports r
  where r.status <> 'resolved'
  order by r.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
$$;

-- ---------------------------------------------------------------------------
-- mod_claim_report: mark a report as under review (open -> reviewing) so two
-- moderators don't work the same item. Idempotent; returns the new status.
-- ---------------------------------------------------------------------------
create or replace function public.mod_claim_report(p_report_id uuid)
returns text
language plpgsql
security definer set search_path = public
as $$
begin
  update public.reports
     set status = 'reviewing'
   where id = p_report_id and status = 'open';
  if not found then
    return coalesce(
      (select status from public.reports where id = p_report_id),
      'not_found');
  end if;
  return 'reviewing';
end;
$$;

-- ---------------------------------------------------------------------------
-- mod_resolve_report: the core action. Atomically (1) records a moderation_action
-- against the report's target, (2) optionally issues a restriction on the
-- reported PROFILE (suspend/ban/mute), and (3) marks the report resolved.
--   p_action           dismiss | warn | restrict | remove_content | ban
--   p_restriction_kind mute | suspend | ban   (null = no restriction)
--   p_restriction_days integer days, or null for indefinite
-- A restriction is only issued when the target is a profile — content targets
-- (cat/trade/message) get an action logged but no account limit here. Returns
-- 'ok' | 'not_found' | 'bad_action' | 'bad_kind'.
-- ---------------------------------------------------------------------------
create or replace function public.mod_resolve_report(
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
declare
  rep     public.reports%rowtype;
  act_id  uuid;
  expires timestamptz;
begin
  if p_action not in ('dismiss','warn','restrict','remove_content','ban') then
    return 'bad_action';
  end if;
  if p_restriction_kind is not null
     and p_restriction_kind not in ('mute','suspend','ban') then
    return 'bad_kind';
  end if;

  select * into rep from public.reports where id = p_report_id;
  if not found then
    return 'not_found';
  end if;

  insert into public.moderation_actions
    (target_type, target_id, action, reason, note, report_id)
  values
    (rep.target_type, rep.target_id, p_action, p_reason, p_note, rep.id)
  returning id into act_id;

  if p_restriction_kind is not null and rep.target_type = 'profile' then
    expires := case
      when p_restriction_days is null then null
      else now() + make_interval(days => p_restriction_days)
    end;
    insert into public.restrictions
      (profile_id, kind, reason, expires_at, action_id)
    values
      (rep.target_id::uuid, p_restriction_kind, p_reason, expires, act_id);
  end if;

  update public.reports set status = 'resolved' where id = rep.id;
  return 'ok';
end;
$$;

-- ---------------------------------------------------------------------------
-- mod_issue_restriction: apply a restriction directly (not tied to a report),
-- with an audit action. mod_lift_restriction: end one early (sets expiry to now)
-- and audits a 'lift'. Both service-role only.
-- ---------------------------------------------------------------------------
create or replace function public.mod_issue_restriction(
  p_profile_id uuid,
  p_kind       text,
  p_reason     text default null,
  p_days       int  default null
)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  act_id  uuid;
  expires timestamptz;
begin
  if p_kind not in ('mute','suspend','ban') then
    return 'bad_kind';
  end if;
  if not exists (select 1 from public.profiles where id = p_profile_id) then
    return 'not_found';
  end if;

  insert into public.moderation_actions
    (target_type, target_id, action, reason)
  values
    ('profile', p_profile_id::text, 'restrict', p_reason)
  returning id into act_id;

  expires := case
    when p_days is null then null
    else now() + make_interval(days => p_days)
  end;
  insert into public.restrictions
    (profile_id, kind, reason, expires_at, action_id)
  values
    (p_profile_id, p_kind, p_reason, expires, act_id);
  return 'ok';
end;
$$;

create or replace function public.mod_lift_restriction(
  p_restriction_id uuid,
  p_reason         text default null
)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  rest public.restrictions%rowtype;
begin
  select * into rest from public.restrictions where id = p_restriction_id;
  if not found then
    return 'not_found';
  end if;

  insert into public.moderation_actions
    (target_type, target_id, action, reason)
  values
    ('profile', rest.profile_id::text, 'lift', p_reason);

  -- End it now rather than delete, so the account's history stays auditable.
  update public.restrictions set expires_at = now()
   where id = p_restriction_id;
  return 'ok';
end;
$$;

-- ---------------------------------------------------------------------------
-- Lock the moderator API to the service role only. Default EXECUTE is granted to
-- PUBLIC, so we revoke broadly first, then grant service_role explicitly.
-- ---------------------------------------------------------------------------
revoke execute on function public.mod_queue(int)                    from public, anon, authenticated;
revoke execute on function public.mod_claim_report(uuid)            from public, anon, authenticated;
revoke execute on function public.mod_resolve_report(uuid, text, text, text, text, int)
                                                                    from public, anon, authenticated;
revoke execute on function public.mod_issue_restriction(uuid, text, text, int)
                                                                    from public, anon, authenticated;
revoke execute on function public.mod_lift_restriction(uuid, text)  from public, anon, authenticated;

grant execute on function public.mod_queue(int)                     to service_role;
grant execute on function public.mod_claim_report(uuid)             to service_role;
grant execute on function public.mod_resolve_report(uuid, text, text, text, text, int)
                                                                    to service_role;
grant execute on function public.mod_issue_restriction(uuid, text, text, int)
                                                                    to service_role;
grant execute on function public.mod_lift_restriction(uuid, text)   to service_role;
