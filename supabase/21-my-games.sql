-- AchtungDieKM — Etapa 48: hráčův seznam odehraných (dokončených) her v lobby
-- Spusť přes tools/db/migrate PO 20-norun-empty.sql.

begin;

create or replace function my_finished_games(p_player uuid)
returns table(game_id uuid, plan_id uuid, plan_name text, place int, finished_at timestamptz)
language sql as $$
  select g.id, g.plan_id, m.name, gp.place, g.finished_at
  from game_players gp
  join games g on g.id = gp.game_id
  join matches m on m.id = g.plan_id
  where gp.player_id = p_player and g.status = 'finished'
  order by g.finished_at desc nulls last;
$$;

commit;
