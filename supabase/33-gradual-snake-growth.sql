-- Jahůdka zvyšuje cílovou délku. Skutečné tělo dorůstá pohybem hlavy,
-- takže ocas během růstu stojí a nedojde ke skokovému prodloužení dozadu.

begin;

alter table public.snake_states add column if not exists target_length_m numeric;
alter table public.snake_states add column if not exists tail_distance_m numeric;
update public.snake_states set target_length_m=current_length_m where target_length_m is null;
update public.snake_states set tail_distance_m=greatest(0,head_distance_m-current_length_m) where tail_distance_m is null;

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
  old_head_distance_m numeric; head_advance_m numeric; target_length numeric; tail_distance numeric;
  segment geometry; snap_ok boolean:=true;
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
  if not s.active then
    update snake_states set route=null,body=null,head_pos=null,player_pos=raw,updated_at=now_ts
      where game_id=p_game and player_id=p_player;
    return jsonb_build_object('status','respawn','respawn_started_at',s.respawn_started_at);
  end if;

  -- Do trasy se nikdy nesmí propsat syrová GPS poloha mimo povolenou síť.
  -- Při ztrátě snapu ponecháme hráče na posledním platném bodě; hlava hada
  -- může dál postupovat po již připravené trase.
  if snapped is null then
    if s.route is null or s.player_pos is null then
      return jsonb_build_object('status','off_network','snap_rejected',true);
    end if;
    snapped:=s.player_pos;
    snap_ok:=false;
  end if;

  if s.route is null then
    update snake_states set route=ST_MakeLine(snapped,snapped),body=null,player_pos=snapped,head_pos=snapped,
      target_length_m=coalesce(target_length_m,current_length_m),tail_distance_m=0,last_tick_at=now_ts,updated_at=now_ts
      where game_id=p_game and player_id=p_player;
    return jsonb_build_object('status','live','lead_m',0,'length_m',s.current_length_m);
  elsif s.player_pos is null or ST_Distance(s.player_pos::geography,snapped::geography)>=1 then
    segment:=ST_MakeLine(s.player_pos,snapped);

    -- Samotný snap obou konců nestačí: přímka mezi nimi by mohla přeskočit
    -- přes blok domů nebo na paralelní ulici. Přijmeme jen krátký krok, který
    -- celý leží v koridoru povolených hran uliční sítě.
    if ST_Length(segment::geography)>35 then
      snap_ok:=false;
    else
      select coalesce(
        ST_CoveredBy(segment,ST_Buffer(ST_Collect(e.geom)::geography,8)::geometry),
        false
      ) into snap_ok
      from street_edges e
      where e.match_id=g.plan_id and e.enabled
        and ST_DWithin(e.geom::geography,segment::geography,15);
    end if;

    if snap_ok then
      s.route:=ST_AddPoint(s.route,snapped);
    else
      snapped:=s.player_pos;
    end if;
  end if;

  total:=ST_Length(s.route::geography);
  old_head_distance_m:=s.head_distance_m;
  advance:=coalesce(g.snake_speed_mps,0.833333)*greatest(0,extract(epoch from now_ts-s.last_tick_at));
  s.head_distance_m:=least(total,s.head_distance_m+advance);
  head_advance_m:=greatest(0,s.head_distance_m-old_head_distance_m);
  target_length:=greatest(s.current_length_m,coalesce(s.target_length_m,s.current_length_m));
  tail_distance:=coalesce(s.tail_distance_m,greatest(0,old_head_distance_m-s.current_length_m));

  -- O stejnou vzdálenost, o jakou postoupí hlava, naroste během čekajícího
  -- růstu délka těla. body_start proto zůstává stejný a ocas stojí.
  if s.current_length_m < target_length then
    s.current_length_m:=least(target_length,s.current_length_m+head_advance_m);
    s.max_length_m:=greatest(s.max_length_m,s.current_length_m);
    -- Ocas se během růstu vůbec neposune. Délka přibývá pouze vpředu.
  else
    tail_distance:=greatest(tail_distance,s.head_distance_m-target_length);
  end if;

  head_frac:=case when total>0 then s.head_distance_m/total else 0 end;
  body_start:=case when total>0 then least(head_frac,greatest(0,tail_distance)/total) else 0 end;
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
        ST_DWithin(ST_LineSubstring(s.body,0,greatest(0,(body_length_m-self_skip_m)/body_length_m))::geography,s.head_pos::geography,collision_m)
      then hit:=p_player; reason:='self_collision'; end if;
    end if;
  end if;

  if reason is not null then
    update snake_states set active=false,route=null,body=null,head_pos=null,player_pos=snapped,head_distance_m=0,
      current_length_m=coalesce(g.snake_initial_length_m,10),target_length_m=coalesce(g.snake_initial_length_m,10),
      tail_distance_m=0,
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
    'length_m',s.current_length_m,'target_length_m',target_length,'ate',berry is not null,
    'snap_rejected',not snap_ok);
end $$;

create or replace function public.snake_respawn(p_game uuid,p_player uuid,p_point uuid,p_lng double precision,p_lat double precision)
returns jsonb language plpgsql security definer set search_path=public as $$
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
    current_length_m=coalesce(g.snake_initial_length_m,10),target_length_m=coalesce(g.snake_initial_length_m,10),
    tail_distance_m=0,
    respawn_point_id=null,respawn_started_at=null,last_tick_at=now_ts,updated_at=now_ts
    where game_id=p_game and player_id=p_player;
  return jsonb_build_object('status','live');
end $$;

commit;
