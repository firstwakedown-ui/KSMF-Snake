-- AchtungDieKM — Etapa 49: serverová pojistka – běžící hra bez živých hráčů se ukončí / prázdná smaže
-- Spusť přes tools/db/migrate PO 22-spectate-lobby.sql.

begin;

create or replace function trg_finish_empty_game()
returns trigger
language plpgsql as $$
declare gid uuid; n_players int; n_alive int;
begin
  gid := coalesce(NEW.game_id, OLD.game_id);
  select count(*), count(*) filter (where alive) into n_players, n_alive
  from game_players where game_id = gid;
  if n_players = 0 then
    -- všichni odešli → prázdnou hru smaž (lobby i running)
    delete from games where id = gid and status in ('lobby', 'running');
  elsif n_alive = 0 then
    -- všichni vyřazeni → běžící hra končí (zůstává v historii s pořadím)
    update games set status = 'finished', finished_at = now() where id = gid and status = 'running';
  end if;
  return null;
end $$;

drop trigger if exists game_players_autofinish on game_players;
create trigger game_players_autofinish
after update or delete on game_players
for each row execute function trg_finish_empty_game();

-- Jednorázový úklid: dokonči/smaž případné už existující „zaseklé" běžící hry.
update games g set status = 'finished', finished_at = now()
 where g.status = 'running'
   and exists (select 1 from game_players gp where gp.game_id = g.id)
   and not exists (select 1 from game_players gp where gp.game_id = g.id and gp.alive);
delete from games g
 where g.status in ('lobby', 'running')
   and not exists (select 1 from game_players gp where gp.game_id = g.id);

commit;
