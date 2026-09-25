#!/usr/bin/env python
# Generátor uživatelských příruček (PDF) pro AchtungDieKM.
# Dvě PDF: manual-hrac.pdf (hráč) a manual-admin.pdf (admin) -> app/public/.
# Font Arial z Windows (plná čeština). Spuštění:
#     python -m pip install reportlab
#     python tools/manuals/make-manuals.py
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.lib.styles import StyleSheet1, ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, Image,
    ListFlowable, ListItem, HRFlowable, Table, TableStyle,
)

HERE = os.path.dirname(os.path.abspath(__file__))
PUBLIC = os.path.normpath(os.path.join(HERE, "..", "..", "app", "public"))
ICON = os.path.join(PUBLIC, "pwa-512x512.png")
FONTS = r"C:\Windows\Fonts"

NAVY = colors.HexColor("#0d1117")
BLUE = colors.HexColor("#1f6feb")
GREEN = colors.HexColor("#2ea043")
RED = colors.HexColor("#e5484d")
GREY = colors.HexColor("#57606a")
LIGHT = colors.HexColor("#eef2f6")

pdfmetrics.registerFont(TTFont("Arial", os.path.join(FONTS, "arial.ttf")))
pdfmetrics.registerFont(TTFont("Arial-Bold", os.path.join(FONTS, "arialbd.ttf")))
pdfmetrics.registerFont(TTFont("Arial-It", os.path.join(FONTS, "ariali.ttf")))
pdfmetrics.registerFontFamily("Arial", normal="Arial", bold="Arial-Bold", italic="Arial-It")


def styles():
    s = StyleSheet1()
    s.add(ParagraphStyle("Body", fontName="Arial", fontSize=10.3, leading=15, spaceAfter=5, alignment=TA_LEFT))
    s.add(ParagraphStyle("Title", fontName="Arial-Bold", fontSize=26, leading=30, textColor=BLUE, spaceAfter=2))
    s.add(ParagraphStyle("Sub", fontName="Arial", fontSize=11.5, leading=15, textColor=GREY, spaceAfter=4))
    s.add(ParagraphStyle("H1", fontName="Arial-Bold", fontSize=15, leading=19, textColor=BLUE, spaceBefore=16, spaceAfter=5))
    s.add(ParagraphStyle("H2", fontName="Arial-Bold", fontSize=12, leading=16, textColor=NAVY, spaceBefore=9, spaceAfter=3))
    s.add(ParagraphStyle("Bullet", parent=s["Body"], leftIndent=14, spaceAfter=3))
    s.add(ParagraphStyle("Small", fontName="Arial", fontSize=8.5, leading=11, textColor=GREY))
    return s


def callout(text, bg, border, S):
    st = ParagraphStyle("co", parent=S["Body"], backColor=bg, borderColor=border,
                        borderWidth=1, borderPadding=8, borderRadius=6, spaceBefore=4, spaceAfter=8, leftIndent=0)
    return Paragraph(text, st)


def bullets(items, S, style="Bullet"):
    return ListFlowable(
        [ListItem(Paragraph(t, S[style]), leftIndent=14, value="•") for t in items],
        bulletType="bullet", bulletColor=BLUE, bulletFontSize=8, start="•", leftIndent=10,
    )


def header(title, subtitle, S):
    flow = []
    rows = [[Image(ICON, width=20 * mm, height=20 * mm),
             Paragraph(f'<b>{title}</b><br/><font size=11 color="#57606a">{subtitle}</font>',
                       ParagraphStyle("ht", parent=S["Title"], fontSize=24, leading=26))]]
    t = Table(rows, colWidths=[24 * mm, None])
    t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "MIDDLE"), ("LEFTPADDING", (0, 0), (0, 0), 0),
                           ("LEFTPADDING", (1, 0), (1, 0), 6)]))
    flow.append(t)
    flow.append(Spacer(1, 4))
    flow.append(HRFlowable(width="100%", thickness=1.2, color=BLUE))
    flow.append(Spacer(1, 6))
    return flow


