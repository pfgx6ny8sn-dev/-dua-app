-- Little Muslim – Challenge (Gruppen, Rangliste, Herausforderungen)
-- Fügt nur Neues hinzu, bestehende Daten werden nicht verändert.
create schema if not exists private;

create table public.groups(
  id uuid primary key default gen_random_uuid(),
  invite text not null unique,
  name text not null default '' check (char_length(name) <= 40),
  created_at timestamptz not null default now()
);
create table public.group_members(
  group_id uuid not null references public.groups(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(group_id, family_id)
);
create index group_members_family_idx on public.group_members(family_id);
create table public.duels(
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  from_kid uuid not null references public.kids(id) on delete cascade,
  to_kid uuid not null references public.kids(id) on delete cascade,
  kind text not null check (kind in ('pt','t','q','g','d')),
  wk date not null,
  created_at timestamptz not null default now(),
  unique(group_id, from_kid, to_kid, kind, wk)
);
create index duels_group_wk_idx on public.duels(group_id, wk);
create index duels_to_idx on public.duels(to_kid);
create index duels_from_idx on public.duels(from_kid);
create table public.kid_hidden(
  kid_id uuid primary key references public.kids(id) on delete cascade
);
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.duels enable row level security;
alter table public.kid_hidden enable row level security;
revoke all on public.groups, public.group_members, public.duels, public.kid_hidden from anon, authenticated;

create function private.pts(v text, p_from text, p_to text) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare j jsonb; r jsonb;
begin
  if v is null then return '{"pt":0,"t":0,"q":0,"g":0,"d":0,"l":0,"p":0}'::jsonb; end if;
  begin
    j := v::jsonb;
    if jsonb_typeof(j) <> 'object' then return '{"pt":0,"t":0,"q":0,"g":0,"d":0,"l":0,"p":0}'::jsonb; end if;
    select jsonb_build_object(
      'pt', coalesce(sum((e.value->>'pt')::numeric), 0)::int,
      't',  coalesce(sum((e.value->>'t')::numeric), 0)::int,
      'q',  coalesce(sum((e.value->>'q')::numeric), 0)::int,
      'g',  coalesce(sum((e.value->>'g')::numeric), 0)::int,
      'd',  coalesce(sum((e.value->>'d')::numeric), 0)::int,
      'l',  coalesce(sum((e.value->>'l')::numeric), 0)::int,
      'p',  coalesce(sum((e.value->>'p')::numeric), 0)::int)
      into r
      from jsonb_each(j) e
     where e.key >= p_from and e.key <= p_to and jsonb_typeof(e.value) = 'object';
    return r;
  exception when others then
    return '{"pt":0,"t":0,"q":0,"g":0,"d":0,"l":0,"p":0}'::jsonb;
  end;
end $$;

create function private.member(p_fam uuid, p_group uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not exists(select 1 from public.group_members where family_id = p_fam and group_id = p_group) then
    raise exception 'group_not_found' using errcode = 'P0002';
  end if;
end $$;

create function private.invite() returns text
language plpgsql security definer set search_path = '' as $$
declare alpha text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; b bytea; raw text := ''; i int;
begin
  b := extensions.gen_random_bytes(8);
  for i in 0..7 loop raw := raw || substr(alpha, (get_byte(b, i) % 32) + 1, 1); end loop;
  return substr(raw, 1, 4) || '-' || substr(raw, 5, 4);
end $$;

create function public.my_groups(p_code text) returns json
language plpgsql security definer set search_path = '' as $$
declare f uuid := public._fam(p_code);
begin
  return json_build_object(
    'groups', coalesce((select json_agg(json_build_object('id', g.id, 'name', g.name, 'invite', g.invite,
        'n', (select count(*) from public.group_members x where x.group_id = g.id)) order by gm.joined_at)
      from public.group_members gm join public.groups g on g.id = gm.group_id where gm.family_id = f), '[]'::json),
    'hidden', coalesce((select json_agg(h.kid_id) from public.kid_hidden h join public.kids k on k.id = h.kid_id where k.family_id = f), '[]'::json));
end $$;

create function public.create_group(p_code text, p_name text) returns json
language plpgsql security definer set search_path = '' as $$
declare f uuid := public._fam(p_code); g public.groups;
begin
  if (select count(*) from public.group_members where family_id = f) >= 10 then raise exception 'too_many_groups'; end if;
  loop
    begin
      insert into public.groups(invite, name) values (private.invite(), left(coalesce(trim(p_name), ''), 40)) returning * into g;
      exit;
    exception when unique_violation then end;
  end loop;
  insert into public.group_members(group_id, family_id) values (g.id, f);
  return json_build_object('id', g.id, 'name', g.name, 'invite', g.invite, 'n', 1);
end $$;

create function public.join_group(p_code text, p_invite text) returns json
language plpgsql security definer set search_path = '' as $$
declare f uuid := public._fam(p_code); g public.groups; inv text;
begin
  inv := upper(regexp_replace(coalesce(p_invite, ''), '[^A-Za-z0-9]', '', 'g'));
  inv := substr(inv, 1, 4) || '-' || substr(inv, 5, 4);
  select * into g from public.groups where invite = inv;
  if g.id is null then raise exception 'group_not_found' using errcode = 'P0002'; end if;
  if (select count(*) from public.group_members where group_id = g.id) >= 30 then raise exception 'group_full'; end if;
  if (select count(*) from public.group_members where family_id = f) >= 10 then raise exception 'too_many_groups'; end if;
  insert into public.group_members(group_id, family_id) values (g.id, f) on conflict do nothing;
  return json_build_object('id', g.id, 'name', g.name, 'invite', g.invite,
    'n', (select count(*) from public.group_members where group_id = g.id));
end $$;

create function public.leave_group(p_code text, p_group uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare f uuid := public._fam(p_code);
begin
  perform private.member(f, p_group);
  delete from public.duels d using public.kids k
   where d.group_id = p_group and k.family_id = f and (d.from_kid = k.id or d.to_kid = k.id);
  delete from public.group_members where group_id = p_group and family_id = f;
  delete from public.groups g where g.id = p_group and not exists(select 1 from public.group_members m where m.group_id = g.id);
end $$;

create function public.set_challenge(p_code text, p_kid uuid, p_on boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare k uuid := public._kid(p_code, p_kid);
begin
  if coalesce(p_on, true) then delete from public.kid_hidden where kid_id = k;
  else insert into public.kid_hidden(kid_id) values (k) on conflict do nothing; end if;
end $$;

create function public.group_board(p_code text, p_group uuid, p_from text, p_to text, p_wk date) returns json
language plpgsql security definer set search_path = '' as $$
declare f uuid := public._fam(p_code);
begin
  perform private.member(f, p_group);
  return json_build_object(
    'group', (select json_build_object('id', g.id, 'name', g.name, 'invite', g.invite,
                'n', (select count(*) from public.group_members x where x.group_id = g.id)) from public.groups g where g.id = p_group),
    'kids', coalesce((select json_agg(json_build_object(
        'id', k.id, 'name', k.name, 'avatar', k.avatar, 'fam', fa.name, 'mine', k.family_id = f,
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

create function public.send_duel(p_code text, p_group uuid, p_from uuid, p_to uuid, p_kind text, p_wk date) returns json
language plpgsql security definer set search_path = '' as $$
declare f uuid := public._fam(p_code); nid uuid;
begin
  perform private.member(f, p_group);
  if not exists(select 1 from public.kids where id = p_from and family_id = f)
     or exists(select 1 from public.kid_hidden where kid_id = p_from) then raise exception 'kid_not_found' using errcode = 'P0002'; end if;
  if p_from = p_to or not exists(select 1 from public.kids k join public.group_members gm on gm.family_id = k.family_id
       where k.id = p_to and gm.group_id = p_group)
     or exists(select 1 from public.kid_hidden where kid_id = p_to) then raise exception 'kid_not_found' using errcode = 'P0002'; end if;
  if abs(p_wk - current_date) > 8 then raise exception 'bad_week'; end if;
  if (select count(*) from public.duels where from_kid = p_from and wk = p_wk) >= 10 then raise exception 'too_many_duels'; end if;
  insert into public.duels(group_id, from_kid, to_kid, kind, wk) values (p_group, p_from, p_to, p_kind, p_wk)
    on conflict do nothing returning id into nid;
  return json_build_object('id', nid);
end $$;
