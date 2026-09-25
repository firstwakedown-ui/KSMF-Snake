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