def build(path, title, subtitle, content_fn):
    doc = BaseDocTemplate(path, pagesize=A4, topMargin=16 * mm, bottomMargin=16 * mm,
                          leftMargin=18 * mm, rightMargin=18 * mm, title=title, author="AchtungDieKM")
    frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="f")

    def footer(canvas, d):
        canvas.saveState()
        canvas.setFont("Arial", 8)
        canvas.setFillColor(GREY)
        canvas.drawString(doc.leftMargin, 10 * mm, "AchtungDieKM — lokační hra v reálném městě")
        canvas.drawRightString(doc.width + doc.leftMargin, 10 * mm, f"strana {d.page}")
        canvas.restoreState()

    doc.addPageTemplates([PageTemplate(id="main", frames=[frame], onPage=footer)])
    S = styles()
    flow = header(title, subtitle, S)
    content_fn(flow, S)
    doc.build(flow)
    print("wrote", os.path.relpath(path, os.path.join(HERE, "..", "..")))


# ----------------------------------------------------------------------------- HRÁČ
def player(flow, S):
    P = lambda t: flow.append(Paragraph(t, S["Body"]))
    H1 = lambda t: flow.append(Paragraph(t, S["H1"]))
    H2 = lambda t: flow.append(Paragraph(t, S["H2"]))
    B = lambda items: flow.append(bullets(items, S))

    P("Vítej v <b>AchtungDieKM</b> — obdoba klasické hry „Achtung die Kurve“ (had), ale ve "
      "<b>skutečném městě</b>. Chodíš po opravdových ulicích, telefon přes GPS kreslí za tebou "
      "<b>stopu</b>. Do žádné stopy (své ani cizí) se nesmí vjet — <b>poslední, kdo zbyde, vyhrává.</b>")

    flow.append(callout("<b>POZOR — bezpečnost především.</b> Hraješ ve veřejném prostoru. Sleduj provoz, "
                        "chodce a okolí, nekoukej pořád do telefonu, nevbíhej do silnice. Hraješ na "
                        "vlastní zodpovědnost.", colors.HexColor("#fff0f0"), RED, S))

    H1("1. Co potřebuješ")
    B(["<b>Telefon s GPS</b> a mobilním internetem (data).",
       "<b>Přístupový kód</b> od organizátora (admina) — dostaneš ho při první registraci.",
       "Být fyzicky <b>v herní oblasti</b> (ulice, které organizátor vybral)."])

    H1("2. Registrace a přihlášení")
    B(["Otevři odkaz na aplikaci v prohlížeči (ideálně si ji nainstaluj na plochu — viz níže).",
       "Na úvodní obrazovce zvol záložku <b>Hráč</b>.",
       "<b>Nový hráč:</b> vyplň přezdívku, heslo a <b>přístupový kód</b> od admina → „Zaregistrovat a vstoupit“.",
       "<b>Vracíš se:</b> stačí přezdívka a heslo (kód nechej prázdný) → „Přihlásit se“."])

    H1("3. Nainstaluj si appku na plochu (doporučeno)")
    P("Appka funguje líp jako ikona na ploše (běží na celou obrazovku, drží displej). Dole na úvodní "
      "obrazovce i v lobby je lišta <b>„Nainstaluj appku na plochu“</b>:")
    B(["<b>Android (Chrome/Brave):</b> klepni na „Instalovat“, nebo otevři menu prohlížeče "
       "(tři tečky vpravo nahoře) → <b>Instalovat aplikaci</b> / Přidat na plochu.",
       "<b>iPhone (jen Safari):</b> klepni na <b>Sdílet</b> a zvol <b>Přidat na plochu</b>."])

    H1("4. Lobby — výběr hry")
    P("Po přihlášení jsi v <b>lobby</b>. Tady vidíš otevřené hry:")
    B(["<b>Vybrat start</b> — připojíš se do hry a vybereš si svůj startovní bod (S1, S2, …). "
       "Každý hráč má jiný start.",
       "<b>Jen sledovat</b> — připojíš se jako divák (nehraješ, jen koukáš na mapu).",
       "<b>Odpojit</b> — vystoupíš z hry, dokud nezačala.",
       "<b>Tvoje odehrané hry</b> — historie tvých her s výsledky a obrázkem tras."])

    H1("5. Než hra začne")
    B(["Po výběru startu appka ukáže <b>navigační čáru ke tvému startu</b> a vzdálenost v metrech — "
       "dojdi tam.",
       "Nahoře svítí, kam jít: „Jdi na svůj start S1 …“ (s praporkem).",
       "Čeká se, až <b>admin spustí hru</b>. Pak naskočí <b>odpočet 10 s</b> — připrav se."])

    H1("6. Jak hra probíhá")
    B(["Choď <b>po vyznačených ulicích</b> (oranžové na mapě). GPS za tebou kreslí stopu ve tvé barvě.",
       "<b>Tvoje tečka:</b> <font color='#2ea043'><b>zelená</b></font> = jsi na ulici, "
       "<font color='#e5484d'><b>červená</b></font> = jsi mimo ulici.",
       "Nahoře (HUD) vidíš: přesnost GPS, jestli jsi na ulici, odchylku od ulice, počet hráčů a "
       "<b>délku své trasy</b>.",
       "Vpravo jsou tlačítka <b>+/−</b> (zoom), vlevo dole <b>Legenda</b> (barvy hráčů, vysvětlivky)."])

    H2("Kdy vypadneš")
    B(["<b>Náraz do stopy</b> — vjedeš nebo couvneš do už projeté cesty (své i soupeřovy). "
       "<b>Prokřížení</b> stopy na křižovatce (kolmo) je v pořádku — projet ano, jet podél ne.",
       "<b>Nečinnost</b> — stojíš moc dlouho na místě (limit nastavuje admin, typicky 30 s).",
       "<b>Mimo ulici</b> — když opustíš ulici, dostaneš varování a musíš se <b>vrátit na konec své "
       "stopy</b> do několika sekund, jinak vypadneš."])

    flow.append(callout("<b>Cíl:</b> přežij co nejdéle a zaber co nejvíc cesty. Vyhrává ten, kdo "
                        "zůstane poslední ve hře.", colors.HexColor("#eef6ff"), BLUE, S))

    H1("7. Když vypadneš")
    B(["Ukáže se „Vypadl jsi!“. Můžeš zvolit <b>Sledovat dál</b> (díváš se, jak hra dohrává) nebo "
       "<b>Do lobby</b>.",
       "Tvoje stopa zůstává na mapě — pořád je překážkou pro ostatní.",
       "Když hra ještě běží, můžeš se k ní z lobby vrátit jako <b>divák</b> (tlačítko „Sledovat“)."])

    H1("8. Konec hry a výsledky")
    B(["Po skončení appka ukáže <b>pořadí</b>, <b>obrázek všech tras</b> a <b>délku trasy</b> každého hráče.",
       "Na obrázek tras můžeš klepnout — <b>lupička zvětší</b> detail.",
       "Výsledky si pak kdykoli otevřeš v lobby v „Tvoje odehrané hry“."])

    H1("9. Testovací módy (hra od stolu, bez chození)")
    P("Admin může hru založit v jednom ze tří režimů. <b>Realtime</b> je normální hra venku přes GPS. "
      "Zbylé dva slouží k testování map od stolu, bez GPS:")
    H2("Simulace (klikání)")
    P("V HUD se objeví tlačítko <b>sim</b>. Po zapnutí <b>klikáním do mapy</b> posouváš svoji polohu. "
      "Platí stejná pravidla (náraz, mimo ulici…).")
    H2("Run hra (joystick)")
    P("Hra řízená jako videohra — tvoje tečka se <b>pohybuje sama</b> a ty ji ovládáš:")
    B(["<b>Joystick</b> vlevo dole — <b>drž a táhni</b> ve směru, kam chceš jít; <b>pustíš = stojíš</b>. "
       "(Když stojíš moc dlouho, vypadneš kvůli nečinnosti — jako ve skutečnosti.)",
       "<b>Tři rychlosti</b> vpravo dole: <b>🚶 chůze</b>, <b>🏃 běh</b>, <b>⚡ sprint</b>.",
       "<b>Stamina</b> (zelená lištička nad tlačítky) — <b>sprint ji ubírá</b>; když dojde, sprint se "
       "přepne na běh. Dobíjí se <b>jen při chůzi</b> (a trvá to déle).",
       "<b>Od stolu na klávesnici:</b> směr <b>WASD</b> nebo <b>šipky</b>, rychlost klávesy <b>1 / 2 / 3</b>."])
    P("Run hru si může zahrát i víc lidí najednou — každý na svém zařízení, navzájem se vidíte.")

    H1("10. Tipy")
    B(["Měj <b>zapnutou GPS</b> a appku <b>v popředí</b> (na pozadí GPS usíná).",
       "Appka se snaží <b>držet displej rozsvícený</b> (ukazatel „obrazovka: držena“).",
       "Když appka chvíli „zamrzne“ kvůli signálu, počkej — po obnovení signálu naskočí poloha. "
       "Refresh prohlížeče tě o stopu nepřipraví (obnoví se ze serveru)."])


