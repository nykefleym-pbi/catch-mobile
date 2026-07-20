-- ---------------------------------------------------------------------------
-- 0007_nook_layout: a per-cat decorated "nook" (Phase 2 — home decoration)
--
-- Stores the cat's little room as a JSON array of placed decor
-- ({iid, item, x, y, rot}), with x/y as 0..1 fractions so the layout is
-- resolution-independent. Decor is cosmetic only — unlocked by the bond you
-- build, never bought (docs/product/04-game-systems.md). RLS on `cats` already
-- scopes every write to the owner.
-- ---------------------------------------------------------------------------
alter table public.cats
  add column if not exists nook_layout jsonb not null default '[]'::jsonb;
