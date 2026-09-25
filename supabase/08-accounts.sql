-- AchtungDieKM — Etapa 28: přístup hráčů (přístupové kódy + účty s heslem)
-- Spusť přes tools/db/migrate PO 07-split-edges.sql.

begin;

create extension if not exists pgcrypto;

-- Přístupové kódy (generuje admin). Jeden kód = libovolně registrací, dokud je active.
create table if not exists access_codes (
  id          uuid primary key default gen_random_uuid(),
  code        text unique not null,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);
alter table access_codes enable row level security;
drop policy if exists access_codes_all on access_codes;
create policy access_codes_all on access_codes for all using (true) with check (true);

-- Hráči: unikátní přezdívka (case-insensitive). Heslo bokem (anon se k němu nedostane).
create unique index if not exists players_nick_uidx on players (lower(nickname));

create table if not exists player_auth (
  player_id     uuid primary key references players(id) on delete cascade,
  password_hash text not null
);
alter table player_auth enable row level security;
-- ŽÁDNÉ politiky → anon nemá k hashům přístup; pracují jen SECURITY DEFINER funkce níže.

-- Registrace: ověří kód, volnou přezdívku, uloží bcrypt hash. Vrací id + nickname.
create or replace function register_player(p_nickname text, p_password text, p_code text)
returns table(id uuid, nickname text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare v_id uuid; v_nick text;
begin
  v_nick := btrim(p_nickname);
  if v_nick = '' then raise exception 'Zadej přezdívku.'; end if;
  if length(coalesce(p_password, '')) < 4 then raise exception 'Heslo musí mít aspoň 4 znaky.'; end if;
  if not exists (select 1 from access_codes where code = upper(btrim(p_code)) and active) then
    raise exception 'Neplatný nebo deaktivovaný přístupový kód.';
  end if;
  if exists (select 1 from players where lower(players.nickname) = lower(v_nick)) then
    raise exception 'Tahle přezdívka už je obsazená.';
  end if;
  insert into players(nickname) values (v_nick) returning players.id into v_id;
  insert into player_auth(player_id, password_hash) values (v_id, crypt(p_password, gen_salt('bf')));
  return query select v_id, v_nick;
end
$$;

-- Přihlášení: ověří heslo. Vrací id + nickname, nebo vyhodí výjimku.
create or replace function login_player(p_nickname text, p_password text)
returns table(id uuid, nickname text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare v_id uuid; v_nick text; v_hash text;
begin
  select p.id, p.nickname into v_id, v_nick from players p where lower(p.nickname) = lower(btrim(p_nickname));
  if v_id is null then raise exception 'Přezdívka neexistuje – nejdřív se zaregistruj.'; end if;
  select password_hash into v_hash from player_auth where player_id = v_id;
  if v_hash is null or v_hash <> crypt(p_password, v_hash) then
    raise exception 'Špatné heslo.';
  end if;
  return query select v_id, v_nick;
end
$$;

commit;
