create or replace function public.bulk_import_new_request(p_code text,p_fields jsonb,p_requester_name text,p_requester_email text,p_requester_phone text,p_requester_message text,p_dedupe_key text,p_actor_email text,p_staff_id uuid,p_batch_id uuid,p_row integer)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_id uuid; v_code text; v_is_new boolean:=false; v_division smallint; v_batch_division smallint; v_actor text; v_fields jsonb;
begin
 if p_row<12 or p_row>36 then raise exception 'Invalid spreadsheet row';end if;
 select division_id into v_batch_division from public.bulk_event_imports where id=p_batch_id and importer_staff_id=p_staff_id and status='processing' for update;
 if not found then raise exception 'Bulk import batch is not active';end if;
 v_division:=public.regional_resolve_event_division(p_fields->>'district',p_fields->>'event_type',v_batch_division,p_fields->>'hosted_by');
 v_actor:=public.regional_event_actor(p_staff_id,v_division,false);
 if v_actor is distinct from p_actor_email or v_division is distinct from v_batch_division or (p_fields->>'division_id')::smallint is distinct from v_division then raise exception 'Import division or actor mismatch';end if;
 if p_code not like 'DIV'||v_division||'-%' then raise exception 'Invalid submission code';end if;
 v_fields:=(p_fields-'division_id')||jsonb_build_object('title',public.regional_resolve_calendar_title(v_division,p_fields->>'event_name',p_fields->>'hosted_by',p_fields->>'event_type',p_fields->>'district',null,null));
 insert into public.event_requests(division_id,request_code,event_id,request_type,proposed_fields,requester_name,requester_email,requester_phone,requester_message,submission_source,idempotency_key)
 values(v_division,p_code,null,'new',v_fields,p_requester_name,lower(trim(p_requester_email)),p_requester_phone,p_requester_message,'bulk',p_dedupe_key)
 on conflict(idempotency_key) do nothing returning id,request_code into v_id,v_code;
 if v_id is null then
  select id,request_code into v_id,v_code from public.event_requests where idempotency_key=p_dedupe_key and division_id=v_division;
  if v_id is null then raise exception 'Unable to resolve duplicate import';end if;
 else
  v_is_new:=true;
  insert into public.event_history(event_id,request_id,action,actor_staff_id,actor_email,after_data,notes)
  values(null,v_id,'submitted',p_staff_id,v_actor,jsonb_build_object('kind','new','source','bulk','batch_id',p_batch_id,'row',p_row),'Created via authenticated inspector bulk spreadsheet import');
 end if;
 return jsonb_build_object('id',v_id,'request_code',v_code,'created',v_is_new);
end $$;
revoke all on function public.bulk_import_new_request(text,jsonb,text,text,text,text,text,text,uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.bulk_import_new_request(text,jsonb,text,text,text,text,text,text,uuid,uuid,integer) to service_role;