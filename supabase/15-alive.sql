-- AchtungDieKM — Etapa 42: current_game vrací i alive (vyřazený hráč může do lobby)
-- Spusť přes tools/db/migrate PO 14-active-sim.sql.

begin;

drop function if exists current_game(uuid);
create or replace function current_game(p_player uuid)
returns table(game_id uuid, plan_id uuid, plan_name text, snap_tolerance_m int, status text,
              started_at timestamptz, start_lng double precision, start_lat double precision,
              start_label text, sim boolean, alive boolean)
language sql as $$
  select g.id, g.plan_id, m.name, m.snap_tolerance_m, g.status, g.started_at,
         ST_X(sp.geom), ST_Y(sp.geom), gp.start_label, g.sim, gp.alive
  from game_players gp
  join games g on g.id = gp.game_id
  join matches m on m.id = g.plan_id
  left join start_points sp on sp.id = gp.start_point_id
  where gp.player_id = p_player and g.status in ('lobby', 'running')
  order by gp.joined_at desc limit 1;
$$;

commit;
