# AchtungDieKM — Návrh architektury (MVP)

> Stav: **návrh po prvním kole rozhodnutí (2026-06-26).** Vychází z `docs/02-pozadavky.md` a rešerše open-source technologií.
> Cíl: technologie, které sedí na zadání — PWA, real-time stopy, autoritativní vyhodnocení, graf ulic z OSM, snapping.

---

## 0. Rozhodnutí (2026-06-26)
| # | Téma | Rozhodnutí |
|---|------|-----------|
| 1 | Frontend framework | **React** (+ Vite + TypeScript), jako PWA |
| 2 | Obsazení ulice / kolize | **Jen projetá část** ulice (ne celá hrana) → stopa = lomená čára, kolize = průnik čar |
| 3 | Balení appky | **Základ = PWA**, ale **rovnou i Android APK** (přes Capacitor) — kvůli spolehlivému GPS |
| 4 | Hosting / backend | **Supabase** (DB + Auth + Realtime + Edge Functions) a **Vercel** (frontend) |

➡️ Důsledek bodu 4: **nepoužíváme samostatný Colyseus/Node server.** Autoritu řešíme **událostně** přes Supabase
Edge Functions + **PostGIS**. Pro náš rozsah (5–10 hráčů, ~1–2 GPS/s) to plně stačí (viz trade-off v sekci 4).

---

