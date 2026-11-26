-- Event mutation authorization, based on current canonical assignments.
create function public.regional_event_actor(p_staff uuid,p_division smallint,p_admin_only boolean default false)
returns text language plpgsql stable security invoker set search_path='' as $$
declare actor_email text;
begin
 select s.email into actor_email from public.staff_accounts s
 where s.id=p_staff and s.enabled and s.removed_at is null
 and exists(select 1 from public.divisions d where d.id=p_division and d.onboarded)
 and ((s.role='admin' and s.regional_role='system_admin' and s.division_id is null)
 or exists(select 1 from public.staff_division_assignments a where a.staff_id=s.id and a.division_id=p_division and (a.role='division_admin' or (a.role='inspector' and not p_admin_only))));
 if actor_email is null then raise exception 'Staff access required for this division'; end if;
 return actor_email;
end $$;
revoke all on function public.regional_event_actor(uuid,smallint,boolean) from public,anon,authenticated;
grant execute on function public.regional_event_actor(uuid,smallint,boolean) to service_role;
create function public.regional_validate_event_district(p_division smallint,p_type text,p_district text)
returns void language plpgsql stable security invoker set search_path='' as $$
begin
 if p_type='Division School of Instruction' and nullif(btrim(p_district),'') is null then return; end if;
 if not exists(select 1 from public.districts d where d.division_id=p_division and d.active and d.district_code=p_district) then raise exception 'Choose an active district in this division'; end if;
