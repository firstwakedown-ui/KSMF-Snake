-- Přihlášený hráč může sledovat právě běžící hru, i když není jejím
-- účastníkem. Pohled vrací jen aktuální těla a hlavy hadů; budoucí trasy
-- zůstávají soukromé a přímé čtení snake_states dál chrání RLS.

begin;

create or replace function public.snake_world(p_game uuid)
returns table(
  player_id uuid,
  nickname text,
  active boolean,
  body jsonb,
  head jsonb,
  current_length_m numeric,
  max_length_m numeric,
  strawberries_eaten int,
  opponent_explosions int
)
language sql
security definer
set search_path=public
as $$
  select
    ss.player_id,
    p.nickname,
    ss.active,
    ST_AsGeoJSON(ss.body)::jsonb,
    ST_AsGeoJSON(ss.head_pos)::jsonb,
    ss.current_length_m,
    ss.max_length_m,
    ss.strawberries_eaten,
    ss.opponent_explosions
  from public.snake_states ss
  join public.players p on p.id=ss.player_id
  where ss.game_id=p_game
    and (
      public.is_admin()
      or exists(
        select 1
        from public.game_players gp
        where gp.game_id=p_game
          and gp.player_id=public.current_player_id()
      )
      or (
        public.current_player_id() is not null
        and exists(
          select 1
          from public.games g
          where g.id=p_game
            and g.status='running'
        )
      )
    )
  order by p.nickname
$$;

create or replace function public.active_strawberries(p_game uuid)
returns table(point_id uuid,lng double precision,lat double precision)
language sql
security definer
set search_path=public
as $$
  select gs.point_id,ST_X(sp.geom),ST_Y(sp.geom)
  from public.game_strawberries gs
  join public.strawberry_points sp on sp.id=gs.point_id
  where gs.game_id=p_game
    and gs.active
    and (
      public.is_admin()
      or exists(
        select 1
        from public.game_players gp
        where gp.game_id=p_game
          and gp.player_id=public.current_player_id()
      )
      or (
        public.current_player_id() is not null
        and exists(
          select 1
          from public.games g
          where g.id=p_game
            and g.status='running'
        )
      )
    )
$$;

commit;