## 1. Co architektura musí splnit (z požadavků)
- **PWA** (web) + **Android APK**, bez iOS. *(NFR-08, rozhodnutí #3)*
- **Autoritativní vyhodnocení** kolizí, obsazení, vyřazení na serveru. *(NFR-03)*
- **Real-time**: 5–10 hráčů, ~0,5 km², plynulé stopy všech u všech. *(NFR-01, NFR-02, FR-24)*
- **Mapa = graf** ulic z **OpenStreetMap**. *(FR-03, NFR-10)*
- **Snapping** GPS na nejbližší ulici (default 30 m, nastavitelné). *(FR-26, NFR-04)*
- **Robustnost** vůči výpadku GPS/signálu (interpolace + pojistky). *(FR-27, NFR-05)*

---

## 2. Technologický stack

| Oblast | Volba | Proč sedí na zadání |
|--------|-------|---------------------|
| **Vykreslení mapy** | **MapLibre GL JS** | Open-source, **WebGL/GPU** — plynule zvládne stopy všech hráčů; bez API klíče. |
| **Mapové dlaždice** | **OpenFreeMap** (veřejná instance) | Zdarma, bez klíče, vektorové dlaždice z OSM, nativně pro MapLibre. |
| **Frontend (PWA)** | **React + Vite + TypeScript** | Zralý ekosystém, dobrá podpora MapLibre, snadné PWA (service worker, instalace). |
| **Android APK** | **Capacitor** | Zabalí stejný web kód do nativní Android appky; umožní **background-geolocation** plugin (spolehlivé GPS i při zhasnuté obrazovce). |
| **Databáze + geo** | **Supabase Postgres + PostGIS** | Geo-dotazy přímo v DB: `ST_ClosestPoint` (snapping), `ST_Intersects`/`ST_DWithin` (kolize), `ST_DWithin` (zóny). Uloží graf, stopy, konfiguraci. |
| **Přihlášení** | **Supabase Auth (e-mail OTP)** | Vestavěné přihlášení **kódem na e-mail** = přesně náš PIN (FR-20). Žádná vlastní logika hesel. |
| **Real-time přenos** | **Supabase Realtime** (Broadcast + Presence) | Rozesílání pozic/stop všem hráčům v zápase; Presence = kdo je připojen / dorazil na start. |
| **Herní logika (autorita)** | **Supabase Edge Functions** (Deno/TS) | Každý příchozí GPS update spustí funkci: snap → kolize → obsazení → vyřazení. Logika běží na serveru (autorita), ne v klientovi. |
| **Snapping/geometrie (klient)** | **Turf.js** | Vyhlazení/odhad na klientu (plynulý pohyb), těžké výpočty řeší PostGIS na serveru. |
| **Příprava grafu z OSM** | **OSMnx + NetworkX** (Python, offline) | Jednorázově stáhne pěší síť (MVP: Praha–Barrandov), postaví graf (uzly = křižovatky/náměstí), export do GeoJSON → import do PostGIS. |

**Jednou větou:** *React PWA (Vercel) s MapLibre + OpenFreeMap → přes Supabase Realtime posílá GPS →
Edge Function v PostGIS snapuje na graf (z OSMnx) a vyhodnocuje kolize → stav se realtime rozesílá všem. Android APK přes Capacitor.*

---

## 3. Komponenty a tok dat

```
   [ Telefon hráče ]                              [ Supabase (backend, autorita) ]
   React PWA / Android APK (Capacitor)            ┌────────────────────────────────────┐
   - GPS (watchPosition / bg-geolocation)         │ Auth (e-mail OTP = PIN)            │
   - Screen Wake Lock                  Realtime   │ Postgres + PostGIS:               │
   - MapLibre: stopy + starty      ◄────────────► │   graf ulic, stopy, obsazení, hráči│
   - posílá svou polohu                           │ Edge Function (na každý GPS update):│
                                                   │   snap → kolize → obsazení → výsl.  │
       [ Vercel ]  hosting PWA                     │ Realtime: rozesílá stav všem       │
                                                   └─────────────┬──────────────────────┘
                                                     import grafu │ (jednorázově / při změně oblasti)
                                              [ GeoJSON grafu ulic ]
                                                                  ▲
                                            offline příprava      │
                                      [ OSMnx + NetworkX (Python) ] ◄── OpenStreetMap (Overpass)
```

**Průběh zápasu:**
1. *(Offline)* OSMnx stáhne oblast (MVP: Praha–Barrandov) → graf (uzly/hrany) → GeoJSON → import do PostGIS.
2. Admin nakreslí oblast, povolené/zakázané spojnice a startovní body → uloží do Supabase.
3. Hráči se přihlásí (e-mail OTP), dorazí na starty; Presence hlásí „všichni na místě" → admin **START** → odpočet.
4. Telefon posílá GPS přes Realtime; **Edge Function** polohu **snapuje** na hranu (PostGIS) a aktualizuje stopu.
5. Edge Function vyhodnotí **kolize** (průnik s cizí/vlastní stopou mimo uzly), **uvíznutí**, **časovače** → vyřazení.
6. Realtime rozešle stav → každý vidí **stopy všech** v reálném čase.
7. Poslední přeživší vyhrává. *(Později: PDF výsledků.)*

---

## 4. ⚠️ Dvě klíčová rizika a jejich řešení

**(a) GPS v PWA při zhasnuté obrazovce.** Prohlížeč přestane hlásit polohu, když zhasne displej / appka jde do pozadí (hlavně Android).
- MVP (PWA): **Screen Wake Lock** drží displej rozsvícený (hráč stejně kouká do mapy).
- **Android APK (Capacitor)** s background-geolocation pluginem → spolehlivé GPS i na pozadí. Proto děláme APK rovnou (rozhodnutí #3).

**(b) Supabase nemá trvale běžící „herní smyčku".** Autoritu proto řešíme **událostně**: každý GPS update spustí Edge Function,
která v PostGIS provede snap + kontrolu kolizí + zápis. Časovače (nečinnost / mimo zónu 30 s) se kontrolují při každém updatu
(čas od poslední změny) a/nebo plánovačem. **Pro 5–10 hráčů a ~1–2 polohy/s to plně stačí.**
*Pokud by real-time časem vyžadoval souvislé tikání, doplníme malý always-on server (např. Fly.io) — pro MVP zbytečné.*

---

## 5. Model kolizí — „jen projetá část" (rozhodnutí #2)
- Stopa hráče = **lomená čára (`LINESTRING`)**, která průběžně roste podle GPS.
- **Kolize = průnik** mé nové polohy/úseku s existující stopou (cizí i vlastní) — `ST_Intersects` v PostGIS.
- **Výjimka v uzlu (křižovatce):** křížení je povolené, pokud k němu dojde **v okolí uzlu** a existuje volná výjezdová hrana
  (řeší logiku X vs. T křižovatky). Technicky: průnik blíž než *r* od uzlu se nepočítá jako srážka, pokud je kudy pokračovat.
- **Uvíznutí (FR-06):** v uzlu nezbývá žádná volná výjezdová hrana → vyřazení.
- Tolerance a poloměr uzlu = nastavitelné (souvisí s NFR-04, default 30 m).

> Tohle je nejcitlivější část hratelnosti — doladí se měřením v terénu v prototypu.

---

## 6. Nasazení (MVP)
- **Frontend (PWA):** **Vercel** (statický build Reactu).
- **Android APK:** **Capacitor** build ze stejného kódu.
- **Backend:** **Supabase** (Postgres+PostGIS, Auth, Realtime, Edge Functions).
- **Dlaždice:** OpenFreeMap (bez klíče).
- **Graf:** GeoJSON z OSMnx importovaný do PostGIS.

---

## 7. Co do MVP a co později
**MVP:** React PWA + MapLibre/OpenFreeMap, Supabase Realtime, GPS + Wake Lock, snapping a kolize v PostGIS,
graf z OSM (MVP: Praha–Barrandov), start s odpočtem, bezpečnostní upozornění. Účty zjednoduše přes e-mail OTP (jde to ze Supabase zadarmo).
Android APK přes Capacitor jako druhý build.

**Po MVP:** pozvánky, PDF výsledků, vyladěné UI, upozornění na slabý signál, případně always-on herní server pro jemnější real-time.

---

## 8. Rozhodnutí (2026-06-26, 2. kolo)
1. ✅ **Background-geolocation plugin pro Capacitor:** použít **komunitní (zdarma)**; placený řešit jen kdyby nestačil.
2. ✅ **Frekvence GPS: 2 Hz** (poloha 2× za sekundu); doladit dle baterie/přesnosti.
3. ✅ **Účty až po prototypu** — pro první test stačí přezdívka (Supabase Auth doplníme později).
4. ✅ **Projekty Supabase/Vercel zatím nejsou** → návod v `docs/04-setup.md`, kostra projektu připravena v repu.
