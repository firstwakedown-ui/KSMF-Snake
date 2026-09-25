-- AchtungDieKM — Etapa 44: výsledky hry (pořadí hráčů)
-- Spusť přes tools/db/migrate PO 16-autofinish.sql.

begin;

create or replace function game_results(p_game uuid)
returns table(player_id uuid, nickname text, place int, alive boolean)
language sql as $$
  select gp.player_id, pl.nickname, gp.place, gp.alive
  from game_players gp
  join players pl on pl.id = gp.player_id
  where gp.game_id = p_game
  order by gp.place nulls last, gp.joined_at;
$$;

commit;
