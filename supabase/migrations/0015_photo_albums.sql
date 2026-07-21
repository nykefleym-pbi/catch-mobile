-- Cat-ch — Phase 3 (p3c): shared photo albums, done safely.
--
-- There are no real photos to share: a camera image is deleted immediately after
-- the companion sprite is generated (ADR 0001). So an "album" here is a curated,
-- captioned selection of the OWNER'S OWN cat sprites — never a camera image, and
-- (like every cross-user read) never any location. Building an album is private
-- until the owner opts a specific album into sharing (`is_shared`); accepted
-- friends then read it through one guarded SECURITY DEFINER RPC, exactly like the
-- showcase in 0014. `cats` stays strictly self-access.
--
-- Privacy: the friend-read RPC returns only safe cosmetic fields — never
-- `location_label` — so an album can never reveal where a real cat was met
-- (08-ethics R6). Sharing is adult-only, mirroring the showcase capability
-- (SocialCapabilities.canShowcaseToFriends), and enforced server-side.

-- albums: an owner's collection. Owner-only; friend reads go through the RPC.
create table if not exists public.albums (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references public.profiles (id) on delete cascade,
  title      text not null default 'My album',
  is_shared  boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.albums enable row level security;

create policy "albums are owner-access"
  on public.albums for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create index if not exists albums_owner_idx on public.albums (owner_id);

-- album_entries: which of the owner's cats sit in an album, with an optional
-- caption and a sort position. The WITH CHECK also proves the cat being added is
-- the caller's own, so a modified client can never slip another user's cat id in.
create table if not exists public.album_entries (
  album_id uuid not null references public.albums (id) on delete cascade,
  cat_id   uuid not null references public.cats (id) on delete cascade,
  position int not null default 0,
  caption  text,
  primary key (album_id, cat_id)
);

alter table public.album_entries enable row level security;

create policy "album entries are owner-access"
  on public.album_entries for all
  using (
    exists (
      select 1 from public.albums a
      where a.id = album_id and a.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.albums a
      where a.id = album_id and a.owner_id = auth.uid()
    )
    and exists (
      select 1 from public.cats c
      where c.id = cat_id and c.profile_id = auth.uid()
    )
  );

-- list_friend_albums(p_friend): the caller may read p_friend's *shared* albums
-- only when (a) the caller is old enough for social, (b) they are accepted
-- friends, (c) neither has blocked the other, and (d) the owner is an adult
-- (sharing cats is adult-only). Returns only safe, non-location cat fields plus
-- the album title, caption, and sort position. Empty set otherwise — it never
-- errors and never leaks why. Rows come back album-by-album, entries in order.
create or replace function public.list_friend_albums(p_friend uuid)
returns table (
  album_id     uuid,
  album_title  text,
  cat_id       uuid,
  name         text,
  nickname     text,
  sprite_url   text,
  growth_stage text,
  caption      text,
  sort_pos     int
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
  -- No reading across a block, either direction.
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
  -- Owner must be an adult (sharing cats is adult-only, mirroring the showcase).
  if not exists (
    select 1 from public.profiles p
    where p.id = p_friend and p.age_bracket = 'adult'
  ) then return; end if;

  return query
    select a.id, a.title, c.id, c.name, c.nickname, c.sprite_url,
           c.growth_stage, e.caption, e.position
    from public.albums a
    join public.album_entries e on e.album_id = a.id
    join public.cats c on c.id = e.cat_id
    where a.owner_id = p_friend and a.is_shared = true
    order by a.updated_at desc, e.position asc, c.discovered_at desc;
end;
$$;

revoke execute on function public.list_friend_albums(uuid) from public, anon;
grant execute on function public.list_friend_albums(uuid) to authenticated;
