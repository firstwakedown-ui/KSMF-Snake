-- AchtungDieKM — Etapa 38: admin sleduje hru + výběr startu v mapě
-- Spusť přes tools/db/migrate PO 11-games.sql.

begin;

-- game_starts: doplnit souřadnice startů (pro výběr v mapě).
drop function if exists game_starts(uuid);
create or replace function game_starts(p_game uuid)
returns table(start_id uuid, label text, lng double precision, lat double precision, taken boolean, taken_by text)
language sql as $$
  with g as (select plan_id, capacity from games where id = p_game),
  pool as (
    select sp.id, sp.label, ST_X(sp.geom) lng, ST_Y(sp.geom) lat,
           row_number() over (order by sp.created_at) rn
    from start_points sp, g where sp.match_id = g.plan_id
  )
  select p.id, p.label, p.lng, p.lat,
         exists(select 1 from game_players gp where gp.game_id = p_game and gp.start_point_id = p.id),
         (select pl.nickname from game_players gp join players pl on pl.id = gp.player_id
          where gp.game_id = p_game and gp.start_point_id = p.id limit 1)
  from pool p, g where p.rn <= g.capacity
  order by p.rn;
$$;

-- lobby_games: doplnit plan_id (pro načtení ulic do mapky výběru startu).
drop function if exists lobby_games(uuid);
create or replace function lobby_games(p_player uuid)
returns table(game_id uuid, plan_id uuid, plan_name text, capacity int, joined bigint, mine boolean, my_start text)
language sql as $$
  select g.id, g.plan_id, m.name, g.capacity,
         (select count(*) from game_players gp where gp.game_id = g.id),
         exists(select 1 from game_players gp where gp.game_id = g.id and gp.player_id = p_player),
         (select gp.start_label from game_players gp where gp.game_id = g.id and gp.player_id = p_player limit 1)
  from games g join matches m on m.id = g.plan_id
  where g.status = 'lobby'
  order by g.created_at desc;
$$;

-- active_games: doplnit plan_id (pro „Sleduj").
drop function if exists active_games();
create or replace function active_games()
returns table(game_id uuid, plan_id uuid, plan_name text, status text, capacity int, joined bigint)
language sql as $$
  select g.id, g.plan_id, m.name, g.status, g.capacity,
         (select count(*) from game_players gp where gp.game_id = g.id)
  from games g join matches m on m.id = g.plan_id
  where g.status in ('lobby', 'running')
  order by g.created_at desc;
$$;

-- Roster hry pro admina (kdo hraje + jeho start): pro „Sleduj" a kontrolu, kdo je na startu.
create or replace function game_roster(p_game uuid)
returns table(player_id uuid, nickname text, start_lng double precision, start_lat double precision, start_label text, alive boolean)
language sql as $$
  select gp.player_id, pl.nickname, ST_X(sp.geom), ST_Y(sp.geom), gp.start_label, gp.alive
  from game_players gp
  join players pl on pl.id = gp.player_id
  left join start_points sp on sp.id = gp.start_point_id
  where gp.game_id = p_game
  order by gp.joined_at;
$$;

commit;
