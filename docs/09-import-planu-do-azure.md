# Import herních plánů do Azure PostgreSQL

Export aktuálních herních plánů ze Supabase je uložený v repozitáři KSMF Snake.

## Obsah exportu

- 4 herní plány
- 2 285 úseků cest
- 46 respawn bodů
- 155 jahůdkových bodů

Export neobsahuje hráče, založené ani odehrané hry, herní stav, hesla nebo jiné
přístupové údaje.

## Soubory

- [Datový export `plans.sql`](https://github.com/firstwakedown-ui/KSMF-Snake/blob/main/supabase/data/plans.sql)
- [Podrobný návod v repozitáři](https://github.com/firstwakedown-ui/KSMF-Snake/blob/main/supabase/data/README.md)
- Commit s exportem: `2b596e9`

## Požadavky na cílovou databázi

Před importem musí mít Azure PostgreSQL:

1. aplikované všechny aktuální SQL migrace projektu KSMF Snake,
2. zapnuté rozšíření PostGIS,
3. odpovídající aktuální databázové schéma.

## Import

V kořeni staženého repozitáře spusť:

```powershell
psql "AZURE_DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/data/plans.sql
```

`AZURE_DATABASE_URL` nahraď připojovacím řetězcem cílové Azure PostgreSQL
databáze. Připojovací řetězec ani heslo neukládej do Gitu.

Import probíhá v jedné databázové transakci. Pokud například narazí na již
existující plán se stejným UUID nebo na neodpovídající databázové schéma, skončí
chybou a nevloží pouze část dat.
