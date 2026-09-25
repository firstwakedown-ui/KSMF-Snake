-- AchtungDieKM — Etapa 33: start hry + odpočet (engine fáze 1)
-- Spusť přes tools/db/migrate PO 09-lobby.sql.

begin;

-- Čas zahájení (od něj se počítá odpočet i běh hry).
alter table matches add column if not exists started_at timestamptz;

-- Admin spustí hru: lobby -> running, zapíše čas startu (klienti z něj počítají odpočet).
create or replace function start_game(p_match uuid)
returns void
language plpgsql
as $$
begin
  update matches set status = 'running', started_at = now() where id = p_match and status = 'lobby';
end
$$;

-- Admin ukončí hru: uvolní hráče a vrátí mapu do lobby (znovu hratelná).
create or replace function end_game(p_match uuid)
returns void
language plpgsql
as $$
begin
  delete from match_players where match_id = p_match;
  update matches set status = 'lobby', started_at = null where id = p_match;
end
$$;

-- Mapa hráče teď vrací i stav a čas startu (pro fázi waiting/countdown/running).
drop function if exists player_current_match(uuid);
create or replace function player_current_match(p_player uuid)
returns table(id uuid, name text, snap_tolerance_m int, status text, started_at timestamptz)
language sql
as $$
  select m.id, m.name, m.snap_tolerance_m, m.status, m.started_at
  from match_players mp
  join matches m on m.id = mp.match_id
  where mp.player_id = p_player and m.status in ('lobby', 'running')
  order by mp.joined_at desc
  limit 1;
$$;

commit;
