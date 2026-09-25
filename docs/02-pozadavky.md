# AchtungDieKM — Požadavky (FR / NFR)

> Stav: **draft / probíhá sběr** — vzniká postupně z odpovědí zadavatele (Wake).
> Okruhy A–F zachyceny. **Sběr požadavků dokončen** → následuje **společná validace** a doladění priorit.
>
> Priority (MoSCoW): **M** = Must · **S** = Should · **C** = Could · **W** = Won't (zatím ne).
> Priority jsou **předběžné** — potvrdíme při validaci.

---

## 1. Funkční požadavky (FR)

### A) Herní pravidla a cíl
| ID | Priorita | Požadavek |
|----|----------|-----------|
| FR-01 | M | Multiplayerová **lokační hra v reálném světě**: hráči se fyzicky pohybují po ulicích, GPS zaznamenává jejich trasu a vykresluje ji jako čáru (stopu). |
| FR-02 | M | Cíl hry: **poslední přeživší**, **bez časového limitu**. |
| FR-03 | M | Mapa je modelována jako **graf**: ulice = hrany, křižovatky a náměstí = uzly spojující všechny ulice, co do nich vedou. |
| FR-04 | M | Projetá ulice se stává **trvale zabranou** pro všechny hráče (i pro toho, kdo ji projel). |
| FR-05 | M | **Vyřazení** hráče při **vjezdu do již zabrané ulice**. |
| FR-06 | M | **Vyřazení** hráče, který **uvízne v uzlu** bez jakékoli volné výjezdové ulice (slepá past z obsazených ulic). |
| FR-07 | M | **Křížení vlastní i cizí stopy v uzlu je povoleno**, pokud hráč vjede volnou ulicí a vyjede jinou volnou ulicí (např. X-křižovatka: zleva-doprava a později zdola-nahoru). |
| FR-08 | M | **Vyřazení** hráče při **nečinnosti > 30 s** (stání na místě). |
| FR-09 | M | Zabrané ulice se **nikdy neuvolní** — ani po vyřazení hráče, který je projel. |

### B) Herní zóny a hranice
| ID | Priorita | Požadavek |
|----|----------|-----------|
| FR-10 | M | **Zakázané / povolené zóny** (parky, náměstíčka, parkoviště, parkoviště u nákupních center apod.) konfiguruje **admin**. |
| FR-11 | M | Vstup do **zakázané zóny / mimo herní zónu** → **varování + nutnost návratu**. Návrat musí proběhnout **stejným místem**, kterým hráč zónu opustil. |
| FR-12 | M | Pobyt **mimo herní zónu déle než 30 s → vyřazení**. (Nezávislý časovač na FR-08.) |

### C) Nastavení zápasu a admin
| ID | Priorita | Požadavek |
|----|----------|-----------|
| FR-13 | M | Admin **nakreslí herní oblast** na mapě (polygon). |
| FR-14 | M | Admin nastaví **povolené/zakázané spojnice** (viz FR-10). |
| FR-15 | M | Admin určí **startovací body** pro všechny hráče. |
| FR-16 | M | **Uložená konfigurace** (oblast + spojnice + starty) se **použije pro všechny další zápasy**, dokud admin nezvolí jinou oblast. |
| FR-17 | M | Mapa **zobrazuje startovací body všech hráčů**. |
| FR-31 | M | Admin může nastavit **časové limity** (nečinnost, pobyt mimo zónu) a **toleranci snappingu**. Výchozí: nečinnost **30 s**, mimo zónu **30 s**, snapping **30 m**. |

### D) Role, účty, přístup
| ID | Priorita | Požadavek |
|----|----------|-----------|
| FR-18 | M | Dvě role: **admin** (spravuje nastavení hry a hráče) a **hráč** (hraje). Adminů může být více. |
| FR-19 | M | **Jednoduchý účet**: jedinečná **přezdívka** vázaná na jedinečný **e-mail**. |
| FR-20 | M | Přihlášení **PIN kódem zaslaným na e-mail** (passwordless, bez hesla). |
| FR-21 | M | Aplikace je pro **uzavřenou skupinu uživatelů**; připojení do hry **na pozvánku**. |

