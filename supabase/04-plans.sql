-- AchtungDieKM — Etapa 23: více hracích plánů (pojmenované konfigurace) + aktivní plán pro hru
-- Spusť přes tools/db/migrate PO 03-area-osm.sql.

begin;

-- Který plán hrají hráči. Právě jeden je "aktivní pro hru"; ostatní si admin chystá/edituje.
alter table matches add column if not exists is_active boolean not null default false;

-- Nastav daný plán jako aktivní (ostatní zhasne). Atomické.
create or replace function set_active_match(p_match uuid)
returns void
language plpgsql
as $$
begin
  update matches set is_active = false where is_active;
  update matches set is_active = true  where id = p_match;
end
$$;

commit;
