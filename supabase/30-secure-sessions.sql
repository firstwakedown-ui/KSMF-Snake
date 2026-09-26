-- KSMF Snake — bezpečné serverové relace pro hráče a admina + uzamčení RLS.
-- Admin heslo se po migraci nastaví jednorázově funkcí bootstrap_admin_password z přímého DB spojení.
begin;

create extension if not exists pgcrypto;

create table if not exists player_sessions (
  token uuid primary key default gen_random_uuid(),
  player_id uuid not null references players(id) on delete cascade,
  expires_at timestamptz not null default now()+interval '30 days',
  created_at timestamptz not null default now()
);
create index if not exists player_sessions_player_idx on player_sessions(player_id);
alter table player_sessions enable row level security;

create table if not exists admin_credentials (
  singleton boolean primary key default true check(singleton),
  password_hash text not null,
  updated_at timestamptz not null default now()
);
create table if not exists admin_sessions (
  token uuid primary key default gen_random_uuid(),
  expires_at timestamptz not null default now()+interval '12 hours',
  created_at timestamptz not null default now()
);
alter table admin_credentials enable row level security;
alter table admin_sessions enable row level security;

create or replace function request_token(p_header text) returns uuid
language plpgsql stable as $$
declare v text;
begin
  v:=coalesce(current_setting('request.headers',true),'{}')::jsonb->>p_header;
  return nullif(v,'')::uuid;
exception when others then return null;
end $$;

create or replace function current_player_id() returns uuid
language sql stable security definer set search_path=public as $$
  select player_id from player_sessions where token=request_token('x-player-token') and expires_at>now() limit 1
$$;
create or replace function is_admin() returns boolean
language sql stable security definer set search_path=public as $$
  select exists(select 1 from admin_sessions where token=request_token('x-admin-token') and expires_at>now())
$$;
create or replace function assert_player(p_player uuid) returns void language plpgsql stable as $$
begin if current_player_id() is distinct from p_player then raise exception 'Neplatná nebo vypršená hráčská relace.' using errcode='28000'; end if; end $$;
create or replace function assert_admin() returns void language plpgsql stable as $$
begin if not is_admin() then raise exception 'Neplatná nebo vypršená administrátorská relace.' using errcode='28000'; end if; end $$;

drop function if exists register_player(text,text,text);
create function register_player(p_nickname text,p_password text,p_code text)
returns table(id uuid,nickname text,token uuid) language plpgsql security definer set search_path=public,extensions as $$
declare v_id uuid; v_nick text; v_token uuid;
begin
  v_nick:=btrim(p_nickname);
  if v_nick='' then raise exception 'Zadej přezdívku.'; end if;
  if length(coalesce(p_password,''))<4 then raise exception 'Heslo musí mít aspoň 4 znaky.'; end if;
  if not exists(select 1 from access_codes where code=upper(btrim(p_code)) and active) then raise exception 'Neplatný nebo deaktivovaný přístupový kód.'; end if;
  if exists(select 1 from players p where lower(p.nickname)=lower(v_nick)) then raise exception 'Tahle přezdívka už je obsazená.'; end if;
  insert into players(nickname) values(v_nick) returning players.id into v_id;
  insert into player_auth(player_id,password_hash) values(v_id,crypt(p_password,gen_salt('bf')));
  insert into player_sessions(player_id) values(v_id) returning player_sessions.token into v_token;
  return query select v_id,v_nick,v_token;
end $$;

drop function if exists login_player(text,text);
create function login_player(p_nickname text,p_password text)
returns table(id uuid,nickname text,token uuid) language plpgsql security definer set search_path=public,extensions as $$
declare v_id uuid; v_nick text; v_hash text; v_token uuid;
begin
  select p.id,p.nickname into v_id,v_nick from players p where lower(p.nickname)=lower(btrim(p_nickname));
  if v_id is null then raise exception 'Přezdívka neexistuje.'; end if;
  select password_hash into v_hash from player_auth where player_id=v_id;
  if v_hash is null or v_hash<>crypt(p_password,v_hash) then raise exception 'Špatné heslo.'; end if;
  delete from player_sessions where expires_at<=now();
  insert into player_sessions(player_id) values(v_id) returning player_sessions.token into v_token;
  return query select v_id,v_nick,v_token;
end $$;

create or replace function login_admin(p_password text) returns uuid
language plpgsql security definer set search_path=public,extensions as $$
declare v_hash text; v_token uuid;
begin
  select password_hash into v_hash from admin_credentials where singleton;
  if v_hash is null or v_hash<>crypt(p_password,v_hash) then raise exception 'Špatné admin heslo.'; end if;
  delete from admin_sessions where expires_at<=now();
  insert into admin_sessions default values returning token into v_token;
  return v_token;
end $$;

