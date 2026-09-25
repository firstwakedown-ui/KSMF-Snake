-- AchtungDieKM — Etapa 27: rozdělení cest v průsečících (noding)
-- Spusť přes tools/db/migrate PO 06-add-footpaths.sql.
-- Každou cestu rozseká v bodech, kde ji kříží jiná cesta → úseky mezi křižovatkami jdou
-- zapínat/vypínat zvlášť. Zachová name / is_foot / enabled. Idempotentní (znovu = beze změny).

begin;

create or replace function split_match_edges(p_match uuid)
returns integer
language plpgsql
as $$
declare n integer;
begin
  -- 1) Pro každou hranu najdi průsečíkové BODY se všemi ostatními a rozsekej ji jimi.
  create temp table _seg on commit drop as
  with e as (
    select id, name, is_foot, enabled, geom
    from street_edges
    where match_id = p_match
  ),
  blades as (
    select a.id,
           ST_Union(ST_CollectionExtract(ST_Intersection(a.geom, b.geom), 1)) as pts
    from e a
    join e b on a.id <> b.id and ST_Intersects(a.geom, b.geom)
    group by a.id
  )
  select e.name, e.is_foot, e.enabled,
         (ST_Dump(
            case
              when bl.pts is null or ST_IsEmpty(bl.pts) then e.geom
              -- ST_Snap vloží průsečíkové body přesně na čáru (jinak ST_Split kvůli
              -- plovoucí aritmetice nerozsekne). Tolerance ~1 cm.
              else ST_Split(ST_Snap(e.geom, bl.pts, 0.0000001), bl.pts)
            end
          )).geom as geom
  from e
  left join blades bl on bl.id = e.id;

  -- 2) Nahraď hrany plánu rozsekanými úseky.
  delete from street_edges where match_id = p_match;

  insert into street_edges (match_id, name, enabled, is_foot, geom)
  select p_match, name, enabled, is_foot, ST_SetSRID(geom, 4326)
  from _seg
  where ST_Dimension(geom) = 1 and ST_NPoints(geom) >= 2;

  get diagnostics n = row_count;
  return n;
end
$$;

commit;
