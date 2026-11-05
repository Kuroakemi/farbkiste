-- SCHRITT 5: Armeen, Farbrezepte und Rezept-Schritte

-- Eine Armee, z. B. "Death Guard". Genau eine kann "gerade dran" sein.
create table public.armeen (
  id bigint generated always as identity primary key,
  name text not null unique,
  notizen text,
  aktiv boolean not null default false,
  erstellt_am timestamptz not null default now()
);

-- Ein Rezept gehört zu einer Armee, z. B. "Rüstung" oder "Base".
-- "on delete cascade": Wird die Armee gelöscht, verschwinden ihre Rezepte mit.
create table public.rezepte (
  id bigint generated always as identity primary key,
  armee_id bigint not null references public.armeen(id) on delete cascade,
  name text not null,
  notizen text,
  geaendert_am timestamptz not null default now()
);

-- Ein Schritt im Rezept: Phase, optional eine Farbe, optional freier Text.
-- Die Farbe kommt entweder aus eurer Liste (farbe_id) oder aus dem Katalog (katalog_id).
-- "on delete set null": Löscht ihr eine Farbe, bleibt der Schritt erhalten, nur ohne Farbe.
create table public.schritte (
  id bigint generated always as identity primary key,
  rezept_id bigint not null references public.rezepte(id) on delete cascade,
  position int not null default 0,
  phase text not null check (phase in
    ('Grundierung','Base','Shade','Layer','Highlight','Drybrush','Effekt','Basing','Sonstiges')),
  farbe_id bigint references public.farben(id) on delete set null,
  katalog_id bigint references public.katalog(id) on delete set null,
  text text,      -- z. B. "Eis-Effekt von Green Stuff World" oder eine Technik
  notiz text
);

-- Gleicher Schutz wie bei den Farben: nur eingeloggte Benutzer
alter table public.armeen enable row level security;
alter table public.rezepte enable row level security;
alter table public.schritte enable row level security;

create policy "Eingeloggte duerfen alles" on public.armeen
  for all to authenticated using (true) with check (true);
create policy "Eingeloggte duerfen alles" on public.rezepte
  for all to authenticated using (true) with check (true);
create policy "Eingeloggte duerfen alles" on public.schritte
  for all to authenticated using (true) with check (true);
