-- Konfigurovatelná bezpečná délka vlastního hada za hlavou a procento
-- jahůdek aktivních bezprostředně po startu hry.

begin;

alter table public.matches add column if not exists self_collision_grace_m numeric not null default 10;
alter table public.games add column if not exists self_collision_grace_m numeric;
alter table public.matches add column if not exists strawberry_initial_percent int not null default 33;
alter table public.games add column if not exists strawberry_initial_percent int;

update public.games set self_collision_grace_m=10 where self_collision_grace_m is null;
update public.games set strawberry_initial_percent=33 where strawberry_initial_percent is null;
alter table public.games alter column self_collision_grace_m set default 10;
alter table public.games alter column self_collision_grace_m set not null;
alter table public.games alter column strawberry_initial_percent set default 33;
alter table public.games alter column strawberry_initial_percent set not null;

alter table public.matches drop constraint if exists matches_strawberry_initial_percent_check;
alter table public.matches add constraint matches_strawberry_initial_percent_check check(strawberry_initial_percent between 0 and 100);
alter table public.games drop constraint if exists games_strawberry_initial_percent_check;
alter table public.games add constraint games_strawberry_initial_percent_check check(strawberry_initial_percent between 0 and 100);
alter table public.matches drop constraint if exists matches_self_collision_grace_m_check;
alter table public.matches add constraint matches_self_collision_grace_m_check check(self_collision_grace_m>=0);
alter table public.games drop constraint if exists games_self_collision_grace_m_check;
alter table public.games add constraint games_self_collision_grace_m_check check(self_collision_grace_m>=0);

create or replace function public.create_game(p_plan uuid,p_capacity int,p_sim boolean default false,p_run boolean default false,p_name text default null)
returns uuid language plpgsql as $$
declare v_id uuid; m matches%rowtype; v_name text;
begin
  select * into m from matches where id=p_plan;
  if not found then raise exception 'Plán neexistuje.'; end if;
  if not exists(select 1 from respawn_points where match_id=p_plan) then raise exception 'Plán nemá respawn bod.'; end if;
  v_name:=coalesce(nullif(btrim(p_name),''),coalesce(m.name,'Hra') || ' ' || to_char(now(),'DD.MM. HH24:MI'));
  insert into games(name,plan_id,capacity,sim,run_mode,idle_timeout_s,outside_timeout_s,snap_tolerance_m,
    snake_initial_length_m,strawberry_growth_m,game_duration_s,snake_speed_mps,
    strawberry_spawn_min_s,strawberry_spawn_max_s,strawberry_active_percent,strawberry_initial_percent,
    max_lead_m,respawn_countdown_s,collision_radius_m,strawberry_radius_m,self_collision_grace_m)
  values(v_name,p_plan,greatest(1,p_capacity),coalesce(p_sim,false),coalesce(p_run,false),m.idle_timeout_s,m.outside_timeout_s,m.snap_tolerance_m,
    m.snake_initial_length_m,m.strawberry_growth_m,m.game_duration_s,m.snake_speed_mps,
    m.strawberry_spawn_min_s,m.strawberry_spawn_max_s,m.strawberry_active_percent,m.strawberry_initial_percent,
    m.max_lead_m,m.respawn_countdown_s,m.collision_radius_m,m.strawberry_radius_m,m.self_collision_grace_m)
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.run_game(p_game uuid)
returns void language plpgsql as $$
declare g games%rowtype; n int; initial_count int; maximum_count int;
begin
  perform assert_admin();
  select * into g from games where id=p_game for update;
  if g.status <> 'lobby' then return; end if;
  if not exists(select 1 from game_players where game_id=p_game) then raise exception 'Ke hře není připojený žádný hráč.'; end if;
  update games set status='running',started_at=now(),finished_at=null where id=p_game;
  insert into snake_states(game_id,player_id,current_length_m,max_length_m,target_length_m,tail_distance_m)
    select p_game,gp.player_id,coalesce(g.snake_initial_length_m,10),coalesce(g.snake_initial_length_m,10),coalesce(g.snake_initial_length_m,10),0
    from game_players gp where gp.game_id=p_game on conflict do nothing;
  insert into game_strawberries(game_id,point_id,active,next_spawn_at)
    select p_game,sp.id,false,now()+make_interval(secs=>floor(random()*(coalesce(g.strawberry_spawn_max_s,60)-coalesce(g.strawberry_spawn_min_s,10)+1)+coalesce(g.strawberry_spawn_min_s,10))::int)
    from strawberry_points sp where sp.match_id=g.plan_id on conflict do nothing;
  select count(*) into n from game_strawberries where game_id=p_game;
  initial_count:=ceil(n*coalesce(g.strawberry_initial_percent,33)/100.0);
  maximum_count:=ceil(n*coalesce(g.strawberry_active_percent,100)/100.0);
  initial_count:=least(initial_count,maximum_count);
  update game_strawberries set active=true,next_spawn_at=null
  where (game_id,point_id) in (
    select game_id,point_id from game_strawberries where game_id=p_game order by random() limit initial_count
  );
