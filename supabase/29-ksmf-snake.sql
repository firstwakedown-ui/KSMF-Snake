-- KSMF Snake — nový herní model: konstantní had, jahůdky, respawn a časovaný zápas.
-- Spusť přes tools/db/migrate PO 28-game-settings.sql.

begin;

-- Konfigurace plánu. Při vytvoření hry se zkopíruje jako snapshot do games.
alter table matches add column if not exists snake_initial_length_m numeric not null default 10;
alter table matches add column if not exists strawberry_growth_m numeric not null default 10;
alter table matches add column if not exists game_duration_s int not null default 900;
alter table matches add column if not exists snake_speed_mps numeric not null default 0.833333;
alter table matches add column if not exists strawberry_spawn_min_s int not null default 10;
alter table matches add column if not exists strawberry_spawn_max_s int not null default 60;
alter table matches add column if not exists max_lead_m numeric not null default 100;
alter table matches add column if not exists respawn_countdown_s int not null default 3;
alter table matches add column if not exists collision_radius_m numeric not null default 3;
alter table matches add column if not exists strawberry_radius_m numeric not null default 5;

alter table games add column if not exists snake_initial_length_m numeric;
alter table games add column if not exists strawberry_growth_m numeric;
alter table games add column if not exists game_duration_s int;
alter table games add column if not exists snake_speed_mps numeric;
alter table games add column if not exists strawberry_spawn_min_s int;
alter table games add column if not exists strawberry_spawn_max_s int;
alter table games add column if not exists max_lead_m numeric;
alter table games add column if not exists respawn_countdown_s int;
alter table games add column if not exists collision_radius_m numeric;
alter table games add column if not exists strawberry_radius_m numeric;

-- Dva samostatné druhy bodů mapy.
create table if not exists respawn_points (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references matches(id) on delete cascade,
  label text not null,
  geom geometry(Point, 4326) not null,
  created_at timestamptz not null default now()
);
create index if not exists respawn_points_geom_idx on respawn_points using gist (geom);

create table if not exists strawberry_points (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references matches(id) on delete cascade,
  geom geometry(Point, 4326) not null,
  created_at timestamptz not null default now()
);
create index if not exists strawberry_points_geom_idx on strawberry_points using gist (geom);

-- Staré starty použijeme jako výchozí respawn body, ale typy zůstávají oddělené.
insert into respawn_points(match_id, label, geom)
select sp.match_id, coalesce(sp.label, 'R'), sp.geom from start_points sp
where not exists (select 1 from respawn_points rp where rp.match_id = sp.match_id);

create table if not exists game_strawberries (
  game_id uuid not null references games(id) on delete cascade,
  point_id uuid not null references strawberry_points(id) on delete cascade,
  active boolean not null default false,
  next_spawn_at timestamptz,
  eaten_at timestamptz,
  primary key (game_id, point_id)
);

create table if not exists snake_states (
  game_id uuid not null references games(id) on delete cascade,
  player_id uuid not null references players(id) on delete cascade,
  active boolean not null default true,
  route geometry(LineString, 4326),
  body geometry(LineString, 4326),
  player_pos geometry(Point, 4326),
  head_pos geometry(Point, 4326),
  head_distance_m numeric not null default 0,
  current_length_m numeric not null default 10,
  max_length_m numeric not null default 10,
  strawberries_eaten int not null default 0,
  opponent_explosions int not null default 0,
  respawn_point_id uuid references respawn_points(id) on delete set null,
  respawn_started_at timestamptz,
  outside_since timestamptz,
  last_tick_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (game_id, player_id)
);
create index if not exists snake_states_body_idx on snake_states using gist (body);

alter table respawn_points enable row level security;
alter table strawberry_points enable row level security;
alter table game_strawberries enable row level security;
alter table snake_states enable row level security;
drop policy if exists respawn_points_all on respawn_points;
drop policy if exists strawberry_points_all on strawberry_points;
drop policy if exists game_strawberries_all on game_strawberries;
drop policy if exists snake_states_all on snake_states;
create policy respawn_points_all on respawn_points for select using (true);
create policy strawberry_points_all on strawberry_points for select using (true);
create policy game_strawberries_all on game_strawberries for select using (true);
create policy snake_states_all on snake_states for select using (true);

create or replace function add_respawn_point(p_match uuid, p_label text, p_lng double precision, p_lat double precision)
returns uuid language plpgsql as $$
declare v_id uuid;
begin
  insert into respawn_points(match_id,label,geom) values(p_match,p_label,ST_SetSRID(ST_MakePoint(p_lng,p_lat),4326)) returning id into v_id;
  return v_id;
