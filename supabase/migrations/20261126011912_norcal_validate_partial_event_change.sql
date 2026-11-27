CREATE OR REPLACE FUNCTION public.save_inspector_request_edit(p_id uuid, p_staff uuid, p_version integer, p_fields jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r public.event_requests%rowtype; current_event public.events%rowtype; who text; new_version int;
begin
 select * into r from public.event_requests where id=p_id for update;
 if not found or r.status not in ('pending','needs_correction') then raise exception 'Request is no longer editable'; end if;
 who:=public.regional_event_actor(p_staff,r.division_id,false);
 if r.request_type not in ('new','change') then raise exception 'Only new and change requests can be edited'; end if;
 if r.edit_version is distinct from p_version then raise exception 'Another inspector saved a newer revision. Reload before editing.'; end if;
 if jsonb_typeof(p_fields)<>'object' then raise exception 'Invalid edit details'; end if;
 if r.request_type='change' then
  select * into current_event from public.events where id=r.event_id and division_id=r.division_id;
  if not found then raise exception 'Published event not found'; end if;
  perform public.regional_validate_event_district(r.division_id,coalesce(p_fields->>'event_type',current_event.event_type),coalesce(p_fields->>'district',current_event.district));
 else
  perform public.regional_validate_event_district(r.division_id,coalesce(p_fields->>'event_type',r.proposed_fields->>'event_type'),coalesce(p_fields->>'district',r.proposed_fields->>'district'));
 end if;
 new_version:=r.edit_version+1;
 update public.event_requests set inspector_edits=p_fields,edit_version=new_version,edited_by=p_staff,edited_at=now(),updated_at=now() where id=p_id;
 insert into public.event_history(event_id,request_id,action,actor_staff_id,actor_email,before_data,after_data)
 values(r.event_id,r.id,'inspector_edited',p_staff,who,
 jsonb_build_object('fields',coalesce(r.inspector_edits,r.proposed_fields),'revision',r.edit_version),
 jsonb_build_object('fields',p_fields,'revision',new_version));
 return jsonb_build_object('ok',true,'edit_version',new_version);
end $function$
;
