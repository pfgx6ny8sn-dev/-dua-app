-- Little Muslim – Qur'an- und Hadith-Punkte getrennt in der Rangliste anzeigen
-- (gelesen / auswendig; die Gesamtpunkte zählen auch ohne dieses Update)
create or replace function private.pts(v text, p_from text, p_to text) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare j jsonb; r jsonb;
begin
  if v is null then return '{"pt":0,"s":0,"sn":0,"t":0,"q":0,"g":0,"d":0,"l":0,"p":0,"hr":0,"h":0,"qr":0,"qh":0}'::jsonb; end if;
  begin
    j := v::jsonb;
    if jsonb_typeof(j) <> 'object' then return '{"pt":0,"s":0,"sn":0,"t":0,"q":0,"g":0,"d":0,"l":0,"p":0,"hr":0,"h":0,"qr":0,"qh":0}'::jsonb; end if;
    select jsonb_build_object(
      'pt', coalesce(sum((e.value->>'pt')::numeric), 0)::int,
      's',  coalesce(sum((e.value->>'s')::numeric), 0)::int,
      'sn', coalesce(sum((e.value->>'sn')::numeric), 0)::int,
      't',  coalesce(sum((e.value->>'t')::numeric), 0)::int,
      'q',  coalesce(sum((e.value->>'q')::numeric), 0)::int,
      'g',  coalesce(sum((e.value->>'g')::numeric), 0)::int,
      'd',  coalesce(sum((e.value->>'d')::numeric), 0)::int,
      'l',  coalesce(sum((e.value->>'l')::numeric), 0)::int,
      'p',  coalesce(sum((e.value->>'p')::numeric), 0)::int,
      'hr', coalesce(sum((e.value->>'hr')::numeric), 0)::int,
      'h',  coalesce(sum((e.value->>'h')::numeric), 0)::int,
      'qr', coalesce(sum((e.value->>'qr')::numeric), 0)::int,
      'qh', coalesce(sum((e.value->>'qh')::numeric), 0)::int)
      into r
      from jsonb_each(j) e
     where e.key >= p_from and e.key <= p_to and jsonb_typeof(e.value) = 'object';
    return r;
  exception when others then
    return '{"pt":0,"s":0,"sn":0,"t":0,"q":0,"g":0,"d":0,"l":0,"p":0,"hr":0,"h":0,"qr":0,"qh":0}'::jsonb;
  end;
end $$;
