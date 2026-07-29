-- Cat-ch — v1 schema (Capture -> CatDex core loop)
-- See docs/architecture/06-data-model.md. RLS is on for every table; a player
-- can only touch their own rows. Location is stored fuzzed only (ADR privacy
-- rules); precise coordinates are never persisted.

-- ---------------------------------------------------------------------------
-- profiles: one row per player, keyed to auth.users
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  age_bracket  text,                       -- coarse, for age-appropriate handling
  settings     jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles are self-access"
  on public.profiles for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- captures: the raw "I met a cat here" event
-- ---------------------------------------------------------------------------
create table if not exists public.captures (
  id               uuid primary key default gen_random_uuid(),
  profile_id       uuid not null references public.profiles (id) on delete cascade,
  status           text not null default 'pending'
                     check (status in ('pending','generating','complete','failed','rejected')),
  location_fuzzed  text,                    -- coarse geohash / region label only
  detection_result jsonb,                   -- classifier confidence + quality gate
  perceptual_hash  text,                    -- per-user duplicate detection only
  -- NOTE: the raw source photo is deleted after generation (ADR 0001); we do
  -- not keep a durable reference to it here.
  created_at       timestamptz not null default now()
);

alter table public.captures enable row level security;

create policy "captures are self-access"
  on public.captures for all
  using (auth.uid() = profile_id)
  with check (auth.uid() = profile_id);

create index if not exists captures_profile_idx on public.captures (profile_id);
create index if not exists captures_phash_idx on public.captures (profile_id, perceptual_hash);

-- ---------------------------------------------------------------------------
-- personality_traits: reference catalog (Curious, Brave, Lazy, ...)
-- ---------------------------------------------------------------------------
create table if not exists public.personality_traits (
  id          text primary key,            -- e.g. 'curious'
  label       text not null,
  description text
);

alter table public.personality_traits enable row level security;

create policy "traits are readable by authenticated users"
  on public.personality_traits for select
  to authenticated
  using (true);

-- ---------------------------------------------------------------------------
-- cats: a player's generated companion
-- ---------------------------------------------------------------------------
create table if not exists public.cats (
  id               uuid primary key default gen_random_uuid(),
  capture_id       uuid not null references public.captures (id) on delete cascade,
  profile_id       uuid not null references public.profiles (id) on delete cascade,
  name             text,
  nickname         text,
  sprite_url       text,                    -- transparent PNG in storage/CDN
  generation_meta  jsonb not null default '{}'::jsonb, -- colour, pattern, eyes, tail...
  trait_id         text references public.personality_traits (id),
  growth_stage     text not null default 'kitten'
                     check (growth_stage in ('kitten','young','adult','senior')),
  friendship_level int not null default 0,
  location_label   text,                    -- human-readable, privacy-safe ("Downtown")
  discovered_at    timestamptz not null default now()
);

alter table public.cats enable row level security;

create policy "cats are self-access"
  on public.cats for all
  using (auth.uid() = profile_id)
  with check (auth.uid() = profile_id);

create index if not exists cats_profile_idx on public.cats (profile_id);

-- ---------------------------------------------------------------------------
-- care_state: v1 needs = hunger + happiness (gentle, non-punitive decay)
-- ---------------------------------------------------------------------------
create table if not exists public.care_state (
  cat_id       uuid primary key references public.cats (id) on delete cascade,
  profile_id   uuid not null references public.profiles (id) on delete cascade,
  hunger       int not null default 100 check (hunger between 0 and 100),
  happiness    int not null default 100 check (happiness between 0 and 100),
  mood         text not null default 'content',
  last_updated timestamptz not null default now()
);

alter table public.care_state enable row level security;

create policy "care_state is self-access"
  on public.care_state for all
  using (auth.uid() = profile_id)
  with check (auth.uid() = profile_id);

-- ---------------------------------------------------------------------------
-- items + inventory: v1 = foods only (no purchasable power — cosmetic/optional)
-- ---------------------------------------------------------------------------
create table if not exists public.items (
  id           text primary key,            -- e.g. 'tuna'
  label        text not null,
  type         text not null,               -- 'food' (later: cosmetic, decor, ...)
  affection    int not null default 0,      -- affection granted on use
  is_cosmetic  boolean not null default false
);

alter table public.items enable row level security;

create policy "items are readable by authenticated users"
  on public.items for select
  to authenticated
  using (true);

create table if not exists public.inventory (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  item_id    text not null references public.items (id),
  quantity   int not null default 0 check (quantity >= 0),
  primary key (profile_id, item_id)
);

alter table public.inventory enable row level security;

create policy "inventory is self-access"
  on public.inventory for all
  using (auth.uid() = profile_id)
  with check (auth.uid() = profile_id);

-- ---------------------------------------------------------------------------
-- Auto-create a profile row when a new auth user signs up.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
