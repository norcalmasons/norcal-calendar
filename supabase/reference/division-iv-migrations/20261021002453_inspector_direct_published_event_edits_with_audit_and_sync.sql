create or replace function public.inspector_update_published_event(
 p_id uuid,p_staff uuid,p_expected_version integer,p_fields jsonb
) returns jsonb
language plpgsql security definer set search_path=''
as $func$
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
 items text[]:=array['title','event_type','hosted_by','district','start_local','end_local','event_mode','public_description','location_tbd','location_name','location_address1','location_address2','location_city','location_state','location_zip','attire','invited_audience','registration_url','payment_url','flyer_url'];
begin
 select email into actor from public.staff_accounts where id=p_staff and enabled=true;
 if actor is null then raise exception 'Inspector access is required'; end if;
 select * into old_row from public.events where id=p_id for update;
 if not found then raise exception 'Event not found'; end if;
 if old_row.status<>'active' then raise exception 'Cancelled events cannot be edited'; end if;
 if old_row.version is distinct from p_expected_version then raise exception 'This event has changed. Reload before editing'; end if;
 if jsonb_typeof(p_fields)<>'object' then raise exception 'Invalid event fields'; end if;
 foreach item in array items loop
  if not p_fields ? item then raise exception 'Missing field: %', item; end if;
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
 'payment_url',old_row.payment_url,'flyer_url',old_row.flyer_url);
 foreach item in array items loop
  if coalesce(before_fields->>item,'') is distinct from coalesce(p_fields->>item,'') then
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
end $func$;
revoke all on function public.inspector_update_published_event(uuid,uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function public.inspector_update_published_event(uuid,uuid,integer,jsonb) to service_role;
