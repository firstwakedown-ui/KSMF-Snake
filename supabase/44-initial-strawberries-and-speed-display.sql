-- Počáteční procento jahůdek se při startu uplatní přesně, bez omezení
-- průběžným maximem. Maximální limit platí až pro následné respawny.

begin;

create or replace function public.enforce_strawberry_active_limit()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_total int; v_active int; v_limit int; v_percent int;
begin
  -- run_game si pouze pro počáteční losování nastaví tuto transakční značku.
  if current_setting('app.initializing_strawberries',true)='1' then return new; end if;
  if new.active and not old.active then
    select count(*) into v_total from game_strawberries where game_id=new.game_id;
    select coalesce(strawberry_active_percent,100) into v_percent from games where id=new.game_id;
    v_limit:=ceil(v_total*greatest(1,least(100,v_percent))/100.0);
    select count(*) into v_active from game_strawberries where game_id=new.game_id and active and point_id<>new.point_id;
    if v_active>=v_limit then
      new.active:=false;
      new.next_spawn_at:=coalesce(old.next_spawn_at,clock_timestamp());
    end if;
  end if;
  return new;
end $$;

create or replace function public.run_game(p_game uuid)
returns void language plpgsql security definer set search_path=public as $$
declare g games%rowtype; n int; initial_count int;
begin
  perform assert_admin();
  select * into g from games where id=p_game for update;
  if g.status<>'lobby' then return; end if;
  if not exists(select 1 from game_players where game_id=p_game) then raise exception 'Ke hře není připojený žádný hráč.'; end if;
  update games set status='running',started_at=now(),finished_at=null where id=p_game;
  insert into snake_states(game_id,player_id,current_length_m,max_length_m,target_length_m,tail_distance_m)
    select p_game,gp.player_id,coalesce(g.snake_initial_length_m,10),coalesce(g.snake_initial_length_m,10),coalesce(g.snake_initial_length_m,10),0
    from game_players gp where gp.game_id=p_game on conflict do nothing;
  insert into game_strawberries(game_id,point_id,active,next_spawn_at)
    select p_game,sp.id,false,now()+make_interval(secs=>floor(random()*(coalesce(g.strawberry_spawn_max_s,60)-coalesce(g.strawberry_spawn_min_s,10)+1)+coalesce(g.strawberry_spawn_min_s,10))::int)
    from strawberry_points sp where sp.match_id=g.plan_id on conflict do nothing;
  select count(*) into n from game_strawberries where game_id=p_game;
  initial_count:=ceil(n*coalesce(g.strawberry_initial_percent,33)/100.0);
  perform set_config('app.initializing_strawberries','1',true);
  update game_strawberries set active=true,next_spawn_at=null
  where (game_id,point_id) in (
    select game_id,point_id from game_strawberries where game_id=p_game order by random() limit initial_count
  );
  perform set_config('app.initializing_strawberries','0',true);
end $$;

commit;
