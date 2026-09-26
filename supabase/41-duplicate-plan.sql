-- Kompletní kopie herního plánu včetně geometrie a všech herních bodů.

begin;

create or replace function public.duplicate_match_plan(p_match uuid,p_name text)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare src matches%rowtype; new_id uuid;
begin
  perform assert_admin();
  select * into src from matches where id=p_match;
  if not found then raise exception 'Plán neexistuje.'; end if;

  insert into matches(
    name,area,status,is_active,ready,footpaths_enabled,started_at,
    idle_timeout_s,outside_timeout_s,snap_tolerance_m,
    walk_speed_mps,run_speed_mps,sprint_speed_mps,sprint_range_m,
    snake_initial_length_m,strawberry_growth_m,game_duration_s,snake_speed_mps,
    strawberry_spawn_min_s,strawberry_spawn_max_s,strawberry_active_percent,
    max_lead_m,respawn_countdown_s,collision_radius_m,strawberry_radius_m
  ) values(
    coalesce(nullif(btrim(p_name),''),coalesce(src.name,'Plán') || ' – kopie'),
    src.area,'lobby',false,false,src.footpaths_enabled,null,
    src.idle_timeout_s,src.outside_timeout_s,src.snap_tolerance_m,
    src.walk_speed_mps,src.run_speed_mps,src.sprint_speed_mps,src.sprint_range_m,
    src.snake_initial_length_m,src.strawberry_growth_m,src.game_duration_s,src.snake_speed_mps,
    src.strawberry_spawn_min_s,src.strawberry_spawn_max_s,src.strawberry_active_percent,
    src.max_lead_m,src.respawn_countdown_s,src.collision_radius_m,src.strawberry_radius_m
  ) returning id into new_id;

  insert into street_edges(match_id,source_node,target_node,name,geom,enabled,is_foot)
    select new_id,source_node,target_node,name,geom,enabled,is_foot
    from street_edges where match_id=p_match;

  insert into respawn_points(match_id,label,geom)
    select new_id,label,geom from respawn_points where match_id=p_match;

  insert into strawberry_points(match_id,geom)
    select new_id,geom from strawberry_points where match_id=p_match;

  return new_id;
end $$;

commit;
