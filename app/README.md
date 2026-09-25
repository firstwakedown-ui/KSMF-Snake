# app/ — Frontend (PWA)

React + Vite + TypeScript, mapa **MapLibre GL JS** + dlaždice **OpenFreeMap**, backend **Supabase**.

## Stav
**Prototyp #1** – mapa Praha–Barrandov (MVP; Kroměříž později), GPS přes `watchPosition` (~2 Hz), **Screen Wake Lock** (drží displej),
kreslení vlastní stopy. Slouží k ověření, že GPS + Wake Lock v PWA fungují v terénu (klíčové riziko z architektury).

## Spuštění (po instalaci Node.js)
```bash
cd app
npm install
cp .env.example .env   # doplň Supabase URL + anon key (nepovinné pro prototyp #1)
npm run dev            # otevře se na http://localhost:5173
```
> **GPS funguje jen přes HTTPS / localhost.** Na telefonu testuj přes nasazení (Vercel) nebo přes `vite --host` v zabezpečené síti.

## Co dál
- Napojení na Supabase Realtime (posílání pozic, zobrazení stop ostatních).
- Načtení grafu ulic z PostGIS + snapping.
- Android build přes Capacitor.
