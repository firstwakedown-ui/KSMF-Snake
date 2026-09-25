-- AchtungDieKM — Run hra: zrychlit výchozí rychlosti 3× (z testu byl pohyb moc pomalý).
-- Spusť přes tools/db/migrate PO 26-run-mode.sql.

begin;

-- Nové výchozí hodnoty pro nově zakládané plány.
alter table matches alter column walk_speed_mps   set default 3.6;
alter table matches alter column run_speed_mps    set default 7.5;
alter table matches alter column sprint_speed_mps set default 12.0;

-- Existující plány: posuň jen ty, co mají ještě původní defaulty (ruční úpravy adminem nech být).
update matches set walk_speed_mps   = 3.6  where walk_speed_mps   = 1.2;
update matches set run_speed_mps    = 7.5  where run_speed_mps    = 2.5;
update matches set sprint_speed_mps = 12.0 where sprint_speed_mps = 4.0;

commit;
