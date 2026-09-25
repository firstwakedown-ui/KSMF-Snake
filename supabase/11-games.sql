-- AchtungDieKM — Etapa 37: hry jako instance plánů (víc her nad jedním plánem)
-- Spusť přes tools/db/migrate PO 10-game.sql.
-- Plán = mapa (šablona). Hra = instance plánu s vlastními hráči, kapacitou a stavem.

begin;

-- Plán lze označit „připraven ke hře" (z těch se zakládají hry).
alter table matches add column if not exists ready boolean not null default false;

-- Hra = instance plánu.
create table if not exists games (
  id          uuid primary key default gen_random_uuid(),
  plan_id     uuid not null references matches(id) on delete cascade,
  capacity    int not null,
  status      text not null default 'lobby', -- lobby | running | finished
  started_at  timestamptz,
  finished_at timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists games_status_idx on games (status);

-- Účast hráče ve hře (vlastní vybraný start).
create table if not exists game_players (
  game_id        uuid not null references games(id) on delete cascade,
  player_id      uuid not null references players(id) on delete cascade,
  start_point_id uuid references start_points(id) on delete set null,
  start_label    text,
  alive          boolean not null default true,
  place          int,
  joined_at      timestamptz not null default now(),
  primary key (game_id, player_id)
);

alter table games enable row level security;
drop policy if exists games_all on games;
create policy games_all on games for all using (true) with check (true);
alter table game_players enable row level security;
drop policy if exists game_players_all on game_players;
create policy game_players_all on game_players for all using (true) with check (true);

-- Plány připravené ke hře (pro „Nová hra").
create or replace function ready_plans()
returns table(id uuid, name text, starts bigint)
language sql as $$
  select m.id, m.name, (select count(*) from start_points sp where sp.match_id = m.id)
  from matches m where m.ready = true
  order by m.created_at;
$$;

-- Založení hry z plánu (kapacita se ořízne na počet startů).
create or replace function create_game(p_plan uuid, p_capacity int)
returns uuid
language plpgsql as $$
declare v_starts int; v_cap int; v_id uuid;
begin
  select count(*) into v_starts from start_points where match_id = p_plan;
  if v_starts = 0 then raise exception 'Plán nemá žádné starty.'; end if;
  v_cap := least(greatest(p_capacity, 1), v_starts);
  insert into games(plan_id, capacity) values (p_plan, v_cap) returning id into v_id;
  return v_id;
end $$;

-- Starty hry (pool = prvních „capacity" startů plánu) s informací, kdo je obsadil.
create or replace function game_starts(p_game uuid)
returns table(start_id uuid, label text, taken boolean, taken_by text)
language sql as $$
  with g as (select plan_id, capacity from games where id = p_game),
  pool as (
    select sp.id, sp.label, row_number() over (order by sp.created_at) rn
    from start_points sp, g where sp.match_id = g.plan_id
  )
  select p.id, p.label,
         exists(select 1 from game_players gp where gp.game_id = p_game and gp.start_point_id = p.id),
         (select pl.nickname from game_players gp join players pl on pl.id = gp.player_id
          where gp.game_id = p_game and gp.start_point_id = p.id limit 1)
  from pool p, g where p.rn <= g.capacity
  order by p.rn;
$$;

-- Připojení hráče: vybere si start (p_start). NULL = nejnižší volný.
create or replace function join_game(p_game uuid, p_player uuid, p_start uuid)
returns void
language plpgsql as $$
declare v_status text; v_cap int; v_plan uuid; v_cur int; v_start uuid; v_label text;
begin
  select status, capacity, plan_id into v_status, v_cap, v_plan from games where id = p_game;
  if v_status is null then raise exception 'Hra neexistuje.'; end if;
  if v_status <> 'lobby' then raise exception 'Tahle hra už není otevřená pro připojení.'; end if;
  if exists(select 1 from game_players where game_id = p_game and player_id = p_player) then return; end if;
  select count(*) into v_cur from game_players where game_id = p_game;
  if v_cur >= v_cap then raise exception 'Kapacita hry je plná.'; end if;
  with pool as (
    select sp.id, sp.label, row_number() over (order by sp.created_at) rn
    from start_points sp where sp.match_id = v_plan
  )
  select p2.id, p2.label into v_start, v_label
  from pool p2
  where p2.rn <= v_cap
    and not exists(select 1 from game_players gp where gp.game_id = p_game and gp.start_point_id = p2.id)
    and (p_start is null or p2.id = p_start)
  order by p2.rn limit 1;
  if v_start is null then raise exception 'Vybraný start není volný.'; end if;
  insert into game_players(game_id, player_id, start_point_id, start_label) values (p_game, p_player, v_start, v_label);
end $$;

create or replace function leave_game(p_game uuid, p_player uuid)
returns void language sql as $$
  delete from game_players where game_id = p_game and player_id = p_player;
$$;

create or replace function run_game(p_game uuid)
returns void language sql as $$
  update games set status = 'running', started_at = now() where id = p_game and status = 'lobby';
$$;

create or replace function finish_game(p_game uuid)
returns void language sql as $$
  update games set status = 'finished', finished_at = now() where id = p_game;
$$;

create or replace function delete_game(p_game uuid)
returns void language sql as $$
  delete from games where id = p_game;
$$;

-- Lobby pro hráče: otevřené hry s kapacitou/obsazeností a zda jsem připojen (+ můj start).
create or replace function lobby_games(p_player uuid)
returns table(game_id uuid, plan_name text, capacity int, joined bigint, mine boolean, my_start text)
language sql as $$
  select g.id, m.name, g.capacity,
         (select count(*) from game_players gp where gp.game_id = g.id),
         exists(select 1 from game_players gp where gp.game_id = g.id and gp.player_id = p_player),
         (select gp.start_label from game_players gp where gp.game_id = g.id and gp.player_id = p_player limit 1)
  from games g join matches m on m.id = g.plan_id
  where g.status = 'lobby'
  order by g.created_at desc;
$$;

-- Hra hráče (pro /play): hra + plán + můj start (souřadnice pro navigaci).
create or replace function current_game(p_player uuid)
returns table(game_id uuid, plan_id uuid, plan_name text, snap_tolerance_m int, status text,
              started_at timestamptz, start_lng double precision, start_lat double precision, start_label text)
language sql as $$
  select g.id, g.plan_id, m.name, m.snap_tolerance_m, g.status, g.started_at,
         ST_X(sp.geom), ST_Y(sp.geom), gp.start_label
  from game_players gp
  join games g on g.id = gp.game_id
  join matches m on m.id = g.plan_id
  left join start_points sp on sp.id = gp.start_point_id
  where gp.player_id = p_player and g.status in ('lobby', 'running')
  order by gp.joined_at desc limit 1;
$$;

-- Admin: aktivní hry (lobby/running).
create or replace function active_games()
returns table(game_id uuid, plan_name text, status text, capacity int, joined bigint)
language sql as $$
  select g.id, m.name, g.status, g.capacity,
         (select count(*) from game_players gp where gp.game_id = g.id)
  from games g join matches m on m.id = g.plan_id
  where g.status in ('lobby', 'running')
  order by g.created_at desc;
$$;

-- Admin: dokončené hry (historie).
create or replace function finished_games()
returns table(game_id uuid, plan_name text, players bigint, started_at timestamptz, finished_at timestamptz)
language sql as $$
  select g.id, m.name, (select count(*) from game_players gp where gp.game_id = g.id), g.started_at, g.finished_at
  from games g join matches m on m.id = g.plan_id
  where g.status = 'finished'
  order by g.finished_at desc nulls last;
$$;

commit;
