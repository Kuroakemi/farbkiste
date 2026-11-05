-- SCHRITT 6: Sicherungen (Momentaufnahmen aller Daten, direkt in der Datenbank)

create table public.sicherungen (
  id bigint generated always as identity primary key,
  erstellt_am timestamptz not null default now(),
  art text not null check (art in ('automatisch', 'manuell', 'vor Wiederherstellung')),
  zusammenfassung text,
  daten jsonb not null          -- alle Farben, Armeen, Rezepte und Schritte als ein Paket
);

alter table public.sicherungen enable row level security;
create policy "Eingeloggte duerfen alles" on public.sicherungen
  for all to authenticated using (true) with check (true);


-- Sicherung erstellen: packt alle Tabellen in ein JSON-Paket.
-- Von den automatischen Sicherungen werden nur die neuesten 30 behalten.
create or replace function public.sicherung_erstellen(p_art text default 'manuell')
returns bigint
language plpgsql
set search_path = public
as $$
declare
  neu bigint;
begin
  insert into sicherungen (art, zusammenfassung, daten)
  values (
    p_art,
    format('%s Farben · %s Armeen · %s Rezepte',
           (select count(*) from farben), (select count(*) from armeen), (select count(*) from rezepte)),
    jsonb_build_object(
      'farben',   (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from farben t),
      'armeen',   (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from armeen t),
      'rezepte',  (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from rezepte t),
      'schritte', (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from schritte t)
    )
  )
  returning id into neu;

  delete from sicherungen
  where art <> 'manuell'
    and id not in (select id from sicherungen where art <> 'manuell' order by erstellt_am desc limit 30);

  return neu;
end;
$$;


-- Sicherung wiederherstellen: ersetzt ALLE aktuellen Daten durch den gesicherten Stand.
-- Läuft als Ganzes ("alles oder nichts"): Bei einem Fehler bleibt alles, wie es war.
-- Vorher wird automatisch der jetzige Stand gesichert.
create or replace function public.sicherung_wiederherstellen(p_id bigint)
returns void
language plpgsql
set search_path = public
as $$
declare
  d jsonb;
begin
  select daten into d from sicherungen where id = p_id;
  if d is null then
    raise exception 'Sicherung % nicht gefunden', p_id;
  end if;

  perform sicherung_erstellen('vor Wiederherstellung');

  -- Reihenfolge wegen der Verknüpfungen: zuerst die "Kinder", dann die "Eltern"
  delete from schritte where true;
  delete from rezepte where true;
  delete from armeen where true;
  delete from farben where true;

  -- "overriding system value": die alten Nummern (id) wiederverwenden, damit die Verknüpfungen stimmen
  insert into farben   overriding system value select * from jsonb_populate_recordset(null::farben,   d->'farben');
  insert into armeen   overriding system value select * from jsonb_populate_recordset(null::armeen,   d->'armeen');
  insert into rezepte  overriding system value select * from jsonb_populate_recordset(null::rezepte,  d->'rezepte');
  insert into schritte overriding system value select * from jsonb_populate_recordset(null::schritte, d->'schritte');

  -- Den Zähler für neue Nummern hinter die höchste vorhandene setzen
  perform setval(pg_get_serial_sequence('farben', 'id'),   coalesce((select max(id) from farben), 0) + 1, false);
  perform setval(pg_get_serial_sequence('armeen', 'id'),   coalesce((select max(id) from armeen), 0) + 1, false);
  perform setval(pg_get_serial_sequence('rezepte', 'id'),  coalesce((select max(id) from rezepte), 0) + 1, false);
  perform setval(pg_get_serial_sequence('schritte', 'id'), coalesce((select max(id) from schritte), 0) + 1, false);
end;
$$;

-- Nur eingeloggte Benutzer dürfen die beiden Funktionen aufrufen
revoke execute on function public.sicherung_erstellen(text) from public, anon;
revoke execute on function public.sicherung_wiederherstellen(bigint) from public, anon;
grant execute on function public.sicherung_erstellen(text) to authenticated;
grant execute on function public.sicherung_wiederherstellen(bigint) to authenticated;

-- Gleich eine erste Sicherung anlegen
select public.sicherung_erstellen('manuell');
