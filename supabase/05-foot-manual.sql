-- AchtungDieKM — Etapa 24: chodníky jako přepínač, ruční spojnice, přesun startů
-- Spusť přes tools/db/migrate PO 04-plans.sql.

begin;

-- Rozlišení pěší cesty (chodník) vs silnice – kvůli přepínači „přidat i chodníky".
alter table street_edges add column if not exists is_foot boolean not null default false;

-- Plán si pamatuje, jestli jsou chodníky aktivní (bez nutnosti pregenerovat).
alter table matches add column if not exists footpaths_enabled boolean not null default true;

-- Uložení ulic z OSM – teď i s příznakem is_foot.
create or replace function set_area_streets(p_match uuid, p_streets jsonb)
returns integer
language plpgsql
as $$
declare n integer;
begin
  delete from street_edges where match_id = p_match;
  insert into street_edges (match_id, name, enabled, is_foot, geom)
  select p_match,
         nullif(e->>'name', ''),
         coalesce((e->>'enabled')::boolean, true),
         coalesce((e->>'is_foot')::boolean, false),
         ST_SetSRID(ST_GeomFromGeoJSON((e->'geom')::text), 4326)
  from jsonb_array_elements(p_streets) e;
  get diagnostics n = row_count;
  return n;
end
$$;

-- Ruční spojnice (rovná čára A–B), kterou admin dokreslí. Vrací id nové hrany.
create or replace function add_manual_edge(
  p_match uuid,
  p_a_lng double precision, p_a_lat double precision,
  p_b_lng double precision, p_b_lat double precision
)
returns bigint
language sql
as $$
  insert into street_edges (match_id, name, enabled, is_foot, geom)
  values (p_match, null, true, false,
          ST_SetSRID(ST_MakeLine(ST_MakePoint(p_a_lng, p_a_lat), ST_MakePoint(p_b_lng, p_b_lat)), 4326))
  returning id;
$$;

-- Přesun startovního bodu (drag&drop).
create or replace function move_start_point(p_id uuid, p_lng double precision, p_lat double precision)
returns void
language sql
as $$
  update start_points set geom = ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326) where id = p_id;
$$;

commit;