end $$;
revoke all on function public.regional_validate_event_district(smallint,text,text) from public,anon,authenticated;
grant execute on function public.regional_validate_event_district(smallint,text,text) to service_role;
CREATE OR REPLACE FUNCTION public.regional_resolve_calendar_title(p_division smallint, p_event_name text, p_hosted_by text, p_event_type text, p_district text, p_override text DEFAULT NULL::text, p_fallback text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
 nm text:=btrim(coalesce(p_event_name,''));
 host text:=btrim(coalesce(p_hosted_by,''));
 pref text;
 abbrevi text;
 result_title text;
begin
 -- Explicit title overrides remain restricted to authorized inspector/admin operations.
 if nullif(btrim(coalesce(p_override,'')),'') is not null then
   result_title:=btrim(p_override);
 elsif p_event_type='District School of Instruction' then
   if btrim(coalesce(p_district,'')) !~ '^[0-9]{3,4}$' then
     raise exception 'A valid district number is required for District Schools of Instruction';
   end if;
   result_title:='District '||btrim(p_district)||' School of Instruction';
 elsif p_event_type='Division School of Instruction' then
   select d.name||' School of Instruction' into result_title from public.divisions d where d.id=p_division;
 elsif nm='' then
   result_title:=btrim(coalesce(p_fallback,''));
 else
   if host='' then raise exception 'A hosting lodge or organization is required'; end if;
   select nullif(btrim(l.abbreviation),'') into abbrevi
   from public.lodges l
   where l.active and l.division_id=p_division and (
     lower(host)=lower(l.lodge_name||' Lodge No. '||l.lodge_number) or
     lower(host)=lower(l.lodge_name||' No. '||l.lodge_number) or
     lower(host)=lower(coalesce(l.abbreviation,'')) or
     lower(host)=lower(l.lodge_name)
   )
   order by l.lodge_number limit 1;
   pref:=coalesce(abbrevi,host);
   if lower(left(nm,length(pref)+2))=lower(pref||': ') then
     nm:=btrim(substr(nm,length(pref)+3));
   elsif lower(left(nm,length(host)+2))=lower(host||': ') then
     nm:=btrim(substr(nm,length(host)+3));
   end if;
   result_title:=pref||': '||nm;
 end if;
 if result_title is null or result_title='' then raise exception 'A calendar title is required'; end if;
 if length(result_title)>180 then raise exception 'Calendar title exceeds 180 characters'; end if;
 return result_title;
end
$function$
;
revoke all on function public.regional_resolve_calendar_title(smallint,text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function public.regional_resolve_calendar_title(smallint,text,text,text,text,text,text) to service_role;
CREATE OR REPLACE FUNCTION public.approve_request(p_id uuid, p_staff uuid, p_decision text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
AS $function$
declare r public.event_requests%rowtype; e public.events%rowtype; p jsonb; eid uuid; ver int; who text;
begin
if p_decision not in ('approved','needs_correction','rejected') then raise exception 'Bad decision'; end if;
select * into r from public.event_requests where id=p_id for update;
if not found or r.status not in ('pending','needs_correction') then raise exception 'Request already processed; refresh'; end if;
who:=public.regional_event_actor(p_staff,r.division_id,false);
p:=coalesce(r.inspector_edits,r.proposed_fields);
if p_decision='approved' then
 if r.request_type='new' then
  perform public.regional_validate_event_district(r.division_id,p->>'event_type',p->>'district');
  insert into public.events(division_id,event_code,title,event_name,calendar_title_override,event_type,hosted_by,district,starts_at,ends_at,event_mode,location_name,location_address,location_address1,location_address2,location_city,location_state,location_zip,location_tbd,public_description,attire,invited_audience,registration_url,payment_url,flyer_url,poc_name,poc_position,poc_phone,poc_email,cost_details)
  values(r.division_id,r.request_code,public.regional_resolve_calendar_title(r.division_id,p->>'event_name',p->>'hosted_by',p->>'event_type',p->>'district',p->>'calendar_title_override',p->>'title'),nullif(p->>'event_name',''),nullif(p->>'calendar_title_override',''),p->>'event_type',p->>'hosted_by',p->>'district',
    (p->>'start_local')::timestamp at time zone 'America/Los_Angeles',
    (p->>'end_local')::timestamp at time zone 'America/Los_Angeles',
    coalesce(p->>'event_mode','in_person'),nullif(p->>'location_name',''),nullif(concat_ws(', ',nullif(concat_ws(' ',nullif(p->>'location_address1',''),nullif(p->>'location_address2','')),''),nullif(p->>'location_city',''),nullif(p->>'location_state',''),nullif(p->>'location_zip','')),''),nullif(p->>'location_address1',''),nullif(p->>'location_address2',''),nullif(p->>'location_city',''),nullif(p->>'location_state',''),nullif(p->>'location_zip',''),
    coalesce((p->>'location_tbd')::boolean,false),p->>'public_description',p->>'attire',p->>'invited_audience',p->>'registration_url',p->>'payment_url',p->>'flyer_url',nullif(btrim(p->>'poc_name'),''),nullif(btrim(p->>'poc_position'),''),nullif(btrim(p->>'poc_phone'),''),nullif(btrim(p->>'poc_email'),''),nullif(btrim(p->>'cost_details'),''))
  returning id,version into eid,ver;
 else
  select * into e from public.events where id=r.event_id and division_id=r.division_id for update;
  if not found or e.version is distinct from r.base_event_version then raise exception 'Event changed since request; refresh'; end if;
  if r.request_type='cancel' then
   update public.events set status='cancelled',version=version+1,updated_at=now() where id=e.id returning id,version into eid,ver;
  else
   perform public.regional_validate_event_district(r.division_id,coalesce(p->>'event_type',e.event_type),coalesce(p->>'district',e.district));
   update public.events set
     title=public.regional_resolve_calendar_title(r.division_id,case when p ? 'event_name' then nullif(p->>'event_name','') else e.event_name end,coalesce(p->>'hosted_by',e.hosted_by),coalesce(p->>'event_type',e.event_type),coalesce(p->>'district',e.district),case when p ? 'calendar_title_override' then nullif(p->>'calendar_title_override','') else e.calendar_title_override end,coalesce(p->>'title',e.title)),
     event_name=case when p ? 'event_name' then nullif(p->>'event_name','') else e.event_name end,
     calendar_title_override=case when p ? 'calendar_title_override' then nullif(p->>'calendar_title_override','') else e.calendar_title_override end,
     event_type=coalesce(p->>'event_type',event_type),
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
;
CREATE OR REPLACE FUNCTION public.review_request_checked(p_id uuid, p_staff uuid, p_decision text, p_note text, p_version integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
AS $function$
declare v int; s text;
begin
 select edit_version,status into v,s from public.event_requests where id=p_id for update;
 if not found then raise exception 'Request not found'; end if;
 if s not in ('pending','needs_correction') then raise exception 'Request already processed'; end if;
 if v is distinct from p_version then raise exception 'Another inspector edited this request. Reload before approval.'; end if;
 return public.approve_request(p_id,p_staff,p_decision,p_note);
end $function$
;
CREATE OR REPLACE FUNCTION public.save_inspector_request_edit(p_id uuid, p_staff uuid, p_version integer, p_fields jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
AS $function$
declare r public.event_requests%rowtype; who text; new_version int;
begin
 select * into r from public.event_requests where id=p_id for update;
 if not found or r.status not in ('pending','needs_correction') then raise exception 'Request is no longer editable'; end if;
 who:=public.regional_event_actor(p_staff,r.division_id,false);
 if r.request_type not in ('new','change') then raise exception 'Only new and change requests can be edited'; end if;
 if r.edit_version is distinct from p_version then raise exception 'Another inspector saved a newer revision. Reload before editing.'; end if;
 if jsonb_typeof(p_fields)<>'object' then raise exception 'Invalid edit details'; end if;
 perform public.regional_validate_event_district(r.division_id,coalesce(p_fields->>'event_type',r.proposed_fields->>'event_type'),coalesce(p_fields->>'district',r.proposed_fields->>'district'));
 new_version:=r.edit_version+1;
 update public.event_requests set inspector_edits=p_fields,edit_version=new_version,edited_by=p_staff,edited_at=now(),updated_at=now() where id=p_id;
 insert into public.event_history(event_id,request_id,action,actor_staff_id,actor_email,before_data,after_data)
 values(r.event_id,r.id,'inspector_edited',p_staff,who,
 jsonb_build_object('fields',coalesce(r.inspector_edits,r.proposed_fields),'revision',r.edit_version),
 jsonb_build_object('fields',p_fields,'revision',new_version));
 return jsonb_build_object('ok',true,'edit_version',new_version);
end $function$
;
CREATE OR REPLACE FUNCTION public.inspector_retry_calendar_sync(p_event_id uuid, p_staff uuid, p_expected_version integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
AS $function$
declare
 e public.events%rowtype;
 j public.calendar_jobs%rowtype;
 actor text;
 required_action text;
begin
 select * into e from public.events where id=p_event_id for update;
 if not found then raise exception 'Event not found';end if;
 actor:=public.regional_event_actor(p_staff,e.division_id,false);
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
end $function$
;
CREATE OR REPLACE FUNCTION public.admin_undo_last_published_edit(p_event_id uuid, p_history_id uuid, p_staff uuid, p_expected_version integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
AS $function$
declare
 e public.events%rowtype;
 h public.event_history%rowtype;
 newest uuid;
 result jsonb;
 actor text;
 restore_log public.event_history%rowtype;
begin
 select * into e from public.events where id=p_event_id for update;
 if not found then raise exception 'Event not found';end if;
 actor:=public.regional_event_actor(p_staff,e.division_id,true);
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
end $function$
;
CREATE OR REPLACE FUNCTION public.inspector_update_published_event(p_id uuid, p_staff uuid, p_expected_version integer, p_fields jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY INVOKER
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
 items text[]:=array['title','event_name','calendar_title_override','event_type','hosted_by','district','start_local','end_local','event_mode','public_description','location_tbd','location_name','location_address1','location_address2','location_city','location_state','location_zip','attire','invited_audience','registration_url','payment_url','flyer_url','poc_name','poc_phone','poc_email','cost_details'];
begin
 select * into old_row from public.events where id=p_id for update;
 if not found then raise exception 'Event not found'; end if;
 actor:=public.regional_event_actor(p_staff,old_row.division_id,false);
 if old_row.status<>'active' then raise exception 'Cancelled events cannot be edited'; end if;
 if old_row.version is distinct from p_expected_version then raise exception 'This event has changed. Reload before editing'; end if;
 if jsonb_typeof(p_fields)<>'object' then raise exception 'Invalid event fields'; end if;
 foreach item in array items loop
  if not p_fields ? item and item not in ('poc_name','poc_phone','poc_email','cost_details','event_name','calendar_title_override') then raise exception 'Missing field: %', item; end if;
 end loop;
 if trim(coalesce(p_fields->>'title',''))='' or trim(coalesce(p_fields->>'hosted_by',''))='' or
    trim(coalesce(p_fields->>'public_description',''))='' then
   raise exception 'Title, hosting lodge and public description are required';
 end if;
 if length(p_fields->>'title')>180 or length(p_fields->>'public_description')>4000 then raise exception 'Text is too long'; end if;
 if (p_fields->>'event_mode') not in ('in_person','hybrid','online') then raise exception 'Invalid event format'; end if;
 perform public.regional_validate_event_district(old_row.division_id,p_fields->>'event_type',p_fields->>'district');
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
 'title',old_row.title,'event_name',old_row.event_name,'calendar_title_override',old_row.calendar_title_override,'event_type',old_row.event_type,'hosted_by',old_row.hosted_by,'district',old_row.district,
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
 title=public.regional_resolve_calendar_title(old_row.division_id,case when p_fields ? 'event_name' then nullif(trim(p_fields->>'event_name'),'') else old_row.event_name end,
 trim(p_fields->>'hosted_by'),p_fields->>'event_type',p_fields->>'district',
 case when p_fields ? 'calendar_title_override' then nullif(trim(p_fields->>'calendar_title_override'),'') else old_row.calendar_title_override end,old_row.title),
 event_name=case when p_fields ? 'event_name' then nullif(trim(p_fields->>'event_name'),'') else event_name end,
 calendar_title_override=case when p_fields ? 'calendar_title_override' then nullif(trim(p_fields->>'calendar_title_override'),'') else calendar_title_override end,
 event_type=p_fields->>'event_type',hosted_by=trim(p_fields->>'hosted_by'),
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
revoke all on function public.approve_request(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.approve_request(uuid,uuid,text,text) to service_role;
revoke all on function public.review_request_checked(uuid,uuid,text,text,integer) from public,anon,authenticated;
grant execute on function public.review_request_checked(uuid,uuid,text,text,integer) to service_role;
revoke all on function public.save_inspector_request_edit(uuid,uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function public.save_inspector_request_edit(uuid,uuid,integer,jsonb) to service_role;
revoke all on function public.inspector_retry_calendar_sync(uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.inspector_retry_calendar_sync(uuid,uuid,integer) to service_role;
revoke all on function public.admin_undo_last_published_edit(uuid,uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.admin_undo_last_published_edit(uuid,uuid,uuid,integer) to service_role;
revoke all on function public.inspector_update_published_event(uuid,uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function public.inspector_update_published_event(uuid,uuid,integer,jsonb) to service_role;
