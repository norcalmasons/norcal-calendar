CREATE OR REPLACE FUNCTION public.regional_inspector_dashboard_data(p_staff uuid, p_requested smallint DEFAULT NULL::smallint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
with
 scope as (select public.regional_event_divisions(p_staff,p_requested,false) as ids),
 status_counts as (
   select count(*) filter(where status='pending')::integer as pending,
          count(*) filter(where status='needs_correction')::integer as corrections
   from public.event_requests where division_id=any((select ids from scope)::smallint[])
 ),
 live_jobs as (
  select e.id as event_id,e.division_id,e.title,e.event_code,e.hosted_by,e.version,e.status as event_status,
         j.id as job_id,j.status as job_status,j.action as job_action,j.last_error,j.created_at as job_created
  from public.events e
  left join lateral (
   select * from public.regional_calendar_jobs c where c.event_id=e.id and c.division_id=e.division_id
   and c.event_version=e.version
   and c.action=(case when e.status='cancelled' then 'cancel' else 'upsert' end)
   order by c.created_at desc,c.id desc limit 1
  ) j on true
  where e.division_id=any((select ids from scope)::smallint[])
 ),
 sync_counts as(
  select count(*) filter(where job_status='failed')::integer as failed,
         count(*) filter(where job_status in ('pending','running'))::integer as queued
  from live_jobs
 ),
 pending_list as(
  select coalesce(jsonb_agg(q.data order by q.submitted_at desc),'[]'::jsonb) as arr from (
   select r.submitted_at,jsonb_build_object('id',r.id,'division_id',r.division_id,'code',r.request_code,
      'title',coalesce(nullif(r.proposed_fields->>'title',''),e.title,'Event request'),
      'status',r.status,'request_type',r.request_type,'submitted_at',r.submitted_at) as data
   from public.event_requests r left join public.events e on e.id=r.event_id
   where r.status in ('pending','needs_correction') and r.division_id=any((select ids from scope)::smallint[])
   order by r.submitted_at desc limit 8
  ) q
 ),
 failed_list as (
  select coalesce(jsonb_agg(f.data order by f.job_created desc),'[]'::jsonb) as arr from (
    select job_created, jsonb_build_object('id',event_id,'division_id',division_id,'title',title,'code',event_code,
      'event_status',event_status,'error',last_error,'job_id',job_id) as data
    from live_jobs where job_status='failed' order by job_created desc limit 8
  ) f
 ),
 recent_list as(
  select coalesce(jsonb_agg(a.data order by a.occurred_at desc),'[]'::jsonb) as arr from (
   select h.occurred_at,jsonb_build_object('id',h.id,'division_id',h.division_id,'action',h.action,
      'event_id',h.event_id,'request_id',h.request_id,
      'event_title',coalesce(e.title,r.proposed_fields->>'title','Event request'),
      'actor',h.actor_email,'at',h.occurred_at) as data
   from public.regional_event_history h
   left join public.events e on e.id=h.event_id
   left join public.event_requests r on r.id=h.request_id
   where h.division_id=any((select ids from scope)::smallint[])
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
$function$
;
revoke all on function public.regional_inspector_dashboard_data(uuid,smallint) from public,anon,authenticated;
grant execute on function public.regional_inspector_dashboard_data(uuid,smallint) to service_role;