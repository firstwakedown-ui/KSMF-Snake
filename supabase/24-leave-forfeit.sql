-- AchtungDieKM — Etapa 50: odpojení z běžící hry = vzdání (vyřazení), 0 živých → dokončit (nemazat)
-- Spusť přes tools/db/migrate PO 23-autofinish-trigger.sql.

begin;

-- Odpojení: z běžící hry = vzdání (vyřazení s pořadím); z lobby = odhlášení (uvolní slot).
create or replace function leave_game(p_game uuid, p_player uuid)
returns void
language plpgsql as $$
declare st text;
begin
  select status into st from games where id = p_game;
  if st = 'running' then
    perform eliminate_player(p_game, p_player);
  else
    delete from game_players where game_id = p_game and player_id = p_player;
  end if;
end $$;

-- Pojistka: běžící hra s 0 živými → dokončit (NE mazat). Lobby hry se netýká (čekají na hráče).
create or replace function trg_finish_empty_game()
returns trigger
language plpgsql as $$
declare gid uuid; n_alive int;
begin
  gid := coalesce(NEW.game_id, OLD.game_id);
  select count(*) filter (where alive) into n_alive from game_players where game_id = gid;
  if n_alive = 0 then
    update games set status = 'finished', finished_at = now() where id = gid and status = 'running';
  end if;
  return null;
end $$;

commit;
