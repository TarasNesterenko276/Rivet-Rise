create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;

create table if not exists public.rivet_players (
  appid text not null,
  player_id uuid not null references auth.users(id) on delete cascade,
  crew_name text not null check (length(crew_name) between 1 and 32),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (appid, player_id)
);

create table if not exists public.rivet_shifts (
  submission_id uuid primary key,
  appid text not null,
  player_id uuid not null references auth.users(id) on delete cascade,
  week text not null check (week ~ '^[0-9]{4}-W[0-9]{2}$'),
  floors integer not null check (floors between 0 and 10000),
  score integer not null check (score between 0 and 2000000000),
  rivets integer not null check (rivets between 0 and 10000),
  perfects integer not null check (perfects between 0 and 10000),
  districts integer not null check (districts between 0 and 10000),
  duration_seconds double precision not null check (duration_seconds between 0 and 86400),
  foreman_id text not null check (length(foreman_id) between 1 and 64),
  completed_at timestamptz not null default now(),
  foreign key (appid, player_id) references public.rivet_players(appid, player_id) on delete cascade
);

create index if not exists rivet_shifts_week_best_idx
  on public.rivet_shifts (appid, week, floors desc, score desc, completed_at desc);
create index if not exists rivet_shifts_player_week_idx
  on public.rivet_shifts (appid, player_id, week, completed_at desc);

create table if not exists public.rivet_reward_claims (
  appid text not null,
  week text not null,
  player_id uuid not null references auth.users(id) on delete cascade,
  slot_id text not null check (slot_id in ('gold-jib', 'neon-crown', 'chrome-hook')),
  cosmetic_id text not null,
  claimed_at timestamptz not null default now(),
  primary key (appid, week, player_id, slot_id)
);

create table if not exists private.rivet_rate_limits (
  player_id uuid not null references auth.users(id) on delete cascade,
  bucket text not null,
  window_started_at timestamptz not null,
  request_count integer not null,
  primary key (player_id, bucket)
);

create table if not exists private.launch_routes (
  appid text primary key,
  target text not null default 'blocked',
  updated_at timestamptz not null default now(),
  check (target in ('blocked', 'resolve') or target ~ '^https://')
);

alter table public.rivet_players enable row level security;
alter table public.rivet_shifts enable row level security;
alter table public.rivet_reward_claims enable row level security;
alter table private.rivet_rate_limits enable row level security;
alter table private.launch_routes enable row level security;