end $$;

create or replace function move_respawn_point(p_id uuid, p_lng double precision, p_lat double precision)
returns void language sql as $$ update respawn_points set geom=ST_SetSRID(ST_MakePoint(p_lng,p_lat),4326) where id=p_id $$;

create or replace function add_strawberry_point(p_match uuid, p_lng double precision, p_lat double precision)
returns uuid language plpgsql as $$
declare v_id uuid;
begin
  insert into strawberry_points(match_id,geom) values(p_match,ST_SetSRID(ST_MakePoint(p_lng,p_lat),4326)) returning id into v_id;
  return v_id;
end $$;

create or replace function remove_respawn_point(p_id uuid)
returns void language sql as $$ delete from respawn_points where id=p_id $$;
create or replace function clear_respawn_points(p_match uuid)
returns void language sql as $$ delete from respawn_points where match_id=p_match $$;
create or replace function remove_strawberry_point(p_id uuid)
returns void language sql as $$ delete from strawberry_points where id=p_id $$;

-- Nová hra už nepotřebuje předem přidělené starty; kapacitu určuje admin.
drop function if exists create_game(uuid, int, boolean, boolean);
create or replace function create_game(p_plan uuid, p_capacity int, p_sim boolean default false, p_run boolean default false)
returns uuid language plpgsql as $$
declare v_id uuid; m matches%rowtype;
begin
  select * into m from matches where id=p_plan;
  if not found then raise exception 'Plán neexistuje.'; end if;
  if not exists(select 1 from respawn_points where match_id=p_plan) then raise exception 'Plán nemá respawn bod.'; end if;
  insert into games(plan_id,capacity,sim,run_mode,idle_timeout_s,outside_timeout_s,snap_tolerance_m,
    snake_initial_length_m,strawberry_growth_m,game_duration_s,snake_speed_mps,
    strawberry_spawn_min_s,strawberry_spawn_max_s,max_lead_m,respawn_countdown_s,collision_radius_m,strawberry_radius_m)
  values(p_plan,greatest(1,p_capacity),coalesce(p_sim,false),coalesce(p_run,false),m.idle_timeout_s,m.outside_timeout_s,m.snap_tolerance_m,
    m.snake_initial_length_m,m.strawberry_growth_m,m.game_duration_s,m.snake_speed_mps,
    m.strawberry_spawn_min_s,m.strawberry_spawn_max_s,m.max_lead_m,m.respawn_countdown_s,m.collision_radius_m,m.strawberry_radius_m)
  returning id into v_id;
  return v_id;
end $$;

-- Start je kdekoliv: parametr p_start zůstává kvůli kompatibilitě klientů, ale ignoruje se.
create or replace function join_game(p_game uuid, p_player uuid, p_start uuid default null)
returns void language plpgsql as $$
declare v_status text; v_cap int; v_cur int;
begin
  select status,capacity into v_status,v_cap from games where id=p_game;
  if v_status is null then raise exception 'Hra neexistuje.'; end if;
  if v_status <> 'lobby' then raise exception 'Tahle hra už není otevřená.'; end if;
  if exists(select 1 from game_players where game_id=p_game and player_id=p_player) then return; end if;
  select count(*) into v_cur from game_players where game_id=p_game;
  if v_cur >= v_cap then raise exception 'Kapacita hry je plná.'; end if;
  insert into game_players(game_id,player_id,start_point_id,start_label) values(p_game,p_player,null,null);
end $$;

create or replace function run_game(p_game uuid)
returns void language plpgsql as $$
declare g games%rowtype; n int; initial_count int;
begin
  perform assert_admin();
  select * into g from games where id=p_game for update;
  if g.status <> 'lobby' then return; end if;
  if not exists(select 1 from game_players where game_id=p_game) then raise exception 'Ke hře není připojený žádný hráč.'; end if;
  update games set status='running',started_at=now(),finished_at=null where id=p_game;
  insert into snake_states(game_id,player_id,current_length_m,max_length_m)
    select p_game,gp.player_id,coalesce(g.snake_initial_length_m,10),coalesce(g.snake_initial_length_m,10)
    from game_players gp where gp.game_id=p_game on conflict do nothing;
  insert into game_strawberries(game_id,point_id,active,next_spawn_at)
    select p_game,sp.id,false,now() + make_interval(secs => floor(random()*(coalesce(g.strawberry_spawn_max_s,60)-coalesce(g.strawberry_spawn_min_s,10)+1)+coalesce(g.strawberry_spawn_min_s,10))::int)
    from strawberry_points sp where sp.match_id=g.plan_id on conflict do nothing;
  select count(*) into n from game_strawberries where game_id=p_game;
  initial_count := ceil(n/3.0);
  update game_strawberries set active=true,next_spawn_at=null
  where (game_id,point_id) in (select game_id,point_id from game_strawberries where game_id=p_game order by random() limit initial_count);
