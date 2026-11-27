
create or replace function public.admin_undo_last_published_edit(p_event_id uuid,p_history_id uuid,p_staff uuid,p_expected_version integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 e public.events%rowtype;
 h public.event_history%rowtype;
 newest uuid;
 result jsonb;
 actor text;
 restore_log public.event_history%rowtype;
begin
 select email into actor from public.staff_accounts where id=p_staff and enabled=true and role='admin';
 if actor is null then raise exception 'Administrator permission required';end if;
 select * into e from public.events where id=p_event_id for update;
 if not found then raise exception 'Event not found';end if;
 if e.status<>'active' then raise exception 'Cannot undo an edit to a cancelled event';end if;
 if e.version is distinct from p_expected_version then raise exception 'Event changed. Reload before undoing';end if;
 select id into newest from public.event_history where event_id=p_event_id and action in
 ('inspector_updated_published','inspector_undo_published') order by occurred_at desc,id desc limit 1;
 if newest is null or newest<>p_history_id then raise exception 'Only the most recent inspector edit can be undone';end if;
 select * into h from public.event_history where id=p_history_id and event_id=p_event_id;
 if (h.after_data->>'version')::integer is distinct from e.version then
  raise exception 'Newer changes exist. Undo is no longer safe';
 end if;
 if jsonb_typeof(h.before_data->'fields')<>'object' then raise exception 'Previous event details unavailable';end if;
 result:=public.inspector_update_published_event(p_event_id,p_staff,p_expected_version,h.before_data->'fields');
 select * into restore_log from public.event_history
   where event_id=p_event_id and action='inspector_updated_published'
   and (after_data->>'version')::integer=(p_expected_version+1)
   order by occurred_at desc,id desc limit 1;
 if not found then raise exception 'Undo audit could not be recorded';end if;
 insert into public.event_history(event_id,action,actor_staff_id,actor_email,before_data,after_data,notes)
 values(p_event_id,'inspector_undo_published',p_staff,actor,
  restore_log.before_data,
  restore_log.after_data||jsonb_build_object('undone_history_id',p_history_id,'restoration_history_id',restore_log.id),
  'Administrator reversed inspector edit '||p_history_id::text);
 return result||jsonb_build_object('undone_history_id',p_history_id,'notice','Prior version restored. Calendar update queued.');
end $$;
revoke all on function public.admin_undo_last_published_edit(uuid,uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.admin_undo_last_published_edit(uuid,uuid,uuid,integer) to service_role;
