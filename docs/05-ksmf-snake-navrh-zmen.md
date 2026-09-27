# KSMF Snake — návrh změny hry

> Stav: **schválená specifikace — implementace zahájena**
>
> Implementace nezačne, dokud nebude celý dokument přečtený a schválený.
>
> Tento dokument popisuje zamýšlený stav KSMF Snake a nahrazuje herní pravidla AchtungDieKM. Původní dokumentace zůstává jako popis výchozího projektu.

---

## 1. Shrnutí konceptu

KSMF Snake je multiplayerová lokační hra v reálném městě. Hráči se pohybují s mobilem po vymezeném území a každý ovládá svého hada.

Telefon zaznamenává trasu hráče, ale had se po této trase pohybuje vlastní konstantní rychlostí. Tělo hada má omezenou délku: jak hlava postupuje dopředu, konec ocasu za ní mizí. Sbíráním jahůdek se had prodlužuje.

Hráč vybuchne, když:

- jeho had narazí do těla jiného hada;
- vlastní had jej při příliš pomalém pohybu dožene;
- hráč uteče od hlavy svého hada dále, než dovoluje nastavený limit.

Výbuch neznamená konec účasti. Hráč se znovu objeví na jednom z adminem definovaných respawn bodů a jeho had se vrátí na výchozí délku. Zápas trvá pevně stanovený čas. Po jeho skončení se zobrazí tabulka výsledků.

---

## 2. Hlavní změny proti AchtungDieKM

| Oblast | AchtungDieKM | KSMF Snake |
|---|---|---|
| Herní objekt | Trvale rostoucí stopa hráče | Pohybující se had s omezenou délkou |
| Vliv rychlosti běhu | Rychlejší hráč rychleji zabírá prostor | Rychlost hada je konstantní; rychlost hráče vytváří pouze budoucí trasu |
| Trvání stopy | Stopa zůstává | Ocas průběžně mizí tak, aby had držel aktuální délku |
| Růst | Bez sběratelných předmětů | Jahůdka prodlouží hada o nastavenou hodnotu |
| Kolize | Hráč je vyřazen ze zápasu | Had vybuchne a hráč se po respawnu vrací |
| Křížení stop | Na vybraných místech bylo povolené | Křížení těl hadů nebude povolené |
| Start | Předem přidělené startovní body | Hráč může začít kdekoli v povolené oblasti |
| Návrat do hry | Nebyl | Adminem definované respawn body |
| Konec hry | Poslední přeživší | Vypršení nastaveného času |
| Vyhodnocení | Pořadí podle přežití | Více statistik, bez zatím stanoveného souhrnného vítěze |

---

## 3. Herní model

### 3.1 Tři rozdílné polohy

Pro každého hráče je nutné rozlišovat:

1. **Fyzickou polohu hráče** — aktuální GPS pozice telefonu.
2. **Budoucí trasu hada** — cesta, kterou hráč již fyzicky vytvořil, ale hlava hada ji ještě neprojela.
3. **Tělo hada** — již projetý aktivní úsek mezi hlavou a koncem ocasu; pouze tento úsek je nebezpečnou kolizní překážkou.

Budoucí trasu svého hada vidí pouze její vlastník. Ostatní hráči vidí jeho aktuální tělo, ne plánovanou cestu.

### 3.2 Konstantní rychlost hada

- Hlava hada se po zaznamenané trase pohybuje konstantní herní rychlostí.
- Rychlost fyzického pohybu hráče rychlost hada nemění.
- Pokud hráč běží rychleji než had, vytváří se mezi ním a hlavou hada delší budoucí trasa.
- Pokud se hráč pohybuje pomaleji než had, hlava postupně spotřebuje připravenou trasu a přibližuje se k hráči.

Tím je odstraněna výhoda hráče, který pouze běhá rychleji než ostatní.

### 3.3 Délka hada

- Každý had začíná s konfigurovatelnou výchozí délkou.
- Bez sebrání jahůdky zůstává jeho délka konstantní.
- Při pohybu hlavy se ocas o stejnou vzdálenost zkracuje na svém konci.
- Sebrání jahůdky zvětší cílovou délku hada o hodnotu nastavenou pro danou hru.
- Po výbuchu a respawnu se cílová délka resetuje na výchozí hodnotu.

### 3.4 Vzdálenost hráče od hlavy hada

Hráč musí udržovat hlavu hada v povoleném rozsahu:

