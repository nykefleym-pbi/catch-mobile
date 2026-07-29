-- ---------------------------------------------------------------------------
-- 0006_cosmetic_collar: a per-cat cosmetic collar (Phase 2 — grooming wardrobe)
--
-- Collars are cosmetic only — never power (docs/product/04-game-systems.md) —
-- and are earned by the bond you build with a cat, not bought. Stored as a free
-- text id matching the client catalogue; null means "no collar". RLS on `cats`
-- already scopes every write to the owner.
-- ---------------------------------------------------------------------------
alter table public.cats
  add column if not exists cosmetic_collar text;
