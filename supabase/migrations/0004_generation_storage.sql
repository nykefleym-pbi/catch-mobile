-- Cat-ch — generation storage (Phase 1, generation slice)
-- See docs/architecture/07-ai-pipeline.md.
--
-- Generated companion sprites live in a PUBLIC bucket so the CatDex can render
-- them by URL. The sprites are stylized art derived from a photo — they contain
-- no location data and no identifying information. The RAW source photo is never
-- stored: the client sends it inline to the `generate-companion` Edge Function,
-- which generates and discards it (privacy rule, ADR 0001). Hence there is no
-- private "captures" upload bucket here.

insert into storage.buckets (id, name, public)
values ('sprites', 'sprites', true)
on conflict (id) do nothing;

-- The Edge Function writes sprites with the service-role key (bypasses RLS), so
-- no INSERT policy is needed. Reads are served by the public bucket endpoint.
-- Defensive: allow public SELECT on this bucket's objects explicitly in case the
-- project is configured to require a policy even for public buckets.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'sprites are publicly readable'
  ) then
    create policy "sprites are publicly readable"
      on storage.objects for select
      using (bucket_id = 'sprites');
  end if;
end $$;
