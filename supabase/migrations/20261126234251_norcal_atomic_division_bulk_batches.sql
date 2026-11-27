-- Split one upload into independently owned division batches, atomically.
alter table public.bulk_event_imports drop constraint bulk_event_imports_migration_division_iv_only;
alter table public.bulk_event_imports alter column division_id drop default;
create function public.regional_bulk_submit(p_staff uuid,p_filename text,p_hash text,p_rows jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare item jsonb; row_fields jsonb; v_division smallint; derived smallint; actor text; divisions smallint[]; b public.bulk_event_imports%rowtype; b_key text; b_id uuid; all_results jsonb:='[]'; group_results jsonb; result_row jsonb; saved jsonb; batch_ids jsonb:='[]'; n integer; submitted integer; skipped integer; replayed boolean:=true; row_num integer; row_nums integer[]:='{}'; batch_exists integer; code text; idem text;
begin
 if p_rows is null or jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows) not between 1 and 25 or p_hash is null or p_hash !~ '^[0-9a-f]{64}$' or p_filename is null or length(p_filename)>180 or p_filename !~* '\.xlsx$' then raise exception 'Invalid workbook';end if;
 divisions:='{}'::smallint[];
 for item in select value from jsonb_array_elements(p_rows) loop
  row_num:=(item->>'row_number')::integer;
  if row_num is null or row_num not between 12 and 36 or row_num=any(row_nums) then raise exception 'Invalid or repeated spreadsheet row';end if;
  row_nums:=array_append(row_nums,row_num);
  row_fields:=item->'fields'; v_division:=(item->>'division_id')::smallint;
  if jsonb_typeof(row_fields) is distinct from 'object' or v_division is null or (row_fields->>'division_id')::smallint is distinct from v_division then raise exception 'Invalid row division';end if;
  derived:=public.regional_resolve_event_division(row_fields->>'district',row_fields->>'event_type',v_division,row_fields->>'hosted_by');
  actor:=public.regional_event_actor(p_staff,derived,false);
  if derived<>v_division then raise exception 'Row division mismatch';end if;
  if not coalesce(item->>'fingerprint' ~ '^[0-9a-f]{64}$',false) or jsonb_typeof(item->'skip') is distinct from 'boolean' or jsonb_typeof(item->'confirmed_duplicate') is distinct from 'boolean' then raise exception 'Invalid row metadata';end if;
  if not (v_division=any(divisions)) then divisions:=array_append(divisions,v_division);end if;
 end loop;
 -- Serialize identical submissions. All batches are either created together or not at all.
 perform pg_advisory_xact_lock(hashtextextended(p_staff::text||':'||p_hash,0));
 select count(*) into batch_exists from public.bulk_event_imports x where x.importer_staff_id=p_staff and x.division_id=any(divisions) and x.batch_key=p_staff::text||':'||x.division_id||':'||p_hash;
 if batch_exists<>0 and batch_exists<>cardinality(divisions) then raise exception 'Incomplete prior import; contact administrator';end if;
 for v_division in select unnest(divisions) order by 1 loop
  actor:=public.regional_event_actor(p_staff,v_division,false);
  b_key:=p_staff::text||':'||v_division||':'||p_hash;
  select * into b from public.bulk_event_imports where batch_key=b_key;
  if found then
   if b.status<>'completed' or b.importer_staff_id<>p_staff or b.division_id<>v_division then raise exception 'Previous import is not complete';end if;
   all_results:=all_results||b.results; batch_ids:=batch_ids||jsonb_build_array(jsonb_build_object('division_id',v_division,'batch_id',b.id));continue;
  end if;
  replayed:=false;
  select count(*) into n from jsonb_array_elements(p_rows) x where (x->>'division_id')::smallint=v_division;
  insert into public.bulk_event_imports(division_id,batch_key,filename,importer_staff_id,importer_email,source_count) values(v_division,b_key,p_filename,p_staff,actor,n) returning id into b_id;
  group_results:='[]'::jsonb;
  for item in select value from jsonb_array_elements(p_rows) where (value->>'division_id')::smallint=v_division order by (value->>'row_number')::integer loop
   row_num:=(item->>'row_number')::integer; row_fields:=item->'fields';
   result_row:=jsonb_build_object('row_number',row_num,'division_id',v_division,'title',row_fields->>'title','host',row_fields->>'hosted_by');
   if (item->>'skip')::boolean then
    result_row:=result_row||jsonb_build_object('status','skipped','message','Possible duplicate — not confirmed.');
   else
    idem:=case when (item->>'confirmed_duplicate')::boolean then 'bulk-confirm:'||b_id||':'||row_num else 'bulk:'||(item->>'fingerprint') end;
    code:='DIV'||v_division||'-'||to_char(now() at time zone 'UTC','YYYYMMDD')||'-'||upper(left(gen_random_uuid()::text,8));
    saved:=public.bulk_import_new_request(code,row_fields,item->>'requester_name',item->>'requester_email',item->>'requester_phone',item->>'requester_message',idem,actor,p_staff,b_id,row_num);
    result_row:=result_row||jsonb_build_object('status',case when (saved->>'created')::boolean then 'submitted' else 'skipped' end,'message',case when (saved->>'created')::boolean then 'Submitted for individual approval' else 'Previously imported; no duplicate created' end,'request_id',saved->>'id','request_code',saved->>'request_code');
   end if;
   group_results:=group_results||jsonb_build_array(result_row);
  end loop;
  select count(*) filter(where value->>'status'='submitted'),count(*) filter(where value->>'status'='skipped') into submitted,skipped from jsonb_array_elements(group_results);
  update public.bulk_event_imports set status='completed',completed_at=now(),submitted_count=submitted,skipped_count=skipped,error_count=0,results=group_results where id=b_id;
  if submitted>0 then
   insert into public.email_deliveries(message_type,recipient_email,idempotency_key)
   select distinct 'bulk_import_summary',s.email,'bulk-summary:'||b_id||':'||s.email from public.staff_accounts s join public.staff_division_assignments a on a.staff_id=s.id where a.division_id=v_division and s.enabled and s.removed_at is null on conflict(idempotency_key) do nothing;
  end if;
  all_results:=all_results||group_results;batch_ids:=batch_ids||jsonb_build_array(jsonb_build_object('division_id',v_division,'batch_id',b_id));
 end loop;
 select coalesce(jsonb_agg(value order by (value->>'row_number')::integer),'[]'::jsonb),count(*) filter(where value->>'status'='submitted'),count(*) filter(where value->>'status'='skipped') into all_results,submitted,skipped from jsonb_array_elements(all_results);
 return jsonb_build_object('ok',true,'replayed',replayed,'batches',batch_ids,'results',all_results,'submitted',submitted,'skipped',skipped,'errors',0);
end $$;
revoke all on function public.regional_bulk_submit(uuid,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.regional_bulk_submit(uuid,text,text,jsonb) to service_role;