
create or replace function public.approve_request(p_id uuid,p_staff uuid,p_decision text,p_note text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.event_requests%rowtype; e public.events%rowtype; p jsonb; eid uuid; ver int; who text;
begin
select email into who from public.staff_accounts where id=p_staff and enabled;
if who is null then raise exception 'Reviewer disabled'; end if;
if p_decision not in ('approved','needs_correction','rejected') then raise exception 'Bad decision'; end if;
select * into r from public.event_requests where id=p_id for update;
if not found or r.status not in ('pending','needs_correction') then raise exception 'Request already processed; refresh'; end if;
p:=r.proposed_fields;
if p_decision='approved' then
 if r.request_type='new' then
  insert into public.events(event_code,title,event_type,hosted_by,district,starts_at,ends_at,event_mode,location_name,location_address,location_tbd,public_description,registration_url,payment_url,flyer_url)
  values(r.request_code,p->>'title',p->>'event_type',p->>'hosted_by',p->>'district',
    (p->>'start_local')::timestamp at time zone 'America/Los_Angeles',
    (p->>'end_local')::timestamp at time zone 'America/Los_Angeles',
    coalesce(p->>'event_mode','in_person'),nullif(p->>'location_name',''),nullif(p->>'location_address',''),
    coalesce((p->>'location_tbd')::boolean,false),p->>'public_description',p->>'registration_url',p->>'payment_url',p->>'flyer_url')
  returning id,version into eid,ver;
 else
  select * into e from public.events where id=r.event_id for update;
  if not found or e.version is distinct from r.base_event_version then raise exception 'Event changed since request; refresh'; end if;
  if r.request_type='cancel' then
   update public.events set status='cancelled',version=version+1,updated_at=now() where id=e.id returning id,version into eid,ver;
  else
   update public.events set
     title=coalesce(p->>'title',title),event_type=coalesce(p->>'event_type',event_type),
     hosted_by=coalesce(p->>'hosted_by',hosted_by),district=coalesce(p->>'district',district),
     starts_at=case when p ? 'start_local' then (p->>'start_local')::timestamp at time zone 'America/Los_Angeles' else starts_at end,
     ends_at=case when p ? 'end_local' then (p->>'end_local')::timestamp at time zone 'America/Los_Angeles' else ends_at end,
     event_mode=coalesce(p->>'event_mode',event_mode),
     location_name=case when p ? 'location_name' then nullif(p->>'location_name','') else location_name end,
     location_address=case when p ? 'location_address' then nullif(p->>'location_address','') else location_address end,
     location_tbd=coalesce((p->>'location_tbd')::boolean,location_tbd),
     public_description=coalesce(p->>'public_description',public_description),
     registration_url=coalesce(p->>'registration_url',registration_url),
     payment_url=coalesce(p->>'payment_url',payment_url),flyer_url=coalesce(p->>'flyer_url',flyer_url),
     version=version+1,updated_at=now() where id=e.id returning id,version into eid,ver;
  end if;
 end if;
 insert into public.calendar_jobs(event_id,request_id,action,event_version,idempotency_key)
 values(eid,r.id,case when r.request_type='cancel' then 'cancel' else 'upsert' end,ver,eid::text||':'||ver::text)
 on conflict(idempotency_key) do nothing;
end if;
update public.event_requests set status=p_decision,reviewer_id=p_staff,reviewer_public_message=p_note,
 reviewed_at=now(),updated_at=now(),approved_event_id=case when p_decision='approved' then eid else null end where id=r.id;
insert into public.event_history(event_id,request_id,action,actor_staff_id,actor_email,before_data,after_data)
values(eid,r.id,p_decision,p_staff,who,jsonb_build_object('status',r.status),jsonb_build_object('status',p_decision,'changes',p));
insert into public.email_deliveries(event_id,request_id,message_type,recipient_email,idempotency_key)
values(eid,r.id,'decision',r.requester_email,r.id::text||':decision') on conflict do nothing;
return jsonb_build_object('status',p_decision,'event_id',eid,'calendar_queued',p_decision='approved');
end $$;
revoke all on function public.approve_request(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.approve_request(uuid,uuid,text,text) to service_role;
