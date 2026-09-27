-- Existing lobby games contain a settings snapshot created with the game.
-- Keep their strawberry percentages aligned with the current plan settings.
update public.games as g
set
  strawberry_active_percent = m.strawberry_active_percent,
  strawberry_initial_percent = m.strawberry_initial_percent
from public.matches as m
where g.plan_id = m.id
  and g.status = 'lobby';
