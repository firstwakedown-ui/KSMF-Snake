-- AchtungDieKM — Etapa 53: lobby_games vrací i alive (vyřazený hráč u běžící hry → „Sledovat")
-- Spusť přes tools/db/migrate PO 24-leave-forfeit.sql.

begin;

drop function if exists lobby_games(uuid);
create or replace function lobby_games(p_player uuid)
returns table(game_id uuid, plan_id uuid, plan_name text, capacity int, joined bigint,
              mine boolean, my_start text, status text, alive boolean)
language sql as $$
  select g.id, g.plan_id, m.name, g.capacity,
         (select count(*) from game_players gp where gp.game_id = g.id),
         exists(select 1 from game_players gp where gp.game_id = g.id and gp.player_id = p_player),
         (select gp.start_label from game_players gp where gp.game_id = g.id and gp.player_id = p_player limit 1),
         g.status,
         (select gp.alive from game_players gp where gp.game_id = g.id and gp.player_id = p_player limit 1)
  from games g join matches m on m.id = g.plan_id
  where g.status in ('lobby', 'running')
  order by g.created_at desc;
$$;

commit;
