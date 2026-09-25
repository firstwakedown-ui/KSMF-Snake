-- AchtungDieKM — Etapa 47: zákaz spuštění hry bez hráče
-- Spusť přes tools/db/migrate PO 19-lobby-mine.sql.

begin;

create or replace function run_game(p_game uuid)
returns void
language plpgsql as $$
begin
  if (select count(*) from game_players where game_id = p_game) = 0 then
    raise exception 'Ke hře není připojený žádný hráč.';
  end if;
  update games set status = 'running', started_at = now() where id = p_game and status = 'lobby';
end $$;

commit;