- **Příliš daleko před hadem:** pokud délka budoucí trasy překročí nastavený limit, hráč vybuchne. Jde o herní omezení maximálního náskoku, nikoli pouze o vzdušnou vzdálenost GPS bodů.
- **Příliš pomalu:** pokud hlava hada dojede až k fyzické poloze hráče, had hráče sní a hráč vybuchne.

Na obrazovce hráče musí být srozumitelně vidět zbývající rezerva oběma směry, aby výbuch nebyl překvapivý.

### 3.5 Opuštění herní oblasti

- V maximální míře se zachová současná logika upozornění a časového limitu pro návrat.
- Opuštění oblasti je hráči okamžitě oznámeno a začne běžet nastavený čas na návrat.
- Hráč se musí vrátit dříve, než vyprší limit.
- Současně stále platí pohyb hada: pokud hlava spotřebuje celou budoucí trasu a dožene hráče ještě před návratem, hráč vybuchne.

---

## 4. Jahůdky

### 4.1 Definice jahůdkových bodů

- Admin v editoru mapy ručně nakliká body, na kterých se mohou objevovat jahůdky.
- Body jsou součástí uložené definice mapy/plánu.
- Jeden bod může v jeden okamžik obsahovat nejvýše jednu aktivní jahůdku.
- Jahůdkové body jsou jiný typ bodů než respawn body. V datovém modelu i adminském editoru musí být jednoznačně oddělené.
- Hráči nevidí samotné jahůdkové body. Na mapě se jim zobrazí pouze aktuálně přítomné jahůdky.

### 4.2 Objevování jahůdek

- Při startu hry se náhodně vybere a jahůdkami obsadí jedna třetina všech jahůdkových bodů, zaokrouhlená nahoru.
- Ostatní jahůdkové body začínají prázdné.
- Pro všechny jahůdkové body platí společný náhodný interval `10–60 sekund`.
- Po startu hry systém pro každý prázdný bod určí náhodný okamžik objevení jahůdky v tomto intervalu.
- Jakmile se na bodě jahůdka objeví, zůstává tam, dokud ji některý hráč nesní.
- Dokud stávající jahůdka není snědena, na stejném bodě se další nevytvoří.
- Po snědení se pro daný bod znovu naplánuje náhodné objevení podle stejného intervalu.
- Pokud hráči jahůdky nesbírají, mohou se postupně zaplnit všechny jahůdkové body. Není zaveden další globální limit.

### 4.3 Sebrání

- Jahůdku sebere první **hlava hada**, která vstoupí do nastaveného sběracího poloměru. Samotná GPS poloha hráče jahůdku nesbírá.
- Sebrání je vyhodnoceno serverem, aby jednu jahůdku nemohlo současně získat více hráčů.
- Po sebrání se zvýší aktuální délka hada a statistika snědených jahůdek.
- Sebraná jahůdka zmizí v reálném čase z mapy všem hráčům.

---

## 5. Kolize, výbuch a respawn

### 5.1 Kolizní pravidla

- Tělo hada je kolizní po celé své aktuální délce.
- Budoucí trasa není kolizní, protože na ní had ještě není.
- Křížení těla vlastního ani cizího hada nebude mít výjimku na křižovatkách.
- Náraz do těla protivníka způsobí výbuch narážejícího hráče.
- Náraz hlavy do vlastního těla také způsobí výbuch.
- Pokud se dvě hlavy srazí ve stejném serverovém kroku, vybuchnou oba hráči.

### 5.2 Připsání zásahu

Pokud hráč narazí do těla cizího hada, vlastník tohoto hada získá jeden bod do statistiky **způsobené výbuchy soupeřů**.

Výbuch způsobený vlastním hadem nebo překročením maximálního náskoku se nepřipisuje soupeři.

### 5.3 Respawn

- Admin definuje respawn body při tvorbě mapy.
- Pro jejich editaci lze technicky a uživatelsky přepracovat současné startovní body.
- Po výbuchu aktuální tělo hada okamžitě zmizí a hráč je neaktivní.
- Pouze neaktivnímu hráči se na jeho mapě zobrazí respawn body.
- Hráč si sám vybere libovolný respawn bod a musí k němu fyzicky dojít.
- Po příchodu aplikace zobrazí hlášku **„Vracíš se do hry“** a spustí třísekundový odpočet.
- Po skončení odpočtu se na daném bodě aktivuje nový had s výchozí délkou `10 m` a prázdnou budoucí trasou.
- Od výbuchu do dokončení respawnu hráč nemůže sbírat jahůdky ani způsobovat kolize.
- Hráč pokračuje ve stejné hře a jeho dosavadní statistiky zůstávají zachovány.

---

