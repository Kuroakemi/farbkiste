"""Baut aus zwei offenen Farb-Datensätzen die SQL-Datei für den Farbkatalog.

Quellen (beide MIT-Lizenz, siehe LIZENZEN.md):
  - Arcturus5404/miniature-paints  -> Namen, Produktlinien, Vallejo-Nummern, Farbcodes
  - ArturSkowronski/minipainter    -> genauere Farbfamilien und Farbcodes (falls vorhanden)

Aufruf:  python3 katalog_bauen.py <ordner-miniature-paints> <ordner-minipainter> <sql/03_katalog_daten.sql>
"""
import colorsys
import json
import re
import sys
from pathlib import Path

mp_dir, minip_dir, ausgabe = map(Path, sys.argv[1:4])

# Englische Familien aus minipainter -> unsere deutschen Farbfamilien
FAMILIEN = {
    "black": "Schwarz", "white": "Weiss", "grey": "Grau", "red": "Rot", "orange": "Orange",
    "yellow": "Gelb", "green": "Grün", "teal": "Türkis", "blue": "Blau", "purple": "Violett",
    "pink": "Pink", "brown": "Braun", "leather": "Braun", "khaki": "Braun", "bone": "Knochen",
    "skin": "Hautton", "metallic": "Metallic",
}

METALL = re.compile(
    r"gold|silver|steel|bronze|brass|copper|iron|metal|alloy|chrome|armour|leadbelcher|"
    r"chainmail|gunmetal|mithril|bolt ?gun|warplock|runefang|canoptek|tin bitz|necron compound|"
    r"stormhost|fulgurite|gehenna|liberator|sycorax|hashut|balthasar|aluminium|titanium|plata|oro|screaming bell|golden griffon",
    re.I,
)

# Namen, die zwar ein Metall-Wort enthalten, aber keine Metallfarben sind (z. B. "Golden Yellow")
KEIN_METALL = re.compile(
    r"brown|flesh|green|yellow|olive|drab|armourshade|martian|desert|steel grey|silver grey|steel blue",
    re.I,
)


def ist_metall(name, linie):
    if linie in ("Metal Color", "Liquid Gold") or "(Metallic)" in name:
        return True
    return bool(METALL.search(name)) and not KEIN_METALL.search(name)


# Produktlinie -> unser "typ" (muss zur check-Regel in der Datenbank passen)
CITADEL_TYP = {
    "Base": "Base", "Layer": "Layer", "Shade": "Shade", "Contrast": "Contrast",
    "Technical": "Technical", "Dry": "Dry", "Air": "Air", "Spray": "Spray",
}
VALLEJO_TYP = {
    "Game Air": "Air", "Model Air": "Air", "Premium Airbrush Color": "Air",
    "Game Color Wash": "Shade", "Wash FX": "Shade",
    "Xpress Color": "Contrast", "Xpress Color Intense": "Contrast",
    "Surface Primer": "Spray",
    "Game Color Special FX": "Technical", "Weathering FX": "Technical",
}
# Bastelfarben, keine Miniaturfarben -> weglassen
VALLEJO_OHNE = {"Arte Deco", "Arte Deco Colores Fluoresecents"}


def tabelle(datei):
    """Liest die Markdown-Tabelle einer Marke als Liste von Spaltenlisten."""
    zeilen = []
    for z in datei.read_text(encoding="utf-8").splitlines():
        if not z.startswith("|") or z.startswith("|Name") or z.startswith("|---"):
            continue
        zeilen.append([s.strip() for s in z.strip("|").split("|")])
    return zeilen


# Farbwörter im Namen -> Farbfamilie. Der Name ist meist die zuverlässigste Angabe.
NAMENSWOERTER = [
    (r"black|negro|noir", "Schwarz"), (r"white|blanco|ivory", "Weiss"), (r"gr[ae]y|ash", "Grau"),
    (r"red|crimson|scarlet|blood|carmine|rojo", "Rot"), (r"orange|ochre|amber", "Orange"),
    (r"yellow|amarillo|sand|cream", "Gelb"), (r"green|olive|verde|emerald|jade|lime", "Grün"),
    (r"turquoise|teal|cyan|aqua", "Türkis"), (r"blue|azul|navy|sky|ultramarine", "Blau"),
    (r"purple|violet|lilac|lavender|magenta|plum", "Violett"), (r"pink|rose|rosa", "Pink"),
    (r"brown|leather|wood|earth|rust|mud|tan|khaki|marron|chocolate|beige", "Braun"),
    (r"flesh|skin|kislev|cadian fleshtone", "Hautton"), (r"bone|ushabti|wraithbone|bleached", "Knochen"),
]


def familie_aus_name(name):
    """Sucht das LETZTE Farbwort im Namen ("Yellow Olive" -> Olive -> Grün)."""
    bester = None
    for muster, familie in NAMENSWOERTER:
        for m in re.finditer(r"\b(" + muster + r")\b", name, re.I):
            if bester is None or m.start() > bester[0]:
                bester = (m.start(), familie)
    return bester[1] if bester else None


