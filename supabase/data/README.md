# Přenos mapových plánů

Soubor `plans.sql` je datový export aktuálních mapových plánů ze Supabase.
Obsahuje pouze:

- plány (`matches`),
- síť cest plánu (`street_edges`),
- původní startovní body (`start_points`),
- respawn body (`respawn_points`),
- body možného výskytu jahůdek (`strawberry_points`).

Neobsahuje účty, hráče, založené či odehrané hry, herní stav ani globální
`game_settings`.

## Vytvoření exportu

V kořeni repozitáře ve Windows PowerShellu:

```powershell
cd tools\db
.\set-secret.ps1       # jen pokud zde ještě není aktuální připojení k Supabase
.\export-plans.ps1
```

Výsledkem je `supabase/data/plans.sql`, který lze zkontrolovat a uložit do Gitu.
Connection string ani heslo se do exportu nezapisují.

## Import do Azure PostgreSQL

Cílová databáze musí mít předem aplikované aktuální migrace projektu a zapnutý
PostGIS. Import je určen primárně pro databázi, která ještě tyto plány neobsahuje.

```powershell
psql "AZURE_DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/data/plans.sql
```

Import probíhá v jedné transakci. Pokud narazí například na stejné UUID již
existujícího plánu, skončí chybou a nevloží jen část dat.
