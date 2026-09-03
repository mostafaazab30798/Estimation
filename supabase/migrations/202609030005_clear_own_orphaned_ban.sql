-- Clear a legacy duplicate ban only when its own authenticated user checks
-- status and has no waiting/playing membership. No other account is touched.

create or replace function public.get_online_play_status(p_device_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_membership record;
  v_ban timestamptz;
  v_room_id uuid;
  v_room_status text;
  v_last_seen timestamptz;
  v_is_online boolean;
  v_active_device_id text;
  v_reclaim_window interval := interval '5 minutes';
  v_grace_ends timestamptz;
  v_can_join boolean := true;
  v_has_membership boolean := false;
  v_active_elsewhere boolean := false;
  v_recovery_available boolean := false;
begin
  if v_uid is null then
    return jsonb_build_object('can_join_new_online', false);
  end if;

  update public.profiles
  set online_ban_until = null,
      updated_at = timezone('utc', now())
  where id = v_uid
    and online_ban_until is not null
    and online_ban_until <= timezone('utc', now());

  for v_membership in
    select gr.id
    from public.room_players rp
    join public.game_rooms gr on gr.id = rp.room_id
    where rp.player_id = v_uid and gr.status in ('waiting', 'playing')
  loop
    perform public.process_room_absences(v_membership.id);
  end loop;

  select online_ban_until into v_ban
  from public.profiles where id = v_uid;

  select gr.id, gr.status, rp.last_seen, rp.is_online, rp.active_device_id
  into v_room_id, v_room_status, v_last_seen, v_is_online, v_active_device_id
  from public.room_players rp
  join public.game_rooms gr on gr.id = rp.room_id
  where rp.player_id = v_uid and gr.status in ('waiting', 'playing')
  order by rp.joined_at desc
  limit 1;

  if found then
    v_has_membership := true;
    v_can_join := false;
    v_active_elsewhere := v_is_online
      and v_active_device_id is not null
      and v_active_device_id is distinct from p_device_id;
    v_recovery_available := not v_active_elsewhere;
    if not v_is_online then
      v_grace_ends := v_last_seen + v_reclaim_window;
    end if;
  elsif v_ban is not null then
    -- With no live membership, this can only be the old post-detach timer.
    update public.profiles
    set online_ban_until = null,
        updated_at = timezone('utc', now())
    where id = v_uid;
    v_ban := null;
  end if;

  if v_ban is not null and v_ban > timezone('utc', now()) then
    v_can_join := false;
  end if;

  return jsonb_build_object(
    'can_join_new_online', v_can_join,
    'has_active_membership', v_has_membership,
    'active_on_another_device', v_active_elsewhere,
    'recovery_available', v_recovery_available,
    'online_ban_until', v_ban,
    'grace_ends_at', case
      when v_has_membership and not v_active_elsewhere then v_grace_ends
      else null
    end,
    'room_id', case when v_has_membership then v_room_id else null end,
    'room_status', case when v_has_membership then v_room_status else null end
  );
end;
$$;

revoke all on function public.get_online_play_status(text) from public;
grant execute on function public.get_online_play_status(text) to authenticated;
