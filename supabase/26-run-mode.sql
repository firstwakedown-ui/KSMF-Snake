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
