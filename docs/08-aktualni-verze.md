# KSMF Snake 2.0

KSMF Snake je současná podoba projektu: časovaná venkovní multiplayerová hra, ve které hráč chůzí připravuje trasu a jeho had se po ní pohybuje konstantní rychlostí.

## Aktuální herní model

- Had má omezenou délku; starší část těla průběžně mizí.
- Hlava se pohybuje stálou rychlostí po trase vytvořené hráčem.
- Příliš velký náskok i dohnání vlastním hadem končí výbuchem.
- Hlava sbírá jahůdky a tím prodlužuje tělo.
- Kolize s vlastním nebo cizím tělem způsobí výbuch, nikoli trvalé vyřazení.
- Hráč se vrací přes fyzicky dosažený respawn bod.
- Hra má pevný čas a tři samostatné výsledkové metriky.

## Výchozí pravidla

- délka hada 10 m;
- prodloužení za jahůdku 10 m;
- rychlost hada 3 km/h;
- délka hry 15 minut;
- spawn jahůdek náhodně za 10 až 60 sekund;
- maximální náskok 100 m;
- respawn odpočet 3 sekundy.

## Technický stav

Projekt běží samostatně na Vercelu a Supabase. Přihlášení hráčů a admina používá bezpečné serverové ověření, herní stav se rozhoduje v databázi a mapové podklady ulic mají vlastní odolnou Vercel bránu s několika veřejnými OpenStreetMap zdroji.

Podrobné ovládání popisují samostatné příručky pro hráče a admina. Níže na stránce lze rozbalit archivní deník původní hry AchtungDieKM, ze které projekt technicky vychází.
