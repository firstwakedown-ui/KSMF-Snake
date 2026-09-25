
-- ===== FILE: schema.sql =====

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


-- ===== FILE: import_graph.sql =====

-- Vygenerováno build_graph.py (OSM drive -> PostGIS). Spusť přes tools/db/migrate.
begin;
truncate table street_edges, street_nodes restart identity cascade;
insert into street_nodes (id, geom) values (21453198, ST_SetSRID(ST_MakePoint(14.3728576, 50.0329029), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (25376168, ST_SetSRID(ST_MakePoint(14.3669065, 50.0264272), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (25376169, ST_SetSRID(ST_MakePoint(14.3669688, 50.0265474), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (25376180, ST_SetSRID(ST_MakePoint(14.3665306, 50.0294388), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (25376192, ST_SetSRID(ST_MakePoint(14.3632272, 50.0308785), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (25376596, ST_SetSRID(ST_MakePoint(14.3741929, 50.0314265), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (25376621, ST_SetSRID(ST_MakePoint(14.3778494, 50.0327698), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (25376722, ST_SetSRID(ST_MakePoint(14.3733199, 50.0311693), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (25376725, ST_SetSRID(ST_MakePoint(14.3721397, 50.0307598), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (25376737, ST_SetSRID(ST_MakePoint(14.3670721, 50.029488), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (25376770, ST_SetSRID(ST_MakePoint(14.3668099, 50.0260686), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (25376771, ST_SetSRID(ST_MakePoint(14.3668316, 50.0261743), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (30930146, ST_SetSRID(ST_MakePoint(14.370866, 50.0321155), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (30930148, ST_SetSRID(ST_MakePoint(14.3726945, 50.0266574), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (30930152, ST_SetSRID(ST_MakePoint(14.3697853, 50.0279115), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (30930154, ST_SetSRID(ST_MakePoint(14.3692302, 50.0298026), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (30930156, ST_SetSRID(ST_MakePoint(14.3741857, 50.0279606), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (30930157, ST_SetSRID(ST_MakePoint(14.3705391, 50.026795), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (30930210, ST_SetSRID(ST_MakePoint(14.374047, 50.0285958), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (30930211, ST_SetSRID(ST_MakePoint(14.3701572, 50.0273424), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (30930261, ST_SetSRID(ST_MakePoint(14.3740362, 50.0293425), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (30930364, ST_SetSRID(ST_MakePoint(14.3743577, 50.0272305), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (30930481, ST_SetSRID(ST_MakePoint(14.3738854, 50.0292677), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (143797669, ST_SetSRID(ST_MakePoint(14.3635699, 50.0291732), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697550, ST_SetSRID(ST_MakePoint(14.3730071, 50.0289773), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697551, ST_SetSRID(ST_MakePoint(14.3765619, 50.0287868), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697552, ST_SetSRID(ST_MakePoint(14.3753828, 50.0283573), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697556, ST_SetSRID(ST_MakePoint(14.3739148, 50.0291574), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697557, ST_SetSRID(ST_MakePoint(14.3755197, 50.0298789), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697558, ST_SetSRID(ST_MakePoint(14.373521, 50.029971), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697936, ST_SetSRID(ST_MakePoint(14.3669416, 50.0275396), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697937, ST_SetSRID(ST_MakePoint(14.3726745, 50.0296564), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697938, ST_SetSRID(ST_MakePoint(14.3695003, 50.0286275), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697939, ST_SetSRID(ST_MakePoint(14.3704246, 50.0289138), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697946, ST_SetSRID(ST_MakePoint(14.3725382, 50.0299329), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697948, ST_SetSRID(ST_MakePoint(14.3712889, 50.0296758), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697949, ST_SetSRID(ST_MakePoint(14.3714898, 50.0292629), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697950, ST_SetSRID(ST_MakePoint(14.3718085, 50.0285723), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697951, ST_SetSRID(ST_MakePoint(14.3720765, 50.0279631), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697952, ST_SetSRID(ST_MakePoint(14.372351, 50.0273749), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697953, ST_SetSRID(ST_MakePoint(14.3728914, 50.0267278), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697954, ST_SetSRID(ST_MakePoint(14.3725688, 50.0274499), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697955, ST_SetSRID(ST_MakePoint(14.3722947, 50.0280386), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697956, ST_SetSRID(ST_MakePoint(14.3720235, 50.028636), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (246697959, ST_SetSRID(ST_MakePoint(14.3717213, 50.0293391), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (277483398, ST_SetSRID(ST_MakePoint(14.3638053, 50.0281745), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (309633943, ST_SetSRID(ST_MakePoint(14.370705, 50.0308388), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (309636097, ST_SetSRID(ST_MakePoint(14.3720945, 50.0313391), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (309636330, ST_SetSRID(ST_MakePoint(14.3695115, 50.0299092), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (309636356, ST_SetSRID(ST_MakePoint(14.3698544, 50.0305231), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (309636873, ST_SetSRID(ST_MakePoint(14.367509, 50.0295259), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (309636981, ST_SetSRID(ST_MakePoint(14.3675369, 50.0305782), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (309636998, ST_SetSRID(ST_MakePoint(14.3671679, 50.03049), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (312021576, ST_SetSRID(ST_MakePoint(14.3764803, 50.0322679), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (312021789, ST_SetSRID(ST_MakePoint(14.3750945, 50.0317554), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (312023808, ST_SetSRID(ST_MakePoint(14.3773863, 50.0333046), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (312023809, ST_SetSRID(ST_MakePoint(14.3765257, 50.0330031), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (312023854, ST_SetSRID(ST_MakePoint(14.3736544, 50.0332929), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (312024763, ST_SetSRID(ST_MakePoint(14.3738118, 50.0331725), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (390717117, ST_SetSRID(ST_MakePoint(14.3633275, 50.0304165), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (757435777, ST_SetSRID(ST_MakePoint(14.3668803, 50.030453), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (1272543034, ST_SetSRID(ST_MakePoint(14.3662113, 50.0309553), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (1421082248, ST_SetSRID(ST_MakePoint(14.377692, 50.0282384), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (1421082255, ST_SetSRID(ST_MakePoint(14.3771742, 50.0282782), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (1837466632, ST_SetSRID(ST_MakePoint(14.3711613, 50.0317849), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (2273369314, ST_SetSRID(ST_MakePoint(14.3777795, 50.0327406), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (3135710144, ST_SetSRID(ST_MakePoint(14.3769942, 50.0279679), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (5453749166, ST_SetSRID(ST_MakePoint(14.3751453, 50.0303172), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (6124372095, ST_SetSRID(ST_MakePoint(14.3631659, 50.0310788), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (6124372098, ST_SetSRID(ST_MakePoint(14.3628095, 50.0320533), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (6484919238, ST_SetSRID(ST_MakePoint(14.3663608, 50.0262313), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (6484919242, ST_SetSRID(ST_MakePoint(14.3672754, 50.0261212), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (7636024230, ST_SetSRID(ST_MakePoint(14.3653822, 50.0274417), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (8594742617, ST_SetSRID(ST_MakePoint(14.3667789, 50.0259125), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (8594742618, ST_SetSRID(ST_MakePoint(14.3664067, 50.0261182), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (8594742621, ST_SetSRID(ST_MakePoint(14.3667284, 50.0259154), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (8594742622, ST_SetSRID(ST_MakePoint(14.3668351, 50.0259179), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (8594742627, ST_SetSRID(ST_MakePoint(14.3672582, 50.0260173), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (8595405124, ST_SetSRID(ST_MakePoint(14.3774383, 50.0280132), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (8595405125, ST_SetSRID(ST_MakePoint(14.3773612, 50.0281067), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (9104444538, ST_SetSRID(ST_MakePoint(14.367256, 50.0285675), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (9104444539, ST_SetSRID(ST_MakePoint(14.3681282, 50.0286346), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (9514707253, ST_SetSRID(ST_MakePoint(14.3759916, 50.0327372), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (9514707255, ST_SetSRID(ST_MakePoint(14.3759315, 50.0329059), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (9514707294, ST_SetSRID(ST_MakePoint(14.3708802, 50.0302064), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (9522455265, ST_SetSRID(ST_MakePoint(14.3632916, 50.0305414), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (10537611964, ST_SetSRID(ST_MakePoint(14.3772577, 50.0334495), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (10679553244, ST_SetSRID(ST_MakePoint(14.3664193, 50.0275165), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (12603694153, ST_SetSRID(ST_MakePoint(14.3630107, 50.0316267), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (12603694154, ST_SetSRID(ST_MakePoint(14.3656456, 50.0318601), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (13295083186, ST_SetSRID(ST_MakePoint(14.3743704, 50.0327644), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (13483561866, ST_SetSRID(ST_MakePoint(14.3631194, 50.0308537), 4326)) on conflict (id) do nothing;
insert into street_nodes (id, geom) values (13860430177, ST_SetSRID(ST_MakePoint(14.3774369, 50.0311685), 4326)) on conflict (id) do nothing;
insert into street_edges (source_node, target_node, name, geom) values (21453198, 312023854, 'Tréglova', ST_GeomFromText('LINESTRING (14.3728576 50.0329029, 14.3730468 50.0329955, 14.3734273 50.0331817, 14.3736544 50.0332929)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (21453198, 30930146, 'Werichova', ST_GeomFromText('LINESTRING (14.3728576 50.0329029, 14.3722504 50.0326424, 14.3720875 50.0325725, 14.37192 50.0325017, 14.370866 50.0321155)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (21453198, 25376596, 'Štěpařská', ST_GeomFromText('LINESTRING (14.3728576 50.0329029, 14.3732623 50.0324804, 14.3734482 50.03227, 14.3741133 50.0315171, 14.3741929 50.0314265)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376168, 25376169, 'Wassermannova', ST_GeomFromText('LINESTRING (14.3669065 50.0264272, 14.3669688 50.0265474)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376168, 25376771, 'Wassermannova', ST_GeomFromText('LINESTRING (14.3669065 50.0264272, 14.3668568 50.0262593, 14.3668316 50.0261743)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376168, 6484919238, 'Wassermannova', ST_GeomFromText('LINESTRING (14.3669065 50.0264272, 14.3667595 50.0262988, 14.3667286 50.0262808, 14.3666756 50.0262606, 14.3666373 50.0262495, 14.3665687 50.0262384, 14.3665014 50.0262334, 14.3663608 50.0262313)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376169, 246697936, 'Wassermannova', ST_GeomFromText('LINESTRING (14.3669688 50.0265474, 14.3670326 50.0267441, 14.3670694 50.0269525, 14.3670711 50.0270076, 14.3670593 50.0270821, 14.3670389 50.0271567, 14.3669416 50.0275396)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376180, 143797669, 'Voskovcova', ST_GeomFromText('LINESTRING (14.3665306 50.0294388, 14.3662348 50.0294122, 14.3655929 50.0293528, 14.3643585 50.0292432, 14.3637097 50.0291844, 14.3635699 50.0291732)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376180, 25376737, 'Voskovcova', ST_GeomFromText('LINESTRING (14.3665306 50.0294388, 14.3667674 50.0294603, 14.3670721 50.029488)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376180, 1272543034, 'Wassermannova', ST_GeomFromText('LINESTRING (14.3665306 50.0294388, 14.3665064 50.0295446, 14.3664338 50.029892, 14.3662267 50.030882, 14.3662113 50.0309553)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376180, 246697936, 'Wassermannova', ST_GeomFromText('LINESTRING (14.3665306 50.0294388, 14.3665476 50.0293556, 14.3665513 50.0293384, 14.3666227 50.0290016, 14.366742 50.0284383, 14.3668284 50.0280495, 14.3669416 50.0275396)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376192, 13483561866, 'Gollové', ST_GeomFromText('LINESTRING (14.3632272 50.0308785, 14.3631194 50.0308537)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376192, 1272543034, 'Werichova', ST_GeomFromText('LINESTRING (14.3632272 50.0308785, 14.3633647 50.030907, 14.3656272 50.0311095, 14.3658035 50.0311212, 14.3659504 50.0311121, 14.366063 50.0310643, 14.3661704 50.0310033, 14.3662113 50.0309553)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376192, 9522455265, 'Werichova', ST_GeomFromText('LINESTRING (14.3632272 50.0308785, 14.3632381 50.0307829, 14.3632722 50.0306284, 14.3632916 50.0305414)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376192, 6124372095, 'Miloše Havla', ST_GeomFromText('LINESTRING (14.3632272 50.0308785, 14.3632155 50.0309426, 14.3632037 50.0309694, 14.3631659 50.0310788)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376596, 25376722, 'Voskovcova', ST_GeomFromText('LINESTRING (14.3741929 50.0314265, 14.3737351 50.0312991, 14.3733199 50.0311693)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376596, 312021789, 'Högerova', ST_GeomFromText('LINESTRING (14.3741929 50.0314265, 14.3744306 50.0314984, 14.3744767 50.0315131, 14.3745171 50.0315259, 14.3750945 50.0317554)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376596, 5453749166, 'Štěpařská', ST_GeomFromText('LINESTRING (14.3741929 50.0314265, 14.3743023 50.0312888, 14.3744079 50.031169, 14.3747524 50.0307807, 14.3751453 50.0303172)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376621, 2273369314, 'Högerova', ST_GeomFromText('LINESTRING (14.3778494 50.0327698, 14.3777795 50.0327406)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376621, 312023808, 'Machatého', ST_GeomFromText('LINESTRING (14.3778494 50.0327698, 14.3777631 50.032865, 14.3773863 50.0333046)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376722, 25376725, 'Voskovcova', ST_GeomFromText('LINESTRING (14.3733199 50.0311693, 14.3723114 50.030818, 14.3722547 50.0307982, 14.3721397 50.0307598)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376722, 309636097, 'Pivcova', ST_GeomFromText('LINESTRING (14.3733199 50.0311693, 14.3732454 50.0312711, 14.3729185 50.0316368, 14.3725746 50.0315126, 14.3720945 50.0313391)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376725, 309636330, 'Voskovcova', ST_GeomFromText('LINESTRING (14.3721397 50.0307598, 14.3719467 50.0306955, 14.3707892 50.0303255, 14.3705619 50.030251, 14.3697807 50.0299949, 14.369709 50.0299659, 14.3695115 50.0299092)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376725, 246697946, 'Záhorského', ST_GeomFromText('LINESTRING (14.3721397 50.0307598, 14.3722158 50.0306786, 14.3725382 50.0299329)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376725, 309633943, 'Peškova', ST_GeomFromText('LINESTRING (14.3721397 50.0307598, 14.3720355 50.0308049, 14.371966 50.0308786, 14.3719492 50.0308971, 14.3718439 50.0310157, 14.371688 50.031193, 14.3715876 50.0311585, 14.370705 50.0308388)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376737, 309636873, 'Voskovcova', ST_GeomFromText('LINESTRING (14.3670721 50.029488, 14.367509 50.0295259)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376770, 25376771, 'Wassermannova', ST_GeomFromText('LINESTRING (14.3668099 50.0260686, 14.3668316 50.0261743)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (25376770, 8594742617, NULL, ST_GeomFromText('LINESTRING (14.3668099 50.0260686, 14.3667939 50.025988, 14.3667789 50.0259125)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930146, 1837466632, 'Peškova', ST_GeomFromText('LINESTRING (14.370866 50.0321155, 14.3709169 50.0320577, 14.3709821 50.0319837, 14.3710601 50.0318939, 14.3710728 50.0318813, 14.3711613 50.0317849)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930146, 1272543034, 'Werichova', ST_GeomFromText('LINESTRING (14.370866 50.0321155, 14.3695656 50.0316409, 14.3694467 50.0315891, 14.369283 50.0315198, 14.3688944 50.0313823, 14.3683824 50.0311942, 14.3680475 50.0311082, 14.3678354 50.0310735, 14.3677882 50.0310683, 14.3675476 50.0310417, 14.3672697 50.0310154, 14.3671674 50.0310057, 14.3663711 50.0309637, 14.3662113 50.0309553)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930148, 30930157, 'V Remízku', ST_GeomFromText('LINESTRING (14.3726945 50.0266574, 14.3726225 50.0266334, 14.3722131 50.0264966, 14.3713679 50.0262143, 14.3712093 50.0261613, 14.3711614 50.0261528, 14.3711165 50.0261538, 14.3710635 50.026162, 14.3710204 50.0261777, 14.3709891 50.0262023, 14.3705391 50.026795)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930148, 246697952, 'Lipová alej', ST_GeomFromText('LINESTRING (14.3726945 50.0266574, 14.372664 50.0267211, 14.3726441 50.0267628, 14.372351 50.0273749)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930152, 30930211, 'V Remízku', ST_GeomFromText('LINESTRING (14.3697853 50.0279115, 14.3701572 50.0273424)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930152, 246697950, 'V Javoříčku', ST_GeomFromText('LINESTRING (14.3697853 50.0279115, 14.3699463 50.0279641, 14.3717756 50.0285615, 14.3718085 50.0285723)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930152, 246697938, 'V Remízku', ST_GeomFromText('LINESTRING (14.3697853 50.0279115, 14.3695326 50.028534, 14.3695212 50.0285621, 14.3695003 50.0286275)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930154, 309636330, 'Voskovcova', ST_GeomFromText('LINESTRING (14.3692302 50.0298026, 14.3695115 50.0299092)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930154, 309636873, 'Voskovcova', ST_GeomFromText('LINESTRING (14.3692302 50.0298026, 14.3690532 50.0297604, 14.3686626 50.0296492, 14.3684979 50.0296176, 14.3682451 50.0295865, 14.3681292 50.0295772, 14.3680258 50.0295679, 14.367509 50.0295259)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930154, 246697938, 'V Remízku', ST_GeomFromText('LINESTRING (14.3692302 50.0298026, 14.3692461 50.0297171, 14.3693261 50.0293069, 14.3694439 50.0288228, 14.3694701 50.0287321, 14.3695003 50.0286275)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930156, 30930210, 'V Zálesí', ST_GeomFromText('LINESTRING (14.3741857 50.0279606, 14.374047 50.0285958)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930156, 246697954, 'Pod Třešněmi', ST_GeomFromText('LINESTRING (14.3741857 50.0279606, 14.374121 50.02794, 14.3726016 50.0274603, 14.3725688 50.0274499)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930156, 246697552, 'Pod Třešněmi', ST_GeomFromText('LINESTRING (14.3741857 50.0279606, 14.3742536 50.0279858, 14.3753828 50.0283573)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930156, 30930364, 'V Zálesí', ST_GeomFromText('LINESTRING (14.3741857 50.0279606, 14.3743327 50.0272824, 14.3743577 50.0272305)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930157, 30930211, 'V Remízku', ST_GeomFromText('LINESTRING (14.3705391 50.026795, 14.3701572 50.0273424)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930157, 246697952, 'Pod Třešněmi', ST_GeomFromText('LINESTRING (14.3705391 50.026795, 14.3723165 50.0273639, 14.372351 50.0273749)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930210, 246697556, 'V Zálesí', ST_GeomFromText('LINESTRING (14.374047 50.0285958, 14.3739148 50.0291574)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930210, 246697955, 'U Šípků', ST_GeomFromText('LINESTRING (14.374047 50.0285958, 14.3739717 50.0285786, 14.3723352 50.0280516, 14.3722947 50.0280386)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930211, 246697951, 'U Šípků', ST_GeomFromText('LINESTRING (14.3701572 50.0273424, 14.3720473 50.0279536, 14.3720765 50.0279631)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930261, 30930481, 'V Javoříčku', ST_GeomFromText('LINESTRING (14.3740362 50.0293425, 14.3738854 50.0292677)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930261, 246697557, 'Šejbalové', ST_GeomFromText('LINESTRING (14.3740362 50.0293425, 14.374195 50.0294002, 14.3752253 50.0297744, 14.3755197 50.0298789)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930261, 246697558, 'Šejbalové', ST_GeomFromText('LINESTRING (14.3740362 50.0293425, 14.3739602 50.0294401, 14.373521 50.029971)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930481, 246697550, 'V Javoříčku', ST_GeomFromText('LINESTRING (14.3738854 50.0292677, 14.3730071 50.0289773)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (30930481, 246697556, 'V Zálesí', ST_GeomFromText('LINESTRING (14.3738854 50.0292677, 14.373892 50.0292456, 14.3739033 50.0292077, 14.3739148 50.0291574)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (143797669, 277483398, 'Voskovcova', ST_GeomFromText('LINESTRING (14.3635699 50.0291732, 14.3635923 50.0290736, 14.3636998 50.0285964, 14.3637719 50.0282767, 14.3638053 50.0281745)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (143797669, 390717117, 'Voskovcova, Werichova', ST_GeomFromText('LINESTRING (14.3635699 50.0291732, 14.3635502 50.0292836, 14.3634418 50.029761, 14.3634184 50.0298693, 14.3633275 50.0304165)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697550, 246697937, 'Záhorského', ST_GeomFromText('LINESTRING (14.3730071 50.0289773, 14.3729953 50.0290013, 14.3726745 50.0296564)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697550, 246697956, 'V Javoříčku', ST_GeomFromText('LINESTRING (14.3730071 50.0289773, 14.3720615 50.0286492, 14.3720235 50.028636)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697551, 246697552, 'Pod Třešněmi', ST_GeomFromText('LINESTRING (14.3765619 50.0287868, 14.3763199 50.0286635, 14.3753828 50.0283573)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697551, 1421082255, 'Štěpařská', ST_GeomFromText('LINESTRING (14.3765619 50.0287868, 14.3771078 50.0283385, 14.3771742 50.0282782)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697551, 246697557, 'Štěpařská', ST_GeomFromText('LINESTRING (14.3765619 50.0287868, 14.3761514 50.0291425, 14.3760668 50.029244, 14.3756223 50.0297598, 14.3755438 50.029851, 14.3755197 50.0298789)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697552, 246697556, 'Podbělová', ST_GeomFromText('LINESTRING (14.3753828 50.0283573, 14.3750763 50.0287599, 14.3749505 50.0289022, 14.3749128 50.028928, 14.3747843 50.0290158, 14.3745485 50.0291044, 14.3743021 50.0291439, 14.37411 50.0291599, 14.3739926 50.0291584, 14.3739148 50.0291574)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697557, 5453749166, 'Štěpařská', ST_GeomFromText('LINESTRING (14.3755197 50.0298789, 14.3754413 50.0299679, 14.3753339 50.0300947, 14.3751453 50.0303172)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697936, 9104444538, 'Wassermannova', ST_GeomFromText('LINESTRING (14.3669416 50.0275396, 14.3671103 50.0275405, 14.3672461 50.0275605, 14.3673471 50.0275803, 14.3673979 50.0275978, 14.3674264 50.0276221, 14.3674351 50.027637, 14.3674407 50.0276547, 14.3674413 50.0276756, 14.3673919 50.0279124, 14.367322 50.028246, 14.3672875 50.0284111, 14.3672772 50.0284637, 14.3672727 50.0284856, 14.3672628 50.0285344, 14.367256 50.0285675)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697936, 10679553244, 'Schránilova', ST_GeomFromText('LINESTRING (14.3669416 50.0275396, 14.3668052 50.0275509, 14.3666416 50.0275325, 14.3664193 50.0275165)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697937, 246697946, 'Záhorského', ST_GeomFromText('LINESTRING (14.3726745 50.0296564, 14.3725382 50.0299329)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697937, 246697959, 'U Akátů', ST_GeomFromText('LINESTRING (14.3726745 50.0296564, 14.3717502 50.0293487, 14.3717213 50.0293391)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697938, 246697939, 'U Akátů', ST_GeomFromText('LINESTRING (14.3695003 50.0286275, 14.3696555 50.0286641, 14.3704246 50.0289138)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697939, 246697949, 'U Akátů', ST_GeomFromText('LINESTRING (14.3704246 50.0289138, 14.3714599 50.0292526, 14.3714898 50.0292629)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697939, 246697948, 'U Sídliště', ST_GeomFromText('LINESTRING (14.3704246 50.0289138, 14.3702997 50.0290671, 14.3702679 50.0291488, 14.3702702 50.0292101, 14.370299 50.0292765, 14.3703523 50.0293294, 14.3704103 50.0293717, 14.370487 50.0294115, 14.3712889 50.0296758)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697946, 246697948, 'U Sídliště', ST_GeomFromText('LINESTRING (14.3725382 50.0299329, 14.3723861 50.0299557, 14.3722417 50.0299514, 14.3721291 50.0299306, 14.3712889 50.0296758)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697948, 9514707294, 'U Sídliště', ST_GeomFromText('LINESTRING (14.3712889 50.0296758, 14.3708802 50.0302064)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697949, 246697959, 'U Akátů', ST_GeomFromText('LINESTRING (14.3714898 50.0292629, 14.3717213 50.0293391)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697949, 246697950, 'Lipová alej', ST_GeomFromText('LINESTRING (14.3714898 50.0292629, 14.3718085 50.0285723)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697950, 246697956, 'V Javoříčku', ST_GeomFromText('LINESTRING (14.3718085 50.0285723, 14.3720235 50.028636)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697950, 246697951, 'Lipová alej', ST_GeomFromText('LINESTRING (14.3718085 50.0285723, 14.3720765 50.0279631)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697951, 246697955, 'U Šípků', ST_GeomFromText('LINESTRING (14.3720765 50.0279631, 14.3722947 50.0280386)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697951, 246697952, 'Lipová alej', ST_GeomFromText('LINESTRING (14.3720765 50.0279631, 14.372351 50.0273749)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697952, 246697954, 'Pod Třešněmi', ST_GeomFromText('LINESTRING (14.372351 50.0273749, 14.3725688 50.0274499)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697953, 246697954, 'Lipová alej', ST_GeomFromText('LINESTRING (14.3728914 50.0267278, 14.3728654 50.026786, 14.3728343 50.0268556, 14.3725688 50.0274499)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697954, 246697955, 'Lipová alej', ST_GeomFromText('LINESTRING (14.3725688 50.0274499, 14.3722947 50.0280386)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697955, 246697956, 'Lipová alej', ST_GeomFromText('LINESTRING (14.3722947 50.0280386, 14.3720235 50.028636)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (246697956, 246697959, 'Lipová alej', ST_GeomFromText('LINESTRING (14.3720235 50.028636, 14.3717213 50.0293391)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (277483398, 7636024230, 'Novotného, Benešova', ST_GeomFromText('LINESTRING (14.3638053 50.0281745, 14.3639338 50.0281852, 14.3651888 50.0282894, 14.3652001 50.0282398, 14.3652112 50.0281912, 14.3652301 50.0281079, 14.3652999 50.0278015, 14.3653578 50.0275289, 14.3653822 50.0274417)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (309636330, 309636356, 'V Remízku', ST_GeomFromText('LINESTRING (14.3695115 50.0299092, 14.3694632 50.0299903, 14.369442 50.0302144, 14.369431 50.0303368, 14.3694853 50.0303907, 14.3695655 50.0304195, 14.3698544 50.0305231)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (309636873, 309636998, 'Wassermannova', ST_GeomFromText('LINESTRING (14.367509 50.0295259, 14.3674909 50.0296124, 14.3674168 50.0299496, 14.3674047 50.0299586, 14.3672537 50.0300709, 14.3671679 50.03049)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (309636981, 309636998, 'Wassermannova', ST_GeomFromText('LINESTRING (14.3675369 50.0305782, 14.3671679 50.03049)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (309636998, 757435777, 'Wassermannova', ST_GeomFromText('LINESTRING (14.3671679 50.03049, 14.3668803 50.030453)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (312021576, 9514707253, 'Brichtova', ST_GeomFromText('LINESTRING (14.3764803 50.0322679, 14.3764079 50.0323518, 14.3761135 50.0326989, 14.3759916 50.0327372)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (312021576, 312021789, 'Högerova', ST_GeomFromText('LINESTRING (14.3764803 50.0322679, 14.3762142 50.0321633, 14.3752226 50.0318021, 14.3750945 50.0317554)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (312021576, 2273369314, 'Högerova', ST_GeomFromText('LINESTRING (14.3764803 50.0322679, 14.3766393 50.0323242, 14.3777229 50.0327202, 14.3777795 50.0327406)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (312023808, 10537611964, 'Machatého', ST_GeomFromText('LINESTRING (14.3773863 50.0333046, 14.3772577 50.0334495)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (312023808, 312023809, 'Machatého', ST_GeomFromText('LINESTRING (14.3773863 50.0333046, 14.3772484 50.0332586, 14.3765257 50.0330031)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (312023854, 312024763, 'Tréglova', ST_GeomFromText('LINESTRING (14.3736544 50.0332929, 14.3738118 50.0331725)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (312024763, 13295083186, 'Tréglova', ST_GeomFromText('LINESTRING (14.3738118 50.0331725, 14.3738985 50.0330701, 14.3742281 50.0327078, 14.3743704 50.0327644)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (1272543034, 6124372095, 'Hermanové', ST_GeomFromText('LINESTRING (14.3662113 50.0309553, 14.3661793 50.0311059, 14.3661622 50.031186, 14.3661548 50.0312195, 14.3661482 50.0312484, 14.366141 50.0312811, 14.3661268 50.0313297, 14.3631659 50.0310788)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (1421082248, 1421082255, NULL, ST_GeomFromText('LINESTRING (14.377692 50.0282384, 14.3775419 50.0282264, 14.3774697 50.0282257, 14.3774142 50.0282289, 14.377362 50.0282351, 14.377298 50.0282469, 14.3772633 50.0282543, 14.3771742 50.0282782)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (1421082255, 3135710144, NULL, ST_GeomFromText('LINESTRING (14.3771742 50.0282782, 14.3771868 50.0281717, 14.3771822 50.0281404, 14.3771715 50.0281089, 14.3771557 50.0280852, 14.3771235 50.028054, 14.3770693 50.028013, 14.3769942 50.0279679)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (1421082255, 8595405125, 'Štěpařská', ST_GeomFromText('LINESTRING (14.3771742 50.0282782, 14.3772629 50.0282064, 14.3773612 50.0281067)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (5453749166, 13860430177, 'Divíškové', ST_GeomFromText('LINESTRING (14.3751453 50.0303172, 14.3752018 50.0303411, 14.3754452 50.0304439, 14.3758402 50.0306075, 14.3774369 50.0311685)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (6124372095, 12603694153, 'Miloše Havla', ST_GeomFromText('LINESTRING (14.3631659 50.0310788, 14.3631562 50.0311337, 14.3631114 50.0313417, 14.3630764 50.0314873, 14.3630211 50.0316046, 14.3630107 50.0316267)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (6124372098, 12603694153, 'Miloše Havla', ST_GeomFromText('LINESTRING (14.3628095 50.0320533, 14.3628469 50.031974, 14.3630107 50.0316267)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (6484919242, 25376169, 'Wassermannova', ST_GeomFromText('LINESTRING (14.3672754 50.0261212, 14.3671365 50.0261795, 14.3670841 50.0262092, 14.367057 50.0262306, 14.3670292 50.0262578, 14.3670144 50.0262796, 14.3669997 50.0263098, 14.3669947 50.0263438, 14.3669688 50.0265474)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (8594742618, 8594742621, NULL, ST_GeomFromText('LINESTRING (14.3664067 50.0261182, 14.3665265 50.0260831, 14.366601 50.0260492, 14.3666637 50.0260027, 14.366702 50.0259601, 14.3667284 50.0259154)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (8594742622, 8594742627, NULL, ST_GeomFromText('LINESTRING (14.3668351 50.0259179, 14.3668731 50.0259533, 14.3669111 50.0259747, 14.3669506 50.0259914, 14.3670068 50.0260063, 14.3670614 50.0260121, 14.3671425 50.0260145, 14.3672582 50.0260173)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (8595405124, 8595405125, 'Štěpařská', ST_GeomFromText('LINESTRING (14.3774383 50.0280132, 14.3773612 50.0281067)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (9104444538, 25376737, 'Wassermannova', ST_GeomFromText('LINESTRING (14.367256 50.0285675, 14.3672133 50.0287771, 14.3671068 50.0292999, 14.3670834 50.0294146, 14.3670721 50.029488)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (9104444538, 9104444539, 'Wassermannova', ST_GeomFromText('LINESTRING (14.367256 50.0285675, 14.3673537 50.0285756, 14.3680001 50.0286248, 14.3681282 50.0286346)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (9514707253, 312021789, 'Brichtova', ST_GeomFromText('LINESTRING (14.3759916 50.0327372, 14.3758847 50.0327389, 14.3747559 50.0323362, 14.3746201 50.0322965, 14.3747166 50.0321821, 14.3750038 50.0318418, 14.3750945 50.0317554)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (9514707253, 9514707255, NULL, ST_GeomFromText('LINESTRING (14.3759916 50.0327372, 14.3759942 50.0328324, 14.3759315 50.0329059)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (10679553244, 7636024230, 'Schránilova', ST_GeomFromText('LINESTRING (14.3664193 50.0275165, 14.3663338 50.0275103, 14.3654728 50.0274483, 14.3653822 50.0274417)', 4326));
insert into street_edges (source_node, target_node, name, geom) values (12603694153, 12603694154, 'Fabiánové', ST_GeomFromText('LINESTRING (14.3630107 50.0316267, 14.3631533 50.0316393, 14.3637716 50.0316941, 14.3644435 50.0317536, 14.3656456 50.0318601)', 4326));
commit;

-- ===== FILE: policies_prototype.sql =====

-- AchtungDieKM — prototypové RLS politiky (zatím BEZ přihlášení).
-- ⚠️ DOČASNÉ: před ostrým provozem nahradit politikami vázanými na Supabase Auth
--    (např. zápis do trails jen pro vlastníka hráče). Viz docs/03-architektura.md.
--
-- Supabase u nových tabulek zapíná RLS automaticky → bez politik anon nic nevidí.
-- Tyto politiky čtení/zápis povolí, aby prototyp fungoval.

-- Graf ulic: veřejné čtení (veřejná OSM data).
drop policy if exists street_nodes_read on street_nodes;
create policy street_nodes_read on street_nodes for select using (true);

drop policy if exists street_edges_read on street_edges;
create policy street_edges_read on street_edges for select using (true);

-- Herní tabulky: pro prototyp plný anonymní přístup (dočasné).
drop policy if exists matches_all on matches;
create policy matches_all on matches for all using (true) with check (true);

drop policy if exists players_all on players;
create policy players_all on players for all using (true) with check (true);

drop policy if exists match_players_all on match_players;
create policy match_players_all on match_players for all using (true) with check (true);

drop policy if exists trails_all on trails;
create policy trails_all on trails for all using (true) with check (true);


-- ===== FILE: 02-admin-area.sql =====

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


-- ===== FILE: 03-area-osm.sql =====

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


-- ===== FILE: 04-plans.sql =====

-- AchtungDieKM — Etapa 23: více hracích plánů (pojmenované konfigurace) + aktivní plán pro hru
-- Spusť přes tools/db/migrate PO 03-area-osm.sql.

begin;

-- Který plán hrají hráči. Právě jeden je "aktivní pro hru"; ostatní si admin chystá/edituje.
alter table matches add column if not exists is_active boolean not null default false;

-- Nastav daný plán jako aktivní (ostatní zhasne). Atomické.
create or replace function set_active_match(p_match uuid)
returns void
language plpgsql
as $$
begin
  update matches set is_active = false where is_active;
  update matches set is_active = true  where id = p_match;
end
$$;

commit;


-- ===== FILE: 05-foot-manual.sql =====

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


-- ===== FILE: 06-add-footpaths.sql =====

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


-- ===== FILE: 07-split-edges.sql =====

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


-- ===== FILE: 08-accounts.sql =====

-- AchtungDieKM — Etapa 28: přístup hráčů (přístupové kódy + účty s heslem)
-- Spusť přes tools/db/migrate PO 07-split-edges.sql.

begin;

create extension if not exists pgcrypto;

-- Přístupové kódy (generuje admin). Jeden kód = libovolně registrací, dokud je active.
create table if not exists access_codes (
  id          uuid primary key default gen_random_uuid(),
  code        text unique not null,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);
alter table access_codes enable row level security;
drop policy if exists access_codes_all on access_codes;
create policy access_codes_all on access_codes for all using (true) with check (true);

-- Hráči: unikátní přezdívka (case-insensitive). Heslo bokem (anon se k němu nedostane).
create unique index if not exists players_nick_uidx on players (lower(nickname));

create table if not exists player_auth (
  player_id     uuid primary key references players(id) on delete cascade,
  password_hash text not null
);
alter table player_auth enable row level security;
-- ŽÁDNÉ politiky → anon nemá k hashům přístup; pracují jen SECURITY DEFINER funkce níže.

-- Registrace: ověří kód, volnou přezdívku, uloží bcrypt hash. Vrací id + nickname.
create or replace function register_player(p_nickname text, p_password text, p_code text)
returns table(id uuid, nickname text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare v_id uuid; v_nick text;
begin
  v_nick := btrim(p_nickname);
  if v_nick = '' then raise exception 'Zadej přezdívku.'; end if;
  if length(coalesce(p_password, '')) < 4 then raise exception 'Heslo musí mít aspoň 4 znaky.'; end if;
  if not exists (select 1 from access_codes where code = upper(btrim(p_code)) and active) then
    raise exception 'Neplatný nebo deaktivovaný přístupový kód.';
  end if;
  if exists (select 1 from players where lower(players.nickname) = lower(v_nick)) then
    raise exception 'Tahle přezdívka už je obsazená.';
  end if;
  insert into players(nickname) values (v_nick) returning players.id into v_id;
  insert into player_auth(player_id, password_hash) values (v_id, crypt(p_password, gen_salt('bf')));
  return query select v_id, v_nick;
end
$$;

-- Přihlášení: ověří heslo. Vrací id + nickname, nebo vyhodí výjimku.
create or replace function login_player(p_nickname text, p_password text)
returns table(id uuid, nickname text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare v_id uuid; v_nick text; v_hash text;
begin
  select p.id, p.nickname into v_id, v_nick from players p where lower(p.nickname) = lower(btrim(p_nickname));
  if v_id is null then raise exception 'Přezdívka neexistuje – nejdřív se zaregistruj.'; end if;
  select password_hash into v_hash from player_auth where player_id = v_id;
  if v_hash is null or v_hash <> crypt(p_password, v_hash) then
    raise exception 'Špatné heslo.';
  end if;
  return query select v_id, v_nick;
end
$$;

commit;


-- ===== FILE: 09-lobby.sql =====

-- AchtungDieKM — Etapa 32: lobby (nabízení map ke hře + připojení hráčů)
-- Spusť přes tools/db/migrate PO 08-accounts.sql.

begin;

-- Stav mapy: draft (rozpracovaná) | lobby (nabízená) | running | finished.
-- Default napříště 'draft'; existující (schema měla default 'lobby') srovnáme na draft.
alter table matches alter column status set default 'draft';
update matches set status = 'draft' where status is null or status = 'lobby';

-- Připojení hráče: přidělený startovní bod + čas připojení.
alter table match_players add column if not exists start_point_id uuid references start_points(id) on delete set null;
alter table match_players add column if not exists joined_at timestamptz not null default now();

-- Admin otevře/zavře mapu v lobby (zavření uvolní připojené hráče).
create or replace function set_lobby(p_match uuid, p_open boolean)
returns void
language plpgsql
as $$
begin
  if p_open then
    update matches set status = 'lobby' where id = p_match;
  else
    delete from match_players where match_id = p_match;
    update matches set status = 'draft' where id = p_match;
  end if;
end
$$;

-- Hráč se připojí: ověří otevřenou mapu, kapacitu (= počet startů), přidělí volný start.
create or replace function join_match(p_match uuid, p_player uuid)
returns void
language plpgsql
as $$
declare cap int; cur int; free_id uuid;
begin
  if not exists (select 1 from matches where id = p_match and status = 'lobby') then
    raise exception 'Tahle mapa není otevřená pro připojení.';
  end if;
  if exists (select 1 from match_players where match_id = p_match and player_id = p_player) then
    return; -- už připojen, noop
  end if;
  select count(*) into cap from start_points where match_id = p_match;
  if cap = 0 then raise exception 'Mapa nemá nastavené starty.'; end if;
  select count(*) into cur from match_players where match_id = p_match;
  if cur >= cap then raise exception 'Kapacita mapy je plná.'; end if;
  select sp.id into free_id from start_points sp
   where sp.match_id = p_match
     and not exists (select 1 from match_players mp where mp.match_id = p_match and mp.start_point_id = sp.id)
   order by sp.created_at limit 1;
  insert into match_players(match_id, player_id, start_point_id) values (p_match, p_player, free_id);
end
$$;

create or replace function leave_match(p_match uuid, p_player uuid)
returns void
language sql
as $$
  delete from match_players where match_id = p_match and player_id = p_player;
$$;

-- Seznam map v lobby pro hráče (s kapacitou, obsazeností a zda jsem připojen).
create or replace function lobby_list(p_player uuid)
returns table(match_id uuid, name text, capacity bigint, joined bigint, mine boolean)
language sql
as $$
  select m.id, m.name,
         (select count(*) from start_points sp where sp.match_id = m.id),
         (select count(*) from match_players mp where mp.match_id = m.id),
         exists(select 1 from match_players mp where mp.match_id = m.id and mp.player_id = p_player)
  from matches m
  where m.status = 'lobby'
  order by m.created_at desc;
$$;

-- Mapa, ke které je hráč připojený (pro /play).
create or replace function player_current_match(p_player uuid)
returns table(id uuid, name text, snap_tolerance_m int)
language sql
as $$
  select m.id, m.name, m.snap_tolerance_m
  from match_players mp
  join matches m on m.id = mp.match_id
  where mp.player_id = p_player and m.status in ('lobby', 'running')
  order by mp.joined_at desc
  limit 1;
$$;

-- Přehled map pro admina (stav, kapacita, obsazenost).
create or replace function admin_games()
returns table(id uuid, name text, status text, capacity bigint, joined bigint)
language sql
as $$
  select m.id, m.name, m.status,
         (select count(*) from start_points sp where sp.match_id = m.id),
         (select count(*) from match_players mp where mp.match_id = m.id)
  from matches m
  order by m.created_at;
$$;

commit;


-- ===== FILE: 10-game.sql =====

-- AchtungDieKM — Etapa 33: start hry + odpočet (engine fáze 1)
-- Spusť přes tools/db/migrate PO 09-lobby.sql.

begin;

-- Čas zahájení (od něj se počítá odpočet i běh hry).
alter table matches add column if not exists started_at timestamptz;

-- Admin spustí hru: lobby -> running, zapíše čas startu (klienti z něj počítají odpočet).
create or replace function start_game(p_match uuid)
returns void
language plpgsql
as $$
begin
  update matches set status = 'running', started_at = now() where id = p_match and status = 'lobby';
end
$$;

-- Admin ukončí hru: uvolní hráče a vrátí mapu do lobby (znovu hratelná).
create or replace function end_game(p_match uuid)
returns void
language plpgsql
as $$
begin
  delete from match_players where match_id = p_match;
  update matches set status = 'lobby', started_at = null where id = p_match;
end
$$;

-- Mapa hráče teď vrací i stav a čas startu (pro fázi waiting/countdown/running).
drop function if exists player_current_match(uuid);
create or replace function player_current_match(p_player uuid)
returns table(id uuid, name text, snap_tolerance_m int, status text, started_at timestamptz)
language sql
as $$
  select m.id, m.name, m.snap_tolerance_m, m.status, m.started_at
  from match_players mp
  join matches m on m.id = mp.match_id
  where mp.player_id = p_player and m.status in ('lobby', 'running')
  order by mp.joined_at desc
  limit 1;
$$;

commit;


-- ===== FILE: 11-games.sql =====

-- AchtungDieKM — Etapa 37: hry jako instance plánů (víc her nad jedním plánem)
-- Spusť přes tools/db/migrate PO 10-game.sql.
-- Plán = mapa (šablona). Hra = instance plánu s vlastními hráči, kapacitou a stavem.

begin;

-- Plán lze označit „připraven ke hře" (z těch se zakládají hry).
alter table matches add column if not exists ready boolean not null default false;

-- Hra = instance plánu.
create table if not exists games (
  id          uuid primary key default gen_random_uuid(),
  plan_id     uuid not null references matches(id) on delete cascade,
  capacity    int not null,
  status      text not null default 'lobby', -- lobby | running | finished
  started_at  timestamptz,
  finished_at timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists games_status_idx on games (status);

-- Účast hráče ve hře (vlastní vybraný start).
create table if not exists game_players (
  game_id        uuid not null references games(id) on delete cascade,
  player_id      uuid not null references players(id) on delete cascade,
  start_point_id uuid references start_points(id) on delete set null,
  start_label    text,
  alive          boolean not null default true,
  place          int,
  joined_at      timestamptz not null default now(),
  primary key (game_id, player_id)
);

alter table games enable row level security;
drop policy if exists games_all on games;
create policy games_all on games for all using (true) with check (true);
alter table game_players enable row level security;
drop policy if exists game_players_all on game_players;
create policy game_players_all on game_players for all using (true) with check (true);

-- Plány připravené ke hře (pro „Nová hra").
create or replace function ready_plans()
returns table(id uuid, name text, starts bigint)
language sql as $$
  select m.id, m.name, (select count(*) from start_points sp where sp.match_id = m.id)
  from matches m where m.ready = true
  order by m.created_at;
$$;

-- Založení hry z plánu (kapacita se ořízne na počet startů).
create or replace function create_game(p_plan uuid, p_capacity int)
returns uuid
language plpgsql as $$
declare v_starts int; v_cap int; v_id uuid;
begin
  select count(*) into v_starts from start_points where match_id = p_plan;
  if v_starts = 0 then raise exception 'Plán nemá žádné starty.'; end if;
  v_cap := least(greatest(p_capacity, 1), v_starts);
  insert into games(plan_id, capacity) values (p_plan, v_cap) returning id into v_id;
  return v_id;
end $$;

-- Starty hry (pool = prvních „capacity" startů plánu) s informací, kdo je obsadil.
create or replace function game_starts(p_game uuid)
returns table(start_id uuid, label text, taken boolean, taken_by text)
language sql as $$
  with g as (select plan_id, capacity from games where id = p_game),
  pool as (
    select sp.id, sp.label, row_number() over (order by sp.created_at) rn
    from start_points sp, g where sp.match_id = g.plan_id
  )
  select p.id, p.label,
         exists(select 1 from game_players gp where gp.game_id = p_game and gp.start_point_id = p.id),
         (select pl.nickname from game_players gp join players pl on pl.id = gp.player_id
          where gp.game_id = p_game and gp.start_point_id = p.id limit 1)
  from pool p, g where p.rn <= g.capacity
  order by p.rn;
$$;

-- Připojení hráče: vybere si start (p_start). NULL = nejnižší volný.
create or replace function join_game(p_game uuid, p_player uuid, p_start uuid)
returns void
language plpgsql as $$
declare v_status text; v_cap int; v_plan uuid; v_cur int; v_start uuid; v_label text;
begin
  select status, capacity, plan_id into v_status, v_cap, v_plan from games where id = p_game;
  if v_status is null then raise exception 'Hra neexistuje.'; end if;
  if v_status <> 'lobby' then raise exception 'Tahle hra už není otevřená pro připojení.'; end if;
  if exists(select 1 from game_players where game_id = p_game and player_id = p_player) then return; end if;
  select count(*) into v_cur from game_players where game_id = p_game;
  if v_cur >= v_cap then raise exception 'Kapacita hry je plná.'; end if;
  with pool as (
    select sp.id, sp.label, row_number() over (order by sp.created_at) rn
    from start_points sp where sp.match_id = v_plan
  )
  select p2.id, p2.label into v_start, v_label
  from pool p2
  where p2.rn <= v_cap
    and not exists(select 1 from game_players gp where gp.game_id = p_game and gp.start_point_id = p2.id)
    and (p_start is null or p2.id = p_start)
  order by p2.rn limit 1;
  if v_start is null then raise exception 'Vybraný start není volný.'; end if;
  insert into game_players(game_id, player_id, start_point_id, start_label) values (p_game, p_player, v_start, v_label);
end $$;

create or replace function leave_game(p_game uuid, p_player uuid)
returns void language sql as $$
  delete from game_players where game_id = p_game and player_id = p_player;
$$;

create or replace function run_game(p_game uuid)
returns void language sql as $$
  update games set status = 'running', started_at = now() where id = p_game and status = 'lobby';
$$;

create or replace function finish_game(p_game uuid)
returns void language sql as $$
  update games set status = 'finished', finished_at = now() where id = p_game;
$$;

create or replace function delete_game(p_game uuid)
returns void language sql as $$
  delete from games where id = p_game;
$$;

-- Lobby pro hráče: otevřené hry s kapacitou/obsazeností a zda jsem připojen (+ můj start).
create or replace function lobby_games(p_player uuid)
returns table(game_id uuid, plan_name text, capacity int, joined bigint, mine boolean, my_start text)
language sql as $$
  select g.id, m.name, g.capacity,
         (select count(*) from game_players gp where gp.game_id = g.id),
         exists(select 1 from game_players gp where gp.game_id = g.id and gp.player_id = p_player),
         (select gp.start_label from game_players gp where gp.game_id = g.id and gp.player_id = p_player limit 1)
  from games g join matches m on m.id = g.plan_id
  where g.status = 'lobby'
  order by g.created_at desc;
$$;

-- Hra hráče (pro /play): hra + plán + můj start (souřadnice pro navigaci).
create or replace function current_game(p_player uuid)
returns table(game_id uuid, plan_id uuid, plan_name text, snap_tolerance_m int, status text,
              started_at timestamptz, start_lng double precision, start_lat double precision, start_label text)
language sql as $$
  select g.id, g.plan_id, m.name, m.snap_tolerance_m, g.status, g.started_at,
         ST_X(sp.geom), ST_Y(sp.geom), gp.start_label
  from game_players gp
  join games g on g.id = gp.game_id
  join matches m on m.id = g.plan_id
  left join start_points sp on sp.id = gp.start_point_id
  where gp.player_id = p_player and g.status in ('lobby', 'running')
  order by gp.joined_at desc limit 1;
$$;

-- Admin: aktivní hry (lobby/running).
create or replace function active_games()
returns table(game_id uuid, plan_name text, status text, capacity int, joined bigint)
language sql as $$
  select g.id, m.name, g.status, g.capacity,
         (select count(*) from game_players gp where gp.game_id = g.id)
  from games g join matches m on m.id = g.plan_id
  where g.status in ('lobby', 'running')
  order by g.created_at desc;
$$;

-- Admin: dokončené hry (historie).
create or replace function finished_games()
returns table(game_id uuid, plan_name text, players bigint, started_at timestamptz, finished_at timestamptz)
language sql as $$
  select g.id, m.name, (select count(*) from game_players gp where gp.game_id = g.id), g.started_at, g.finished_at
  from games g join matches m on m.id = g.plan_id
  where g.status = 'finished'
  order by g.finished_at desc nulls last;
$$;

commit;


-- ===== FILE: 12-spectate.sql =====

-- AchtungDieKM — Etapa 38: admin sleduje hru + výběr startu v mapě
-- Spusť přes tools/db/migrate PO 11-games.sql.

begin;

-- game_starts: doplnit souřadnice startů (pro výběr v mapě).
drop function if exists game_starts(uuid);
create or replace function game_starts(p_game uuid)
returns table(start_id uuid, label text, lng double precision, lat double precision, taken boolean, taken_by text)
language sql as $$
  with g as (select plan_id, capacity from games where id = p_game),
  pool as (
    select sp.id, sp.label, ST_X(sp.geom) lng, ST_Y(sp.geom) lat,
           row_number() over (order by sp.created_at) rn
    from start_points sp, g where sp.match_id = g.plan_id
  )
  select p.id, p.label, p.lng, p.lat,
         exists(select 1 from game_players gp where gp.game_id = p_game and gp.start_point_id = p.id),
         (select pl.nickname from game_players gp join players pl on pl.id = gp.player_id
          where gp.game_id = p_game and gp.start_point_id = p.id limit 1)
  from pool p, g where p.rn <= g.capacity
  order by p.rn;
$$;

-- lobby_games: doplnit plan_id (pro načtení ulic do mapky výběru startu).
drop function if exists lobby_games(uuid);
create or replace function lobby_games(p_player uuid)
returns table(game_id uuid, plan_id uuid, plan_name text, capacity int, joined bigint, mine boolean, my_start text)
language sql as $$
  select g.id, g.plan_id, m.name, g.capacity,
         (select count(*) from game_players gp where gp.game_id = g.id),
         exists(select 1 from game_players gp where gp.game_id = g.id and gp.player_id = p_player),
         (select gp.start_label from game_players gp where gp.game_id = g.id and gp.player_id = p_player limit 1)
  from games g join matches m on m.id = g.plan_id
  where g.status = 'lobby'
  order by g.created_at desc;
$$;

-- active_games: doplnit plan_id (pro „Sleduj").
drop function if exists active_games();
create or replace function active_games()
returns table(game_id uuid, plan_id uuid, plan_name text, status text, capacity int, joined bigint)
language sql as $$
  select g.id, g.plan_id, m.name, g.status, g.capacity,
         (select count(*) from game_players gp where gp.game_id = g.id)
  from games g join matches m on m.id = g.plan_id
  where g.status in ('lobby', 'running')
  order by g.created_at desc;
$$;

-- Roster hry pro admina (kdo hraje + jeho start): pro „Sleduj" a kontrolu, kdo je na startu.
create or replace function game_roster(p_game uuid)
returns table(player_id uuid, nickname text, start_lng double precision, start_lat double precision, start_label text, alive boolean)
language sql as $$
  select gp.player_id, pl.nickname, ST_X(sp.geom), ST_Y(sp.geom), gp.start_label, gp.alive
  from game_players gp
  join players pl on pl.id = gp.player_id
  left join start_points sp on sp.id = gp.start_point_id
  where gp.game_id = p_game
  order by gp.joined_at;
$$;

commit;


-- ===== FILE: 13-sim.sql =====

-- AchtungDieKM — Etapa 39: simulace povolená per hra
-- Spusť přes tools/db/migrate PO 12-spectate.sql.

begin;

-- Hra může mít povolenou simulaci (hráč pak smí přejít do sim módu).
alter table games add column if not exists sim boolean not null default false;

-- create_game s volbou simulace.
drop function if exists create_game(uuid, int);
create or replace function create_game(p_plan uuid, p_capacity int, p_sim boolean default false)
returns uuid
language plpgsql as $$
declare v_starts int; v_cap int; v_id uuid;
begin
  select count(*) into v_starts from start_points where match_id = p_plan;
  if v_starts = 0 then raise exception 'Plán nemá žádné starty.'; end if;
  v_cap := least(greatest(p_capacity, 1), v_starts);
  insert into games(plan_id, capacity, sim) values (p_plan, v_cap, coalesce(p_sim, false)) returning id into v_id;
  return v_id;
end $$;

-- current_game vrací i příznak sim.
drop function if exists current_game(uuid);
create or replace function current_game(p_player uuid)
returns table(game_id uuid, plan_id uuid, plan_name text, snap_tolerance_m int, status text,
              started_at timestamptz, start_lng double precision, start_lat double precision, start_label text, sim boolean)
language sql as $$
  select g.id, g.plan_id, m.name, m.snap_tolerance_m, g.status, g.started_at,
         ST_X(sp.geom), ST_Y(sp.geom), gp.start_label, g.sim
  from game_players gp
  join games g on g.id = gp.game_id
  join matches m on m.id = g.plan_id
  left join start_points sp on sp.id = gp.start_point_id
  where gp.player_id = p_player and g.status in ('lobby', 'running')
  order by gp.joined_at desc limit 1;
$$;

commit;


-- ===== FILE: 14-active-sim.sql =====

-- AchtungDieKM — Etapa 41: do přehledu aktivních her přidat příznak simulace
-- Spusť přes tools/db/migrate PO 13-sim.sql.

begin;

drop function if exists active_games();
create or replace function active_games()
returns table(game_id uuid, plan_id uuid, plan_name text, status text, capacity int, joined bigint, sim boolean)
language sql as $$
  select g.id, g.plan_id, m.name, g.status, g.capacity,
         (select count(*) from game_players gp where gp.game_id = g.id), g.sim
  from games g join matches m on m.id = g.plan_id
  where g.status in ('lobby', 'running')
  order by g.created_at desc;
$$;

commit;


-- ===== FILE: 15-alive.sql =====

-- AchtungDieKM — Etapa 42: current_game vrací i alive (vyřazený hráč může do lobby)
-- Spusť přes tools/db/migrate PO 14-active-sim.sql.

begin;

drop function if exists current_game(uuid);
create or replace function current_game(p_player uuid)
returns table(game_id uuid, plan_id uuid, plan_name text, snap_tolerance_m int, status text,
              started_at timestamptz, start_lng double precision, start_lat double precision,
              start_label text, sim boolean, alive boolean)
language sql as $$
  select g.id, g.plan_id, m.name, m.snap_tolerance_m, g.status, g.started_at,
         ST_X(sp.geom), ST_Y(sp.geom), gp.start_label, g.sim, gp.alive
  from game_players gp
  join games g on g.id = gp.game_id
  join matches m on m.id = g.plan_id
  left join start_points sp on sp.id = gp.start_point_id
  where gp.player_id = p_player and g.status in ('lobby', 'running')
  order by gp.joined_at desc limit 1;
$$;

commit;


-- ===== FILE: 16-autofinish.sql =====

-- AchtungDieKM — Etapa 43: automatické ukončení hry (poslední přeživší vyhrává) + smazání prázdné hry
-- Spusť přes tools/db/migrate PO 15-alive.sql.

begin;

-- Vyřazení hráče: alive=false, přiřadí pořadí (place), a když zbývá ≤1 živý → hru dokonči.
create or replace function eliminate_player(p_game uuid, p_player uuid)
returns void
language plpgsql as $$
declare v_alive int;
begin
  update game_players set alive = false
   where game_id = p_game and player_id = p_player and alive = true;
  if not found then return; end if;

  -- kolik zbývá živých PO tomto vyřazení
  select count(*) into v_alive from game_players where game_id = p_game and alive = true;
  -- pořadí vyřazeného: živí budou mít lepší (1..v_alive), tenhle dostane v_alive+1
  update game_players set place = v_alive + 1 where game_id = p_game and player_id = p_player;

  if v_alive <= 1 then
    -- poslední přeživší (pokud je) = 1. místo; hra končí
    update game_players set place = 1 where game_id = p_game and alive = true;
    update games set status = 'finished', finished_at = now() where id = p_game and status = 'running';
  end if;
end $$;

-- Ukončení hry adminem: prázdnou (nikdo nehrál) rovnou smaž, jinak do historie.
create or replace function finish_game(p_game uuid)
returns void
language plpgsql as $$
declare v_players int;
begin
  select count(*) into v_players from game_players where game_id = p_game;
  if v_players = 0 then
    delete from games where id = p_game;
  else
    update games set status = 'finished', finished_at = now() where id = p_game;
  end if;
end $$;

commit;


-- ===== FILE: 17-results.sql =====

-- AchtungDieKM — Etapa 44: výsledky hry (pořadí hráčů)
-- Spusť přes tools/db/migrate PO 16-autofinish.sql.

begin;

create or replace function game_results(p_game uuid)
returns table(player_id uuid, nickname text, place int, alive boolean)
language sql as $$
  select gp.player_id, pl.nickname, gp.place, gp.alive
  from game_players gp
  join players pl on pl.id = gp.player_id
  where gp.game_id = p_game
  order by gp.place nulls last, gp.joined_at;
$$;

commit;


-- ===== FILE: 18-trails.sql =====

-- AchtungDieKM — Etapa 45: uložené stopy hráčů (obrázek tras k výsledkům)
-- Spusť přes tools/db/migrate PO 17-results.sql.

begin;

-- Finální stopa hráče (pole [lng,lat]) – nahraje klient při vyřazení / na konci hry.
alter table game_players add column if not exists trail jsonb;

-- Výsledky teď vrací i trasu.
drop function if exists game_results(uuid);
create or replace function game_results(p_game uuid)
returns table(player_id uuid, nickname text, place int, alive boolean, trail jsonb)
language sql as $$
  select gp.player_id, pl.nickname, gp.place, gp.alive, gp.trail
  from game_players gp
  join players pl on pl.id = gp.player_id
  where gp.game_id = p_game
  order by gp.place nulls last, gp.joined_at;
$$;

-- Historie potřebuje plan_id (kvůli načtení ulic do obrázku).
drop function if exists finished_games();
create or replace function finished_games()
returns table(game_id uuid, plan_id uuid, plan_name text, players bigint, started_at timestamptz, finished_at timestamptz)
language sql as $$
  select g.id, g.plan_id, m.name, (select count(*) from game_players gp where gp.game_id = g.id),
         g.started_at, g.finished_at
  from games g join matches m on m.id = g.plan_id
  where g.status = 'finished'
  order by g.finished_at desc nulls last;
$$;

commit;


-- ===== FILE: 19-lobby-mine.sql =====

-- AchtungDieKM — Etapa 47: lobby ukazuje i vlastní běžící hru (konec auto-stahování)
-- Spusť přes tools/db/migrate PO 18-trails.sql.

begin;

drop function if exists lobby_games(uuid);
create or replace function lobby_games(p_player uuid)
returns table(game_id uuid, plan_id uuid, plan_name text, capacity int, joined bigint,
              mine boolean, my_start text, status text)
language sql as $$
  select g.id, g.plan_id, m.name, g.capacity,
         (select count(*) from game_players gp where gp.game_id = g.id),
         exists(select 1 from game_players gp where gp.game_id = g.id and gp.player_id = p_player),
         (select gp.start_label from game_players gp where gp.game_id = g.id and gp.player_id = p_player limit 1),
         g.status
  from games g join matches m on m.id = g.plan_id
  where g.status = 'lobby'
     or (g.status = 'running' and exists(select 1 from game_players gp where gp.game_id = g.id and gp.player_id = p_player))
  order by g.created_at desc;
$$;

commit;


-- ===== FILE: 20-norun-empty.sql =====

-- AchtungDieKM — Etapa 47: zákaz spuštění hry bez hráče
-- Spusť přes tools/db/migrate PO 19-lobby-mine.sql.

begin;

create or replace function run_game(p_game uuid)
returns void
language plpgsql as $$
begin
  if (select count(*) from game_players where game_id = p_game) = 0 then
    raise exception 'Ke hře není připojený žádný hráč.';
  end if;
  update games set status = 'running', started_at = now() where id = p_game and status = 'lobby';
end $$;

commit;


-- ===== FILE: 21-my-games.sql =====

-- AchtungDieKM — Etapa 48: hráčův seznam odehraných (dokončených) her v lobby
-- Spusť přes tools/db/migrate PO 20-norun-empty.sql.

begin;

create or replace function my_finished_games(p_player uuid)
returns table(game_id uuid, plan_id uuid, plan_name text, place int, finished_at timestamptz)
language sql as $$
  select g.id, g.plan_id, m.name, gp.place, g.finished_at
  from game_players gp
  join games g on g.id = gp.game_id
  join matches m on m.id = g.plan_id
  where gp.player_id = p_player and g.status = 'finished'
  order by g.finished_at desc nulls last;
$$;

commit;


-- ===== FILE: 22-spectate-lobby.sql =====

-- AchtungDieKM — Etapa 49: lobby ukazuje i běžící hry (možnost připojit se jako divák)
-- Spusť přes tools/db/migrate PO 21-my-games.sql.

begin;

drop function if exists lobby_games(uuid);
create or replace function lobby_games(p_player uuid)
returns table(game_id uuid, plan_id uuid, plan_name text, capacity int, joined bigint,
              mine boolean, my_start text, status text)
language sql as $$
  select g.id, g.plan_id, m.name, g.capacity,
         (select count(*) from game_players gp where gp.game_id = g.id),
         exists(select 1 from game_players gp where gp.game_id = g.id and gp.player_id = p_player),
         (select gp.start_label from game_players gp where gp.game_id = g.id and gp.player_id = p_player limit 1),
         g.status
  from games g join matches m on m.id = g.plan_id
  where g.status in ('lobby', 'running')
  order by g.created_at desc;
$$;

commit;


-- ===== FILE: 23-autofinish-trigger.sql =====

-- AchtungDieKM — Etapa 49: serverová pojistka – běžící hra bez živých hráčů se ukončí / prázdná smaže
-- Spusť přes tools/db/migrate PO 22-spectate-lobby.sql.

begin;

create or replace function trg_finish_empty_game()
returns trigger
language plpgsql as $$
declare gid uuid; n_players int; n_alive int;
begin
  gid := coalesce(NEW.game_id, OLD.game_id);
  select count(*), count(*) filter (where alive) into n_players, n_alive
  from game_players where game_id = gid;
  if n_players = 0 then
    -- všichni odešli → prázdnou hru smaž (lobby i running)
    delete from games where id = gid and status in ('lobby', 'running');
  elsif n_alive = 0 then
    -- všichni vyřazeni → běžící hra končí (zůstává v historii s pořadím)
    update games set status = 'finished', finished_at = now() where id = gid and status = 'running';
  end if;
  return null;
end $$;

drop trigger if exists game_players_autofinish on game_players;
create trigger game_players_autofinish
after update or delete on game_players
for each row execute function trg_finish_empty_game();

-- Jednorázový úklid: dokonči/smaž případné už existující „zaseklé" běžící hry.
update games g set status = 'finished', finished_at = now()
 where g.status = 'running'
   and exists (select 1 from game_players gp where gp.game_id = g.id)
   and not exists (select 1 from game_players gp where gp.game_id = g.id and gp.alive);
delete from games g
 where g.status in ('lobby', 'running')
   and not exists (select 1 from game_players gp where gp.game_id = g.id);

commit;


-- ===== FILE: 24-leave-forfeit.sql =====

-- AchtungDieKM — Etapa 50: odpojení z běžící hry = vzdání (vyřazení), 0 živých → dokončit (nemazat)
-- Spusť přes tools/db/migrate PO 23-autofinish-trigger.sql.

begin;

-- Odpojení: z běžící hry = vzdání (vyřazení s pořadím); z lobby = odhlášení (uvolní slot).
create or replace function leave_game(p_game uuid, p_player uuid)
returns void
language plpgsql as $$
declare st text;
begin
  select status into st from games where id = p_game;
  if st = 'running' then
    perform eliminate_player(p_game, p_player);
  else
    delete from game_players where game_id = p_game and player_id = p_player;
  end if;
end $$;

-- Pojistka: běžící hra s 0 živými → dokončit (NE mazat). Lobby hry se netýká (čekají na hráče).
create or replace function trg_finish_empty_game()
returns trigger
language plpgsql as $$
declare gid uuid; n_alive int;
begin
  gid := coalesce(NEW.game_id, OLD.game_id);
  select count(*) filter (where alive) into n_alive from game_players where game_id = gid;
  if n_alive = 0 then
    update games set status = 'finished', finished_at = now() where id = gid and status = 'running';
  end if;
  return null;
end $$;

commit;


-- ===== FILE: 25-lobby-alive.sql =====

-- AchtungDieKM — Etapa 53: lobby_games vrací i alive (vyřazený hráč u běžící hry → „Sledovat")
-- Spusť přes tools/db/migrate PO 24-leave-forfeit.sql.

begin;

drop function if exists lobby_games(uuid);
create or replace function lobby_games(p_player uuid)
returns table(game_id uuid, plan_id uuid, plan_name text, capacity int, joined bigint,
              mine boolean, my_start text, status text, alive boolean)
language sql as $$
  select g.id, g.plan_id, m.name, g.capacity,
         (select count(*) from game_players gp where gp.game_id = g.id),
         exists(select 1 from game_players gp where gp.game_id = g.id and gp.player_id = p_player),
         (select gp.start_label from game_players gp where gp.game_id = g.id and gp.player_id = p_player limit 1),
         g.status,
         (select gp.alive from game_players gp where gp.game_id = g.id and gp.player_id = p_player limit 1)
  from games g join matches m on m.id = g.plan_id
  where g.status in ('lobby', 'running')
  order by g.created_at desc;
$$;

commit;


-- ===== FILE: 26-run-mode.sql =====

-- AchtungDieKM — Etapa: „Run Hra" mód (joystick + rychlosti + stamina), oddělený od realtime/sim.
-- Spusť přes tools/db/migrate PO 25-lobby-alive.sql.

begin;

-- Třetí mód hry (vedle realtime a sim): auto-pohyb řízený joystickem, bez GPS.
alter table games add column if not exists run_mode boolean not null default false;

-- Konfigurovatelné rychlosti (m/s) + dosah sprintu (m) per plán – jen pro Run Hra mód.
alter table matches add column if not exists walk_speed_mps   numeric not null default 1.2;
alter table matches add column if not exists run_speed_mps    numeric not null default 2.5;
alter table matches add column if not exists sprint_speed_mps numeric not null default 4.0;
alter table matches add column if not exists sprint_range_m   int     not null default 200;

-- create_game s volbou módu (sim NEBO run; obojí default false = realtime).
drop function if exists create_game(uuid, int, boolean);
drop function if exists create_game(uuid, int, boolean, boolean);
create or replace function create_game(p_plan uuid, p_capacity int, p_sim boolean default false, p_run boolean default false)
returns uuid
language plpgsql as $$
declare v_starts int; v_cap int; v_id uuid;
begin
  select count(*) into v_starts from start_points where match_id = p_plan;
  if v_starts = 0 then raise exception 'Plán nemá žádné starty.'; end if;
  v_cap := least(greatest(p_capacity, 1), v_starts);
  insert into games(plan_id, capacity, sim, run_mode)
    values (p_plan, v_cap, coalesce(p_sim, false), coalesce(p_run, false))
    returning id into v_id;
  return v_id;
end $$;

-- current_game vrací i run_mode (navazuje na 15-alive: ...sim, alive, + run_mode).
drop function if exists current_game(uuid);
create or replace function current_game(p_player uuid)
returns table(game_id uuid, plan_id uuid, plan_name text, snap_tolerance_m int, status text,
              started_at timestamptz, start_lng double precision, start_lat double precision,
              start_label text, sim boolean, alive boolean, run_mode boolean)
language sql as $$
  select g.id, g.plan_id, m.name, m.snap_tolerance_m, g.status, g.started_at,
         ST_X(sp.geom), ST_Y(sp.geom), gp.start_label, g.sim, gp.alive, g.run_mode
  from game_players gp
  join games g on g.id = gp.game_id
  join matches m on m.id = g.plan_id
  left join start_points sp on sp.id = gp.start_point_id
  where gp.player_id = p_player and g.status in ('lobby', 'running')
  order by gp.joined_at desc limit 1;
$$;

-- active_games vrací i run_mode (admin přehled – ikonka módu).
drop function if exists active_games();
create or replace function active_games()
returns table(game_id uuid, plan_id uuid, plan_name text, status text, capacity int, joined bigint, sim boolean, run_mode boolean)
language sql as $$
  select g.id, g.plan_id, m.name, g.status, g.capacity,
         (select count(*) from game_players gp where gp.game_id = g.id), g.sim, g.run_mode
  from games g join matches m on m.id = g.plan_id
  where g.status in ('lobby', 'running')
  order by g.created_at desc;
$$;

commit;


-- ===== FILE: 27-run-speeds-3x.sql =====

-- AchtungDieKM — Run hra: zrychlit výchozí rychlosti 3× (z testu byl pohyb moc pomalý).
-- Spusť přes tools/db/migrate PO 26-run-mode.sql.

begin;

-- Nové výchozí hodnoty pro nově zakládané plány.
alter table matches alter column walk_speed_mps   set default 3.6;
alter table matches alter column run_speed_mps    set default 7.5;
alter table matches alter column sprint_speed_mps set default 12.0;

-- Existující plány: posuň jen ty, co mají ještě původní defaulty (ruční úpravy adminem nech být).
update matches set walk_speed_mps   = 3.6  where walk_speed_mps   = 1.2;
update matches set run_speed_mps    = 7.5  where run_speed_mps    = 2.5;
update matches set sprint_speed_mps = 12.0 where sprint_speed_mps = 4.0;

commit;


-- ===== FILE: 28-game-settings.sql =====

-- AchtungDieKM — nastavení (limity/rychlosti) jako SNAPSHOT na konkrétní hru (ne živě z plánu).
-- Při založení hry se zkopírují aktuální hodnoty plánu → jedna mapa může jet jednou pomalu, jednou rychle.
-- Spusť přes tools/db/migrate PO 27-run-speeds-3x.sql.

begin;

-- Snapshot herních parametrů na hru (NULL u starých her → current_game spadne zpět na plán).
alter table games add column if not exists idle_timeout_s    int;
alter table games add column if not exists outside_timeout_s int;
alter table games add column if not exists snap_tolerance_m  int;
alter table games add column if not exists walk_speed_mps    numeric;
alter table games add column if not exists run_speed_mps     numeric;
alter table games add column if not exists sprint_speed_mps  numeric;
alter table games add column if not exists sprint_range_m    int;

-- create_game zkopíruje aktuální nastavení plánu do hry (snapshot).
drop function if exists create_game(uuid, int, boolean, boolean);
create or replace function create_game(p_plan uuid, p_capacity int, p_sim boolean default false, p_run boolean default false)
returns uuid
language plpgsql as $$
declare v_starts int; v_cap int; v_id uuid; m matches%rowtype;
begin
  select * into m from matches where id = p_plan;
  if not found then raise exception 'Plán neexistuje.'; end if;
  select count(*) into v_starts from start_points where match_id = p_plan;
  if v_starts = 0 then raise exception 'Plán nemá žádné starty.'; end if;
  v_cap := least(greatest(p_capacity, 1), v_starts);
  insert into games(plan_id, capacity, sim, run_mode,
                    idle_timeout_s, outside_timeout_s, snap_tolerance_m,
                    walk_speed_mps, run_speed_mps, sprint_speed_mps, sprint_range_m)
    values (p_plan, v_cap, coalesce(p_sim, false), coalesce(p_run, false),
            m.idle_timeout_s, m.outside_timeout_s, m.snap_tolerance_m,
            m.walk_speed_mps, m.run_speed_mps, m.sprint_speed_mps, m.sprint_range_m)
    returning id into v_id;
  return v_id;
end $$;

-- current_game vrací snapshot z hry (coalesce na plán kvůli starým hrám bez snapshotu).
drop function if exists current_game(uuid);
create or replace function current_game(p_player uuid)
returns table(game_id uuid, plan_id uuid, plan_name text, snap_tolerance_m int, status text,
              started_at timestamptz, start_lng double precision, start_lat double precision,
              start_label text, sim boolean, alive boolean, run_mode boolean,
              idle_timeout_s int, outside_timeout_s int,
              walk_speed_mps numeric, run_speed_mps numeric, sprint_speed_mps numeric, sprint_range_m int)
language sql as $$
  select g.id, g.plan_id, m.name,
         coalesce(g.snap_tolerance_m, m.snap_tolerance_m), g.status, g.started_at,
         ST_X(sp.geom), ST_Y(sp.geom), gp.start_label, g.sim, gp.alive, g.run_mode,
         coalesce(g.idle_timeout_s, m.idle_timeout_s),
         coalesce(g.outside_timeout_s, m.outside_timeout_s),
         coalesce(g.walk_speed_mps, m.walk_speed_mps),
         coalesce(g.run_speed_mps, m.run_speed_mps),
         coalesce(g.sprint_speed_mps, m.sprint_speed_mps),
         coalesce(g.sprint_range_m, m.sprint_range_m)
  from game_players gp
  join games g on g.id = gp.game_id
  join matches m on m.id = g.plan_id
  left join start_points sp on sp.id = gp.start_point_id
  where gp.player_id = p_player and g.status in ('lobby', 'running')
  order by gp.joined_at desc limit 1;
$$;

commit;