end $$;

-- Duplikace plánu musí přenést i obě nová nastavení.
create or replace function public.duplicate_match_plan(p_match uuid,p_name text)
returns uuid language plpgsql security definer set search_path=public as $$
declare src matches%rowtype; new_id uuid;
begin
  perform assert_admin();
  select * into src from matches where id=p_match;
  if not found then raise exception 'Plán neexistuje.'; end if;
  insert into matches(
    name,area,status,is_active,ready,footpaths_enabled,started_at,
    idle_timeout_s,outside_timeout_s,snap_tolerance_m,
    walk_speed_mps,run_speed_mps,sprint_speed_mps,sprint_range_m,
    snake_initial_length_m,strawberry_growth_m,game_duration_s,snake_speed_mps,
    strawberry_spawn_min_s,strawberry_spawn_max_s,strawberry_active_percent,strawberry_initial_percent,
    max_lead_m,respawn_countdown_s,collision_radius_m,strawberry_radius_m,self_collision_grace_m
  ) values(
    coalesce(nullif(btrim(p_name),''),coalesce(src.name,'Plán') || ' – kopie'),src.area,'lobby',false,false,src.footpaths_enabled,null,
    src.idle_timeout_s,src.outside_timeout_s,src.snap_tolerance_m,
    src.walk_speed_mps,src.run_speed_mps,src.sprint_speed_mps,src.sprint_range_m,
    src.snake_initial_length_m,src.strawberry_growth_m,src.game_duration_s,src.snake_speed_mps,
    src.strawberry_spawn_min_s,src.strawberry_spawn_max_s,src.strawberry_active_percent,src.strawberry_initial_percent,
    src.max_lead_m,src.respawn_countdown_s,src.collision_radius_m,src.strawberry_radius_m,src.self_collision_grace_m
  ) returning id into new_id;
  insert into street_edges(match_id,source_node,target_node,name,geom,enabled,is_foot)
    select new_id,source_node,target_node,name,geom,enabled,is_foot from street_edges where match_id=p_match;
  insert into respawn_points(match_id,label,geom) select new_id,label,geom from respawn_points where match_id=p_match;
  insert into strawberry_points(match_id,geom) select new_id,geom from strawberry_points where match_id=p_match;
  return new_id;
end $$;

create or replace function public.snake_tick(p_game uuid,p_player uuid,p_lng double precision,p_lat double precision)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  g games%rowtype; s snake_states%rowtype; raw geometry; snapped geometry; total numeric; advance numeric;
  body_start numeric; head_frac numeric; hit uuid; berry uuid; now_ts timestamptz:=clock_timestamp(); reason text;
  collision_m numeric; self_skip_m numeric; body_length_m numeric;
  old_head_distance_m numeric; head_advance_m numeric; target_length numeric; tail_distance numeric;
  segment geometry; snap_ok boolean:=true;
