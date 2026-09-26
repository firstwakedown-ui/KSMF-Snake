-- Vyšší tolerance návratu k budoucí trase pro reálnou GPS. Podmínka
-- přibližování brání tomu, aby se za smyčku považovala běžná chůze vpřed.

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
  old_endpoint geometry;
  candidate_segment geometry;
  candidate_point geometry;
  candidate_index int;
  segment_prefix_m numeric;
  cut_m numeric;
  cut_fraction numeric;
  kept geometry;
begin
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
  old_endpoint:=ST_EndPoint(old.route);
  search_end_m:=old_total_m-ST_Distance(
    ST_PointN(old.route,ST_NPoints(old.route)-1)::geography,
    old_endpoint::geography
  );

  if search_end_m<=coalesce(old.head_distance_m,0) then return new; end if;

  search_line:=ST_LineSubstring(
    old.route,
    greatest(0,least(1,coalesce(old.head_distance_m,0)/old_total_m)),
    greatest(0,least(1,search_end_m/old_total_m))
  );
  if search_line is null or GeometryType(search_line)<>'LINESTRING' then return new; end if;

  -- Nový bod může být až 5 m od dřívější trasy. Musí se k ní ale oproti
  -- předchozí poloze přiblížit alespoň o 0,5 m; pokračování vpřed po stejné
  -- ulici proto smyčku nespustí. Nejnovější shoda odstraní nejmenší smyčku.
  select d.geom,d.path[1] into candidate_segment,candidate_index
  from ST_DumpSegments(search_line) d
  where ST_DWithin(d.geom::geography,new_point::geography,5)
    and ST_Distance(d.geom::geography,new_point::geography)+0.5
      < ST_Distance(d.geom::geography,old_endpoint::geography)
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

  if ST_Distance(ST_EndPoint(kept)::geography,new_point::geography)>0.01 then
    kept:=ST_AddPoint(kept,new_point);
  end if;
  new.route:=kept;
  return new;
end $$;

commit;
