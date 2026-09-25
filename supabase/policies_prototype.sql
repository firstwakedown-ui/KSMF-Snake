-- AchtungDieKM — prototypové RLS politiky (zatím BEZ přihlášení).
-- ⚠️ DOČASNÉ: před ostrým provozem nahradit politikami vázanými na Supabase Auth
--    (např. zápis do trails jen pro vlastníka hráče). Viz docs/03-architektura.md.
--
-- Supabase u nových tabulek zapíná RLS automaticky → bez politik anon nic nevidí.
-- Tyto politiky čtení/zápis povolí, aby prototyp fungoval.

-- Graf ulic: veřejné čtení (veřejná OSM data).
drop policy if exists street_nodes_read on street_nodes;
create policy street_nodes_read on street_nodes for select using (true);

drop policy if exists street_edges_read on street_edges;
create policy street_edges_read on street_edges for select using (true);

-- Herní tabulky: pro prototyp plný anonymní přístup (dočasné).
drop policy if exists matches_all on matches;
create policy matches_all on matches for all using (true) with check (true);

drop policy if exists players_all on players;
create policy players_all on players for all using (true) with check (true);

drop policy if exists match_players_all on match_players;
create policy match_players_all on match_players for all using (true) with check (true);

drop policy if exists trails_all on trails;
create policy trails_all on trails for all using (true) with check (true);
