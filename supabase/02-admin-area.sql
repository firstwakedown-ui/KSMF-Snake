-- AchtungDieKM — Etapa 21: správa hracího území (admin)
-- Spusť přes tools/db/migrate PO schema.sql a import_graph.sql.
-- Přidává: vyřazování ulic (enabled), nastavení zápasu, startovní body a RPC pro zápis geometrie.

begin;

-- 1) Ulice lze "vyřadit z plánu" (soft-delete) – reverzibilní, hráč uvidí jen enabled.
alter table street_edges add column if not exists enabled boolean not null default true;

-- 2) Nastavení zápasu (FR-31) – časovače a tolerance snappingu (default 30).
alter table matches add column if not exists idle_timeout_s    int not null default 30;
alter table matches add column if not exists outside_timeout_s int not null default 30;
alter table matches add column if not exists snap_tolerance_m   int not null default 30;

-- 3) Startovní body hráčů (FR-15, FR-17). Vázané na zápas (konfiguraci).
create table if not exists start_points (
  id          uuid primary key default gen_random_uuid(),
  match_id    uuid references matches(id) on delete cascade,
  label       text,
  geom        geometry(Point, 4326) not null,
  created_at  timestamptz not null default now()
);
create index if not exists start_points_geom_idx on start_points using gist (geom);

-- 4) RPC pro spolehlivý zápis geometrie (klient posílá GeoJSON / souřadnice, server udělá PostGIS).
--    set_match_area: uloží/smaže nakreslenou oblast (GeoJSON polygon, nebo NULL = smazat).
create or replace function set_match_area(p_match uuid, p_geojson jsonb)
returns void
language sql
as $$
  update matches
     set area = case
                  when p_geojson is null then null
                  else ST_SetSRID(ST_GeomFromGeoJSON(p_geojson::text), 4326)
                end
   where id = p_match;
$$;

--    add_start_point: přidá startovní bod (lng/lat) a vrátí jeho id.
create or replace function add_start_point(p_match uuid, p_label text, p_lng double precision, p_lat double precision)
returns uuid
language sql
as $$
  insert into start_points (match_id, label, geom)
  values (p_match, p_label, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326))
  returning id;
$$;

-- 5) RLS politiky (prototyp – plný anonymní přístup; před ostrým provozem nahradit Auth-based).
alter table start_points enable row level security;
drop policy if exists start_points_all on start_points;
create policy start_points_all on start_points for all using (true) with check (true);

-- Admin smí ulice vyřazovat/vracet (update). Čtení už povoluje street_edges_read.
drop policy if exists street_edges_admin_write on street_edges;
create policy street_edges_admin_write on street_edges for update using (true) with check (true);

commit;
