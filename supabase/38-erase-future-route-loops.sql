-- Automaticky vymaže smyčku pouze z dosud neprojeté trasy před hlavou hada.
-- Tělo a projetá část za hlavou se nikdy nemění.

begin;

create or replace function public.erase_snake_future_loop()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  old_total_m numeric;
  search_end_m numeric;
  search_line geometry;
  new_point geometry;
  candidate_segment geometry;
  candidate_point geometry;
  candidate_index int;
  segment_prefix_m numeric;
  cut_m numeric;
  cut_fraction numeric;
  kept geometry;
begin
  -- Smyčku hledáme jen ve chvíli, kdy snake_tick přidal nový koncový bod.
  if old.route is null or new.route is null
     or GeometryType(old.route)<>'LINESTRING'
     or GeometryType(new.route)<>'LINESTRING'
     or ST_NPoints(old.route)<2
     or ST_NPoints(new.route)<=ST_NPoints(old.route) then
    return new;
  end if;

  old_total_m:=ST_Length(old.route::geography);
  if old_total_m<=0 then return new; end if;

  new_point:=ST_EndPoint(new.route);

  -- Poslední sousední segment není smyčka: nový bod na něj běžně navazuje.
  -- Jeho počáteční bod ale zůstává součástí prohledávané starší trasy, takže
  -- i krátké otočení zpět se stále správně odstraní.
  search_end_m:=old_total_m-ST_Distance(
    ST_PointN(old.route,ST_NPoints(old.route)-1)::geography,
    ST_EndPoint(old.route)::geography
  );

  if search_end_m<=coalesce(old.head_distance_m,0) then return new; end if;

  search_line:=ST_LineSubstring(
    old.route,
    greatest(0,least(1,coalesce(old.head_distance_m,0)/old_total_m)),
    greatest(0,least(1,search_end_m/old_total_m))
  );
  if search_line is null or GeometryType(search_line)<>'LINESTRING' then return new; end if;

  -- Vezmeme nejnovější vhodný segment, aby se odstranila jen nejmenší
  -- vzniklá smyčka. Tolerance 1,5 m zachytí i drobné GPS zakolísání.
  select d.geom,d.path[1] into candidate_segment,candidate_index
  from ST_DumpSegments(search_line) d
  where ST_DWithin(d.geom::geography,new_point::geography,1.5)
  order by d.path[1] desc,ST_Distance(d.geom::geography,new_point::geography)
  limit 1;

  if candidate_segment is null then return new; end if;

  candidate_point:=ST_ClosestPoint(candidate_segment,new_point);
  select coalesce(sum(ST_Length(d.geom::geography)),0) into segment_prefix_m
  from ST_DumpSegments(search_line) d
  where d.path[1]<candidate_index;

  cut_m:=coalesce(old.head_distance_m,0)+segment_prefix_m+
    ST_Distance(ST_StartPoint(candidate_segment)::geography,candidate_point::geography);
  cut_fraction:=greatest(0,least(1,cut_m/old_total_m));

  if cut_fraction<=0 then
    kept:=ST_MakeLine(ST_StartPoint(old.route),ST_StartPoint(old.route));
  else
    kept:=ST_LineSubstring(old.route,0,cut_fraction);
  end if;

  -- K nalezenému místu návratu připojíme přesnou aktuální snapped polohu.
  if ST_Distance(ST_EndPoint(kept)::geography,new_point::geography)>0.01 then
    kept:=ST_AddPoint(kept,new_point);
  end if;
  new.route:=kept;
  return new;
end $$;

drop trigger if exists snake_states_erase_future_loop on public.snake_states;
create trigger snake_states_erase_future_loop
before update of route on public.snake_states
for each row execute function public.erase_snake_future_loop();

commit;