# ----------------------------------------------------------------------------- ADMIN
def admin(flow, S):
    P = lambda t: flow.append(Paragraph(t, S["Body"]))
    H1 = lambda t: flow.append(Paragraph(t, S["H1"]))
    H2 = lambda t: flow.append(Paragraph(t, S["H2"]))
    B = lambda items: flow.append(bullets(items, S))

    P("Tahle příručka je pro <b>organizátora</b> hry. Admin připraví herní mapu (plán), vytvoří z ní "
      "hru, rozdá hráčům přístupové kódy a hru spustí. Vše běží v prohlížeči, data jsou sdílená přes "
      "server (Supabase).")

    H1("1. Přihlášení jako admin")
    B(["Na úvodní obrazovce zvol záložku <b>Admin</b> a zadej <b>admin heslo</b>.",
       "Admin rozhraní má dvě sekce, přepínáš je nahoře: <b>Plány</b> (práce s mapou) a "
       "<b>Správa</b> (hry, kódy, hráči, nastavení)."])

    H1("2. Plán = herní mapa")
    P("Plán obsahuje <b>oblast</b>, <b>ulice</b> zařazené do hry, <b>startovní body</b> a <b>nastavení</b>. "
      "Plánů můžeš mít víc (nahoře je výběr + „+ Plán“, Přejmenovat, Smazat).")

    H2("Režimy (sekce Plány)")
    B(["<b>Oblast</b> — klikáním do mapy obkresli území (min. 3 body), pak <b>„Najít ulice v oblasti“</b>. "
       "Aplikace stáhne ulice + chodníky z OpenStreetMap. „Znovu načíst“ a „Doplnit chodníky“ pracují "
       "s uloženou oblastí.",
       "<b>Ulice</b> — klik na cestu ji <b>zařadí/vyřadí</b> ze hry (oranžová = ve hře, šedá = mimo, "
       "hráč ji nevidí). „Rozdělit v křižovatkách“ rozseká cesty na úseky, které jdou zapínat zvlášť. "
       "Přepínač zapne/vypne hromadně chodníky.",
       "<b>Spojnice</b> — ručně dokresli cestu navíc: klikni dva body → vznikne rovná čára "
       "(silnice nebo chodník).",
       "<b>Starty</b> — klik do mapy = nový start (praporek S1, S2 …), táhni praporek = přesuň, "
       "dvojklik = smazat (zbývající se přečíslují)."])

    flow.append(callout("<b>Počet startů</b> určuje maximální počet hráčů ve hře — každý hráč "
                        "potřebuje vlastní start. Udělej aspoň tolik startů, kolik čekáš hráčů.",
                        LIGHT, GREY, S))

    H2("Připravit plán ke hře")
    B(["Až je plán hotový (ulice + starty), klikni <b>„připravit ke hře“</b> (pak svítí „ke hře“).",
       "<b>Jen připravené plány</b> jdou použít při zakládání hry."])

    H1("3. Nastavení zápasu (sekce Správa)")
    P("Karta <b>Nastavení zápasu</b> platí pro vybraný plán. U každé položky je ikonka „i“ s popisem:")
    B(["<b>Nečinnost (s)</b> — po kolika sekundách bez pohybu hráč vypadne (stojí na místě). Default 30 s.",
       "<b>Mimo ulici – limit (s)</b> — kolik sekund má hráč na návrat na konec své stopy, když opustí "
       "ulici. Default 30 s.",
       "<b>Tolerance snap (m)</b> — do kolika metrů od osy ulice se poloha „přichytí“ a počítá jako na "
       "ulici. Větší = benevolentnější ke GPS. Default 30 m.",
       "<b>Run hra — rychlosti</b> (chůze / běh / sprint, m/s) a <b>dosah sprintu (m)</b> — platí jen pro "
       "režim „Run hra“ (joystick). Defaulty 3,6 / 7,5 / 12 m/s, sprint 200 m (dobití 3× déle, jen při chůzi).",
       "<b>Nastavení = snapshot na hru:</b> hodnoty z této karty se <b>uloží do každé nově založené hry</b>. "
       "Stejná mapa tak může jet jednou pomalu, jednou extrémně rychle. Změna se nepromítne do už založených her.",
       "Nezapomeň <b>„Uložit nastavení“</b>."])

    H1("4. Přístupové kódy")
    B(["Karta <b>Přístup — kódy</b>: „+ Nový kód“ vygeneruje kód, který <b>řekneš hráčům</b> pro registraci.",
       "Kód můžeš <b>zkopírovat</b>, <b>deaktivovat</b> (přestane platit) nebo <b>smazat</b>.",
       "Jeden kód může použít víc hráčů — rozdej ho testerům předem."])

    H1("5. Vytvoření a řízení hry")
    B(["Karta <b>Hry</b>: vyber <b>připravený plán</b>, zadej <b>počet hráčů</b> (≤ počet startů) a "
       "<b>režim hry</b> → <b>„+ Nová hra“</b>. Režimy: <b>Realtime (GPS)</b> = normální hra venku; "
       "<b>Simulace (klikání)</b> = test od stolu klikáním do mapy; <b>Run hra (joystick)</b> = test od "
       "stolu s auto-pohybem (joystick + rychlosti + stamina, viz hráčská příručka).",
       "Hra se objeví v seznamu jako <b>„v lobby“</b> — hráči se k ní teď můžou připojovat a vybírat starty.",
       "<b>Sleduj</b> — otevře živou mapu hry (viz níže).",
       "<b>Spustit</b> — zahájí hru (hráčům naskočí odpočet 10 s). Spustit lze jen s aspoň jedním "
       "připojeným hráčem.",
       "<b>Ukončit</b> — předčasně ukončí běžící hru (jde do historie).",
       "<b>Smazat</b> — zahodí hru v lobby."])

    H2("Sledování hry (Sleduj)")
    B(["Vidíš <b>stopy všech hráčů</b> a jejich polohu v reálném čase, i kdo už <b>je na svém startu</b> "
       "(ano / ne).",
       "Před spuštěním zkontroluj, že jsou hráči na startech — pak <b>„Spustit hru“</b> i odsud.",
       "Jako divák uvidíš celou stopu od začátku (ukládá se na server)."])

    H1("6. Po hře")
    B(["Karta <b>Dokončené hry</b>: u každé „Výsledky“ ukážou <b>pořadí</b>, <b>obrázek tras</b> a "
       "<b>délky</b>. Hru lze i smazat.",
       "Hra se <b>ukončí sama</b>, když vypadne poslední hráč. Hra bez hráčů se rovnou vyhodnotí."])

    H1("7. Hráči — účty")
    B(["Karta <b>Hráči — účty</b>: seznam registrovaných hráčů; „smazat“ hráče zapomene "
       "(bude se muset zaregistrovat znovu novým kódem)."])

    H1("8. Doporučený postup (poprvé)")
    B(["Vytvoř <b>plán</b> → <b>Oblast</b> obkresli území → <b>Najít ulice</b> → v <b>Ulice</b> uprav, "
       "co je ve hře.",
       "Přidej <b>Starty</b> (aspoň tolik, kolik čekáš hráčů) → <b>připravit ke hře</b>.",
       "Ve <b>Správě</b> zkontroluj <b>Nastavení zápasu</b>, vygeneruj <b>kódy</b> a rozdej je hráčům.",
       "Hráči se zaregistrují a připojí → <b>vytvoř hru</b> z plánu → počkej, až budou na startech → "
       "<b>Spustit</b>.",
       "Tip pro první test: založ hru v režimu <b>Simulace</b> nebo <b>Run hra</b>, ať si vše vyzkoušíš "
       "od stolu bez chození."])


if __name__ == "__main__":
    build(os.path.join(PUBLIC, "manual-hrac.pdf"),
          "Příručka pro hráče", "AchtungDieKM — jak hrát", player)
    build(os.path.join(PUBLIC, "manual-admin.pdf"),
          "Příručka pro admina", "AchtungDieKM — správa her a plánů", admin)
    print("done ->", PUBLIC)
