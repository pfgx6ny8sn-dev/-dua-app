-- Little Muslim – Quiz „Wer ist der schlauste Muslim?“: Ergebnisse, Rangliste, Duelle
-- Fügt nur Neues hinzu. Kann mehrfach ausgeführt werden.
create table if not exists public.quiz_scores(
  id uuid primary key default gen_random_uuid(),
  kid_id uuid not null references public.kids(id) on delete cascade,
  score int not null check (score between 0 and 1000000),
  correct int not null check (correct between 0 and 15),
  ms int not null default 0 check (ms between 0 and 3600000),
  duel text check (duel ~ '^[A-Z0-9]{6}$'),
  created_at timestamptz not null default now()
);
create index if not exists quiz_scores_kid_idx on public.quiz_scores(kid_id, created_at desc);
create index if not exists quiz_scores_duel_idx on public.quiz_scores(duel) where duel is not null;
alter table public.quiz_scores enable row level security;
revoke all on public.quiz_scores from anon, authenticated;

create or replace function public.quiz_submit(p_code text, p_kid uuid, p_score int, p_correct int, p_ms int, p_duel text) returns json
language plpgsql security definer set search_path = '' as $$
declare k uuid := public._kid(p_code, p_kid); d text := nullif(upper(regexp_replace(coalesce(p_duel, ''), '[^A-Za-z0-9]', '', 'g')), '');
begin
  if (select count(*) from public.quiz_scores where kid_id = k and created_at > now() - interval '1 day') >= 40 then raise exception 'too_many'; end if;
  if d is not null and exists(select 1 from public.quiz_scores where kid_id = k and duel = d) then
    return json_build_object('ok', true, 'dup', true);
  end if;
  insert into public.quiz_scores(kid_id, score, correct, ms, duel)
  values (k, greatest(0, least(coalesce(p_score, 0), 1000000)), greatest(0, least(coalesce(p_correct, 0), 15)),
          greatest(0, least(coalesce(p_ms, 0), 3600000)), case when d ~ '^[A-Z0-9]{6}$' then d end);
  return json_build_object('ok', true);
end $$;

-- Rangliste: p_group = null → nur die eigene Familie. p_days = 7 (Woche) oder 0 (gesamt).
create or replace function public.quiz_board(p_code text, p_group uuid, p_days int) returns json
language plpgsql security definer set search_path = '' as $$
declare f uuid := public._fam(p_code); since timestamptz := case when coalesce(p_days, 0) > 0 then now() - make_interval(days => p_days) else '-infinity'::timestamptz end;
begin
  if p_group is not null then perform private.member(f, p_group); end if;
  return coalesce((select json_agg(r order by (r->>'best')::int desc, (r->>'ms')::int asc) from (
    select json_build_object('id', k.id, 'name', k.name, 'avatar', k.avatar, 'fam', fa.name, 'mine', k.family_id = f,
      'best', coalesce(max(s.score), 0), 'games', count(s.id), 'correct', coalesce(max(s.correct), 0),
      'ms', coalesce((select s2.ms from public.quiz_scores s2 where s2.kid_id = k.id and s2.created_at >= since order by s2.score desc, s2.ms asc limit 1), 0)) r
    from public.kids k
    join public.families fa on fa.id = k.family_id
    join public.quiz_scores s on s.kid_id = k.id and s.created_at >= since
    where (case when p_group is null then k.family_id = f
                else exists(select 1 from public.group_members gm where gm.group_id = p_group and gm.family_id = k.family_id) end)
      and not exists(select 1 from public.kid_hidden h where h.kid_id = k.id)
    group by k.id, fa.name) t), '[]'::json);
end $$;

-- Duell: alle Ergebnisse zu einem Code – aus der eigenen Familie und aus Familien, mit denen man eine Gruppe teilt.
create or replace function public.quiz_duel(p_code text, p_duel text) returns json
language plpgsql security definer set search_path = '' as $$
declare f uuid := public._fam(p_code); d text := upper(regexp_replace(coalesce(p_duel, ''), '[^A-Za-z0-9]', '', 'g'));
begin
  return coalesce((select json_agg(json_build_object('id', k.id, 'name', k.name, 'avatar', k.avatar, 'fam', fa.name, 'mine', k.family_id = f,
      'score', s.score, 'correct', s.correct, 'ms', s.ms, 'at', s.created_at) order by s.score desc, s.ms asc)
    from public.quiz_scores s
    join public.kids k on k.id = s.kid_id
    join public.families fa on fa.id = k.family_id
    where s.duel = d
      and (k.family_id = f or exists(select 1 from public.group_members a join public.group_members b on a.group_id = b.group_id
                                     where a.family_id = f and b.family_id = k.family_id))
      and not exists(select 1 from public.kid_hidden h where h.kid_id = k.id)), '[]'::json);
end $$;

revoke all on function public.quiz_submit(text, uuid, int, int, int, text), public.quiz_board(text, uuid, int), public.quiz_duel(text, text) from public;
grant execute on function public.quiz_submit(text, uuid, int, int, int, text), public.quiz_board(text, uuid, int), public.quiz_duel(text, text) to anon, authenticated;
