-- Server-side event read scopes; callers must already have verified identity/MFA.
create function public.regional_event_divisions(p_staff uuid,p_requested smallint default null,p_admin_only boolean default false)
returns smallint[] language plpgsql stable security invoker set search_path='' as $$
declare allowed_ids smallint[];
begin
 select array_agg(d.id order by d.display_order) into allowed_ids from public.divisions d
 where d.onboarded and exists(
  select 1 from public.staff_accounts s where s.id=p_staff and s.enabled and s.removed_at is null
  and ((s.role='admin' and s.regional_role='system_admin' and s.division_id is null)
  or exists(select 1 from public.staff_division_assignments a where a.staff_id=s.id and a.division_id=d.id and (a.role='division_admin' or (a.role='inspector' and not p_admin_only))))
 );
 if coalesce(cardinality(allowed_ids),0)=0 then raise exception 'Staff access required for an onboarded division'; end if;
 if p_requested is not null then
  if not (p_requested=any(allowed_ids)) then raise exception 'Staff access required for this division'; end if;
  return array[p_requested];
 end if;
 return allowed_ids;
end $$;
revoke all on function public.regional_event_divisions(uuid,smallint,boolean) from public,anon,authenticated;
grant execute on function public.regional_event_divisions(uuid,smallint,boolean) to service_role;

create view public.regional_request_index with (security_invoker=true) as
select i.*,r.division_id from public.request_index i join public.event_requests r on r.id=i.id;
create view public.regional_event_history with (security_invoker=true) as
select h.*,coalesce(r.division_id,e.division_id) as division_id
from public.event_history h
left join public.event_requests r on r.id=h.request_id
left join public.events e on e.id=h.event_id
where coalesce(r.division_id,e.division_id) is not null
and (h.request_id is null or r.id is not null)
and (h.event_id is null or e.id is not null)
and (r.id is null or e.id is null or r.division_id=e.division_id);
create view public.regional_calendar_jobs with (security_invoker=true) as
select j.*,e.division_id from public.calendar_jobs j join public.events e on e.id=j.event_id
left join public.event_requests r on r.id=j.request_id
where j.request_id is null or (r.id is not null and r.division_id=e.division_id);
revoke all on public.regional_request_index from public,anon,authenticated;
grant select on public.regional_request_index to service_role;
revoke all on public.regional_event_history from public,anon,authenticated;
grant select on public.regional_event_history to service_role;
revoke all on public.regional_calendar_jobs from public,anon,authenticated;
grant select on public.regional_calendar_jobs to service_role;
CREATE OR REPLACE FUNCTION public.regional_inspector_dashboard_data(p_staff uuid,p_requested smallint default null)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY INVOKER
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
  select e.id as event_id,e.title,e.event_code,e.hosted_by,e.version,e.status as event_status,
         j.id as job_id,j.status as job_status,j.action as job_action,j.last_error,j.created_at as job_created
  from public.events e
  left join lateral (
   select * from public.calendar_jobs c where c.event_id=e.id
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
   select r.submitted_at,jsonb_build_object('id',r.id,'code',r.request_code,
      'title',coalesce(nullif(r.proposed_fields->>'title',''),e.title,'Event request'),
      'status',r.status,'request_type',r.request_type,'submitted_at',r.submitted_at) as data
   from public.event_requests r left join public.events e on e.id=r.event_id
   where r.status in ('pending','needs_correction') and r.division_id=any((select ids from scope)::smallint[])
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
