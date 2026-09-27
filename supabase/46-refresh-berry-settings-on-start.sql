-- The plan is the authoritative source for strawberry percentages.
-- Refresh the game's snapshot immediately before every game start, so even a
-- lobby created before the settings were changed starts with current values.

begin;

create or replace function public.run_game(p_game uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  g games%rowtype;
  n int;
  initial_count int;
begin
  perform assert_admin();

  select * into g
  from games
  where id = p_game
  for update;

  if not found then
    raise exception 'Hra neexistuje.';
  end if;
  if g.status <> 'lobby' then
    return;
  end if;
  if not exists(select 1 from game_players where game_id = p_game) then
    raise exception 'Ke hře není připojený žádný hráč.';
  end if;

  update games as game
  set
    strawberry_active_percent = plan.strawberry_active_percent,
    strawberry_initial_percent = plan.strawberry_initial_percent
  from matches as plan
  where game.id = p_game
    and plan.id = game.plan_id;

  -- Reload the row so the initial activation uses the freshly copied values.
  select * into g from games where id = p_game;

  update games
  set status = 'running', started_at = now(), finished_at = null
  where id = p_game;

  insert into snake_states(
    game_id, player_id, current_length_m, max_length_m,
    target_length_m, tail_distance_m
  )
  select
    p_game, gp.player_id,
    coalesce(g.snake_initial_length_m, 10),
    coalesce(g.snake_initial_length_m, 10),
    coalesce(g.snake_initial_length_m, 10),
    0
  from game_players gp
  where gp.game_id = p_game
  on conflict do nothing;

  insert into game_strawberries(game_id, point_id, active, next_spawn_at)
  select
    p_game,
    sp.id,
    false,
    now() + make_interval(
      secs => floor(
        random() * (
          coalesce(g.strawberry_spawn_max_s, 60)
          - coalesce(g.strawberry_spawn_min_s, 10)
          + 1
        ) + coalesce(g.strawberry_spawn_min_s, 10)
      )::int
    )
  from strawberry_points sp
  where sp.match_id = g.plan_id
  on conflict do nothing;

  select count(*) into n
  from game_strawberries
  where game_id = p_game;

  initial_count := ceil(
    n * coalesce(g.strawberry_initial_percent, 33) / 100.0
  );

  perform set_config('app.initializing_strawberries', '1', true);

  update game_strawberries
  set active = true, next_spawn_at = null
  where (game_id, point_id) in (
    select game_id, point_id
    from game_strawberries
    where game_id = p_game
    order by random()
    limit initial_count
  );

  perform set_config('app.initializing_strawberries', '0', true);
end
$$;

commit;
