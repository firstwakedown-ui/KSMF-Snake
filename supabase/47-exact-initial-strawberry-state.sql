-- Create the initial strawberry state in one INSERT. This deliberately avoids
-- the active-limit UPDATE trigger; that trigger is only for later respawns.

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

  -- The current plan settings always win over the snapshot stored at creation.
  update games as game
  set
    strawberry_active_percent = plan.strawberry_active_percent,
    strawberry_initial_percent = plan.strawberry_initial_percent
  from matches as plan
  where game.id = p_game
    and plan.id = game.plan_id;

  select * into g from games where id = p_game;

  select count(*) into n
  from strawberry_points
  where match_id = g.plan_id;

  initial_count := least(
    n,
    greatest(
      0,
      ceil(n * coalesce(g.strawberry_initial_percent, 33) / 100.0)::int
    )
  );

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

  -- A lobby should not have rows yet, but clearing them makes a previously
  -- interrupted start deterministic as well.
  delete from game_strawberries where game_id = p_game;

  insert into game_strawberries(
    game_id, point_id, active, next_spawn_at, eaten_at
  )
  select
    p_game,
    ranked.id,
    ranked.position <= initial_count,
    case
      when ranked.position <= initial_count then null
      else now() + make_interval(
        secs => floor(
          random() * (
            coalesce(g.strawberry_spawn_max_s, 60)
            - coalesce(g.strawberry_spawn_min_s, 10)
            + 1
          ) + coalesce(g.strawberry_spawn_min_s, 10)
        )::int
      )
    end,
    null
  from (
    select
      sp.id,
      row_number() over(order by random()) as position
    from strawberry_points sp
    where sp.match_id = g.plan_id
  ) as ranked;
end
$$;

-- Admin diagnostic: shows the values actually used by a game and the exact
-- number of active rows. Handy for verifying a production game without guessing
-- from map icons.
create or replace function public.strawberry_game_diagnostics(p_game uuid)
returns table(
  plan_initial_percent int,
  plan_max_percent int,
  game_initial_percent int,
  game_max_percent int,
  total_points bigint,
  active_points bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  perform assert_admin();
  return query
  select
    m.strawberry_initial_percent,
    m.strawberry_active_percent,
    g.strawberry_initial_percent,
    g.strawberry_active_percent,
    count(gs.point_id),
    count(gs.point_id) filter (where gs.active)
  from games g
  join matches m on m.id = g.plan_id
  left join game_strawberries gs on gs.game_id = g.id
  where g.id = p_game
  group by
    m.strawberry_initial_percent,
    m.strawberry_active_percent,
    g.strawberry_initial_percent,
    g.strawberry_active_percent;
end
$$;

commit;
