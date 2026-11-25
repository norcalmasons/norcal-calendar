
create or replace function public.inspector_retry_calendar_sync(p_event_id uuid,p_staff uuid,p_expected_version integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 e public.events%rowtype;
 j public.calendar_jobs%rowtype;
 actor text;
 required_action text;
begin
 select email into actor from public.staff_accounts where id=p_staff and enabled=true;
 if actor is null then raise exception 'Inspector access required';end if;
 select * into e from public.events where id=p_event_id for update;
 if not found then raise exception 'Event not found';end if;
 if e.version is distinct from p_expected_version then raise exception 'Event changed. Reload and try again';end if;
 required_action:=case when e.status='cancelled' then 'cancel' else 'upsert' end;
 select * into j from public.calendar_jobs where event_id=p_event_id and event_version=e.version
 and action=required_action order by created_at desc,id desc limit 1 for update;
 if not found then raise exception 'No calendar delivery record for the current event version';end if;
 if j.status<>'failed' then raise exception 'Only failed calendar updates can be retried. Refresh the event status';end if;
 update public.calendar_jobs set status='pending',last_error=null,finished_at=null where id=j.id;
 insert into public.event_history(event_id,action,actor_staff_id,actor_email,before_data,after_data,notes)
 values(p_event_id,'calendar_retry_requested',p_staff,actor,
  jsonb_build_object('job_id',j.id,'error',j.last_error,'attempts',j.attempts),
  jsonb_build_object('job_id',j.id,'status','pending','version',e.version),
  'Inspector queued manual Google Calendar retry');
 return jsonb_build_object('ok',true,'job_id',j.id,'event_id',p_event_id,'status','pending');
end $$;
revoke all on function public.inspector_retry_calendar_sync(uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.inspector_retry_calendar_sync(uuid,uuid,integer) to service_role;

create or replace function public.admin_undo_last_published_edit(p_event_id uuid,p_history_id uuid,p_staff uuid,p_expected_version integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 e public.events%rowtype;
 h public.event_history%rowtype;
 newest uuid;
 result jsonb;
 actor text;
 count_updated integer;
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
 update public.event_history
 set action='inspector_undo_published',
 notes='Administrator reversed inspector edit '||p_history_id::text,
 after_data=after_data||jsonb_build_object('undone_history_id',p_history_id)
 where event_id=p_event_id and action='inspector_updated_published'
   and (after_data->>'version')::integer=(p_expected_version+1);
 get diagnostics count_updated=row_count;
 if count_updated<>1 then raise exception 'Undo audit could not be recorded';end if;
 return result||jsonb_build_object('undone_history_id',p_history_id,'notice','Prior version restored. Calendar update queued.');
end $$;
revoke all on function public.admin_undo_last_published_edit(uuid,uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.admin_undo_last_published_edit(uuid,uuid,uuid,integer) to service_role;

create or replace function public.inspector_dashboard_data()
returns jsonb language sql stable security definer set search_path='' as $$
with
 status_counts as (
   select count(*) filter(where status='pending')::integer as pending,
          count(*) filter(where status='needs_correction')::integer as corrections
   from public.event_requests
 ),
 live_jobs as (
  select e.id as event_id,e.title,e.event_code,e.hosted_by,e.version,e.status as event_status,
         j.id as job_id,j.status as job_status,j.action as job_action,j.last_error,j.created_at as job_created
  from public.events e
  left join lateral (
   select * from public.calendar_jobs c where c.event_id=e.id
   and c.event_version=e.version
   and c.action=(case when e.status='cancelled' then 'cancel' else 'upsert' end)
   order by c.created_at desc,c.id desc limit 1
  ) j on true
 ),
 sync_counts as(
  select count(*) filter(where job_status='failed')::integer as failed,
         count(*) filter(where job_status in ('pending','running'))::integer as queued
  from live_jobs
 ),
 pending_list as(
  select coalesce(jsonb_agg(q.data order by q.submitted_at desc),'[]'::jsonb) as arr from (
   select r.submitted_at,jsonb_build_object('id',r.id,'code',r.request_code,
      'title',coalesce(nullif(r.proposed_fields->>'title',''),e.title,'Event request'),
      'status',r.status,'request_type',r.request_type,'submitted_at',r.submitted_at) as data
   from public.event_requests r left join public.events e on e.id=r.event_id
   where r.status in ('pending','needs_correction')
   order by r.submitted_at desc limit 8
  ) q
 ),
 failed_list as (
  select coalesce(jsonb_agg(f.data order by f.job_created desc),'[]'::jsonb) as arr from (
    select job_created, jsonb_build_object('id',event_id,'title',title,'code',event_code,
      'event_status',event_status,'error',last_error,'job_id',job_id) as data
    from live_jobs where job_status='failed' order by job_created desc limit 8
  ) f
 ),
 recent_list as(
  select coalesce(jsonb_agg(a.data order by a.occurred_at desc),'[]'::jsonb) as arr from (
   select h.occurred_at,jsonb_build_object('id',h.id,'action',h.action,
      'event_id',h.event_id,'request_id',h.request_id,
      'event_title',coalesce(e.title,r.proposed_fields->>'title','Event request'),
      'actor',h.actor_email,'at',h.occurred_at) as data
   from public.event_history h
   left join public.events e on e.id=h.event_id
   left join public.event_requests r on r.id=h.request_id
   order by h.occurred_at desc limit 8
  ) a
 )
select jsonb_build_object('counts',jsonb_build_object('pending',(select pending from status_counts),
 'corrections',(select corrections from status_counts),
 'failed',(select failed from sync_counts),
 'queued',(select queued from sync_counts)),
 'requests',(select arr from pending_list),
 'failures',(select arr from failed_list),
 'recent',(select arr from recent_list));
$$;
revoke all on function public.inspector_dashboard_data() from public,anon,authenticated;
grant execute on function public.inspector_dashboard_data() to service_role;
