-- SCHRITT 9: "Tone Pro" als eigenen Typ, damit der Typ-Filter die neuen Farben findet

-- Erlaubte Typen um "Tone Pro" erweitern
alter table public.farben drop constraint if exists farben_typ_check;
alter table public.farben add constraint farben_typ_check
  check (typ in ('Base','Layer','Shade','Contrast','Tone Pro','Technical','Dry','Air','Spray','Andere'));

-- Katalog und bereits erfasste Farben nachführen
update public.katalog set typ = 'Tone Pro' where linie = 'Tone Pro';
update public.farben set typ = 'Tone Pro' where linie = 'Tone Pro';
