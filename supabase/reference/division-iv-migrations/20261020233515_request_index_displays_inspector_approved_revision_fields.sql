create or replace view public.request_index with (security_invoker=true) as SELECT r.id,
    r.request_code,
    r.event_id,
    r.request_type,
    r.proposed_fields,
    r.requester_name,
    r.requester_email,
    r.status,
    r.submitted_at,
    r.reviewed_at,
    r.approved_event_id,
    COALESCE(COALESCE(r.inspector_edits,r.proposed_fields) ->> 'title'::text, e.title, r.request_type || ' request'::text) AS event_title,
    COALESCE(COALESCE(r.inspector_edits,r.proposed_fields) ->> 'event_type'::text, e.event_type) AS event_type,
    COALESCE(COALESCE(r.inspector_edits,r.proposed_fields) ->> 'hosted_by'::text, e.hosted_by) AS lodge,
    COALESCE((((COALESCE(r.inspector_edits,r.proposed_fields) ->> 'start_local'::text)::timestamp without time zone) AT TIME ZONE 'America/Los_Angeles'::text), e.starts_at) AS event_starts
   FROM event_requests r
     LEFT JOIN events e ON e.id = r.event_id;
