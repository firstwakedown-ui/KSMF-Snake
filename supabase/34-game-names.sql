-- Vlastní název každé herní instance ve všech přehledech a výsledcích.

begin;

alter table public.games add column if not exists name text;
update public.games g set name=coalesce(m.name,'Hra') || ' ' || to_char(g.created_at,'DD.MM. HH24:MI')
from public.matches m where m.id=g.plan_id and nullif(btrim(g.name),'') is null;
alter table public.games alter column name set not null;

drop function if exists public.create_game(uuid,int,boolean,boolean);
drop function if exists public.create_game(uuid,int,boolean,boolean,text);
create function public.create_game(p_plan uuid,p_capacity int,p_sim boolean default false,p_run boolean default false,p_name text default null)
returns uuid language plpgsql as $$
declare v_id uuid; m matches%rowtype; v_name text;
begin
  select * into m from matches where id=p_plan;
  if not found then raise exception 'Plán neexistuje.'; end if;
  if not exists(select 1 from respawn_points where match_id=p_plan) then raise exception 'Plán nemá respawn bod.'; end if;
  v_name:=coalesce(nullif(btrim(p_name),''),coalesce(m.name,'Hra') || ' ' || to_char(now(),'DD.MM. HH24:MI'));
  insert into games(name,plan_id,capacity,sim,run_mode,idle_timeout_s,outside_timeout_s,snap_tolerance_m,
    snake_initial_length_m,strawberry_growth_m,game_duration_s,snake_speed_mps,
    strawberry_spawn_min_s,strawberry_spawn_max_s,max_lead_m,respawn_countdown_s,collision_radius_m,strawberry_radius_m)
  values(v_name,p_plan,greatest(1,p_capacity),coalesce(p_sim,false),coalesce(p_run,false),m.idle_timeout_s,m.outside_timeout_s,m.snap_tolerance_m,
    m.snake_initial_length_m,m.strawberry_growth_m,m.game_duration_s,m.snake_speed_mps,
    m.strawberry_spawn_min_s,m.strawberry_spawn_max_s,m.max_lead_m,m.respawn_countdown_s,m.collision_radius_m,m.strawberry_radius_m)
  returning id into v_id;
  return v_id;
end $$;

drop function if exists public.lobby_games(uuid);
create function public.lobby_games(p_player uuid)
returns table(game_id uuid,game_name text,plan_id uuid,plan_name text,capacity int,joined bigint,mine boolean,my_start text,status text,alive boolean)
language sql as $$
  select g.id,g.name,g.plan_id,m.name,g.capacity,
    (select count(*) from game_players gp where gp.game_id=g.id),
    exists(select 1 from game_players gp where gp.game_id=g.id and gp.player_id=p_player),
    null::text,g.status,
    (select ss.active from snake_states ss where ss.game_id=g.id and ss.player_id=p_player limit 1)
  from games g join matches m on m.id=g.plan_id
  where g.status in ('lobby','running') order by g.created_at desc
$$;

drop function if exists public.current_game(uuid);
create function public.current_game(p_player uuid)
returns table(game_id uuid,game_name text,plan_id uuid,plan_name text,snap_tolerance_m int,status text,started_at timestamptz,
  start_lng double precision,start_lat double precision,start_label text,sim boolean,alive boolean,run_mode boolean,
  idle_timeout_s int,outside_timeout_s int,walk_speed_mps numeric,run_speed_mps numeric,sprint_speed_mps numeric,sprint_range_m int,
  game_duration_s int,max_lead_m numeric)
language sql as $$
  select g.id,g.name,g.plan_id,m.name,coalesce(g.snap_tolerance_m,m.snap_tolerance_m),g.status,g.started_at,
    null::double precision,null::double precision,null::text,g.sim,coalesce(ss.active,true),g.run_mode,
    coalesce(g.idle_timeout_s,m.idle_timeout_s),coalesce(g.outside_timeout_s,m.outside_timeout_s),
    g.walk_speed_mps,g.run_speed_mps,g.sprint_speed_mps,g.sprint_range_m,
    coalesce(g.game_duration_s,m.game_duration_s),coalesce(g.max_lead_m,m.max_lead_m)
  from game_players gp join games g on g.id=gp.game_id join matches m on m.id=g.plan_id
  left join snake_states ss on ss.game_id=gp.game_id and ss.player_id=gp.player_id
  where gp.player_id=p_player and g.status in ('lobby','running') order by gp.joined_at desc limit 1
$$;

drop function if exists public.active_games();
create function public.active_games()
returns table(game_id uuid,game_name text,plan_id uuid,plan_name text,status text,capacity int,joined bigint,sim boolean,run_mode boolean)
language sql as $$
  select g.id,g.name,g.plan_id,m.name,g.status,g.capacity,
    (select count(*) from game_players gp where gp.game_id=g.id),g.sim,g.run_mode
  from games g join matches m on m.id=g.plan_id where g.status in ('lobby','running') order by g.created_at desc
$$;

drop function if exists public.finished_games();
create function public.finished_games()
returns table(game_id uuid,game_name text,plan_id uuid,plan_name text,players bigint,started_at timestamptz,finished_at timestamptz)
language sql as $$
  select g.id,g.name,g.plan_id,m.name,(select count(*) from game_players gp where gp.game_id=g.id),g.started_at,g.finished_at
  from games g join matches m on m.id=g.plan_id where g.status='finished' order by g.finished_at desc nulls last
$$;

drop function if exists public.my_finished_games(uuid);
create function public.my_finished_games(p_player uuid)
returns table(game_id uuid,game_name text,plan_id uuid,plan_name text,place int,finished_at timestamptz)
language sql as $$
  select g.id,g.name,g.plan_id,m.name,gp.place,g.finished_at
  from game_players gp join games g on g.id=gp.game_id join matches m on m.id=g.plan_id
  where gp.player_id=p_player and g.status='finished' order by g.finished_at desc nulls last
$$;

commit;
