-- Little Muslim – Push-Erinnerungen wie auf dem Home-Bildschirm (Athkar, Wird, Hadith des Tages) + Punkte für alle Aktivitäten
alter table public.push_subs add column if not exists extras text[] not null default '{athkar,wird,hadith}';
alter table public.push_subs add column if not exists done text not null default '';
alter table public.push_subs drop constraint if exists push_subs_extras_check;
alter table public.push_subs add constraint push_subs_extras_check check (extras <@ array['athkar','wird','hadith']);

create or replace function public.push_extras(p_endpoint text, p_extras text[])
returns void language sql security definer set search_path = public as $$
  update public.push_subs set extras = coalesce(array(select unnest(p_extras) intersect select unnest(array['athkar','wird','hadith'])), '{}'), updated_at = now()
   where endpoint = p_endpoint;
$$;
create or replace function public.push_done(p_endpoint text, p_tags text[])
returns void language sql security definer set search_path = public as $$
  update public.push_subs set done = left(array_to_string(array(select t from unnest(p_tags) t where t ~ '^\d{4}-\d{2}-\d{2}:(sabah|masa|mulk|kahf)$' limit 8), ','), 300)
   where endpoint = p_endpoint;
$$;
revoke all on function public.push_extras(text, text[]) from public;
revoke all on function public.push_done(text, text[]) from public;
grant execute on function public.push_extras(text, text[]) to anon, authenticated;
grant execute on function public.push_done(text, text[]) to anon, authenticated;
-- Little Muslim – Punkte aller Aktivitäten getrennt in der Rangliste anzeigen
-- (gelesen / auswendig; die Gesamtpunkte zählen auch ohne dieses Update)
create or replace function private.pts(v text, p_from text, p_to text) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare j jsonb; r jsonb;
begin
  if v is null then return '{"pt":0,"s":0,"sn":0,"t":0,"q":0,"g":0,"d":0,"l":0,"p":0,"hr":0,"h":0,"qr":0,"qh":0,"a":0,"wd":0,"qp":0,"qg":0,"f":0,"du":0,"wi":0,"st":0,"nm":0}'::jsonb; end if;
  begin
    j := v::jsonb;
    if jsonb_typeof(j) <> 'object' then return '{"pt":0,"s":0,"sn":0,"t":0,"q":0,"g":0,"d":0,"l":0,"p":0,"hr":0,"h":0,"qr":0,"qh":0,"a":0,"wd":0,"qp":0,"qg":0,"f":0,"du":0,"wi":0,"st":0,"nm":0}'::jsonb; end if;
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
      'qh', coalesce(sum((e.value->>'qh')::numeric), 0)::int,
      'a', coalesce(sum((e.value->>'a')::numeric), 0)::int,
      'wd', coalesce(sum((e.value->>'wd')::numeric), 0)::int,
      'qp', coalesce(sum((e.value->>'qp')::numeric), 0)::int,
      'qg', coalesce(sum((e.value->>'qg')::numeric), 0)::int,
      'f', coalesce(sum((e.value->>'f')::numeric), 0)::int,
      'du', coalesce(sum((e.value->>'du')::numeric), 0)::int,
      'wi', coalesce(sum((e.value->>'wi')::numeric), 0)::int,
      'st', coalesce(sum((e.value->>'st')::numeric), 0)::int,
      'nm', coalesce(sum((e.value->>'nm')::numeric), 0)::int)
      into r
      from jsonb_each(j) e
     where e.key >= p_from and e.key <= p_to and jsonb_typeof(e.value) = 'object';
    return r;
  exception when others then
    return '{"pt":0,"s":0,"sn":0,"t":0,"q":0,"g":0,"d":0,"l":0,"p":0,"hr":0,"h":0,"qr":0,"qh":0,"a":0,"wd":0,"qp":0,"qg":0,"f":0,"du":0,"wi":0,"st":0,"nm":0}'::jsonb;
  end;
end $$;
