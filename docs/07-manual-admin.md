# KSMF Snake - příručka pro admina

Admin připravuje mapové plány, respawn a jahůdkové body, nastavuje pravidla, vytváří hry, sleduje jejich průběh a vyhodnocuje výsledky.

> Než pustíš venkovní hru, projdi fyzicky zvolenou oblast. Vyřaď nebezpečné silnice, uzavřené průchody, staveniště a místa bez bezpečného přístupu.

## 1. Přihlášení a základní orientace

Na úvodní stránce zvol **Admin** a zadej admin heslo. Rozhraní má dvě hlavní části:

- **Plány** pro přípravu mapy, cest a herních bodů;
- **Správa** pro nastavení, hry, přístupové kódy, hráče a výsledky.

Admin relace je časově omezená. Po odhlášení nebo vypršení relace je nutné zadat heslo znovu.

## 2. Vytvoření mapového plánu

V části **Plány** založ nový plán tlačítkem **+ Plán** a pojmenuj ho. Plán je opakovaně použitelná šablona; nastavení se při vytvoření hry zkopíruje do konkrétního zápasu.

### Oblast a cesty

1. Zvol režim **Oblast**.
2. Klikáním do mapy vytvoř polygon s nejméně třemi body.
3. Použij **Najít ulice v oblasti**. Aplikace načte silnice a pěší cesty z OpenStreetMap.
4. V režimu **Ulice** klikáním zařaď nebo vyřaď jednotlivé úseky. Šedé cesty jsou mimo hru.
5. Podle potřeby použij **Rozdělit v křižovatkách**, hromadný přepínač chodníků nebo režim **Spojnice** pro ručně doplněnou cestu.

Pokud jsou veřejné mapové servery dočasně přetížené, vyhledávání může trvat desítky sekund. Aplikace automaticky zkouší více zdrojů; při chybě opakuj hledání později.

### Respawn body

V režimu **Respawny** kliknutím přidávej body R1, R2 a další. Bod lze tažením přesunout a dvojklikem smazat. Rozmísti několik bezpečných bodů po oblasti tak, aby po výbuchu žádný hráč nemusel přecházet nebezpečnou trasu.

Respawn není povinný start. Hráči mohou začít kdekoliv na povolených cestách. Respawn body se jim zobrazí až po výbuchu.

### Jahůdkové body

V režimu **Jahůdky** kliknutím vytvoř skryté možné pozice jahůdek. Dvojklik bod smaže.

- Hráči nevidí prázdné jahůdkové body, pouze aktuálně aktivní jahůdky.
- Na jednom bodu může být současně nejvýše jedna jahůdka.
- Při startu se náhodně aktivuje jedna třetina bodů, zaokrouhlená nahoru.
- Pokud jahůdku nikdo nesní, bod zůstane obsazený a nová se na něm negeneruje.

Rozmísti body na bezpečná a fyzicky dostupná místa. Nedávej je doprostřed vozovky ani za plot.

### Připravení plánu

Plán musí mít povolené cesty a alespoň jeden respawn bod. Po dokončení klikni **připravit ke hře**. Jen připravené plány lze použít pro novou hru.

## 3. Nastavení zápasu

V části **Správa - Nastavení zápasu** uprav společné hodnoty pro nové hry a klikni **Uložit nastavení**. Po úspěchu aplikace zobrazí **Nastavení bylo uloženo.**

- **Výchozí délka hada:** délka při startu a po respawnu; výchozí 10 m.
- **Prodloužení za jahůdku:** přírůstek po sebrání hlavou; výchozí 10 m.
- **Délka hry:** pevná doba zápasu; výchozí 15 minut.
- **Rychlost hada:** konstantní rychlost hlavy po připravené trase; výchozí 3 km/h.
- **Jahůdka nejdříve / nejpozději:** náhodný interval dalšího spawnu; výchozí 10 až 60 s.
- **Maximální náskok:** největší povolená vzdálenost hráče před hlavou měřená po trase; výchozí 100 m.
- **Respawn odpočet:** čekání u dosaženého bodu; výchozí 3 s.
- **Tolerance snap:** jak daleko od osy cesty se GPS ještě přichytí na povolenou síť; výchozí 30 m.

