# AchtungDieKM — Vize a koncept

> Stav: **draft** — průběžně doplňováno během sběru požadavků. Verzováno v Gitu.

## Stručný popis (elevator pitch)
Multiplayerová **lokační hra v reálném světě**. Hráči fyzicky chodí/běhají po městě s mobilem.
GPS zaznamenává jejich trasu, která se v reálném čase vykresluje jako **čára (had / „světelná stopa")**
na mapě ulic. Hra je inspirovaná *Achtung, die Kurve!* a *Tron* — přenesená do reálného terénu.

## Základní herní smyčka (jak ji zatím chápeme)
1. Vybere se **území** (MVP: **Praha–Barrandov**; Kroměříž později).
2. Aplikace načte z mapových dat **graf ulic** vybraného území.
3. Hráči se fyzicky pohybují po ulicích; mobil průběžně posílá **GPS souřadnice** na server.
4. Server v **reálném čase** zakresluje trajektorie všech hráčů a všem je zobrazuje.
5. Čára hráče musí zůstat **na ulici / chodníku** — hráč „nesmí opustit chodník".
6. Když hráč **narazí do čáry jiného hráče → vypadává**.

## Klíčové prvky
- **Reálné území** a pohyb v něm (ne virtuální plocha).
- **GPS tracking** v reálném čase.
- **Server** jako autorita: sbírá pozice, vykresluje, vyhodnocuje kolize.
- **Graf ulic** z mapových dat (pravděpodobně OpenStreetMap) — definuje, kudy se smí.
- **Kolize** s cizí (a možná vlastní?) stopou = vyřazení.

## Otevřené otázky
_(viz `docs/02-pozadavky.md` — sekce k validaci)_