### E) Průběh zápasu (real-time)
| ID | Priorita | Požadavek |
|----|----------|-----------|
| FR-22 | M | Před startem hra **čeká, až všichni hráči dorazí na startovací body**, pak **upozorní admina**. |
| FR-23 | M | Admin stiskne **START** → všem hráčům se zobrazí **odpočet (10, 9, …)**, poté hra začíná. |
| FR-24 | M | Mobil průběžně **posílá GPS souřadnice na server**; server v **reálném čase** zakresluje a **všem zobrazuje trajektorie všech hráčů**. |
| FR-26 | M | **Poloha hráče se přichytává na nejbližší ulici** v grafu (snapping) s rozumnou tolerancí (viz NFR-04). |
| FR-27 | M | Při **výpadku GPS/internetu** se pohyb **dopočítá interpolací** mezi poslední a novou známou polohou. **Vyřazení**, pokud výpadek trvá **> 1 min** nebo je „skok" mezi polohami **> ~200 m**. |
| FR-28 | S | Hra hráče **upozorní na slabý signál / ztrátu spojení**. |

### F) Bezpečnost a výstupy
| ID | Priorita | Požadavek |
|----|----------|-----------|
| FR-25 | S | Aplikace umí po zápase **vygenerovat PDF s výsledky**. |
| FR-29 | M | **Před zahájením odpočtu** se hráčům zobrazí **bezpečnostní upozornění** (např. „Pohybuj se opatrně, sleduj provoz kolem sebe."). |
| FR-30 | M | **Bezpečné území volí admin** (organizátor) — hra nerozlišuje automaticky bezpečnost chodníků vs. vozovek. |

---

## 2. Nefunkční požadavky (NFR)
| ID | Priorita | Požadavek |
|----|----------|-----------|
| NFR-01 | M | **Kapacita zápasu:** území ~**0,5 km²** (≈ 800 × 550 m), **5–10 hráčů** současně. |
| NFR-02 | M | **Real-time:** pozice hráčů a stopy se aktualizují průběžně a plynule (cílová latence/frekvence — *k doplnění v okruhu D*). |
| NFR-03 | M | Server je **autorita** nad stavem hry (pozice, obsazené ulice, kolize, vyřazení). |
| NFR-04 | M | **Snapping na graf ulic** s tolerancí od osy ulice. Tolerance je **nastavitelná adminem**, výchozí **30 m** (doladit při testech v terénu). |
| NFR-05 | M | **Odolnost proti výpadku GPS/internetu** (interpolace + pojistky, viz FR-27); krátké výpadky nesmí vést k falešnému vyřazení. |
| NFR-06 | W | **Ochrana proti podvádění (fake GPS) se neřeší** — uzavřená skupina, fair play. |
| NFR-07 | M | **Bezpečnost:** odpovědnost na adminovi (volba bezpečného území) + předstartovní upozornění (FR-29). Jde o **soukromou akci** party kamarádů v konkrétní den. |
| NFR-08 | M | **Platforma:** primárně **Web / PWA**, případně **Android**; **iOS se neřeší**. |
| NFR-09 | M | **Rozsah první verze = MVP** (ověřit jádro v terénu); doladěnosti až poté (viz „Rozsah MVP"). |
| NFR-10 | M | **Mapová data z OpenStreetMap** (obsahuje chodníky i ulice; např. přes Overpass API). Z nich se staví graf ulic. |

---

## 3. Rozsah MVP (první verze)
Cíl: **ověřit jádro hry v terénu** (MVP: **Praha–Barrandov**; Kroměříž později). V MVP musí být:
- Načtení **grafu ulic** vybraného území z mapových dat (FR-03).
- Admin **nakreslí oblast** + **startovací body** (FR-13, FR-15) — stačí v základní podobě.
- **Pohyb hráče přes GPS** + **snapping** na ulici (FR-26, NFR-04).
- **Posílání pozic na server** a **real-time vykreslení** stop všech hráčů (FR-24).
- **Kolize a vyřazení**: zabraná ulice, uvíznutí v uzlu, nečinnost 30 s (FR-04–FR-09).
- **Start zápasu**: čekání na hráče → START → odpočet (FR-22, FR-23) + bezpečnostní upozornění (FR-29).

**Až po MVP (ne v první verzi):** plné účty s PINem (FR-19, FR-20), pozvánky (FR-21),
generování PDF (FR-25), vyladěné menu/UI, upozornění na slabý signál (FR-28).

## 4. Validace (2026-06-26) — ✅ odsouhlaseno
- ✅ Časovače (nečinnost, mimo zónu) **nastavitelné adminem**, default **30 s** (FR-31).
- ✅ Zdroj mapových dat: **OpenStreetMap** (NFR-10).
- ✅ Tolerance snappingu **nastavitelná adminem**, default **30 m**, doladit v terénu (NFR-04).
- ✅ **FR-28** (upozornění na slabý signál) — **ano**, priorita S.
- ✅ Priority M/S/C/W odsouhlaseny (jádro = Must, PDF = Should, anti-cheat = Won't).

**Business analýza je tímto uzavřená.** Další krok: návrh architektury a technologie pro MVP.