begin
  perform assert_player(p_player);
  select * into g from games where id=p_game for update;
  if not found or g.status<>'running' then return jsonb_build_object('status','ended'); end if;
  if now_ts>=g.started_at+make_interval(secs=>10+coalesce(g.game_duration_s,900)) then
    update games set status='finished',finished_at=now_ts where id=p_game;
    return jsonb_build_object('status','ended');
  end if;
  select * into s from snake_states where game_id=p_game and player_id=p_player for update;
  if not found then raise exception 'Hráč není součástí hry.'; end if;
  raw:=ST_SetSRID(ST_MakePoint(p_lng,p_lat),4326);
  select ST_ClosestPoint(e.geom,raw) into snapped from street_edges e
    where e.match_id=g.plan_id and e.enabled and ST_DWithin(e.geom::geography,raw::geography,coalesce(g.snap_tolerance_m,30))
    order by e.geom<->raw limit 1;

  if not s.active then
    update snake_states set route=null,body=null,head_pos=null,player_pos=raw,updated_at=now_ts where game_id=p_game and player_id=p_player;
    return jsonb_build_object('status','respawn','respawn_started_at',s.respawn_started_at);
  end if;
  if snapped is null then
    if s.route is null or s.player_pos is null then return jsonb_build_object('status','off_network','snap_rejected',true); end if;
    snapped:=s.player_pos; snap_ok:=false;
  end if;
  if s.route is null then
    update snake_states set route=ST_MakeLine(snapped,snapped),body=null,player_pos=snapped,head_pos=snapped,
      target_length_m=coalesce(target_length_m,current_length_m),tail_distance_m=0,last_tick_at=now_ts,updated_at=now_ts
      where game_id=p_game and player_id=p_player;
    return jsonb_build_object('status','live','lead_m',0,'length_m',s.current_length_m);
  elsif s.player_pos is null or ST_Distance(s.player_pos::geography,snapped::geography)>=1 then
    segment:=ST_MakeLine(s.player_pos,snapped);
    if ST_Length(segment::geography)>35 then snap_ok:=false;
    else
      select coalesce(ST_CoveredBy(segment,ST_Buffer(ST_Collect(e.geom)::geography,8)::geometry),false) into snap_ok
      from street_edges e where e.match_id=g.plan_id and e.enabled and ST_DWithin(e.geom::geography,segment::geography,15);
    end if;
    if snap_ok then s.route:=ST_AddPoint(s.route,snapped); else snapped:=s.player_pos; end if;
  end if;

  total:=ST_Length(s.route::geography);
  old_head_distance_m:=s.head_distance_m;
  advance:=coalesce(g.snake_speed_mps,0.833333)*greatest(0,extract(epoch from now_ts-s.last_tick_at));
  s.head_distance_m:=least(total,s.head_distance_m+advance);
  head_advance_m:=greatest(0,s.head_distance_m-old_head_distance_m);
  target_length:=greatest(s.current_length_m,coalesce(s.target_length_m,s.current_length_m));
  tail_distance:=coalesce(s.tail_distance_m,greatest(0,old_head_distance_m-s.current_length_m));
  if s.current_length_m<target_length then
    s.current_length_m:=least(target_length,s.current_length_m+head_advance_m);
    s.max_length_m:=greatest(s.max_length_m,s.current_length_m);
  else tail_distance:=greatest(tail_distance,s.head_distance_m-target_length); end if;
  head_frac:=case when total>0 then s.head_distance_m/total else 0 end;
  body_start:=case when total>0 then least(head_frac,greatest(0,tail_distance)/total) else 0 end;
  s.head_pos:=ST_LineInterpolatePoint(s.route,least(1,head_frac));
  s.body:=case when total>0 and head_frac>body_start then ST_LineSubstring(s.route,body_start,head_frac) else null end;

  collision_m:=coalesce(g.collision_radius_m,3);
  self_skip_m:=greatest(0,coalesce(g.self_collision_grace_m,10));
  if total-s.head_distance_m>coalesce(g.max_lead_m,100) then reason:='too_far'; end if;
  if reason is null and total>s.current_length_m and total-s.head_distance_m<0.5 and ST_Distance(s.head_pos::geography,snapped::geography)<collision_m then reason:='caught'; end if;

  -- Soupeřovo tělo je kolizní celé. U vlastního těla ignorujeme nastavenou
  -- bezpečnou délku bezprostředně za hlavou.
  if reason is null then
    select ss.player_id into hit from snake_states ss
    where ss.game_id=p_game and ss.active and ss.player_id<>p_player and ss.body is not null
      and ST_DWithin(ss.body::geography,s.head_pos::geography,collision_m) limit 1;
    if hit is not null then reason:='collision'; end if;
  end if;
  if reason is null and s.head_distance_m>self_skip_m and s.body is not null then
    body_length_m:=ST_Length(s.body::geography);
    if body_length_m>self_skip_m+collision_m and
      ST_DWithin(ST_LineSubstring(s.body,0,greatest(0,(body_length_m-self_skip_m)/body_length_m))::geography,s.head_pos::geography,collision_m)
    then hit:=p_player; reason:='self_collision'; end if;
  end if;

  if reason is not null then
    update snake_states set active=false,route=null,body=null,head_pos=null,player_pos=snapped,head_distance_m=0,
      current_length_m=coalesce(g.snake_initial_length_m,10),target_length_m=coalesce(g.snake_initial_length_m,10),tail_distance_m=0,
      respawn_point_id=null,respawn_started_at=null,last_tick_at=now_ts,updated_at=now_ts
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
    target_length:=target_length+coalesce(g.strawberry_growth_m,10);
    s.strawberries_eaten:=s.strawberries_eaten+1;
  end if;
  update game_strawberries set active=true,next_spawn_at=null where game_id=p_game and not active and next_spawn_at<=now_ts;
  update snake_states set route=s.route,body=s.body,player_pos=snapped,head_pos=s.head_pos,head_distance_m=s.head_distance_m,
    current_length_m=s.current_length_m,target_length_m=target_length,tail_distance_m=tail_distance,max_length_m=s.max_length_m,
    strawberries_eaten=s.strawberries_eaten,last_tick_at=now_ts,updated_at=now_ts
    where game_id=p_game and player_id=p_player;
  return jsonb_build_object('status','live','lead_m',greatest(0,total-s.head_distance_m),
    'length_m',s.current_length_m,'target_length_m',target_length,'ate',berry is not null,'snap_rejected',not snap_ok);
end $$;

commit;
