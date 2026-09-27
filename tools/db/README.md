# tools/db/ — Migrace databáze (bezpečně, bez plaintext hesla)

Spouští SQL soubory proti Supabase/Postgres. Heslo (connection string) je uložené **zašifrovaně**
přes **Windows DPAPI** mimo repozitář — v plaintextu nikde není a do Gitu se nedostane.

## Jak to funguje
- `set-secret.ps1` — jednorázově uloží connection string zašifrovaně do `%APPDATA%\achtungdiekm\db-url.secret`
  (dešifrovat ho umí jen tvůj Windows účet na tomto PC).
- `migrate.ps1` — tajemství dešifruje do paměti, předá ho `migrate.py` přes proměnnou prostředí
  (neloguje se), a spustí zadané SQL soubory.
- `migrate.py` — připojí se přes `psycopg` a vykoná SQL.

## První nastavení
```powershell
cd tools/db
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
.\set-secret.ps1          # vlož Supabase connection string (URI, Session pooler)
```

## Použití (kdykoliv při změnách DB)
```powershell
cd tools/db
.\migrate.ps1 ..\..\supabase\schema.sql
.\migrate.ps1 ..\..\supabase\import_graph.sql
```

## Export mapových plánů pro jiný PostgreSQL

```powershell
cd tools/db
.\export-plans.ps1
```

Vytvoří `supabase/data/plans.sql`. Export obsahuje pouze mapové plány, jejich
cesty, startovní/respawn body a jahůdkové body. Neobsahuje hráče, hry, herní
stav ani přístupové údaje. Podrobný návod k importu je v
`supabase/data/README.md`.

## Bezpečnost
- Connection string **neposílej do chatu** ani nedávej do Gitu.
- Šifrovaný soubor je vázaný na tvůj účet + počítač (DPAPI) — jinde se nedešifruje.
- `*.venv` i `%APPDATA%` jsou mimo repozitář.
