-- Global configuration for newly created games.
-- Plans contain map data only. Every game receives an immutable settings
-- snapshot when it is created; later configuration changes never modify it.

begin;

drop function if exists public.save_plan_settings(uuid,jsonb);
drop function if exists public.save_strawberry_settings(uuid,int,int);

create table if not exists public.game_settings (
  singleton boolean primary key default true check (singleton),
  idle_timeout_s int not null default 30,
  outside_timeout_s int not null default 30,
  snap_tolerance_m int not null default 30,
  walk_speed_mps numeric not null default 3.6,
  run_speed_mps numeric not null default 7.5,
  sprint_speed_mps numeric not null default 12,
  sprint_range_m int not null default 200,
  snake_initial_length_m numeric not null default 10,
  strawberry_growth_m numeric not null default 10,
  game_duration_s int not null default 900,
  snake_speed_mps numeric not null default 0.833333,
  strawberry_spawn_min_s int not null default 10,
  strawberry_spawn_max_s int not null default 60,
  strawberry_active_percent int not null default 100,
  strawberry_initial_percent int not null default 33,
  max_lead_m numeric not null default 100,
  respawn_countdown_s int not null default 3,
  self_collision_grace_m numeric not null default 10,
  collision_radius_m numeric not null default 3,
  strawberry_radius_m numeric not null default 5,
  updated_at timestamptz not null default now()
);

-- Preserve the configuration currently visible in the active/first plan when
-- installing this migration. It becomes independent immediately afterwards.
insert into public.game_settings (
  singleton,idle_timeout_s,outside_timeout_s,snap_tolerance_m,
  walk_speed_mps,run_speed_mps,sprint_speed_mps,sprint_range_m,
  snake_initial_length_m,strawberry_growth_m,game_duration_s,snake_speed_mps,
  strawberry_spawn_min_s,strawberry_spawn_max_s,strawberry_active_percent,
  strawberry_initial_percent,max_lead_m,respawn_countdown_s,
  self_collision_grace_m,collision_radius_m,strawberry_radius_m
)
select
  true,m.idle_timeout_s,m.outside_timeout_s,m.snap_tolerance_m,
  m.walk_speed_mps,m.run_speed_mps,m.sprint_speed_mps,m.sprint_range_m,
  m.snake_initial_length_m,m.strawberry_growth_m,m.game_duration_s,m.snake_speed_mps,
  m.strawberry_spawn_min_s,m.strawberry_spawn_max_s,m.strawberry_active_percent,
  m.strawberry_initial_percent,m.max_lead_m,m.respawn_countdown_s,
  m.self_collision_grace_m,m.collision_radius_m,m.strawberry_radius_m
from public.matches m
order by m.is_active desc,m.created_at
limit 1
on conflict (singleton) do nothing;

insert into public.game_settings(singleton) values(true)
on conflict (singleton) do nothing;

alter table public.game_settings enable row level security;
drop policy if exists game_settings_admin_read on public.game_settings;
create policy game_settings_admin_read on public.game_settings
for select using(public.is_admin());

create or replace function public.get_game_settings()
returns jsonb language plpgsql security definer set search_path=public as $$
declare result game_settings%rowtype;
begin
  perform assert_admin();
  select * into result from game_settings where singleton=true;
  return to_jsonb(result);
end $$;