revoke all on public.rivet_players from anon, authenticated;
revoke all on public.rivet_shifts from anon, authenticated;
revoke all on public.rivet_reward_claims from anon, authenticated;
revoke all on private.rivet_rate_limits from anon, authenticated;
revoke all on private.launch_routes from anon, authenticated;
grant all on public.rivet_players, public.rivet_shifts, public.rivet_reward_claims to service_role;
grant all on private.rivet_rate_limits, private.launch_routes to service_role;
create or replace function public.rivet_submit_shift(
  p_appid text,
  p_player_id uuid,
  p_crew_name text,
  p_submission_id uuid,
  p_week text,
  p_floors integer,
  p_score integer,
  p_rivets integer,
  p_perfects integer,
  p_districts integer,
  p_duration_seconds double precision,
  p_foreman_id text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.rivet_players(appid, player_id, crew_name)
  values (p_appid, p_player_id, left(trim(p_crew_name), 32))
  on conflict (appid, player_id) do update
    set crew_name = excluded.crew_name,
        updated_at = now();

  insert into public.rivet_shifts(
    appid, player_id, submission_id, week, floors, score, rivets, perfects,
    districts, duration_seconds, foreman_id
  ) values (
    p_appid, p_player_id, p_submission_id, p_week, p_floors, p_score,
    p_rivets, p_perfects, p_districts, p_duration_seconds, p_foreman_id
  ) on conflict (submission_id) do nothing;
end;
$$;

create or replace function public.rivet_read_launch_route(p_appid text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select target from private.launch_routes where appid = p_appid;
$$;

create or replace function public.rivet_consume_rate_limit(
  p_player_id uuid,
  p_bucket text,
  p_limit integer,
  p_window_seconds integer default 300
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_count integer;
begin
  insert into private.rivet_rate_limits(player_id, bucket, window_started_at, request_count)
  values (p_player_id, p_bucket, now(), 1)
  on conflict (player_id, bucket) do update
    set window_started_at = case
          when private.rivet_rate_limits.window_started_at + make_interval(secs => p_window_seconds) <= now() then now()
          else private.rivet_rate_limits.window_started_at end,
        request_count = case
          when private.rivet_rate_limits.window_started_at + make_interval(secs => p_window_seconds) <= now() then 1
          else private.rivet_rate_limits.request_count + 1 end
  returning request_count into current_count;
  return current_count <= p_limit;
end;
$$;

create or replace function public.rivet_weekly_board(
  p_appid text,
  p_player_id uuid,
  p_week text
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  week_start date;
  week_end timestamptz;
  ended boolean;
  result jsonb;
begin
  if p_week !~ '^[0-9]{4}-W[0-9]{2}$' then raise exception 'Invalid week'; end if;
  week_start := to_date(left(p_week, 4) || ' ' || right(p_week, 2), 'IYYY IW');
  week_end := (week_start + 7)::timestamp at time zone 'UTC';
  ended := week_end <= now();

  with best as (
    select distinct on (s.player_id)
      s.player_id, p.crew_name, s.floors, s.score
    from public.rivet_shifts s
    join public.rivet_players p on p.appid = s.appid and p.player_id = s.player_id
    where s.appid = p_appid and s.week = p_week
    order by s.player_id, s.floors desc, s.score desc, s.completed_at asc
  ), ranked as (
    select row_number() over (order by floors desc, score desc, player_id) as rank,
      player_id, crew_name, floors, score
    from best
  ), entries as (
    select jsonb_agg(jsonb_build_object(
      'rank', rank,
      'playerID', player_id::text,
      'crewName', crew_name,
      'floors', floors,
      'score', score,
      'league', case when floors >= 50 then 'skyline' when floors >= 35 then 'rivet' when floors >= 20 then 'girder' else 'scaffold' end,
      'isPlayer', player_id = p_player_id
    ) order by rank) as rows
    from (select * from ranked order by rank limit 5) top_rows
  ), player_row as (
    select jsonb_build_object(
      'rank', rank,
      'playerID', player_id::text,
      'crewName', crew_name,
      'floors', floors,
      'score', score,
      'league', case when floors >= 50 then 'skyline' when floors >= 35 then 'rivet' when floors >= 20 then 'girder' else 'scaffold' end,
      'isPlayer', true
    ) as row
    from ranked where player_id = p_player_id and rank > 5
  ), player_rank as (
    select rank from ranked where player_id = p_player_id
  ), slots as (
    select jsonb_agg(jsonb_build_object(
      'id', c.slot_id,
      'ranks', c.ranks,
      'title', c.title,
      'detail', c.detail,
      'cosmeticID', c.cosmetic_id,
      'state', case
        when exists(select 1 from public.rivet_reward_claims rc where rc.appid=p_appid and rc.week=p_week and rc.player_id=p_player_id and rc.slot_id=c.slot_id) then 'claimed'
        when ended and (select rank from player_rank) between c.min_rank and c.max_rank then 'claimable'
        when not ended and (select rank from player_rank) between c.min_rank and c.max_rank then 'pending'
        else 'locked'
      end
    ) order by c.min_rank) as rows
    from (values
      ('gold-jib', '#1', 'Gold Leaf Jib', 'The crane jib is painted gold for a week.', 'crane.jib.gold', 1, 1),
      ('neon-crown', '#2–3', 'Neon Crown', 'Penthouses get a glowing rooftop crown.', 'roof.crown.neon', 2, 3),
      ('chrome-hook', '#4–5', 'Chrome Hook', 'A polished chrome hook block with a beacon.', 'hook.chrome', 4, 5)
    ) as c(slot_id, ranks, title, detail, cosmetic_id, min_rank, max_rank)
  )
  select jsonb_build_object(
    'week', p_week,
    'endsAt', week_end,
    'seasonName', 'Season 1 · Steel Spring',
    'entries', coalesce(entries.rows, '[]'::jsonb),
    'playerRow', (select row from player_row),
    'rewards', coalesce(slots.rows, '[]'::jsonb),
    'isMock', false
  ) into result
  from entries cross join slots;

  return result;
end;
$$;

create or replace function public.rivet_claim_weekly_reward(
  p_appid text,
  p_player_id uuid,
  p_week text,
  p_slot_id text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  start_date date;
  end_at timestamptz;
  slot record;
  player_rank bigint;
  claim public.rivet_reward_claims%rowtype;
begin
  if p_week !~ '^[0-9]{4}-W[0-9]{2}$' then raise exception 'Invalid week'; end if;
  start_date := to_date(left(p_week, 4) || ' ' || right(p_week, 2), 'IYYY IW');
  end_at := (start_date + 7)::timestamp at time zone 'UTC';
  if end_at > now() then raise exception 'Week is still active'; end if;

  select * into slot from (values
    ('gold-jib', '#1', 'Gold Leaf Jib', 'The crane jib is painted gold for a week.', 'crane.jib.gold', 1, 1),
    ('neon-crown', '#2–3', 'Neon Crown', 'Penthouses get a glowing rooftop crown.', 'roof.crown.neon', 2, 3),
    ('chrome-hook', '#4–5', 'Chrome Hook', 'A polished chrome hook block with a beacon.', 'hook.chrome', 4, 5)
  ) as c(slot_id, ranks, title, detail, cosmetic_id, min_rank, max_rank)
  where c.slot_id = p_slot_id;
  if not found then raise exception 'Unknown reward'; end if;

  select ranked.rank into player_rank from (
    select row_number() over (order by best.floors desc, best.score desc, best.player_id) as rank,
      best.player_id
    from (
      select distinct on (s.player_id) s.player_id, s.floors, s.score
      from public.rivet_shifts s
      where s.appid=p_appid and s.week=p_week
      order by s.player_id, s.floors desc, s.score desc, s.completed_at asc
    ) best
  ) ranked where ranked.player_id = p_player_id;
  if player_rank is null or player_rank < slot.min_rank or player_rank > slot.max_rank then
    raise exception 'Reward is not claimable';
  end if;

  insert into public.rivet_reward_claims(appid, week, player_id, slot_id, cosmetic_id)
  values (p_appid, p_week, p_player_id, slot.slot_id, slot.cosmetic_id)
  on conflict (appid, week, player_id, slot_id) do nothing;
  select * into claim from public.rivet_reward_claims
    where appid=p_appid and week=p_week and player_id=p_player_id and slot_id=p_slot_id;

  return jsonb_build_object('id', slot.slot_id, 'ranks', slot.ranks, 'title', slot.title,
    'detail', slot.detail, 'cosmeticID', claim.cosmetic_id, 'state', 'claimed');
end;
$$;

revoke all on function public.rivet_submit_shift(text, uuid, text, uuid, text, integer, integer, integer, integer, integer, double precision, text) from public, anon, authenticated;
revoke all on function public.rivet_read_launch_route(text) from public, anon, authenticated;
revoke all on function public.rivet_consume_rate_limit(uuid, text, integer, integer) from public, anon, authenticated;
revoke all on function public.rivet_weekly_board(text, uuid, text) from public, anon, authenticated;
revoke all on function public.rivet_claim_weekly_reward(text, uuid, text, text) from public, anon, authenticated;
grant execute on function public.rivet_submit_shift(text, uuid, text, uuid, text, integer, integer, integer, integer, integer, double precision, text) to service_role;
grant execute on function public.rivet_read_launch_route(text) to service_role;
grant execute on function public.rivet_consume_rate_limit(uuid, text, integer, integer) to service_role;
grant execute on function public.rivet_weekly_board(text, uuid, text) to service_role;
grant execute on function public.rivet_claim_weekly_reward(text, uuid, text, text) to service_role;

insert into private.launch_routes(appid, target)
values ('com.rivetrise.game18', 'resolve')
on conflict (appid) do nothing;
