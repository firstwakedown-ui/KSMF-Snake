-- Save strawberry percentages through an authenticated server function.
-- A direct client UPDATE can be filtered by RLS without changing any row.

begin;

create or replace function public.save_strawberry_settings(
  p_match uuid,
  p_active_percent int,
  p_initial_percent int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform assert_admin();

  if p_active_percent < 1 or p_active_percent > 100 then
    raise exception 'Maximum aktivních jahůdek musí být 1 až 100 %.';
  end if;
  if p_initial_percent < 0 or p_initial_percent > 100 then
    raise exception 'Počet jahůdek při startu musí být 0 až 100 %.';
  end if;

  update matches
  set
    strawberry_active_percent = p_active_percent,
    strawberry_initial_percent = p_initial_percent
  where id = p_match;

  if not found then
    raise exception 'Plán neexistuje.';
  end if;

  update games
  set
    strawberry_active_percent = p_active_percent,
    strawberry_initial_percent = p_initial_percent
  where plan_id = p_match
    and status = 'lobby';
end
$$;

commit;