def familie_aus_farbe(r, g, b):
    """Notlösung, wenn keine Familie bekannt ist: aus dem Farbton schätzen."""
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    h *= 360
    if s < 0.15 or v < 0.12:
        return "Schwarz" if v < 0.22 else "Weiss" if v > 0.85 else "Grau"
    if 15 <= h < 45 and v < 0.6:
        return "Braun"
    for grenze, name in [(15, "Rot"), (40, "Orange"), (70, "Gelb"), (165, "Grün"),
                         (195, "Türkis"), (255, "Blau"), (290, "Violett"), (340, "Pink")]:
        if h < grenze:
            return name
    return "Rot"


def minipainter(marke):
    daten = json.loads((minip_dir / "data/catalog" / f"{marke}.json").read_text(encoding="utf-8"))
    return {p["normalized_name"]: p for p in daten["paints"]}


def hexcode(r, g, b):
    return f"#{int(r):02X}{int(g):02X}{int(b):02X}"


eintraege = {}


def hinzufuegen(marke, name, linie, typ, code, r, g, b, extra):
    if (marke, name, linie) in eintraege:   # die Quelle enthält einige Doppel
        return
    # Genauere Daten aus minipainter übernehmen, wenn der Name passt
    # Metallfarben zuerst erkennen: die Quellen ordnen sie oft nach Farbton ein
    familie = "Metallic" if ist_metall(name, linie) else familie_aus_name(name)
    if extra:
        fams = [FAMILIEN[f] for f in extra["color_families"] if f in FAMILIEN]
        if KEIN_METALL.search(name) or not METALL.search(name):
            # Die Quelle markiert manche normalen Farben als Metallic, z. B. "Ultramarine Blue"
            fams = [f for f in fams if f != "Metallic"]
        if fams and not familie:
            familie = "Metallic" if "Metallic" in fams else fams[0]
        # Farbcode nur übernehmen, wenn es keine abweichende Variante (z. B. Air) ist
        if linie in ("Base", "Layer", "Shade", "Contrast", "Technical", "Dry", "Game Color"):
            c = extra["rgb"]
            r, g, b = c["r"], c["g"], c["b"]
    if not familie:
        familie = familie_aus_farbe(int(r), int(g), int(b))
    eintraege[(marke, name, linie)] = (marke, name, linie, typ, code, familie, hexcode(r, g, b))


# --- Citadel ---
mini_cit = minipainter("citadel")
for name, linie, r, g, b, _ in tabelle(mp_dir / "paints/Citadel_Colour.md"):
    linie = linie.replace(" (discontinued)", " (alt)")
    typ = CITADEL_TYP.get(linie, "Andere")
    hinzufuegen("Citadel", name, linie, typ, None, r, g, b, mini_cit.get(name.lower()))

# --- Vallejo ---
mini_val = minipainter("vallejo")
for name, code, linie, r, g, b, _ in tabelle(mp_dir / "paints/Vallejo.md"):
    if linie in VALLEJO_OHNE:
        continue
    typ = VALLEJO_TYP.get(linie)  # Game/Model Color usw. bleiben ohne festen Typ
    extra = mini_val.get(name.lower()) if linie.startswith("Game Color") else None
    hinzufuegen("Vallejo", name, linie, typ, code or None, r, g, b, extra)


def sql(wert):
    return "null" if wert is None else "'" + str(wert).replace("'", "''") + "'"


zeilen = sorted(eintraege.values(), key=lambda e: (e[0], e[1].lower(), e[2]))
werte = ",\n".join("  (" + ", ".join(sql(w) for w in e) + ")" for e in zeilen)
ausgabe.write_text(
    "-- SCHRITT 3 von 3 (nach 02_katalog_tabelle.sql ausführen)\n"
    "-- Automatisch erzeugt von tools/katalog_bauen.py. Quellen und Lizenzen: LIZENZEN.md\n"
    "insert into public.katalog (marke, name, linie, typ, code, farbfamilie, hex)\nvalues\n"
    + werte + "\non conflict (marke, name, linie) do update\n"
    "  set typ = excluded.typ, code = excluded.code, farbfamilie = excluded.farbfamilie, hex = excluded.hex;\n\n"
    "-- Bereits erfasste Citadel-Farben mit dem Katalog verbinden (Linie und Farbcode ergänzen)\n"
    "update public.farben f\n"
    "set linie = k.linie, code = k.code, hex = k.hex\n"
    "from public.katalog k\n"
    "where f.linie is null and f.marke = k.marke and f.name = k.name and k.linie = f.typ;\n",
    encoding="utf-8",
)
anzahl = {}
for e in zeilen:
    anzahl[e[0]] = anzahl.get(e[0], 0) + 1
print("Geschrieben:", ausgabe, anzahl)
