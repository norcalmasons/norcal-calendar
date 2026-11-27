
create view public.request_index with (security_invoker=true) as
select r.id,r.request_code,r.event_id,r.request_type,r.proposed_fields,r.requester_name,r.requester_email,
 r.status,r.submitted_at,r.reviewed_at,r.approved_event_id,
 coalesce(r.proposed_fields->>'title',e.title,r.request_type||' request') as event_title,
 coalesce(r.proposed_fields->>'event_type',e.event_type) as event_type,
 coalesce(r.proposed_fields->>'hosted_by',e.hosted_by) as lodge,
 coalesce(((r.proposed_fields->>'start_local')::timestamp at time zone 'America/Los_Angeles'),e.starts_at) as event_starts
from public.event_requests r left join public.events e on e.id=r.event_id;
revoke all on public.request_index from public,anon,authenticated;
grant select on public.request_index to service_role;
