# supabase/ — Databáze, geo, realtime, auth

Backend běží na **Supabase** (Postgres + PostGIS + Realtime + Edge Functions + Auth).

## Nasazení schématu
1. V Supabase otevři **SQL Editor → New query**.
2. Vlož obsah `schema.sql` a klikni **Run**.
3. Ověř v **Table Editor**, že vznikly tabulky `street_nodes`, `street_edges`, `matches`, `players`, `match_players`, `trails`.

## Import grafu ulic (Barrandov)
1. Po `schema.sql` spusť stejným způsobem **`import_graph.sql`** (vygenerováno `tools/osm/build_graph.py` z OpenStreetMap).
2. Naplní `street_nodes` (40) a `street_edges` (92) pěší sítí Barrandova. Skript je idempotentní (na začátku `truncate`).

## RLS politiky (důležité!)
Supabase u nových tabulek **automaticky zapíná RLS** → bez politik `anon` (frontend) nic nevidí.
Spusť **`policies_prototype.sql`** — povolí veřejné čtení grafu a (dočasně) anonymní přístup k herním tabulkám.
⚠️ Před ostrým provozem nahradit politikami vázanými na Auth.

## Doporučený způsob spouštění
Místo ručního kopírování do SQL editoru použij migrační nástroj `tools/db/` (heslo šifrované přes DPAPI):
```powershell
cd tools/db
.\migrate.ps1 ..\..\supabase\schema.sql ..\..\supabase\import_graph.sql ..\..\supabase\policies_prototype.sql
```

## Geo operace (kde se počítá herní logika)
- **Snapping:** `ST_ClosestPoint(edge.geom, point)` + `ST_DWithin(edge.geom, point, tol)` (tolerance default 30 m).
- **Kolize:** `ST_Intersects(novy_usek, cizi_stopa.geom)` (mimo okolí uzlu – povolené křížení v křižovatce).
- **Mimo zónu:** `NOT ST_Contains(match.area, point)`.

## Co dál
- Edge Function, která na každý GPS update provede snap → kolize → zápis (autorita).
- RLS politiky a Auth (e-mail OTP = PIN) – až po prototypu.
