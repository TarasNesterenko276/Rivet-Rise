create table if not exists private.rivet_launch_decisions (
  appid text not null,
  idfv uuid not null,
  target text check (target = 'blocked' or target ~ '^https://'),
  lease uuid,
  lease_until timestamptz,
  primary key (appid, idfv)
);

alter table private.rivet_launch_decisions enable row level security;

create or replace function public.rivet_acquire_launch(p_appid text, p_idfv uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  state private.rivet_launch_decisions;
  next_lease uuid := gen_random_uuid();
begin
  insert into private.rivet_launch_decisions(appid, idfv)
  values (p_appid, p_idfv) on conflict do nothing;

  select * into strict state from private.rivet_launch_decisions
  where appid = p_appid and idfv = p_idfv for update;

  if state.target is not null then
    return jsonb_build_object('target', state.target);
  end if;
  if state.lease_until > now() then
    return jsonb_build_object('pending', true);
  end if;

  update private.rivet_launch_decisions
  set lease = next_lease, lease_until = now() + interval '45 seconds'
  where appid = p_appid and idfv = p_idfv;
  return jsonb_build_object('lease', next_lease);
end;
$$;

create or replace function public.rivet_finish_launch(
  p_appid text, p_idfv uuid, p_lease uuid, p_target text
) returns boolean language plpgsql security definer set search_path = '' as $$
begin
  update private.rivet_launch_decisions
  set target = coalesce(p_target, target), lease = null, lease_until = null
  where appid = p_appid and idfv = p_idfv and lease = p_lease;
  return found;
end;
$$;

revoke all on function public.rivet_acquire_launch(text, uuid) from public, anon, authenticated;
revoke all on function public.rivet_finish_launch(text, uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.rivet_acquire_launch(text, uuid) to service_role;
grant execute on function public.rivet_finish_launch(text, uuid, uuid, text) to service_role;