Rozhraní stále zobrazuje také starší parametry nečinnosti, opuštění ulice a virtuálního Run režimu. Pro základní venkovní KSMF Snake používej především výše uvedené hodnoty.

Nastavení není součástí plánu. Při založení hry se aktuální společná konfigurace zkopíruje do hry jako snapshot. Pozdější změna konfigurace nezmění žádnou již založenou hru, včetně hry čekající v lobby.

## 4. Přístupové kódy a hráči

V kartě **Přístup - kódy** vytvoř registrační kód a bezpečně ho pošli hráčům. Jeden aktivní kód může použít více hráčů. Po registraci skupiny ho deaktivuj nebo smaž.

Hráč si při registraci vytváří vlastní heslo. V kartě hráčů může admin účet odstranit, ale nemůže zobrazit jeho heslo.

## 5. Vytvoření a spuštění hry

1. Ulož požadované **Nastavení zápasu**.
2. V kartě **Hry** vyber připravený plán.
3. Nastav kapacitu hráčů a pro venkovní test zvol **Realtime (GPS)**.
4. Klikni **+ Nová hra**. V tomto okamžiku se plán spojí s aktuální konfigurací a vznikne neměnný snapshot hry.
5. Počkej, až se hráči připojí v lobby.
6. Tlačítkem **Sleduj** otevři živou mapu a zkontroluj účastníky.
7. Klikni **Spustit**. Hráčům začne desetisekundový odpočet a poté běží herní čas.

Hráči nepotřebují předem přidělené starty. Mohou se před spuštěním rozmístit kdekoliv na herní síti.

Volby **Simulace** a **Run hra** pocházejí z testovacích režimů. Pro reálnou venkovní hru vždy použij Realtime (GPS); před ostrým použitím ostatních režimů je samostatně ověř.

## 6. Průběh hry

Ve sledování vidíš aktivní těla a hlavy hadů a můžeš kontrolovat průběh. Hra je serverově časovaná a standardně skončí po 15 minutách.

Po výbuchu tělo hada okamžitě zmizí. Hráč si vybere respawn, fyzicky k němu dojde a po odpočtu pokračuje s výchozí délkou. Jeho dosavadní maximum, jahůdky a způsobené výbuchy se zachovají.

Hru můžeš předčasně ukončit tlačítkem **Ukončit**. Hru čekající v lobby lze smazat.

## 7. Výsledky

Admin vidí výsledkové metriky průběžně a po skončení je otevře v kartě **Dokončené hry - Výsledky**. Hráči je uvidí na konci a později ve své historii.

Tabulka obsahuje:

- maximální dosaženou délku hada;
- počet sebraných jahůdek;
- počet soupeřů, kteří vybuchli nárazem do hada daného hráče.

Sloupce se pouze zobrazují. Aplikace automaticky neurčuje jednoho celkového vítěze.

## 8. Doporučený postup prvního testu

1. Připrav malou, bezpečnou a osobně známou oblast.
2. Zkontroluj všechny povolené cesty a přidej alespoň tři dobře dostupné respawny.
3. Rozmísti více jahůdkových bodů, než kolik chceš mít současně aktivních jahůdek.
4. Ponech výchozí délku 10 m, růst 10 m, rychlost 3 km/h, náskok 100 m a hru zkrať například na 5 minut.
5. Nejprve proveď test se dvěma telefony na místě bez dopravy.
6. Ověř GPS, sběr hlavou hada, vlastní a cizí kolizi, zmizení těla, výběr respawnu a konečnou tabulku.
7. Teprve potom zvětšuj oblast, počet hráčů nebo délku zápasu.

## 9. Řešení častých problémů

- **Ulice se nenačetly:** chvíli počkej a spusť hledání znovu; veřejné OpenStreetMap služby mohou být vytížené.
- **Hráč se nepohybuje:** zkontroluj oprávnění k přesné poloze, mobilní data a vypnutý úsporný režim.
- **Hráč má starou verzi:** úplně zavřít PWA, znovu ji otevřít a ověřit verzi na stránce Info.
- **Nelze vytvořit hru:** plán musí být označený jako připravený a mít alespoň jeden respawn bod.
- **Jahůdka není vidět:** prázdné body jsou záměrně skryté; aktivní je zpočátku jen třetina bodů.
