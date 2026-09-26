-- Jednotný serverový konec časovaných her. Každé načtení lobby, hry nebo
-- adminského přehledu nejprve dokončí hry, kterým vypršel čas.

begin;

create or replace function public.expire_games()
returns void
language sql
security definer
set search_path=public
as $$
  update games g
  set status='finished', finished_at=coalesce(g.finished_at,clock_timestamp())
  where g.status='running' and g.started_at is not null
    and clock_timestamp() >= g.started_at + make_interval(secs=>10+coalesce(g.game_duration_s,900));
$$;

drop function if exists public.lobby_games(uuid);
create function public.lobby_games(p_player uuid)
returns table(game_id uuid,game_name text,plan_id uuid,plan_name text,capacity int,joined bigint,mine boolean,my_start text,status text,alive boolean)
language plpgsql as $$
begin
  perform expire_games();
  return query
  select g.id,g.name,g.plan_id,m.name,g.capacity,
    (select count(*) from game_players gp where gp.game_id=g.id),
    exists(select 1 from game_players gp where gp.game_id=g.id and gp.player_id=p_player),
    null::text,g.status,
    (select ss.active from snake_states ss where ss.game_id=g.id and ss.player_id=p_player limit 1)
  from games g join matches m on m.id=g.plan_id
  where g.status in ('lobby','running') order by g.created_at desc;
end $$;

drop function if exists public.current_game(uuid);
create function public.current_game(p_player uuid)
returns table(game_id uuid,game_name text,plan_id uuid,plan_name text,snap_tolerance_m int,status text,started_at timestamptz,
  start_lng double precision,start_lat double precision,start_label text,sim boolean,alive boolean,run_mode boolean,
  idle_timeout_s int,outside_timeout_s int,walk_speed_mps numeric,run_speed_mps numeric,sprint_speed_mps numeric,sprint_range_m int,
  game_duration_s int,max_lead_m numeric)
language plpgsql as $$
begin
  perform expire_games();
  return query
  select g.id,g.name,g.plan_id,m.name,coalesce(g.snap_tolerance_m,m.snap_tolerance_m),g.status,g.started_at,
    null::double precision,null::double precision,null::text,g.sim,coalesce(ss.active,true),g.run_mode,
    coalesce(g.idle_timeout_s,m.idle_timeout_s),coalesce(g.outside_timeout_s,m.outside_timeout_s),
    g.walk_speed_mps,g.run_speed_mps,g.sprint_speed_mps,g.sprint_range_m,
    coalesce(g.game_duration_s,m.game_duration_s),coalesce(g.max_lead_m,m.max_lead_m)
  from game_players gp join games g on g.id=gp.game_id join matches m on m.id=g.plan_id
  left join snake_states ss on ss.game_id=gp.game_id and ss.player_id=gp.player_id
  where gp.player_id=p_player and g.status in ('lobby','running') order by gp.joined_at desc limit 1;
end $$;

drop function if exists public.active_games();
create function public.active_games()
returns table(game_id uuid,game_name text,plan_id uuid,plan_name text,status text,capacity int,joined bigint,sim boolean,run_mode boolean,remaining_s int)
language plpgsql as $$
begin
  perform expire_games();
  return query
  select g.id,g.name,g.plan_id,m.name,g.status,g.capacity,
    (select count(*) from game_players gp where gp.game_id=g.id),g.sim,g.run_mode,
    case when g.status='running' then greatest(0,ceil(extract(epoch from
      (g.started_at+make_interval(secs=>10+coalesce(g.game_duration_s,900))-clock_timestamp())))::int)
      else null::int end
  from games g join matches m on m.id=g.plan_id
  where g.status in ('lobby','running') order by g.created_at desc;
end $$;

drop function if exists public.finished_games();
create function public.finished_games()
returns table(game_id uuid,game_name text,plan_id uuid,plan_name text,players bigint,started_at timestamptz,finished_at timestamptz)
language plpgsql as $$
begin
  perform expire_games();
  return query
  select g.id,g.name,g.plan_id,m.name,(select count(*) from game_players gp where gp.game_id=g.id),g.started_at,g.finished_at
  from games g join matches m on m.id=g.plan_id where g.status='finished' order by g.finished_at desc nulls last;
end $$;

drop function if exists public.my_finished_games(uuid);
create function public.my_finished_games(p_player uuid)
returns table(game_id uuid,game_name text,plan_id uuid,plan_name text,place int,finished_at timestamptz)
language plpgsql as $$
begin
  perform expire_games();
  return query
  select g.id,g.name,g.plan_id,m.name,gp.place,g.finished_at
  from game_players gp join games g on g.id=gp.game_id join matches m on m.id=g.plan_id
  where gp.player_id=p_player and g.status='finished' order by g.finished_at desc nulls last;
end $$;

commit;