## 6. Průběh zápasu

### 6.1 Před startem

1. Admin vybere uložený plán/mapu.
2. Plán obsahuje povolené území a cesty, respawn body a oddělené jahůdkové body.
3. Admin nastaví parametry konkrétní hry.
4. Hráči se připojí do lobby.
5. Hráči nemusí stát na předem přiděleném startu; mohou začít kdekoli v povolené herní oblasti.
6. Admin hru spustí obdobně jako v aktuální verzi a proběhne společný odpočet.

### 6.2 Během hry

- Hra běží po nastavenou dobu.
- Server posouvá hady konstantní rychlostí, spravuje jejich ocas a vyhodnocuje kolize.
- Server spravuje spawn a sběr jahůdek.
- Výbuch hráče nezastavuje celou hru; následuje respawn.
- Všichni hráči vidí zbývající čas zápasu.

### 6.3 Konec hry

- Po vypršení času server zápas ukončí pro všechny hráče.
- Další pohyb, sběr i kolize se již nezapočítávají.
- Zobrazí se tabulka statistik za danou hru.
- Způsob určení celkového vítěze zatím není stanoven; v první verzi lze jednotlivé statistiky pouze zobrazit a vyhodnotit po každé hře ručně.

---

## 7. Statistiky hry

Pro každého hráče se v rámci jedné hry ukládá:

1. **Maximální dosažená délka hada** — nejvyšší hodnota před kterýmkoli respawnem.
2. **Celkový počet snědených jahůdek** — součet za celý zápas, neresetuje se respawnem.
3. **Počet způsobených výbuchů soupeřů** — kolikrát jiný hráč narazil do těla tohoto hada.

Výsledková tabulka zobrazí minimálně:

| Hráč | Maximální délka | Jahůdky | Způsobené výbuchy |
|---|---:|---:|---:|
| Přezdívka | délka v metrech | počet | počet |

- Hráči uvidí tabulku až po skončení hry.
- Admin uvidí stejné statistiky průběžně během hry.
- Sloupce se pouze zobrazí; aplikace z nich zatím neurčí jednoho ani dílčí vítěze.
- Počet vlastních výbuchů ani jejich příčiny se nebudou ukládat jako další statistika.

---

## 8. Konfigurace

### 8.1 Konfigurace mapy/plánu

Mapa, kterou lze použít opakovaně pro více her, obsahuje:

- polygon povolené herní oblasti;
- povolené cesty a stávající mapovou geometrii;
- respawn body;
- samostatné jahůdkové body.

### 8.2 Konfigurace hry

Admin před založením hry uloží společnou konfiguraci nové hry:

| Parametr | Význam | Jednotka / tvar | Výchozí hodnota |
|---|---|---|---:|
| Výchozí délka hada | Délka po startu a každém respawnu | metry | `10 m` |
| Prodloužení za jahůdku | O kolik naroste cílová délka | metry | `10 m` |
| Celkový čas hry | Okamžik automatického konce | minuty/sekundy | `15 minut` |
| Rychlost hada | Konstantní rychlost hlavy po trase | km/h v UI, m/s interně | `3 km/h` (≈ `0,833 m/s`) |
| Interval jahůdek | Náhodné objevení na prázdném jahůdkovém bodě | minimum–maximum v sekundách | `10–60 s` |
| Maximální náskok před hadem | Nejdelší povolená budoucí trasa | metry | `100 m` |
| Doba respawnu | Odpočet po dosažení respawn bodu | sekundy | `3 s` |
| Čas na návrat do oblasti | Zachovaný limit po opuštění plánu | sekundy | stávající konfigurovatelná hodnota |
| Kolizní tolerance | Rezerva pro GPS nepřesnost | metry | k terénnímu doladění |
| Poloměr sběru jahůdky | Vzdálenost hlavy nutná pro sebrání | metry | k terénnímu doladění |

Plán obsahuje mapová data. Při založení konkrétní hry se plán spojí s aktuální společnou konfigurací a všechny parametry se uloží do hry jako **snapshot**. Pozdější změna konfigurace neovlivní žádnou již založenou, rozehranou ani historickou hru.

---

## 9. Dopad na současnou aplikaci

### 9.1 Funkce, které lze z velké části zachovat

- React/Vite PWA a nasazení na Vercelu.
- MapLibre mapa, GPS vstup a snapping na cesty.
- Supabase, PostGIS a realtime infrastruktura.
- Přihlášení hráče, lobby a adminské spuštění hry.
- Editor herní oblasti a cest.
- Uložené plány a instance her.
- Odpočet před startem, sledování hry a historie výsledků.
- Současné startovní body jako základ editoru respawn bodů.

