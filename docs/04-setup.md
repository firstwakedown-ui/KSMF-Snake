# AchtungDieKM — Setup (instalace nástrojů + založení projektů)

> Návod pro **Wake**. Kroky, které musíš udělat ty (instalace, registrace), jsou označené 🧑.
> Co připraví/udělá AI, je označené 🤖. Postupuj odshora dolů.

---

## A) Nástroje na počítači

### 🧑 1. Node.js (nutné pro frontend, Vite, Capacitor)
- Stáhni **LTS** verzi z <https://nodejs.org> a nainstaluj (necháš výchozí volby).
- Ověření (v novém PowerShellu): `node --version` a `npm --version` → měly by vypsat čísla.

### 🧑 2. Python (nutné jen pro přípravu grafu ulic z OSM — nástroj OSMnx)
- Stáhni **Python 3.12+** z <https://www.python.org/downloads/> a při instalaci zaškrtni **„Add Python to PATH"**.
- Ověření: `python --version` a `pip --version`.
- *(Pozn.: Java 11 už na počítači je — pro pozdější Android build se možná bude hodit novější JDK 17, vyřešíme až u APK.)*

> Po instalaci Node a Pythonu mi dej vědět — 🤖 spustím instalaci závislostí projektu a rozjedeme prototyp.

---

## B) Supabase (databáze + geo + realtime + přihlášení)

### 🧑 1. Účet a projekt
1. Jdi na <https://supabase.com> → **Sign in** (klidně přes GitHub `firstwakedown-ui`).
2. **New project**:
   - **Name:** `achtungdiekm`
   - **Database Password:** vygeneruj silné a **ulož si ho** (budeš ho potřebovat).
   - **Region:** vyber blízký (např. *Frankfurt / EU Central*).
3. Počkej ~2 min, než se projekt vytvoří.

### 🧑 2. Co mi pošleš (a co NE)
V **Project Settings → API** najdeš:
- ✅ **Project URL** (např. `https://xxxx.supabase.co`) — pošli mi.
- ✅ **anon public key** — pošli mi (je určený do frontendu, je veřejný).
- ⛔ **service_role key** — **NIKDY neposílej do chatu** ani nedávej do Gitu. Použiješ ho jen sám lokálně, když bude potřeba.

### 🤖 3. Co udělám já
- Připravím SQL pro **PostGIS** a tabulky (`supabase/schema.sql`) — ty ho jen spustíš v Supabase **SQL Editoru** (návod přidám).
- Napojím frontend na tvé URL + anon key přes `.env` (lokálně, mimo Git).

---

## C) Vercel (hosting frontendu / PWA)

### 🧑 1. Účet
1. Jdi na <https://vercel.com> → **Sign Up** přes **GitHub** (`firstwakedown-ui`) — propojí se ti rovnou repozitář.
2. Zatím **nic nenasazuj** — počkáme, až bude v repu připravený frontend (`app/`).

### 🤖 2. Co udělám já
- Až bude frontend hotový, připravím konfiguraci tak, aby Vercel buildil složku `app/`.
- Ty pak v Vercelu klikneš **Import Project → vyber repo `AchtungDieKM`** a nastavíš env proměnné (Supabase URL + anon key).

---

## D) Pořadí kroků (souhrn)
1. 🧑 Nainstaluj **Node** a **Python** (sekce A).
2. 🧑 Založ **Supabase** projekt a pošli mi **URL + anon key** (sekce B).
3. 🤖 Já napojím frontend, připravím DB schéma a OSM nástroj.
4. 🧑 Spustíme **prototyp #1** (mapa Praha–Barrandov + GPS + Wake Lock) lokálně.
5. 🧑 Založ **Vercel** a naimportuj repo (sekce C) — nasadíme PWA online.

> Kostra projektu (`app/`, `supabase/`, `tools/osm/`) je už v repu připravená — viz `README.md` v každé složce.
