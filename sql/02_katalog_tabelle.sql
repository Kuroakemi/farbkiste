-- SCHRITT 2 von 3: Katalog-Tabelle anlegen und "farben" erweitern

-- 1) Der Katalog: alle Citadel- und Vallejo-Farben, nur zum Nachschlagen
create table public.katalog (
  id bigint generated always as identity primary key,
  marke text not null,
  name text not null,
  linie text not null,          -- Produktlinie, z. B. "Base", "Shade" oder "Game Color"
  typ text,                     -- passend zu den Typen in "farben" (bei Vallejo oft leer)
  code text,                    -- Vallejo-Artikelnummer, z. B. "72.120"
  farbfamilie text,
  hex text,                     -- Farbcode für das Farbmuster, z. B. "#141414"
  unique (marke, name, linie)
);

alter table public.katalog enable row level security;

-- Eingeloggte dürfen den Katalog nur lesen, nicht verändern
create policy "Eingeloggte duerfen lesen"
  on public.katalog for select
  to authenticated
  using (true);

-- 2) Eure eigene Farbliste bekommt die gleichen Zusatzinfos
alter table public.farben
  add column linie text,
  add column code text,
  add column hex text;

-- 3) Gleicher Name + Marke darf es jetzt mehrfach geben, wenn die Linie anders ist
--    (z. B. "Abaddon Black" als Base UND als Air). "nulls not distinct" heisst:
--    Auch zwei Einträge ohne Linie gelten als Doppel.
alter table public.farben drop constraint farben_name_marke_key;
alter table public.farben
  add constraint farben_name_marke_linie_key unique nulls not distinct (name, marke, linie);