### 9.2 Funkce, které se musí zásadně změnit

- Datový model trvale rostoucí stopy.
- Pohybový model: GPS hráče už nebude přímo polohou hlavy hada.
- Udržování konstantní délky a ořezávání ocasu.
- Kolizní logika bez výjimky pro křížení stop.
- Vyřazení hráče se změní na výbuch a respawn.
- Podmínka konce hry se změní z posledního přeživšího na časový limit.
- Vykreslení soukromé budoucí trasy a veřejného těla hada.
- Nové jahůdky, jejich jahůdkové body, časová logika a sběr hlavou hada.
- Nové průběžné a koncové statistiky.

### 9.3 Serverová autorita

Server musí být autoritou minimálně pro:

- aktuální pozici hlavy a ocasu každého hada;
- spotřebu budoucí trasy konstantní rychlostí;
- kolize;
- generování a atomické sebrání jahůdek;
- výbuch, dosažení zvoleného respawn bodu a obnovení hada;
- herní čas a konec zápasu;
- statistiky.

Pouhé klientské vyhodnocování by mohlo mezi telefony vytvořit rozdílný stav hry.

---

## 10. Potvrzená rozhodnutí

1. Kolizní je pouze aktuální tělo hada; budoucí trasa nikoli.
2. Maximální vzdálenost před hadem se měří po budoucí trase, ne vzdušnou čarou.
3. Jahůdku sbírá hlava hada.
4. Jahůdky vidí všichni hráči a po sebrání zmizí všem.
5. Tělo vybuchlého hada okamžitě zmizí.
6. Od výbuchu do dokončení respawnu hráč nemůže sbírat jahůdky ani způsobovat kolize.
7. Po respawnu se statistiky zachovají a aktuální délka hada se resetuje na `10 m`.
8. V první verzi se neurčuje jeden celkový vítěz; zobrazí se tři samostatné metriky.
9. Náraz hlavy do vlastního těla způsobí výbuch.
10. Hráč si po výbuchu vybírá respawn bod a musí k němu fyzicky dojít.
11. Po dosažení respawn bodu proběhne třísekundový odpočet.
12. Při současné srážce dvou hlav vybuchnou oba hadi.
13. Opuštění oblasti použije současné varování a konfigurovatelný čas na návrat.
14. Jahůdky se na prázdném bodě generují náhodně jednou za `10–60 sekund`.
15. Maximálně může být aktivní jedna jahůdka na každém jahůdkovém bodě; globální limit není.
16. Hráči vidí statistiky až po konci, admin průběžně.
17. Výsledková tabulka metriky pouze zobrazuje.
18. Vlastní výbuchy ani jejich příčiny se jako další statistika neukládají.
19. Při startu hry se jahůdkami obsadí náhodná třetina jahůdkových bodů, zaokrouhlená nahoru.
20. Hráči nevidí prázdné jahůdkové body, pouze aktivní jahůdky.

---

## 11. Otevřené otázky k rozhodnutí

V tuto chvíli nejsou evidovány žádné otevřené otázky k herním pravidlům.

---

## 12. Návrh etap implementace

Toto je zatím pouze podklad k budoucímu schválení, nikoli pokyn k implementaci.

1. **Datový model a konfigurace** — mapové body, snapshot nastavení hry, stav hada a statistiky.
2. **Pohybový model hada** — budoucí trasa, konstantní rychlost, ořezávání ocasu a limity vzdálenosti.
3. **Admin editor** — oddělené respawn body, jahůdkové body a nové parametry hry.
4. **Jahůdky** — plánování, zobrazení, sběr a růst hada.
5. **Kolize a respawn** — výbuchy, připsání zásahu a bezpečný návrat do hry.
6. **Časovaný zápas a výsledky** — konec podle času, agregace statistik a tabulka.
7. **Realtime synchronizace a odolnost** — serverová autorita, souběhy, výpadky GPS a reconnect.
8. **UI, značka a dokumentace** — přejmenování AchtungDieKM na KSMF Snake a finální herní obrazovky.
9. **Testování** — simulace, souběžné kolize, terénní test GPS a vyvážení hodnot.

---

## 13. Podmínka zahájení implementace

Před zahájením implementace bude:

- uzavřen seznam otevřených herních rozhodnutí;
- potvrzen rozsah první implementační verze;
- schválen datový a serverový model;
- dohodnuta sada výchozích konfiguračních hodnot;
- celý tento dokument přečten a schválen zadavatelem.
