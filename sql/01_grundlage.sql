-- SCHRITT 1 (bereits ausgeführt am 05.11.2026)
-- Nur zur Dokumentation: So wurde die Tabelle "farben" ursprünglich angelegt.

create table public.farben (
  id bigint generated always as identity primary key,
  name text not null,
  marke text not null default 'Citadel',
  typ text check (typ in ('Base','Layer','Shade','Contrast','Technical','Dry','Air','Spray','Andere')),
  farbfamilie text,
  anzahl int not null default 1 check (anzahl >= 0),
  fuellstand text not null default 'voll'
    check (fuellstand in ('voll','halb','fast leer','eingetrocknet','leer')),
  einkaufen boolean not null default false,
  notizen text,
  erstellt_am timestamptz not null default now(),
  unique (name, marke)
);

alter table public.farben enable row level security;

create policy "Eingeloggte duerfen alles"
  on public.farben for all
  to authenticated
  using (true) with check (true);
