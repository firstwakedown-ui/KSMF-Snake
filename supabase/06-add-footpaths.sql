-- AchtungDieKM — Etapa 25: nedestruktivní doplnění chodníků do stávajícího plánu
-- Spusť přes tools/db/migrate PO 05-foot-manual.sql.

begin;

-- Doplní chodníky do plánu: smaže jen stávající chodníky (is_foot=true) a vloží nové,
-- silnice i ruční spojnice (is_foot=false) nechá být. Vrací počet vložených.
create or replace function add_area_footpaths(p_match uuid, p_streets jsonb)
returns integer
language plpgsql
as $$
declare n integer;
begin
  delete from street_edges where match_id = p_match and is_foot = true;
  insert into street_edges (match_id, name, enabled, is_foot, geom)
  select p_match,
         nullif(e->>'name', ''),
         coalesce((e->>'enabled')::boolean, true),
         true,
         ST_SetSRID(ST_GeomFromGeoJSON((e->'geom')::text), 4326)
  from jsonb_array_elements(p_streets) e;
  get diagnostics n = row_count;
  return n;
end
$$;

-- Ruční spojnice teď umí i chodník (p_is_foot). Starou verzi (5 parametrů) zahodíme.
drop function if exists add_manual_edge(uuid, double precision, double precision, double precision, double precision);
create or replace function add_manual_edge(
  p_match uuid,
  p_a_lng double precision, p_a_lat double precision,
  p_b_lng double precision, p_b_lat double precision,
  p_is_foot boolean default false
)
returns bigint
language sql
as $$
  insert into street_edges (match_id, name, enabled, is_foot, geom)
  values (p_match, null, true, p_is_foot,
          ST_SetSRID(ST_MakeLine(ST_MakePoint(p_a_lng, p_a_lat), ST_MakePoint(p_b_lng, p_b_lat)), 4326))
  returning id;
$$;

commit;
