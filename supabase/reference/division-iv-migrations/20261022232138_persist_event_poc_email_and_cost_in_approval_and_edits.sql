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
  insert into public.events(event_code,title,event_type,hosted_by,district,starts_at,ends_at,event_mode,location_name,location_address,location_address1,location_address2,location_city,location_state,location_zip,location_tbd,public_description,attire,invited_audience,registration_url,payment_url,flyer_url,poc_name,poc_phone,poc_email,cost_details)
  values(r.request_code,p->>'title',p->>'event_type',p->>'hosted_by',p->>'district',
    (p->>'start_local')::timestamp at time zone 'America/Los_Angeles',
    (p->>'end_local')::timestamp at time zone 'America/Los_Angeles',
    coalesce(p->>'event_mode','in_person'),nullif(p->>'location_name',''),nullif(concat_ws(', ',nullif(concat_ws(' ',nullif(p->>'location_address1',''),nullif(p->>'location_address2','')),''),nullif(p->>'location_city',''),nullif(p->>'location_state',''),nullif(p->>'location_zip','')),''),nullif(p->>'location_address1',''),nullif(p->>'location_address2',''),nullif(p->>'location_city',''),nullif(p->>'location_state',''),nullif(p->>'location_zip',''),
    coalesce((p->>'location_tbd')::boolean,false),p->>'public_description',p->>'attire',p->>'invited_audience',p->>'registration_url',p->>'payment_url',p->>'flyer_url',nullif(btrim(p->>'poc_name'),''),nullif(btrim(p->>'poc_phone'),''),nullif(btrim(p->>'poc_email'),''),nullif(btrim(p->>'cost_details'),''))
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
;
CREATE OR REPLACE FUNCTION public.inspector_update_published_event(p_id uuid, p_staff uuid, p_expected_version integer, p_fields jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 old_row public.events%rowtype;
 updated_row public.events%rowtype;
 actor text;
 request_id uuid;
 recipient text;
 stored_values jsonb;
 before_fields jsonb;
 delta jsonb:='{}'::jsonb;
 allowed_districts jsonb;
 item text;
 items text[]:=array['title','event_type','hosted_by','district','start_local','end_local','event_mode','public_description','location_tbd','location_name','location_address1','location_address2','location_city','location_state','location_zip','attire','invited_audience','registration_url','payment_url','flyer_url','poc_name','poc_phone','poc_email','cost_details'];
begin
 select email into actor from public.staff_accounts where id=p_staff and enabled=true;
 if actor is null then raise exception 'Inspector access is required'; end if;
 select * into old_row from public.events where id=p_id for update;
 if not found then raise exception 'Event not found'; end if;
 if old_row.status<>'active' then raise exception 'Cancelled events cannot be edited'; end if;
 if old_row.version is distinct from p_expected_version then raise exception 'This event has changed. Reload before editing'; end if;
 if jsonb_typeof(p_fields)<>'object' then raise exception 'Invalid event fields'; end if;
 foreach item in array items loop
  if not p_fields ? item and item not in ('poc_name','poc_phone','poc_email','cost_details') then raise exception 'Missing field: %', item; end if;
 end loop;
 if trim(coalesce(p_fields->>'title',''))='' or trim(coalesce(p_fields->>'hosted_by',''))='' or
    trim(coalesce(p_fields->>'public_description',''))='' then
   raise exception 'Title, hosting lodge and public description are required';
 end if;
 if length(p_fields->>'title')>180 or length(p_fields->>'public_description')>4000 then raise exception 'Text is too long'; end if;
 if (p_fields->>'event_mode') not in ('in_person','hybrid','online') then raise exception 'Invalid event format'; end if;
 select setting_value into allowed_districts from public.system_settings where setting_key='district_numbers';
 if not coalesce(allowed_districts ? (p_fields->>'district'),false) then raise exception 'Invalid district'; end if;
 if not exists(select 1 from public.event_types where enabled=true and label=p_fields->>'event_type') then raise exception 'Invalid event type'; end if;
 if coalesce(p_fields->>'start_local','') !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$' or
    coalesce(p_fields->>'end_local','') !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$' then raise exception 'Invalid event date'; end if;
 if (p_fields->>'end_local')::timestamp <= (p_fields->>'start_local')::timestamp then raise exception 'End must be after start'; end if;
 if not coalesce((p_fields->>'location_tbd')::boolean,false) then
   if trim(coalesce(p_fields->>'location_name',''))='' or trim(coalesce(p_fields->>'location_address1',''))='' or
      trim(coalesce(p_fields->>'location_city',''))='' or trim(coalesce(p_fields->>'location_state',''))='' or
      trim(coalesce(p_fields->>'location_zip',''))='' then
     raise exception 'Complete the location or select Location TBD';
   end if;
   if p_fields->>'location_state' !~ '^[A-Z]{2}$' or p_fields->>'location_zip' !~ '^\d{5}(-\d{4})?$' then
     raise exception 'Check the state abbreviation and ZIP code';
   end if;
 end if;
 before_fields:=jsonb_build_object(
 'title',old_row.title,'event_type',old_row.event_type,'hosted_by',old_row.hosted_by,'district',old_row.district,
 'start_local',to_char(old_row.starts_at at time zone 'America/Los_Angeles','YYYY-MM-DD"T"HH24:MI'),
 'end_local',to_char(old_row.ends_at at time zone 'America/Los_Angeles','YYYY-MM-DD"T"HH24:MI'),
 'event_mode',old_row.event_mode,'public_description',old_row.public_description,
 'location_tbd',old_row.location_tbd,'location_name',old_row.location_name,
 'location_address1',old_row.location_address1,'location_address2',old_row.location_address2,
 'location_city',old_row.location_city,'location_state',old_row.location_state,'location_zip',old_row.location_zip,
 'attire',old_row.attire,'invited_audience',old_row.invited_audience,'registration_url',old_row.registration_url,
 'payment_url',old_row.payment_url,'flyer_url',old_row.flyer_url,
 'poc_name',old_row.poc_name,'poc_phone',old_row.poc_phone,
 'poc_email',old_row.poc_email,'cost_details',old_row.cost_details);
 foreach item in array items loop
  if p_fields ? item and coalesce(before_fields->>item,'') is distinct from coalesce(p_fields->>item,'') then
    delta:=delta||jsonb_build_object(item,p_fields->item);
  end if;
 end loop;
 if delta='{}'::jsonb then raise exception 'No changes to save'; end if;
 update public.events set
 title=trim(p_fields->>'title'),event_type=p_fields->>'event_type',hosted_by=trim(p_fields->>'hosted_by'),
 district=p_fields->>'district',starts_at=(p_fields->>'start_local')::timestamp at time zone 'America/Los_Angeles',
 ends_at=(p_fields->>'end_local')::timestamp at time zone 'America/Los_Angeles',
 event_mode=p_fields->>'event_mode',public_description=trim(p_fields->>'public_description'),
 location_tbd=coalesce((p_fields->>'location_tbd')::boolean,false),
 location_name=case when (p_fields->>'location_tbd')::boolean then null else nullif(trim(p_fields->>'location_name'),'') end,
 location_address1=case when (p_fields->>'location_tbd')::boolean then null else nullif(trim(p_fields->>'location_address1'),'') end,
 location_address2=case when (p_fields->>'location_tbd')::boolean then null else nullif(trim(p_fields->>'location_address2'),'') end,
 location_city=case when (p_fields->>'location_tbd')::boolean then null else nullif(trim(p_fields->>'location_city'),'') end,
 location_state=case when (p_fields->>'location_tbd')::boolean then null else nullif(trim(p_fields->>'location_state'),'') end,
 location_zip=case when (p_fields->>'location_tbd')::boolean then null else nullif(trim(p_fields->>'location_zip'),'') end,
 location_address=case when (p_fields->>'location_tbd')::boolean then null else
 nullif(concat_ws(', ',nullif(concat_ws(' ',nullif(trim(p_fields->>'location_address1'),''),nullif(trim(p_fields->>'location_address2'),'')),''),nullif(trim(p_fields->>'location_city'),''),nullif(trim(p_fields->>'location_state'),''),nullif(trim(p_fields->>'location_zip'),'')),'') end,
 attire=nullif(trim(p_fields->>'attire'),''),invited_audience=nullif(trim(p_fields->>'invited_audience'),''),
 registration_url=nullif(trim(p_fields->>'registration_url'),''),payment_url=nullif(trim(p_fields->>'payment_url'),''),
 flyer_url=nullif(trim(p_fields->>'flyer_url'),''),
 poc_name=case when p_fields ? 'poc_name' then nullif(trim(p_fields->>'poc_name'),'') else poc_name end,
 poc_phone=case when p_fields ? 'poc_phone' then nullif(trim(p_fields->>'poc_phone'),'') else poc_phone end,
 poc_email=case when p_fields ? 'poc_email' then nullif(trim(p_fields->>'poc_email'),'') else poc_email end,
 cost_details=case when p_fields ? 'cost_details' then nullif(trim(p_fields->>'cost_details'),'') else cost_details end,
 version=version+1,updated_at=now()
 where id=p_id returning * into updated_row;
 insert into public.event_history(event_id,action,actor_staff_id,actor_email,before_data,after_data,notes)
 values(p_id,'inspector_updated_published',p_staff,actor,
 jsonb_build_object('fields',before_fields,'version',old_row.version),
 jsonb_build_object('fields',p_fields,'changes',delta,'version',updated_row.version),
 'Inspector corrected published event');
 insert into public.calendar_jobs(event_id,action,event_version,idempotency_key)
 values(p_id,'upsert',updated_row.version,p_id::text||':'||updated_row.version::text)
 on conflict(idempotency_key) do nothing;
 select id,requester_email into request_id,recipient from public.event_requests
 where request_type='new' and approved_event_id=p_id order by submitted_at asc limit 1;
 if request_id is not null and recipient is not null then
  insert into public.email_deliveries(event_id,request_id,message_type,recipient_email,idempotency_key)
  values(p_id,request_id,'inspector_update',recipient,p_id::text||':'||updated_row.version::text||':inspector_update')
  on conflict do nothing;
 end if;
 return jsonb_build_object('ok',true,'event_id',p_id,'version',updated_row.version,
    'changes',delta,'calendar_status','queued');
end $function$
;
