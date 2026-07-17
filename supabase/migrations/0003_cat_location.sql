-- Cat-ch — coarse "where you met them" coordinates for the Explore map.
--
-- Privacy (ADR 0001): precise coordinates are NEVER persisted. The Edge Function
-- rounds the device location to ~2 decimal places (~1.1 km) before it lands here,
-- so these columns hold only a fuzzed, neighbourhood-level point — enough to drop
-- a memory pin on the map, not enough to reveal a home address. Both are nullable:
-- a catch made with location off simply has no pin.
alter table public.cats
  add column if not exists geo_lat double precision,
  add column if not exists geo_lng double precision;