create or replace function public.save_game_settings(p_settings jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v game_settings%rowtype; result game_settings%rowtype;
begin
  perform assert_admin();
  select * into v from game_settings where singleton=true for update;
  if p_settings is null or jsonb_typeof(p_settings)<>'object' then
    raise exception 'Chybí nastavení hry.';
  end if;
  if exists(
    select 1 from jsonb_object_keys(p_settings) k
    where k <> all(array[
      'idle_timeout_s','outside_timeout_s','snap_tolerance_m',
      'walk_speed_mps','run_speed_mps','sprint_speed_mps','sprint_range_m',
      'snake_initial_length_m','strawberry_growth_m','game_duration_s','snake_speed_mps',
      'strawberry_spawn_min_s','strawberry_spawn_max_s','strawberry_active_percent',
      'strawberry_initial_percent','max_lead_m','respawn_countdown_s','self_collision_grace_m'
    ])
  ) then raise exception 'Neznámý parametr nastavení.'; end if;
  if exists(select 1 from jsonb_each(p_settings) e where jsonb_typeof(e.value)<>'number') then
    raise exception 'Nastavení musí obsahovat čísla.';
  end if;
  v := jsonb_populate_record(v,p_settings);
  if v.snake_initial_length_m<1 or v.strawberry_growth_m<1
    or v.game_duration_s<60 or v.snake_speed_mps<=0
    or v.strawberry_spawn_min_s<1 or v.strawberry_spawn_max_s<v.strawberry_spawn_min_s
    or v.strawberry_active_percent not between 1 and 100
    or v.strawberry_initial_percent not between 0 and 100
    or v.max_lead_m<5 or v.respawn_countdown_s<0 or v.self_collision_grace_m<0
    or v.idle_timeout_s<5 or v.outside_timeout_s<3 or v.snap_tolerance_m<5
    or v.walk_speed_mps<=0 or v.run_speed_mps<=0 or v.sprint_speed_mps<=0 or v.sprint_range_m<1
  then raise exception 'Neplatný rozsah nastavení nebo interval jahůdek.'; end if;

  update game_settings set
    idle_timeout_s=v.idle_timeout_s,outside_timeout_s=v.outside_timeout_s,
    snap_tolerance_m=v.snap_tolerance_m,walk_speed_mps=v.walk_speed_mps,
    run_speed_mps=v.run_speed_mps,sprint_speed_mps=v.sprint_speed_mps,
    sprint_range_m=v.sprint_range_m,snake_initial_length_m=v.snake_initial_length_m,
    strawberry_growth_m=v.strawberry_growth_m,game_duration_s=v.game_duration_s,
    snake_speed_mps=v.snake_speed_mps,strawberry_spawn_min_s=v.strawberry_spawn_min_s,
    strawberry_spawn_max_s=v.strawberry_spawn_max_s,
    strawberry_active_percent=v.strawberry_active_percent,
    strawberry_initial_percent=v.strawberry_initial_percent,max_lead_m=v.max_lead_m,
    respawn_countdown_s=v.respawn_countdown_s,self_collision_grace_m=v.self_collision_grace_m,
    updated_at=now()
  where singleton=true returning * into result;
  return to_jsonb(result);
end $$;

-- The trigger is the single authoritative snapshot boundary. Existing games are
-- deliberately never updated by save_game_settings.
drop trigger if exists games_copy_plan_settings on public.games;
drop trigger if exists games_copy_game_settings on public.games;
create or replace function public.copy_game_settings_to_new_game()
returns trigger language plpgsql security definer set search_path=public as $$
declare v game_settings%rowtype;
begin
  select * into v from game_settings where singleton=true;
  if not found then raise exception 'Chybí globální nastavení hry.'; end if;
  new.idle_timeout_s:=v.idle_timeout_s; new.outside_timeout_s:=v.outside_timeout_s;
  new.snap_tolerance_m:=v.snap_tolerance_m; new.walk_speed_mps:=v.walk_speed_mps;
  new.run_speed_mps:=v.run_speed_mps; new.sprint_speed_mps:=v.sprint_speed_mps;
  new.sprint_range_m:=v.sprint_range_m; new.snake_initial_length_m:=v.snake_initial_length_m;
  new.strawberry_growth_m:=v.strawberry_growth_m; new.game_duration_s:=v.game_duration_s;
  new.snake_speed_mps:=v.snake_speed_mps; new.strawberry_spawn_min_s:=v.strawberry_spawn_min_s;
  new.strawberry_spawn_max_s:=v.strawberry_spawn_max_s;
  new.strawberry_active_percent:=v.strawberry_active_percent;
  new.strawberry_initial_percent:=v.strawberry_initial_percent; new.max_lead_m:=v.max_lead_m;
  new.respawn_countdown_s:=v.respawn_countdown_s; new.self_collision_grace_m:=v.self_collision_grace_m;
  new.collision_radius_m:=v.collision_radius_m; new.strawberry_radius_m:=v.strawberry_radius_m;
  return new;
end $$;
create trigger games_copy_game_settings before insert on public.games
for each row execute function public.copy_game_settings_to_new_game();

-- Start uses only the immutable game snapshot. It never reads configuration
-- values from the plan or from game_settings.
create or replace function public.run_game(p_game uuid)
returns void language plpgsql security definer set search_path=public as $$
declare g games%rowtype; n int; initial_count int;
begin
  perform assert_admin();
  select * into g from games where id=p_game for update;
  if not found then raise exception 'Hra neexistuje.'; end if;
  if g.status<>'lobby' then return; end if;
  if not exists(select 1 from game_players where game_id=p_game) then
    raise exception 'Ke hře není připojený žádný hráč.';
  end if;
  select count(*) into n from strawberry_points where match_id=g.plan_id;
  initial_count:=least(n,greatest(0,ceil(n*coalesce(g.strawberry_initial_percent,33)/100.0)::int));
  update games set status='running',started_at=now(),finished_at=null where id=p_game;
  insert into snake_states(game_id,player_id,current_length_m,max_length_m,target_length_m,tail_distance_m)
    select p_game,gp.player_id,coalesce(g.snake_initial_length_m,10),coalesce(g.snake_initial_length_m,10),
      coalesce(g.snake_initial_length_m,10),0 from game_players gp where gp.game_id=p_game
    on conflict do nothing;
  delete from game_strawberries where game_id=p_game;
  insert into game_strawberries(game_id,point_id,active,next_spawn_at,eaten_at)
  select p_game,ranked.id,ranked.position<=initial_count,
    case when ranked.position<=initial_count then null else now()+make_interval(secs=>floor(random()*(
      coalesce(g.strawberry_spawn_max_s,60)-coalesce(g.strawberry_spawn_min_s,10)+1
    )+coalesce(g.strawberry_spawn_min_s,10))::int) end,null
  from (
    select sp.id,row_number() over(order by random()) position
    from strawberry_points sp where sp.match_id=g.plan_id
  ) ranked;
end $$;

commit;
