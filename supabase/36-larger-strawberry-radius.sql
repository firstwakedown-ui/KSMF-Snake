-- Mírně tolerantnější průjezd hlavy kolem jahůdky (původně 5 m).

begin;

alter table public.matches alter column strawberry_radius_m set default 7;
update public.matches set strawberry_radius_m=7;
update public.games set strawberry_radius_m=7;

commit;
