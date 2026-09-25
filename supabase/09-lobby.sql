-- AchtungDieKM — Etapa 32: lobby (nabízení map ke hře + připojení hráčů)
-- Spusť přes tools/db/migrate PO 08-accounts.sql.

begin;

-- Stav mapy: draft (rozpracovaná) | lobby (nabízená) | running | finished.
-- Default napříště 'draft'; existující (schema měla default 'lobby') srovnáme na draft.
alter table matches alter column status set default 'draft';
update matches set status = 'draft' where status is null or status = 'lobby';

-- Připojení hráče: přidělený startovní bod + čas připojení.
alter table match_players add column if not exists start_point_id uuid references start_points(id) on delete set null;
alter table match_players add column if not exists joined_at timestamptz not null default now();

-- Admin otevře/zavře mapu v lobby (zavření uvolní připojené hráče).
create or replace function set_lobby(p_match uuid, p_open boolean)
returns void
language plpgsql
as $$
begin
  if p_open then
    update matches set status = 'lobby' where id = p_match;
  else
    delete from match_players where match_id = p_match;
    update matches set status = 'draft' where id = p_match;
  end if;
end
$$;

-- Hráč se připojí: ověří otevřenou mapu, kapacitu (= počet startů), přidělí volný start.
create or replace function join_match(p_match uuid, p_player uuid)
returns void
language plpgsql
as $$
declare cap int; cur int; free_id uuid;
begin
  if not exists (select 1 from matches where id = p_match and status = 'lobby') then
    raise exception 'Tahle mapa není otevřená pro připojení.';
  end if;
  if exists (select 1 from match_players where match_id = p_match and player_id = p_player) then
    return; -- už připojen, noop
  end if;
  select count(*) into cap from start_points where match_id = p_match;
  if cap = 0 then raise exception 'Mapa nemá nastavené starty.'; end if;
  select count(*) into cur from match_players where match_id = p_match;
  if cur >= cap then raise exception 'Kapacita mapy je plná.'; end if;
  select sp.id into free_id from start_points sp
   where sp.match_id = p_match
     and not exists (select 1 from match_players mp where mp.match_id = p_match and mp.start_point_id = sp.id)
   order by sp.created_at limit 1;
  insert into match_players(match_id, player_id, start_point_id) values (p_match, p_player, free_id);
end
$$;

create or replace function leave_match(p_match uuid, p_player uuid)
returns void
language sql
as $$
  delete from match_players where match_id = p_match and player_id = p_player;
$$;

-- Seznam map v lobby pro hráče (s kapacitou, obsazeností a zda jsem připojen).
create or replace function lobby_list(p_player uuid)
returns table(match_id uuid, name text, capacity bigint, joined bigint, mine boolean)
language sql
as $$
  select m.id, m.name,
         (select count(*) from start_points sp where sp.match_id = m.id),
         (select count(*) from match_players mp where mp.match_id = m.id),
         exists(select 1 from match_players mp where mp.match_id = m.id and mp.player_id = p_player)
  from matches m
  where m.status = 'lobby'
  order by m.created_at desc;
$$;

-- Mapa, ke které je hráč připojený (pro /play).
create or replace function player_current_match(p_player uuid)
returns table(id uuid, name text, snap_tolerance_m int)
language sql
as $$
  select m.id, m.name, m.snap_tolerance_m
  from match_players mp
  join matches m on m.id = mp.match_id
  where mp.player_id = p_player and m.status in ('lobby', 'running')
  order by mp.joined_at desc
  limit 1;
$$;

-- Přehled map pro admina (stav, kapacita, obsazenost).
create or replace function admin_games()
returns table(id uuid, name text, status text, capacity bigint, joined bigint)
language sql
as $$
  select m.id, m.name, m.status,
         (select count(*) from start_points sp where sp.match_id = m.id),
         (select count(*) from match_players mp where mp.match_id = m.id)
  from matches m
  order by m.created_at;
$$;

commit;
