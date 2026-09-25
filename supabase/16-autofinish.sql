-- AchtungDieKM — Etapa 43: automatické ukončení hry (poslední přeživší vyhrává) + smazání prázdné hry
-- Spusť přes tools/db/migrate PO 15-alive.sql.

begin;

-- Vyřazení hráče: alive=false, přiřadí pořadí (place), a když zbývá ≤1 živý → hru dokonči.
create or replace function eliminate_player(p_game uuid, p_player uuid)
returns void
language plpgsql as $$
declare v_alive int;
begin
  update game_players set alive = false
   where game_id = p_game and player_id = p_player and alive = true;
  if not found then return; end if;

  -- kolik zbývá živých PO tomto vyřazení
  select count(*) into v_alive from game_players where game_id = p_game and alive = true;
  -- pořadí vyřazeného: živí budou mít lepší (1..v_alive), tenhle dostane v_alive+1
  update game_players set place = v_alive + 1 where game_id = p_game and player_id = p_player;

  if v_alive <= 1 then
    -- poslední přeživší (pokud je) = 1. místo; hra končí
    update game_players set place = 1 where game_id = p_game and alive = true;
    update games set status = 'finished', finished_at = now() where id = p_game and status = 'running';
  end if;
end $$;

-- Ukončení hry adminem: prázdnou (nikdo nehrál) rovnou smaž, jinak do historie.
create or replace function finish_game(p_game uuid)
returns void
language plpgsql as $$
declare v_players int;
begin
  select count(*) into v_players from game_players where game_id = p_game;
  if v_players = 0 then
    delete from games where id = p_game;
  else
    update games set status = 'finished', finished_at = now() where id = p_game;
  end if;
end $$;

commit;
