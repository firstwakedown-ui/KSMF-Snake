-- AchtungDieKM — databázové schéma (Supabase / PostgreSQL + PostGIS)
-- Spusť v Supabase: SQL Editor -> New query -> vlož a Run.
-- Stav: základ pro prototyp. Účty/Auth a RLS politiky doplníme po prototypu.

-- 1) Geo rozšíření
create extension if not exists postgis;

-- 2) Graf ulic (z OSMnx -> GeoJSON -> import sem)
create table if not exists street_nodes (
  id          bigint primary key,           -- OSM node id
  geom        geometry(Point, 4326) not null
);
create index if not exists street_nodes_geom_idx on street_nodes using gist (geom);

create table if not exists street_edges (
  id          bigserial primary key,
  source_node bigint references street_nodes(id),
  target_node bigint references street_nodes(id),
  name        text,
  geom        geometry(LineString, 4326) not null
);
create index if not exists street_edges_geom_idx on street_edges using gist (geom);

-- 3) Zápasy a hráči (zjednodušené pro prototyp – bez Auth)
create table if not exists matches (
  id          uuid primary key default gen_random_uuid(),
  name        text,
  area        geometry(Polygon, 4326),       -- nakreslená herní oblast
  status      text not null default 'lobby', -- lobby | running | finished
  created_at  timestamptz not null default now()
);

create table if not exists players (
  id          uuid primary key default gen_random_uuid(),
  nickname    text not null,
  email       text,                          -- (až po prototypu: Auth + OTP/PIN)
  created_at  timestamptz not null default now()
);

create table if not exists match_players (
  match_id    uuid references matches(id) on delete cascade,
  player_id   uuid references players(id) on delete cascade,
  start_point geometry(Point, 4326),         -- startovní bod určený adminem
  alive       boolean not null default true,
  primary key (match_id, player_id)
);

-- 4) Stopy hráčů (rostoucí LINESTRING) – kolize = ST_Intersects mezi stopami
create table if not exists trails (
  match_id    uuid references matches(id) on delete cascade,
  player_id   uuid references players(id) on delete cascade,
  geom        geometry(LineString, 4326),
  updated_at  timestamptz not null default now(),
  primary key (match_id, player_id)
);
create index if not exists trails_geom_idx on trails using gist (geom);

-- Pozn.: snapping = ST_ClosestPoint(edge.geom, point); "v ulici?" = ST_DWithin(edge.geom, point, tolerance);
--        kolize = ST_Intersects(new_segment, other_trail.geom) mimo okolí uzlu.