end $$;

-- Jeden autoritativní krok. Klient dodává GPS; server snapuje, posouvá hlavu konstantní rychlostí,
-- zkracuje ocas, sbírá jahůdky a rozhoduje o kolizi/výbuchu.
create or replace function snake_tick(p_game uuid, p_player uuid, p_lng double precision, p_lat double precision)
returns jsonb language plpgsql security definer as $$
declare
  g games%rowtype; s snake_states%rowtype; raw geometry; snapped geometry; total numeric; advance numeric;
  body_start numeric; head_frac numeric; hit uuid; berry uuid; now_ts timestamptz:=clock_timestamp(); reason text;
begin
  perform assert_player(p_player);
  select * into g from games where id=p_game for update;
  if not found or g.status <> 'running' then return jsonb_build_object('status','ended'); end if;
  if now_ts >= g.started_at + make_interval(secs=>10 + coalesce(g.game_duration_s,900)) then
    update games set status='finished',finished_at=now_ts where id=p_game;
    return jsonb_build_object('status','ended');
  end if;
  select * into s from snake_states where game_id=p_game and player_id=p_player for update;
  if not found then raise exception 'Hráč není součástí hry.'; end if;
  raw:=ST_SetSRID(ST_MakePoint(p_lng,p_lat),4326);
  select ST_ClosestPoint(e.geom,raw) into snapped from street_edges e
    where e.match_id=g.plan_id and e.enabled and ST_DWithin(e.geom::geography,raw::geography,coalesce(g.snap_tolerance_m,30))
    order by e.geom <-> raw limit 1;
  if snapped is null then snapped:=raw; end if;

  if not s.active then
    update snake_states set player_pos=snapped,updated_at=now_ts where game_id=p_game and player_id=p_player;
    return jsonb_build_object('status','respawn','respawn_started_at',s.respawn_started_at);
  end if;

  if s.route is null then
    update snake_states set route=ST_MakeLine(snapped,snapped),player_pos=snapped,head_pos=snapped,last_tick_at=now_ts,updated_at=now_ts where game_id=p_game and player_id=p_player;
    return jsonb_build_object('status','live','lead_m',0,'length_m',s.current_length_m);
  elsif s.player_pos is null or ST_Distance(s.player_pos::geography,snapped::geography)>=1 then
    s.route:=ST_AddPoint(s.route,snapped);
  end if;

  total:=ST_Length(s.route::geography);
  advance:=coalesce(g.snake_speed_mps,0.833333)*greatest(0,extract(epoch from now_ts-s.last_tick_at));
  s.head_distance_m:=least(total,s.head_distance_m+advance);
  head_frac:=case when total>0 then s.head_distance_m/total else 0 end;
  body_start:=case when total>0 then greatest(0,s.head_distance_m-s.current_length_m)/total else 0 end;
  s.head_pos:=ST_LineInterpolatePoint(s.route,least(1,head_frac));
  s.body:=case when total>0 and head_frac>body_start then ST_LineSubstring(s.route,body_start,head_frac) else null end;

  if total-s.head_distance_m > coalesce(g.max_lead_m,100) then reason:='too_far'; end if;
  if reason is null and total>s.current_length_m and total-s.head_distance_m < 0.5 and ST_Distance(s.head_pos::geography,snapped::geography)<coalesce(g.collision_radius_m,3) then reason:='caught'; end if;
  if reason is null and s.head_distance_m>3 then
    select ss.player_id into hit from snake_states ss where ss.game_id=p_game and ss.active and ss.player_id<>p_player and ss.body is not null
      and ST_DWithin(ss.body::geography,s.head_pos::geography,coalesce(g.collision_radius_m,3))
      limit 1;
    if hit is not null then reason:='collision';
    elsif s.body is not null and ST_Length(s.body::geography)>4 and
      ST_DWithin(ST_LineSubstring(s.body,0,greatest(0,(ST_Length(s.body::geography)-3)/ST_Length(s.body::geography)))::geography,s.head_pos::geography,coalesce(g.collision_radius_m,3))
      then hit:=p_player; reason:='self_collision';
    end if;
  end if;

  if reason is not null then
    update snake_states set active=false,route=null,body=null,head_pos=null,player_pos=snapped,head_distance_m=0,
      current_length_m=coalesce(g.snake_initial_length_m,10),respawn_point_id=null,respawn_started_at=null,last_tick_at=now_ts,updated_at=now_ts
      where game_id=p_game and player_id=p_player;
    if hit is not null and hit<>p_player then update snake_states set opponent_explosions=opponent_explosions+1 where game_id=p_game and player_id=hit; end if;
    return jsonb_build_object('status','exploded','reason',reason);
  end if;

  select gs.point_id into berry from game_strawberries gs join strawberry_points sp on sp.id=gs.point_id
    where gs.game_id=p_game and gs.active and ST_DWithin(sp.geom::geography,s.head_pos::geography,coalesce(g.strawberry_radius_m,5))
    order by ST_Distance(sp.geom::geography,s.head_pos::geography) limit 1 for update of gs;
  if berry is not null then
    update game_strawberries set active=false,eaten_at=now_ts,next_spawn_at=now_ts+make_interval(secs=>floor(random()*(coalesce(g.strawberry_spawn_max_s,60)-coalesce(g.strawberry_spawn_min_s,10)+1)+coalesce(g.strawberry_spawn_min_s,10))::int)
      where game_id=p_game and point_id=berry;
    s.current_length_m:=s.current_length_m+coalesce(g.strawberry_growth_m,10);
    s.max_length_m:=greatest(s.max_length_m,s.current_length_m);
    s.strawberries_eaten:=s.strawberries_eaten+1;
  end if;
  update game_strawberries set active=true,next_spawn_at=null where game_id=p_game and not active and next_spawn_at<=now_ts;
  update snake_states set route=s.route,body=s.body,player_pos=snapped,head_pos=s.head_pos,head_distance_m=s.head_distance_m,
    current_length_m=s.current_length_m,max_length_m=s.max_length_m,strawberries_eaten=s.strawberries_eaten,last_tick_at=now_ts,updated_at=now_ts
    where game_id=p_game and player_id=p_player;
  return jsonb_build_object('status','live','lead_m',greatest(0,total-s.head_distance_m),'length_m',s.current_length_m,'ate',berry is not null);
