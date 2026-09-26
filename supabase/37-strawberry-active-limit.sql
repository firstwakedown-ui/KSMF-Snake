-- Procentní strop současně aktivních jahůdek. 100 % zachovává původní chování.

begin;

alter table public.matches add column if not exists strawberry_active_percent int not null default 100;
alter table public.games add column if not exists strawberry_active_percent int;
alter table public.matches drop constraint if exists matches_strawberry_active_percent_check;
alter table public.matches add constraint matches_strawberry_active_percent_check check (strawberry_active_percent between 1 and 100);
alter table public.games drop constraint if exists games_strawberry_active_percent_check;
alter table public.games add constraint games_strawberry_active_percent_check check (strawberry_active_percent between 1 and 100);
update public.matches set strawberry_active_percent=100 where strawberry_active_percent is null;
update public.games set strawberry_active_percent=100 where strawberry_active_percent is null;
alter table public.games alter column strawberry_active_percent set default 100;
alter table public.games alter column strawberry_active_percent set not null;

-- Každá nová hra si uloží procento z plánu jako snapshot.
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
    strawberry_spawn_min_s,strawberry_spawn_max_s,max_lead_m,respawn_countdown_s,collision_radius_m,strawberry_radius_m,
    strawberry_active_percent)
  values(v_name,p_plan,greatest(1,p_capacity),coalesce(p_sim,false),coalesce(p_run,false),m.idle_timeout_s,m.outside_timeout_s,m.snap_tolerance_m,
    m.snake_initial_length_m,m.strawberry_growth_m,m.game_duration_s,m.snake_speed_mps,
    m.strawberry_spawn_min_s,m.strawberry_spawn_max_s,m.max_lead_m,m.respawn_countdown_s,m.collision_radius_m,m.strawberry_radius_m,
    m.strawberry_active_percent)
  returning id into v_id;
  return v_id;
end $$;

-- Pojistka platí pro počáteční losování i každý pozdější respawn. Pokud je
-- limit naplněný, bod zůstane neaktivní a zkusí se znovu při dalším ticku.
create or replace function public.enforce_strawberry_active_limit()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_total int; v_active int; v_limit int; v_percent int;
begin
  if new.active and not old.active then
    select count(*) into v_total from game_strawberries where game_id=new.game_id;
    select coalesce(strawberry_active_percent,100) into v_percent from games where id=new.game_id;
    v_limit:=ceil(v_total*greatest(1,least(100,v_percent))/100.0);
    select count(*) into v_active from game_strawberries
      where game_id=new.game_id and active and point_id<>new.point_id;
    if v_active>=v_limit then
      new.active:=false;
      new.next_spawn_at:=coalesce(old.next_spawn_at,clock_timestamp());
    end if;
  end if;
  return new;
end $$;

drop trigger if exists game_strawberries_active_limit on public.game_strawberries;
create trigger game_strawberries_active_limit
before update of active on public.game_strawberries
for each row execute function public.enforce_strawberry_active_limit();

commit;
