alter table public.events add column if not exists poc_position text;
comment on column public.events.poc_position is 'Public event point-of-contact position or office; arbitrary titles allowed.';
alter table public.events add constraint events_poc_position_length_check check (poc_position is null or char_length(poc_position)<=120);
create table if not exists public.poc_positions (
 title text primary key,
 active boolean not null default true,
 created_at timestamptz not null default now(),
 constraint poc_positions_title_valid check (char_length(btrim(title)) between 1 and 120 and title=btrim(title))
);
alter table public.poc_positions enable row level security;
comment on table public.poc_positions is 'Reusable point-of-contact roles; served by the calendar Edge Function. Custom roles become options after their event is approved.';
insert into public.poc_positions(title) values
 ('Worshipful Master'),('Junior Warden'),('Senior Warden'),
 ('Secretary'),('Committee Chair'),('Inspector')
on conflict(title) do nothing;
create or replace function public.capture_event_poc_position()
returns trigger language plpgsql security invoker set search_path='' as $capture$
begin
 if nullif(btrim(new.poc_position),'') is not null then
  insert into public.poc_positions(title) values (btrim(new.poc_position))
  on conflict(title) do nothing;
 end if;
 return new;
end $capture$;
drop trigger if exists trg_capture_event_poc_position on public.events;
create trigger trg_capture_event_poc_position
 after insert or update of poc_position on public.events
 for each row execute function public.capture_event_poc_position();
insert into public.poc_positions(title)
select distinct btrim(poc_position) from public.events
 where nullif(btrim(poc_position),'') is not null
on conflict(title) do nothing;
CREATE OR REPLACE FUNCTION public.approve_request(p_id uuid, p_staff uuid, p_decision text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.event_requests%rowtype; e public.events%rowtype; p jsonb; eid uuid; ver int; who text;
begin
select email into who from public.staff_accounts where id=p_staff and enabled;
if who is null then raise exception 'Reviewer disabled'; end if;
if p_decision not in ('approved','needs_correction','rejected') then raise exception 'Bad decision'; end if;
select * into r from public.event_requests where id=p_id for update;
if not found or r.status not in ('pending','needs_correction') then raise exception 'Request already processed; refresh'; end if;
p:=coalesce(r.inspector_edits,r.proposed_fields);
if p_decision='approved' then
 if r.request_type='new' then
  insert into public.events(event_code,title,event_type,hosted_by,district,starts_at,ends_at,event_mode,location_name,location_address,location_address1,location_address2,location_city,location_state,location_zip,location_tbd,public_description,attire,invited_audience,registration_url,payment_url,flyer_url,poc_name,poc_position,poc_phone,poc_email,cost_details)
  values(r.request_code,p->>'title',p->>'event_type',p->>'hosted_by',p->>'district',
    (p->>'start_local')::timestamp at time zone 'America/Los_Angeles',
    (p->>'end_local')::timestamp at time zone 'America/Los_Angeles',
    coalesce(p->>'event_mode','in_person'),nullif(p->>'location_name',''),nullif(concat_ws(', ',nullif(concat_ws(' ',nullif(p->>'location_address1',''),nullif(p->>'location_address2','')),''),nullif(p->>'location_city',''),nullif(p->>'location_state',''),nullif(p->>'location_zip','')),''),nullif(p->>'location_address1',''),nullif(p->>'location_address2',''),nullif(p->>'location_city',''),nullif(p->>'location_state',''),nullif(p->>'location_zip',''),
    coalesce((p->>'location_tbd')::boolean,false),p->>'public_description',p->>'attire',p->>'invited_audience',p->>'registration_url',p->>'payment_url',p->>'flyer_url',nullif(btrim(p->>'poc_name'),''),nullif(btrim(p->>'poc_position'),''),nullif(btrim(p->>'poc_phone'),''),nullif(btrim(p->>'poc_email'),''),nullif(btrim(p->>'cost_details'),''))
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
     location_name=case when coalesce((p->>'location_tbd')::boolean,false) then null when p ? 'location_name' then nullif(p->>'location_name','') else location_name end,
     location_address=case when coalesce((p->>'location_tbd')::boolean,false) then null when p ? 'location_address1' or p ? 'location_address2' or p ? 'location_city' or p ? 'location_state' or p ? 'location_zip' then nullif(concat_ws(', ',nullif(concat_ws(' ',nullif(coalesce(p->>'location_address1',location_address1),''),nullif(coalesce(p->>'location_address2',location_address2),'')),''),nullif(coalesce(p->>'location_city',location_city),''),nullif(coalesce(p->>'location_state',location_state),''),nullif(coalesce(p->>'location_zip',location_zip),'')),'') else location_address end,
     location_address1=case when coalesce((p->>'location_tbd')::boolean,false) then null when p ? 'location_address1' then nullif(p->>'location_address1','') else location_address1 end,
     location_address2=case when coalesce((p->>'location_tbd')::boolean,false) then null when p ? 'location_address2' then nullif(p->>'location_address2','') else location_address2 end,
     location_city=case when coalesce((p->>'location_tbd')::boolean,false) then null when p ? 'location_city' then nullif(p->>'location_city','') else location_city end,
     location_state=case when coalesce((p->>'location_tbd')::boolean,false) then null when p ? 'location_state' then nullif(p->>'location_state','') else location_state end,
     location_zip=case when coalesce((p->>'location_tbd')::boolean,false) then null when p ? 'location_zip' then nullif(p->>'location_zip','') else location_zip end,
     location_tbd=coalesce((p->>'location_tbd')::boolean,location_tbd),
     public_description=coalesce(p->>'public_description',public_description),
     attire=coalesce(p->>'attire',attire),invited_audience=coalesce(p->>'invited_audience',invited_audience),
     registration_url=coalesce(p->>'registration_url',registration_url),
     payment_url=coalesce(p->>'payment_url',payment_url),flyer_url=coalesce(p->>'flyer_url',flyer_url),
     poc_name=case when p ? 'poc_name' then nullif(btrim(p->>'poc_name'),'') else poc_name end,
     poc_position=case when p ? 'poc_position' then nullif(btrim(p->>'poc_position'),'') else poc_position end,
     poc_phone=case when p ? 'poc_phone' then nullif(btrim(p->>'poc_phone'),'') else poc_phone end,
     poc_email=case when p ? 'poc_email' then nullif(btrim(p->>'poc_email'),'') else poc_email end,
     cost_details=case when p ? 'cost_details' then nullif(btrim(p->>'cost_details'),'') else cost_details end,
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
end $function$
