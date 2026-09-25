-- AchtungDieKM — Etapa 41: do přehledu aktivních her přidat příznak simulace
-- Spusť přes tools/db/migrate PO 13-sim.sql.

begin;

drop function if exists active_games();
create or replace function active_games()
returns table(game_id uuid, plan_id uuid, plan_name text, status text, capacity int, joined bigint, sim boolean)
language sql as $$
  select g.id, g.plan_id, m.name, g.status, g.capacity,
         (select count(*) from game_players gp where gp.game_id = g.id), g.sim
  from games g join matches m on m.id = g.plan_id
  where g.status in ('lobby', 'running')
  order by g.created_at desc;
$$;

commit;
