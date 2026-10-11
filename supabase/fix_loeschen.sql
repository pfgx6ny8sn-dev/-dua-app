-- Little Muslim – Korrektur: "Kind löschen" und "Familie löschen"
-- (Bisher schlug das Löschen fehl, sobald mehrere Familien gespeichert sind.)
create or replace function public.delete_kid(p_code text, p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare k uuid := public._kid(p_code, p_id);
begin
  delete from public.kids where id = k;
end $$;

create or replace function public.delete_family(p_code text) returns void
language plpgsql security definer set search_path = '' as $$
declare f uuid := public._fam(p_code);
begin
  delete from public.families where id = f;
end $$;

-- Testdaten von Claude entfernen
delete from public.families where name like 'zz-test-claude-%';
