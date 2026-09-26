-- Couvnutí po posledním úseku budoucí trasy ho zkrátí místo toho, aby
-- vytvořilo dva překryté protisměrné úseky a pozdější vlastní kolizi.

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
  last_segment geometry;
  last_segment_m numeric;
  last_fraction numeric;
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
  last_segment:=ST_MakeLine(
    ST_PointN(old.route,ST_NPoints(old.route)-1),
    old_endpoint
  );
  last_segment_m:=ST_Length(last_segment::geography);
  search_end_m:=greatest(0,old_total_m-last_segment_m);

  -- Speciální případ couvnutí: bod je poblíž posledního segmentu a jeho
  -- projekce leží před koncem segmentu. Pokračování dopředu se promítne na
  -- samotný konec (fraction ~ 1), takže se omylem nezkrátí.
  if last_segment_m>0
     and ST_DWithin(last_segment::geography,new_point::geography,5) then
    last_fraction:=ST_LineLocatePoint(last_segment,new_point);
    if last_fraction<0.98 then
      candidate_point:=ST_ClosestPoint(last_segment,new_point);
      cut_m:=search_end_m+last_fraction*last_segment_m;
    end if;
  end if;

  -- Pokud nejde o prosté couvnutí po posledním úseku, hledáme návrat do
  -- libovolné starší části budoucí trasy jako dosud.
  if cut_m is null and search_end_m>coalesce(old.head_distance_m,0) then
    search_line:=ST_LineSubstring(
      old.route,
      greatest(0,least(1,coalesce(old.head_distance_m,0)/old_total_m)),
      greatest(0,least(1,search_end_m/old_total_m))
    );

    if search_line is not null and GeometryType(search_line)='LINESTRING' then
      select d.geom,d.path[1] into candidate_segment,candidate_index
      from ST_DumpSegments(search_line) d
      where ST_DWithin(d.geom::geography,new_point::geography,5)
        and ST_Distance(d.geom::geography,new_point::geography)+0.5
          < ST_Distance(d.geom::geography,old_endpoint::geography)
      order by d.path[1] desc,ST_Distance(d.geom::geography,new_point::geography)
      limit 1;

      if candidate_segment is not null then
        candidate_point:=ST_ClosestPoint(candidate_segment,new_point);
        select coalesce(sum(ST_Length(d.geom::geography)),0) into segment_prefix_m
        from ST_DumpSegments(search_line) d
        where d.path[1]<candidate_index;
        cut_m:=coalesce(old.head_distance_m,0)+segment_prefix_m+
          ST_Distance(ST_StartPoint(candidate_segment)::geography,candidate_point::geography);
      end if;
    end if;
  end if;

  if cut_m is null then return new; end if;

  -- Nikdy nesmíme zkrátit trasu za aktuální hlavu hada.
  cut_m:=greatest(coalesce(old.head_distance_m,0),least(old_total_m,cut_m));
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
