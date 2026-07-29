-- ---------------------------------------------------------------------------
-- 0005_care_depth: deeper daily needs (Phase 2 — deeper care & companionship)
--
-- Extends care_state from two needs (hunger + happiness) to five, matching the
-- "Full needs & mood" design. Every need stays gentle and non-punitive: the
-- client floors decay so a cat is never left miserable, and Sleep actually
-- *recovers* on its own while you're away ("she saved your favorite sunbeam").
--
--   hygiene — restored by Groom
--   sleep   — recovers passively over time; nudged down a little by play
--   play    — the wish for playtime, restored by Play
--
-- All default to 100 so existing cats simply start fully content.
-- ---------------------------------------------------------------------------
alter table public.care_state
  add column if not exists hygiene int not null default 100
    check (hygiene between 0 and 100),
  add column if not exists sleep int not null default 100
    check (sleep between 0 and 100),
  add column if not exists play int not null default 100
    check (play between 0 and 100);
