-- Cat-ch — a private, per-cat diary (launch-readiness, ADR 0005).
--
-- An owner-only timeline of little moments and notes for each cat. Like the rest
-- of the app it stores **no precise location** — only a coarse `location_label`
-- snapshot, enforced here by simply not having geo columns. RLS is owner-only
-- (mirrors care_state): a player can only ever read/write their own entries, and
-- there is no shared-read policy — the diary is never a cross-user surface, so it
-- carries no moderation debt.
--
-- Minor handling (ADR 0003 / 0005): the client keeps minors' diary notes
-- **on-device only** and never writes them here; adults' notes sync to this
-- table. Minimization is thus enforced client-side by construction; this schema
-- simply never receives minor free text.
create table if not exists public.cat_diary_entries (
  id uuid primary key default gen_random_uuid(),
  cat_id uuid not null references public.cats(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('met', 'milestone', 'note')),
  body text,
  location_label text,
  created_at timestamptz not null default now()
);

alter table public.cat_diary_entries enable row level security;

create policy "diary_owner_select" on public.cat_diary_entries
  for select using (profile_id = auth.uid());
create policy "diary_owner_insert" on public.cat_diary_entries
  for insert with check (profile_id = auth.uid());
create policy "diary_owner_update" on public.cat_diary_entries
  for update using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "diary_owner_delete" on public.cat_diary_entries
  for delete using (profile_id = auth.uid());

create index if not exists cat_diary_cat_idx
  on public.cat_diary_entries (cat_id, created_at desc);
