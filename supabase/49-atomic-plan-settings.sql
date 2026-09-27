-- Apply after migration 48. All settings are saved atomically.
begin;
create or replace function public.save_plan_settings(p_match uuid, p_settings jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v matches%rowtype; result matches%rowtype;
begin
  perform assert_admin();
  select * into v from matches where id=p_match for update;
  if not found then raise exception 'Plán neexistuje.'; end if;
  if p_settings is null or jsonb_typeof(p_settings)<>'object' then
    raise exception 'Chybí nastavení plánu.';
  end if;
  if exists(select 1 from jsonb_object_keys(p_settings) k where k <> all(array['idle_timeout_s','outside_timeout_s','snap_tolerance_m','walk_speed_mps','run_speed_mps','sprint_speed_mps','sprint_range_m','snake_initial_length_m','strawberry_growth_m','game_duration_s','snake_speed_mps','strawberry_spawn_min_s','strawberry_spawn_max_s','strawberry_active_percent','strawberry_initial_percent','max_lead_m','respawn_countdown_s','self_collision_grace_m'])) then
    raise exception 'Neznámý parametr nastavení.';
  end if;
  if exists(select 1 from jsonb_each(p_settings) e where jsonb_typeof(e.value)<>'number') then
    raise exception 'Nastavení musí obsahovat čísla.';
  end if;
  v := jsonb_populate_record(v, p_settings);
  if v.snake_initial_length_m<1 or v.strawberry_growth_m<1
    or v.game_duration_s<60 or v.snake_speed_mps<=0
    or v.strawberry_spawn_min_s<1 or v.strawberry_spawn_max_s<v.strawberry_spawn_min_s
    or v.strawberry_active_percent not between 1 and 100
    or v.strawberry_initial_percent not between 0 and 100
    or v.max_lead_m<5 or v.respawn_countdown_s<0 or v.self_collision_grace_m<0
    or v.idle_timeout_s<5 or v.outside_timeout_s<3 or v.snap_tolerance_m<5
    or v.walk_speed_mps<=0 or v.run_speed_mps<=0 or v.sprint_speed_mps<=0 or v.sprint_range_m<1
  then raise exception 'Neplatný rozsah nastavení nebo interval jahůdek.'; end if;
  update matches set
    idle_timeout_s = v.idle_timeout_s,
    outside_timeout_s = v.outside_timeout_s,
    snap_tolerance_m = v.snap_tolerance_m,
    walk_speed_mps = v.walk_speed_mps,
    run_speed_mps = v.run_speed_mps,
    sprint_speed_mps = v.sprint_speed_mps,
    sprint_range_m = v.sprint_range_m,
    snake_initial_length_m = v.snake_initial_length_m,
    strawberry_growth_m = v.strawberry_growth_m,
    game_duration_s = v.game_duration_s,
    snake_speed_mps = v.snake_speed_mps,
    strawberry_spawn_min_s = v.strawberry_spawn_min_s,
    strawberry_spawn_max_s = v.strawberry_spawn_max_s,
    strawberry_active_percent = v.strawberry_active_percent,
    strawberry_initial_percent = v.strawberry_initial_percent,
    max_lead_m = v.max_lead_m,
    respawn_countdown_s = v.respawn_countdown_s,
    self_collision_grace_m = v.self_collision_grace_m
  where id=p_match returning * into result;
  update games set
    idle_timeout_s = v.idle_timeout_s,
    outside_timeout_s = v.outside_timeout_s,
    snap_tolerance_m = v.snap_tolerance_m,
    walk_speed_mps = v.walk_speed_mps,
    run_speed_mps = v.run_speed_mps,
    sprint_speed_mps = v.sprint_speed_mps,
    sprint_range_m = v.sprint_range_m,
    snake_initial_length_m = v.snake_initial_length_m,
    strawberry_growth_m = v.strawberry_growth_m,
    game_duration_s = v.game_duration_s,
    snake_speed_mps = v.snake_speed_mps,
    strawberry_spawn_min_s = v.strawberry_spawn_min_s,
    strawberry_spawn_max_s = v.strawberry_spawn_max_s,
    strawberry_active_percent = v.strawberry_active_percent,
    strawberry_initial_percent = v.strawberry_initial_percent,
    max_lead_m = v.max_lead_m,
    respawn_countdown_s = v.respawn_countdown_s,
    self_collision_grace_m = v.self_collision_grace_m
  where plan_id=p_match and status='lobby';
  return to_jsonb(result);
end $$;

-- Older create_game versions omitted the joystick speed settings.
-- Copy all settings for every newly created game regardless of RPC version.
create or replace function public.copy_plan_settings_to_new_game()
returns trigger language plpgsql security definer set search_path=public as $$
declare v matches%rowtype;
begin
  select * into v from matches where id=new.plan_id;
  if not found then raise exception 'Plán neexistuje.'; end if;
  new.idle_timeout_s := v.idle_timeout_s;
  new.outside_timeout_s := v.outside_timeout_s;
  new.snap_tolerance_m := v.snap_tolerance_m;
  new.walk_speed_mps := v.walk_speed_mps;
  new.run_speed_mps := v.run_speed_mps;
  new.sprint_speed_mps := v.sprint_speed_mps;
  new.sprint_range_m := v.sprint_range_m;
  new.snake_initial_length_m := v.snake_initial_length_m;
  new.strawberry_growth_m := v.strawberry_growth_m;
  new.game_duration_s := v.game_duration_s;
  new.snake_speed_mps := v.snake_speed_mps;
  new.strawberry_spawn_min_s := v.strawberry_spawn_min_s;
  new.strawberry_spawn_max_s := v.strawberry_spawn_max_s;
  new.strawberry_active_percent := v.strawberry_active_percent;
  new.strawberry_initial_percent := v.strawberry_initial_percent;
  new.max_lead_m := v.max_lead_m;
  new.respawn_countdown_s := v.respawn_countdown_s;
  new.self_collision_grace_m := v.self_collision_grace_m;
  new.collision_radius_m := v.collision_radius_m;
  new.strawberry_radius_m := v.strawberry_radius_m;
  return new;
end $$;
drop trigger if exists games_copy_plan_settings on public.games;
create trigger games_copy_plan_settings before insert on public.games
for each row execute function public.copy_plan_settings_to_new_game();
commit;

