-- AchtungDieKM — Etapa 39: simulace povolená per hra
-- Spusť přes tools/db/migrate PO 12-spectate.sql.

begin;

-- Hra může mít povolenou simulaci (hráč pak smí přejít do sim módu).
alter table games add column if not exists sim boolean not null default false;

-- create_game s volbou simulace.
drop function if exists create_game(uuid, int);
create or replace function create_game(p_plan uuid, p_capacity int, p_sim boolean default false)
returns uuid
language plpgsql as $$
declare v_starts int; v_cap int; v_id uuid;
begin
  select count(*) into v_starts from start_points where match_id = p_plan;
  if v_starts = 0 then raise exception 'Plán nemá žádné starty.'; end if;
  v_cap := least(greatest(p_capacity, 1), v_starts);
  insert into games(plan_id, capacity, sim) values (p_plan, v_cap, coalesce(p_sim, false)) returning id into v_id;
  return v_id;
end $$;

-- current_game vrací i příznak sim.
drop function if exists current_game(uuid);
create or replace function current_game(p_player uuid)
returns table(game_id uuid, plan_id uuid, plan_name text, snap_tolerance_m int, status text,
              started_at timestamptz, start_lng double precision, start_lat double precision, start_label text, sim boolean)
language sql as $$
  select g.id, g.plan_id, m.name, m.snap_tolerance_m, g.status, g.started_at,
         ST_X(sp.geom), ST_Y(sp.geom), gp.start_label, g.sim
  from game_players gp
  join games g on g.id = gp.game_id
  join matches m on m.id = g.plan_id
  left join start_points sp on sp.id = gp.start_point_id
  where gp.player_id = p_player and g.status in ('lobby', 'running')
  order by gp.joined_at desc limit 1;
$$;

commit;