end $$;

create or replace function snake_begin_route(p_game uuid,p_player uuid,p_lng double precision,p_lat double precision)
returns void language plpgsql security definer as $$
declare p geometry:=ST_SetSRID(ST_MakePoint(p_lng,p_lat),4326);
begin
  perform assert_player(p_player);
  update snake_states set route=ST_MakeLine(p,p),player_pos=p,head_pos=p,head_distance_m=0,last_tick_at=clock_timestamp(),updated_at=clock_timestamp()
  where game_id=p_game and player_id=p_player and active;
end $$;

create or replace function snake_respawn(p_game uuid,p_player uuid,p_point uuid,p_lng double precision,p_lat double precision)
returns jsonb language plpgsql security definer as $$
declare s snake_states%rowtype; g games%rowtype; rp geometry; pos geometry:=ST_SetSRID(ST_MakePoint(p_lng,p_lat),4326); now_ts timestamptz:=clock_timestamp();
begin
  perform assert_player(p_player);
  select * into s from snake_states where game_id=p_game and player_id=p_player for update;
  select * into g from games where id=p_game;
  if s.active then return jsonb_build_object('status','live'); end if;
  select geom into rp from respawn_points where id=p_point and match_id=g.plan_id;
  if rp is null then raise exception 'Neplatný respawn bod.'; end if;
  if not ST_DWithin(rp::geography,pos::geography,coalesce(g.strawberry_radius_m,5)) then
    update snake_states set respawn_point_id=p_point,respawn_started_at=null,player_pos=pos,updated_at=now_ts where game_id=p_game and player_id=p_player;
    return jsonb_build_object('status','approaching','distance_m',round(ST_Distance(rp::geography,pos::geography)));
  end if;
  if s.respawn_point_id is distinct from p_point or s.respawn_started_at is null then
    update snake_states set respawn_point_id=p_point,respawn_started_at=now_ts,player_pos=pos,updated_at=now_ts where game_id=p_game and player_id=p_player;
    return jsonb_build_object('status','countdown','seconds',coalesce(g.respawn_countdown_s,3));
  end if;
  if now_ts < s.respawn_started_at+make_interval(secs=>coalesce(g.respawn_countdown_s,3)) then
    return jsonb_build_object('status','countdown','seconds',ceil(extract(epoch from (s.respawn_started_at+make_interval(secs=>coalesce(g.respawn_countdown_s,3))-now_ts))));
  end if;
  update snake_states set active=true,route=ST_MakeLine(rp,rp),body=null,player_pos=rp,head_pos=rp,head_distance_m=0,
    current_length_m=coalesce(g.snake_initial_length_m,10),respawn_point_id=null,respawn_started_at=null,last_tick_at=now_ts,updated_at=now_ts
    where game_id=p_game and player_id=p_player;
  return jsonb_build_object('status','live');
