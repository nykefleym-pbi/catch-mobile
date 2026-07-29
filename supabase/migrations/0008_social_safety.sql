-- Cat-ch — Phase 3 groundwork: the Trust & Safety substrate that MUST exist
-- before any user-to-user interaction (docs/08-ethics-privacy-safety.md §Minors,
-- §Content moderation; docs/product/03-roadmap.md Phase 3 entry criterion;
-- R9 in docs/10-risks-and-open-questions.md). See ADR 0004.
--
-- RLS is on for every table. The default everywhere else in the schema is
-- owner-only; the ONLY cross-user read added here is an opt-in, friends-only
-- showcase (never a public directory — docs 08-ethics R6, no location registry).

-- ---------------------------------------------------------------------------
-- blocks: one row per (blocker -> blocked). Owner-scoped to the blocker.
-- ---------------------------------------------------------------------------
create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocks_not_self check (blocker_id <> blocked_id)
);

alter table public.blocks enable row level security;

create policy "blocks are managed by the blocker"
  on public.blocks for all
  using (auth.uid() = blocker_id)
  with check (auth.uid() = blocker_id);

-- ---------------------------------------------------------------------------
-- reports: a reporter flags content/another player. Reporters see only their
-- own reports; moderation reads them out-of-band with the service role (there
-- is no in-app moderation console — that is Phase 5 ops tooling, per R9).
-- ---------------------------------------------------------------------------
create table if not exists public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  target_type text not null check (target_type in ('profile','cat','trade','message')),
  target_id   text not null,
  reason      text not null check (reason in ('harassment','inappropriate','spam','other')),
  detail      text,
  status      text not null default 'open' check (status in ('open','reviewing','resolved')),
  created_at  timestamptz not null default now()
);

alter table public.reports enable row level security;

create policy "reporters insert their own reports"
  on public.reports for insert
  to authenticated
  with check (auth.uid() = reporter_id);

create policy "reporters read their own reports"
  on public.reports for select
  to authenticated
  using (auth.uid() = reporter_id);

create index if not exists reports_status_idx on public.reports (status, created_at);

-- ---------------------------------------------------------------------------
-- friendships: the social graph. Interaction is friends-only by design, so this
-- edge is the safety boundary for visiting/showcase/trading. Either party can
-- read/update their own edge; only the requester can create it.
-- ---------------------------------------------------------------------------
create table if not exists public.friendships (
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status       text not null default 'pending'
                 check (status in ('pending','accepted','declined','blocked')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  primary key (requester_id, addressee_id),
  constraint friendship_not_self check (requester_id <> addressee_id)
);

alter table public.friendships enable row level security;

create policy "friendships are visible to either party"
  on public.friendships for select
  to authenticated
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

create policy "friendship requests are created by the requester"
  on public.friendships for insert
  to authenticated
  with check (auth.uid() = requester_id);

create policy "friendships are updated by either party"
  on public.friendships for update
  to authenticated
  using (auth.uid() = requester_id or auth.uid() = addressee_id)
  with check (auth.uid() = requester_id or auth.uid() = addressee_id);

create policy "friendships are removed by either party"
  on public.friendships for delete
  to authenticated
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

create index if not exists friendships_addressee_idx
  on public.friendships (addressee_id, status);

-- ---------------------------------------------------------------------------
-- trades: SUBSTRATE ONLY (no client execution in this groundwork). Cosmetic-only
-- offers between accepted friends; execution needs realtime + escrow + fraud
-- handling and is deliberately deferred (see ADR 0004 "not built"). The offer
-- payload is validated cosmetic-only client-side by safe_play.itemIsTradable and
-- must be re-validated server-side before any live execution ships.
-- ---------------------------------------------------------------------------
create table if not exists public.trades (
  id         uuid primary key default gen_random_uuid(),
  from_id    uuid not null references public.profiles (id) on delete cascade,
  to_id      uuid not null references public.profiles (id) on delete cascade,
  offer      jsonb not null default '{}'::jsonb,
  status     text not null default 'proposed'
               check (status in ('proposed','accepted','declined','cancelled','completed')),
  created_at timestamptz not null default now(),
  constraint trade_not_self check (from_id <> to_id)
);

alter table public.trades enable row level security;

create policy "trades are visible to either party"
  on public.trades for select
  to authenticated
  using (auth.uid() = from_id or auth.uid() = to_id);

create policy "trades are proposed by the sender"
  on public.trades for insert
  to authenticated
  with check (auth.uid() = from_id);

create policy "trades are updated by either party"
  on public.trades for update
  to authenticated
  using (auth.uid() = from_id or auth.uid() = to_id)
  with check (auth.uid() = from_id or auth.uid() = to_id);

-- ---------------------------------------------------------------------------
-- Opt-in, friends-only showcase read of another player's cats.
-- A cat becomes readable by a viewer ONLY when its owner has switched on
-- settings.showcase_to_friends AND the viewer is an accepted friend. This is
-- purely additive to the existing owner-only "cats are self-access" policy
-- (RLS policies are OR'd), so a cat is private by default. There is no public
-- directory and location columns are coarse-only by construction (ADR privacy).
-- ---------------------------------------------------------------------------
create policy "cats are visible to accepted friends when showcased"
  on public.cats for select
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = cats.profile_id
        and coalesce((p.settings ->> 'showcase_to_friends')::boolean, false)
    )
    and exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
        and (
          (f.requester_id = auth.uid() and f.addressee_id = cats.profile_id)
          or
          (f.addressee_id = auth.uid() and f.requester_id = cats.profile_id)
        )
    )
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = cats.profile_id and b.blocked_id = auth.uid())
         or (b.blocker_id = auth.uid() and b.blocked_id = cats.profile_id)
    )
  );

-- ---------------------------------------------------------------------------
-- friend_request_by_code(code): resolve a short friend code to a profile and
-- create a pending request, WITHOUT exposing any profile data to the caller
-- (profiles stay self-access). SECURITY DEFINER so it can look past RLS to find
-- the target and check blocks, but it only ever performs this one controlled
-- action and returns a status string.
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

-- ---------------------------------------------------------------------------
-- list_friends(): return the caller's edges joined to the minimal profile field
-- (display name only) so the friend list can render without a cross-user read
-- policy on profiles. SECURITY DEFINER, caller-scoped by auth.uid().
-- ---------------------------------------------------------------------------
create or replace function public.list_friends()
returns table (
  friend_id    uuid,
  display_name text,
  status       text,
  is_incoming  boolean
)
language sql
security definer set search_path = public
as $$
  select
    case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end,
    p.display_name,
    f.status,
    (f.addressee_id = auth.uid() and f.status = 'pending')
  from public.friendships f
  join public.profiles p
    on p.id = case when f.requester_id = auth.uid()
                   then f.addressee_id else f.requester_id end
  where (f.requester_id = auth.uid() or f.addressee_id = auth.uid())
    and f.status in ('pending','accepted')
  order by f.updated_at desc;
$$;

-- Both RPCs are meant to be called by signed-in players over /rest/v1/rpc.
revoke execute on function public.friend_request_by_code(text) from public, anon;
revoke execute on function public.list_friends() from public, anon;
grant execute on function public.friend_request_by_code(text) to authenticated;
grant execute on function public.list_friends() to authenticated;
