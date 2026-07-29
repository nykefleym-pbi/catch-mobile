-- Cat-ch — Phase 3 (p3d): the tradable-cosmetic catalogue that trading needs.
--
-- The trade backend (migration 0010) is complete and safe, but there was nothing
-- to trade: cosmetics so far are per-cat, bond-unlocked strings (collars) and
-- nook decor — not ownable, transferable inventory rows. ADR 0004 named "a seeded
-- catalogue of tradable cosmetic items" as the last thing owed before trading.
--
-- This adds "charms": small, purely decorative collectibles that live in
-- `inventory` as ownable instances (is_cosmetic = true, type = 'charm'). They
-- grant NO affection and touch NO cat stat — cosmetic-only, no pay-to-win. Every
-- player starts with a VARIED handful (deterministic by account, not random —
-- no scarcity, no loot-box, no FOMO), so the cozy loop is "complete your set by
-- trading with friends" — kindness and cooperation, never spending or winning.
-- There is no way to BUY charms; the only economy is friendly trading.

-- 1) The catalogue: eight cozy charms.
insert into public.items (id, label, type, affection, is_cosmetic) values
  ('charm_yarn',  'Yarn Ball',   'charm', 0, true),
  ('charm_fish',  'Little Fish', 'charm', 0, true),
  ('charm_bell',  'Jingle Bell', 'charm', 0, true),
  ('charm_star',  'Gold Star',   'charm', 0, true),
  ('charm_leaf',  'Lucky Leaf',  'charm', 0, true),
  ('charm_moon',  'Night Moon',  'charm', 0, true),
  ('charm_heart', 'Warm Heart',  'charm', 0, true),
  ('charm_paw',   'Paw Print',   'charm', 0, true)
on conflict (id) do nothing;

-- 2) Grant every existing player a varied starter set of 3 charms. The pick is
-- deterministic per (player, charm) via hashtext, so it is stable and fair —
-- different players get different starters, which is exactly what makes trading
-- to complete the set meaningful. Idempotent (does nothing on re-run).
insert into public.inventory (profile_id, item_id, quantity)
select p.id, x.id, 1
from public.profiles p
cross join lateral (
  select i.id
  from public.items i
  where i.type = 'charm'
  order by hashtext(p.id::text || i.id)
  limit 3
) x
on conflict (profile_id, item_id) do nothing;

-- 3) Give the same varied starter set to every new player, at sign-up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id)
  on conflict (id) do nothing;

  insert into public.inventory (profile_id, item_id, quantity)
  select new.id, x.id, 1
  from (
    select i.id
    from public.items i
    where i.type = 'charm'
    order by hashtext(new.id::text || i.id)
    limit 3
  ) x
  on conflict (profile_id, item_id) do nothing;

  return new;
end;
$$;
