
create table if not exists public.bulk_event_imports (
  id uuid primary key default gen_random_uuid(),
  batch_key text not null unique,
  filename text not null,
  importer_staff_id uuid not null references public.staff_accounts(id),
  importer_email text not null,
  status text not null default 'processing' check (status in ('processing','completed')),
  source_count integer not null default 0 check (source_count between 0 and 25),
  submitted_count integer not null default 0,
  skipped_count integer not null default 0,
  error_count integer not null default 0,
  results jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
alter table public.bulk_event_imports enable row level security;
revoke all on public.bulk_event_imports from public, anon, authenticated;
grant select,insert,update on public.bulk_event_imports to service_role;
create or replace function public.bulk_import_new_request(
  p_code text,p_fields jsonb,p_requester_name text,p_requester_email text,
  p_requester_phone text,p_requester_message text,p_dedupe_key text,
  p_actor_email text,p_staff_id uuid,p_batch_id uuid,p_row integer
) returns jsonb language plpgsql security invoker set search_path = public, pg_temp
as $body$
declare v_id uuid; v_code text; v_is_new boolean := false;
begin
 if auth.role() <> 'service_role' then
   raise exception 'Bulk imports are service-only';
 end if;
 if p_row < 1 or p_row > 200 then raise exception 'Invalid spreadsheet row'; end if;
 if not exists (select 1 from public.bulk_event_imports where id=p_batch_id and importer_staff_id=p_staff_id and status='processing') then
   raise exception 'Bulk import batch is not active';
 end if;
 insert into public.event_requests(
   request_code,event_id,request_type,proposed_fields,requester_name,
   requester_email,requester_phone,requester_message,submission_source,idempotency_key)
 values(p_code,null,'new',p_fields,p_requester_name,lower(trim(p_requester_email)),
    p_requester_phone,p_requester_message,'bulk',p_dedupe_key)
 on conflict (idempotency_key) do nothing
 returning id,request_code into v_id,v_code;
 if v_id is null then
   select id,request_code into v_id,v_code from public.event_requests where idempotency_key=p_dedupe_key;
   if v_id is null then raise exception 'Unable to resolve duplicate import'; end if;
 else
   v_is_new := true;
   insert into public.event_history(event_id,request_id,action,actor_staff_id,actor_email,after_data,notes)
   values(null,v_id,'submitted',p_staff_id,p_actor_email,
     jsonb_build_object('kind','new','source','bulk','batch_id',p_batch_id,'row',p_row),
     'Created via authenticated inspector bulk spreadsheet import');
 end if;
 return jsonb_build_object('id',v_id,'request_code',v_code,'created',v_is_new);
end
$body$;
revoke all on function public.bulk_import_new_request(text,jsonb,text,text,text,text,text,text,uuid,uuid,integer) from public, anon, authenticated;
grant execute on function public.bulk_import_new_request(text,jsonb,text,text,text,text,text,text,uuid,uuid,integer) to service_role;
