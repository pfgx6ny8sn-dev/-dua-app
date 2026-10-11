-- Little Muslim – Alter der Profile (für faire Punkte) und Gruppenname ändern
alter table public.kids add column if not exists birth_year int check (birth_year between 1900 and 2100);

create or replace function public.set_kid_age(p_code text, p_kid uuid, p_year int) returns void
language plpgsql security definer set search_path = '' as $$
declare k uuid := public._kid(p_code, p_kid);
begin
  if p_year is null or p_year < 1900 or p_year > extract(year from now())::int then raise exception 'bad_year'; end if;
  update public.kids set birth_year = p_year where id = k;
end $$;

create or replace function public.rename_group(p_code text, p_group uuid, p_name text) returns void
language plpgsql security definer set search_path = '' as $$
declare f uuid := public._fam(p_code);
begin
  perform private.member(f, p_group);
  update public.groups set name = left(coalesce(trim(p_name), ''), 40) where id = p_group;
end $$;

create or replace function public.get_family(p_code text) returns json
language plpgsql security definer set search_path = '' as $$
declare f uuid := public._fam(p_code);
begin
  return (select json_build_object(
    'name', fa.name,
    'kids', coalesce((select json_agg(json_build_object(
        'id', k.id, 'name', k.name, 'avatar', k.avatar, 'pin', k.pin, 'by', k.birth_year,
        'tb', (select d.value from public.kid_data d where d.kid_id = k.id and d.key = 'tb-log'),
        'done', (select d.value from public.kid_data d where d.kid_id = k.id and d.key = 'lm-tz-done')
      ) order by k.sort, k.created_at) from public.kids k where k.family_id = f), '[]'::json))
    from public.families fa where fa.id = f);
end $$;

create or replace function public.group_board(p_code text, p_group uuid, p_from text, p_to text, p_wk date) returns json
language plpgsql security definer set search_path = '' as $$
declare f uuid := public._fam(p_code);
begin
  perform private.member(f, p_group);
  return json_build_object(
    'group', (select json_build_object('id', g.id, 'name', g.name, 'invite', g.invite,
                'n', (select count(*) from public.group_members x where x.group_id = g.id)) from public.groups g where g.id = p_group),
    'kids', coalesce((select json_agg(json_build_object(
        'id', k.id, 'name', k.name, 'avatar', k.avatar, 'fam', fa.name, 'mine', k.family_id = f, 'by', k.birth_year,
        's', private.pts((select d.value from public.kid_data d where d.kid_id = k.id and d.key = 'lm-pts'), p_from, p_to)))
      from public.group_members gm
      join public.kids k on k.family_id = gm.family_id
      join public.families fa on fa.id = gm.family_id
      where gm.group_id = p_group and not exists(select 1 from public.kid_hidden h where h.kid_id = k.id)), '[]'::json),
    'duels', coalesce((select json_agg(json_build_object('id', d.id, 'from', d.from_kid, 'to', d.to_kid, 'kind', d.kind,
        'at', d.created_at, 'wk', d.wk) order by d.created_at desc)
      from public.duels d
      where d.group_id = p_group and d.wk = p_wk
        and exists(select 1 from public.kids k where k.family_id = f and (k.id = d.from_kid or k.id = d.to_kid))), '[]'::json));
end $$;

grant execute on function public.set_kid_age(text, uuid, int), public.rename_group(text, uuid, text) to anon, authenticated;
