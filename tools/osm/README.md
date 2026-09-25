# tools/osm/ — Příprava grafu ulic z OpenStreetMap

Jednorázový (offline) krok: stáhne z OSM pěší síť ulic Praha–Barrandov (MVP; Kroměříž později)
a vygeneruje **SQL pro import do PostGIS** (Supabase).

## Spuštění
```powershell
cd tools/osm
python -m venv .venv
.venv\Scripts\python.exe -m pip install osmnx
.venv\Scripts\python.exe build_graph.py
```

Výstup: **`../../supabase/import_graph.sql`** (tj. `supabase/import_graph.sql`).

## Import do Supabase
1. V Supabase → **SQL Editor → New query**.
2. Vlož obsah `supabase/import_graph.sql` a **Run** (předtím musí být spuštěné `supabase/schema.sql`).
3. Skript nejdřív `truncate` tabulky grafu a pak vloží uzly a hrany — dá se pouštět opakovaně.

## Pozn.
- Oblast je zatím bounding box Barrandova (`WEST/SOUTH/EAST/NORTH` v `build_graph.py`).
  Po nakreslení herní oblasti adminem ho nahradíme polygonem.
- `network_type="walk"` = pěší síť (chodníky, cesty, pěší zóny, obytné ulice).
- Aktuální export: **40 uzlů, 92 hran**.