create or replace function bootstrap_admin_password(p_password text) returns void
language plpgsql security definer set search_path=public,extensions as $$
begin
  if length(coalesce(p_password,''))<12 then raise exception 'Admin heslo musí mít nejméně 12 znaků.'; end if;
  insert into admin_credentials(singleton,password_hash) values(true,crypt(p_password,gen_salt('bf')))
  on conflict(singleton) do update set password_hash=excluded.password_hash,updated_at=now();
  delete from admin_sessions;
end $$;
revoke all on function bootstrap_admin_password(text) from public,anon,authenticated;

-- Veřejná jsou pouze data nutná pro mapu/lobby. Zápisy vyžadují platnou relaci.
drop policy if exists matches_all on matches;
create policy matches_read on matches for select using(true);
create policy matches_admin_insert on matches for insert with check(is_admin());
create policy matches_admin_update on matches for update using(is_admin()) with check(is_admin());
create policy matches_admin_delete on matches for delete using(is_admin());

drop policy if exists players_all on players;
create policy players_read on players for select using(true);
create policy players_admin_delete on players for delete using(is_admin());

drop policy if exists access_codes_all on access_codes;
create policy access_codes_admin on access_codes for all using(is_admin()) with check(is_admin());

drop policy if exists games_all on games;
create policy games_read on games for select using(true);
create policy games_admin on games for all using(is_admin()) with check(is_admin());

drop policy if exists game_players_all on game_players;
create policy game_players_read on game_players for select using(true);
create policy game_players_insert_own on game_players for insert with check(player_id=current_player_id() or is_admin());
create policy game_players_update_own on game_players for update using(player_id=current_player_id() or is_admin()) with check(player_id=current_player_id() or is_admin());
create policy game_players_delete_own on game_players for delete using(player_id=current_player_id() or is_admin());

drop policy if exists start_points_all on start_points;
create policy start_points_read on start_points for select using(true);
create policy start_points_admin on start_points for all using(is_admin()) with check(is_admin());

drop policy if exists street_edges_admin_write on street_edges;
drop policy if exists street_edges_admin_all on street_edges;
create policy street_edges_admin_mutate on street_edges for all using(is_admin()) with check(is_admin());

drop policy if exists respawn_points_all on respawn_points;
drop policy if exists strawberry_points_all on strawberry_points;
drop policy if exists game_strawberries_all on game_strawberries;
drop policy if exists snake_states_all on snake_states;
create policy respawn_points_read on respawn_points for select using(true);
create policy respawn_points_admin on respawn_points for all using(is_admin()) with check(is_admin());
create policy strawberry_points_read on strawberry_points for select using(true);
create policy strawberry_points_admin on strawberry_points for all using(is_admin()) with check(is_admin());
create policy game_strawberries_admin on game_strawberries for all using(is_admin()) with check(is_admin());
create policy snake_states_own on snake_states for select using(player_id=current_player_id() or is_admin());

-- Veřejné herní pohledy vrací jen data účastníkovi dané hry nebo adminovi;
-- nikdy nevracejí cizí budoucí trasu.
create or replace function snake_world(p_game uuid)
returns table(player_id uuid,nickname text,active boolean,body jsonb,head jsonb,current_length_m numeric,max_length_m numeric,strawberries_eaten int,opponent_explosions int)
language sql security definer set search_path=public as $$
  select ss.player_id,p.nickname,ss.active,ST_AsGeoJSON(ss.body)::jsonb,ST_AsGeoJSON(ss.head_pos)::jsonb,
    ss.current_length_m,ss.max_length_m,ss.strawberries_eaten,ss.opponent_explosions
  from snake_states ss join players p on p.id=ss.player_id
  where ss.game_id=p_game and (is_admin() or exists(select 1 from game_players gp where gp.game_id=p_game and gp.player_id=current_player_id()))
  order by p.nickname
$$;
create or replace function active_strawberries(p_game uuid)
returns table(point_id uuid,lng double precision,lat double precision)
language sql security definer set search_path=public as $$
  select gs.point_id,ST_X(sp.geom),ST_Y(sp.geom) from game_strawberries gs join strawberry_points sp on sp.id=gs.point_id
  where gs.game_id=p_game and gs.active and (is_admin() or exists(select 1 from game_players gp where gp.game_id=p_game and gp.player_id=current_player_id()))
$$;
create or replace function game_results(p_game uuid)
returns table(player_id uuid,nickname text,place int,alive boolean,trail jsonb,max_length_m numeric,strawberries_eaten int,opponent_explosions int)
language sql security definer set search_path=public as $$
  select gp.player_id,p.nickname,null::int,coalesce(ss.active,false),gp.trail,
    coalesce(ss.max_length_m,0),coalesce(ss.strawberries_eaten,0),coalesce(ss.opponent_explosions,0)
  from game_players gp join players p on p.id=gp.player_id left join snake_states ss on ss.game_id=gp.game_id and ss.player_id=gp.player_id
  where gp.game_id=p_game and (is_admin() or exists(select 1 from game_players mine where mine.game_id=p_game and mine.player_id=current_player_id()))
  order by ss.max_length_m desc nulls last,p.nickname
$$;

commit;
