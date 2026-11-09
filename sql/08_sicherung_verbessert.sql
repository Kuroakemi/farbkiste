-- SCHRITT 8: Sicherungen verbessern
-- 1) Keine doppelten automatischen Sicherungen mehr, auch wenn die App auf zwei
--    Geräten gleichzeitig geöffnet wird ("advisory lock" = nur einer gleichzeitig).
-- 2) Richtige Einzahl in der Zusammenfassung ("1 Armee" statt "1 Armeen").

create or replace function public.sicherung_erstellen(p_art text default 'manuell')
returns bigint
language plpgsql
set search_path = public
as $$
declare
  neu bigint;
  n_f int; n_a int; n_r int;
begin
  perform pg_advisory_xact_lock(hashtext('farbkiste_sicherung'));

  if p_art = 'automatisch' and exists (
    select 1 from sicherungen where art = 'automatisch' and erstellt_am > now() - interval '20 hours'
  ) then
    return null;
  end if;

  select count(*) into n_f from farben;
  select count(*) into n_a from armeen;
  select count(*) into n_r from rezepte;

  insert into sicherungen (art, zusammenfassung, daten)
  values (
    p_art,
    format('%s %s · %s %s · %s %s',
           n_f, case when n_f = 1 then 'Farbe' else 'Farben' end,
           n_a, case when n_a = 1 then 'Armee' else 'Armeen' end,
           n_r, case when n_r = 1 then 'Rezept' else 'Rezepte' end),
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
