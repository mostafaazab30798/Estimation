-- Bot-seat proxy is server-only (edge function service_role). Clients cannot play as bots.

create or replace function public.resolve_acting_player_id(
  p_actor_uid uuid,
  p_payload jsonb,
  p_state jsonb,
  p_is_host boolean
)
returns text
language plpgsql
stable
set search_path = public
as $$
declare
  v_proxy text := nullif(trim(p_payload ->> 'playerId'), '');
begin
  if auth.role() = 'service_role'
    and v_proxy is not null
    and public.is_proxy_bot_seat(p_state, v_proxy) then
    return v_proxy;
  end if;
  return p_actor_uid::text;
end;
$$;
