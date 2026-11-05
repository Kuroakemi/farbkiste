# farbkiste

Farbverwaltung für unsere Warhammer-Farben: Bestand, Füllstand und Einkaufsliste.

**App:** https://kuroakemi.github.io/farbkiste/

## Aufbau

| Teil | Was es macht |
|---|---|
| `index.html` | Die ganze Webseite (Login, Farbliste, Einkaufsliste, Katalog-Vorschläge) |
| `sql/` | Datenbank-Befehle für Supabase, in der Reihenfolge der Nummern |
| `tools/katalog_bauen.py` | Erzeugt `sql/03_katalog_daten.sql` aus den offenen Farb-Datensätzen |
| `.github/workflows/wecker.yml` | Pingt Supabase zweimal pro Woche, damit das Gratis-Projekt nicht pausiert |

Die Daten liegen in Supabase und sind per Login und Row Level Security geschützt.
Lizenzen der Farbdaten: siehe [LIZENZEN.md](LIZENZEN.md).
