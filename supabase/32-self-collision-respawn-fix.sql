-- Oprava falešné vlastní kolize po respawnu.
-- Původní výpočet odřízl od hlavy jen 3 m, tedy stejně jako kolizní poloměr.
-- Navazující úsek vlastního těla proto mohl být vyhodnocen jako okamžitý náraz.

begin;

create or replace function public.snake_tick(p_game uuid, p_player uuid, p_lng double precision, p_lat double precision)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  g games%rowtype; s snake_states%rowtype; raw geometry; snapped geometry; total numeric; advance numeric;
  body_start numeric; head_frac numeric; hit uuid; berry uuid; now_ts timestamptz:=clock_timestamp(); reason text;
  collision_m numeric; self_skip_m numeric; body_length_m numeric;
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
    update snake_states set route=null,body=null,head_pos=null,player_pos=snapped,updated_at=now_ts
      where game_id=p_game and player_id=p_player;
    return jsonb_build_object('status','respawn','respawn_started_at',s.respawn_started_at);
  end if;

  if s.route is null then
    update snake_states set route=ST_MakeLine(snapped,snapped),body=null,player_pos=snapped,head_pos=snapped,last_tick_at=now_ts,updated_at=now_ts
      where game_id=p_game and player_id=p_player;
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

  collision_m:=coalesce(g.collision_radius_m,3);
  self_skip_m:=greatest(8,collision_m*2+1);

  if total-s.head_distance_m > coalesce(g.max_lead_m,100) then reason:='too_far'; end if;
  if reason is null and total>s.current_length_m and total-s.head_distance_m < 0.5 and ST_Distance(s.head_pos::geography,snapped::geography)<collision_m then reason:='caught'; end if;
  if reason is null and s.head_distance_m>self_skip_m then
    select ss.player_id into hit from snake_states ss where ss.game_id=p_game and ss.active and ss.player_id<>p_player and ss.body is not null
      and ST_DWithin(ss.body::geography,s.head_pos::geography,collision_m)
      limit 1;
    if hit is not null then
      reason:='collision';
    elsif s.body is not null then
      body_length_m:=ST_Length(s.body::geography);
      if body_length_m>self_skip_m+collision_m and
        ST_DWithin(
          ST_LineSubstring(s.body,0,greatest(0,(body_length_m-self_skip_m)/body_length_m))::geography,
          s.head_pos::geography,collision_m
        )
      then hit:=p_player; reason:='self_collision'; end if;
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

commit;
