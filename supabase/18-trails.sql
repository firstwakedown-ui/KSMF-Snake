-- AchtungDieKM — Etapa 45: uložené stopy hráčů (obrázek tras k výsledkům)
-- Spusť přes tools/db/migrate PO 17-results.sql.

begin;

-- Finální stopa hráče (pole [lng,lat]) – nahraje klient při vyřazení / na konci hry.
alter table game_players add column if not exists trail jsonb;

-- Výsledky teď vrací i trasu.
drop function if exists game_results(uuid);
create or replace function game_results(p_game uuid)
returns table(player_id uuid, nickname text, place int, alive boolean, trail jsonb)
language sql as $$
  select gp.player_id, pl.nickname, gp.place, gp.alive, gp.trail
  from game_players gp
  join players pl on pl.id = gp.player_id
  where gp.game_id = p_game
  order by gp.place nulls last, gp.joined_at;
$$;

-- Historie potřebuje plan_id (kvůli načtení ulic do obrázku).
drop function if exists finished_games();
create or replace function finished_games()
returns table(game_id uuid, plan_id uuid, plan_name text, players bigint, started_at timestamptz, finished_at timestamptz)
language sql as $$
  select g.id, g.plan_id, m.name, (select count(*) from game_players gp where gp.game_id = g.id),
         g.started_at, g.finished_at
  from games g join matches m on m.id = g.plan_id
  where g.status = 'finished'
  order by g.finished_at desc nulls last;
$$;

commit;
