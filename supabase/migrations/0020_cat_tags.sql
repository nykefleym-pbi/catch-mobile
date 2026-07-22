-- Cat-ch — private, player-defined tags on caught cats (launch-readiness, ADR 0005).
--
-- Tags are a personal way to organise the CatDex: free-text labels the owner
-- adds to their own cats and searches by. They are **owner-only** and never
-- shown to anyone else — a `text[]` column on `cats` deliberately inherits the
-- existing owner-only RLS on that table, so the private-by-default guarantee is
-- structural (no new policy, no cross-user surface, no moderation debt). If tags
-- ever become shareable they must first route through the Trust & Safety
-- substrate (see docs/decisions/0004-phase3-social-safety.md, 0005-...).
alter table public.cats
  add column if not exists tags text[] not null default '{}';

-- GIN index so a "filter by tag" query stays cheap as collections grow.
create index if not exists cats_tags_gin on public.cats using gin (tags);