end $$;

create or replace function snake_world(p_game uuid)
returns table(player_id uuid,nickname text,active boolean,body jsonb,head jsonb,current_length_m numeric,max_length_m numeric,strawberries_eaten int,opponent_explosions int)
language sql security definer as $$
  select ss.player_id,p.nickname,ss.active,ST_AsGeoJSON(ss.body)::jsonb,ST_AsGeoJSON(ss.head_pos)::jsonb,
    ss.current_length_m,ss.max_length_m,ss.strawberries_eaten,ss.opponent_explosions
  from snake_states ss join players p on p.id=ss.player_id where ss.game_id=p_game order by p.nickname
$$;

create or replace function active_strawberries(p_game uuid)
returns table(point_id uuid,lng double precision,lat double precision) language sql security definer as $$
  select gs.point_id,ST_X(sp.geom),ST_Y(sp.geom) from game_strawberries gs join strawberry_points sp on sp.id=gs.point_id
  where gs.game_id=p_game and gs.active
$$;

-- Rozšířený stav hry pro hráčský klient (včetně snapshotu pravidel).
drop function if exists current_game(uuid);
create or replace function current_game(p_player uuid)
returns table(game_id uuid,plan_id uuid,plan_name text,snap_tolerance_m int,status text,started_at timestamptz,
  start_lng double precision,start_lat double precision,start_label text,sim boolean,alive boolean,run_mode boolean,
  idle_timeout_s int,outside_timeout_s int,walk_speed_mps numeric,run_speed_mps numeric,sprint_speed_mps numeric,sprint_range_m int,
  game_duration_s int,max_lead_m numeric)
language sql as $$
  select g.id,g.plan_id,m.name,coalesce(g.snap_tolerance_m,m.snap_tolerance_m),g.status,g.started_at,
    null::double precision,null::double precision,null::text,g.sim,coalesce(ss.active,true),g.run_mode,
    coalesce(g.idle_timeout_s,m.idle_timeout_s),coalesce(g.outside_timeout_s,m.outside_timeout_s),
    g.walk_speed_mps,g.run_speed_mps,g.sprint_speed_mps,g.sprint_range_m,
    coalesce(g.game_duration_s,m.game_duration_s),coalesce(g.max_lead_m,m.max_lead_m)
  from game_players gp join games g on g.id=gp.game_id join matches m on m.id=g.plan_id
  left join snake_states ss on ss.game_id=gp.game_id and ss.player_id=gp.player_id
  where gp.player_id=p_player and g.status in ('lobby','running') order by gp.joined_at desc limit 1
$$;

drop function if exists ready_plans();
create or replace function ready_plans()
returns table(id uuid,name text,starts bigint) language sql as $$
  select m.id,m.name,(select count(*) from respawn_points rp where rp.match_id=m.id) from matches m where m.ready order by m.created_at
$$;

drop function if exists game_results(uuid);
create or replace function game_results(p_game uuid)
returns table(player_id uuid,nickname text,place int,alive boolean,trail jsonb,max_length_m numeric,strawberries_eaten int,opponent_explosions int)
language sql as $$
  select gp.player_id,p.nickname,null::int,coalesce(ss.active,false),gp.trail,
    coalesce(ss.max_length_m,0),coalesce(ss.strawberries_eaten,0),coalesce(ss.opponent_explosions,0)
  from game_players gp join players p on p.id=gp.player_id left join snake_states ss on ss.game_id=gp.game_id and ss.player_id=gp.player_id
  where gp.game_id=p_game order by ss.max_length_m desc nulls last,p.nickname
$$;

commit;
