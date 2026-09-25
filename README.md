# Achtung Die KM

Mobilní **lokační hra** v reálném městě (MVP: **Praha–Barrandov**; Kroměříž později). Hráči se fyzicky pohybují po ulicích,
GPS kreslí jejich **stopu** na mapě; kdo narazí do cizí (nebo vlastní) stopy, vypadává. Poslední přeživší vyhrává.
Inspirováno hrou *Achtung, die Kurve!* / *Tron* — přeneseno do reálného terénu.

**🟢 Živá ukázka (PWA):** <https://achtung-die-km.vercel.app/> — prototyp #1 (mapa Barrandova + GPS + stopa).

## Dokumentace (`docs/`)
- `00-denik-vyvoje.md` — deník vývoje (cesta projektu, „making of")
- `01-vize-a-koncept.md` — vize a koncept
- `02-pozadavky.md` — funkční a nefunkční požadavky (FR/NFR)
- `03-architektura.md` — návrh architektury a volba technologií
- `04-setup.md` — instalace nástrojů a založení projektů (Supabase, Vercel)

## Struktura repozitáře
- `app/` — frontend (React + Vite + MapLibre, PWA) → **prototyp #1**
- `supabase/` — databázové schéma (Postgres + PostGIS)
- `tools/osm/` — příprava grafu ulic z OpenStreetMap (OSMnx)

## Technologie
- **Frontend:** React + Vite + TypeScript (PWA), MapLibre GL JS, dlaždice OpenFreeMap; Android přes Capacitor
- **Backend:** Supabase (Postgres + PostGIS, Auth e-mail OTP, Realtime, Edge Functions)
- **Graf ulic:** OSMnx + NetworkX z OpenStreetMap

## Začínáme
Viz `docs/04-setup.md` (instalace Node.js a Pythonu, založení Supabase + Vercel projektů),
poté `app/README.md` pro spuštění prototypu.
