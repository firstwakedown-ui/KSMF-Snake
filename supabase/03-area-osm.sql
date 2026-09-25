-- AchtungDieKM — Etapa 22: výběr oblasti → živé OSM ulice (Overpass)
-- Spusť přes tools/db/migrate PO 02-admin-area.sql.
-- Ulice se nově ukládají per konfigurace (match_id); admin je natahá z OSM podle nakreslené oblasti.

begin;

-- 1) Ulice patří ke konkrétní konfiguraci (zápasu). Staré globální (match_id NULL) zůstanou neviditelné.
alter table street_edges add column if not exists match_id uuid references matches(id) on delete cascade;
create index if not exists street_edges_match_idx on street_edges (match_id);

-- 2) Admin smí ulice plně spravovat (insert/update/delete) – prototyp, dočasné (jako ostatní *_all politiky).
drop policy if exists street_edges_admin_write on street_edges;
drop policy if exists street_edges_admin_all on street_edges;
create policy street_edges_admin_all on street_edges for all using (true) with check (true);

-- 3) Hromadné uložení ulic z OSM: klient pošle pole {name, enabled, geom(GeoJSON LineString)}.
--    Nahradí ulice dané konfigurace (nejdřív smaže, pak vloží). Vrací počet vložených.
create or replace function set_area_streets(p_match uuid, p_streets jsonb)
returns integer
language plpgsql
as $$
declare n integer;
begin
  delete from street_edges where match_id = p_match;
  insert into street_edges (match_id, name, enabled, geom)
  select p_match,
         nullif(e->>'name', ''),
         coalesce((e->>'enabled')::boolean, true),
         ST_SetSRID(ST_GeomFromGeoJSON((e->'geom')::text), 4326)
  from jsonb_array_elements(p_streets) e;
  get diagnostics n = row_count;
  return n;
end
$$;

-- 4) Vymazání celého hracího plánu konfigurace: ulice + startovní body + nakreslená oblast.
create or replace function clear_match_plan(p_match uuid)
returns void
language plpgsql
as $$
begin
  delete from street_edges where match_id = p_match;
  delete from start_points where match_id = p_match;
  update matches set area = null where id = p_match;
end
$$;

commit;
