-- Private division-owned library. Global taxonomy remains system-admin managed.
alter table public.inspector_documents drop constraint inspector_documents_migration_division_iv_only;
alter table public.inspector_documents alter column division_id drop default;
alter table public.inspector_documents add constraint inspector_document_path_owner check (
 (storage_path is null or storage_path like division_id::text||'/'||id::text||'/%')
 and (pending_path is null or pending_path like division_id::text||'/'||id::text||'/%'));
create function public.regional_resource_upload_init(p_actor uuid,p_document uuid,p_division smallint,p_replace boolean,p_title text,p_description text,p_category text,p_path text,p_name text,p_mime text,p_bytes bigint)
returns uuid language plpgsql security invoker set search_path='' as $$
declare d public.inspector_documents%rowtype;
begin
 perform public.regional_event_actor(p_actor,p_division,true);
 if p_document is null or p_path is null or p_path not like p_division::text||'/'||p_document::text||'/%' or p_path !~ '^[0-9]+/[0-9a-f-]{36}/[0-9a-f-]{36}\.[a-z0-9]+$' or p_bytes is null or p_bytes not between 1 and 20971520 or nullif(btrim(p_name),'') is null or length(p_name)>240 or nullif(btrim(p_mime),'') is null then raise exception 'Invalid upload metadata';end if;
 if p_replace then
  select * into d from public.inspector_documents where id=p_document and division_id=p_division and status='active' for update;
  if not found then raise exception 'Document not found or not active';end if;
  if d.pending_at>now()-interval '2 hours' then raise exception 'Another replacement upload is already pending';end if;
  update public.inspector_documents set pending_path=p_path,pending_original_name=p_name,pending_mime_type=p_mime,pending_bytes=p_bytes,pending_by=p_actor,pending_at=now() where id=p_document;
 else
  if nullif(btrim(p_title),'') is null or length(p_title)>160 or length(coalesce(p_description,''))>1200 or not exists(select 1 from public.inspector_resource_categories where name=p_category and active) then raise exception 'Invalid document title, description or category';end if;
  insert into public.inspector_documents(id,division_id,title,description,category,original_name,uploaded_by,pending_path,pending_original_name,pending_mime_type,pending_bytes,pending_by,pending_at)
  values(p_document,p_division,btrim(p_title),coalesce(p_description,''),p_category,p_name,p_actor,p_path,p_name,p_mime,p_bytes,p_actor,now());
 end if;
 return p_document;
end $$;
revoke all on function public.regional_resource_upload_init(uuid,uuid,smallint,boolean,text,text,text,text,text,text,bigint) from public,anon,authenticated;
grant execute on function public.regional_resource_upload_init(uuid,uuid,smallint,boolean,text,text,text,text,text,text,bigint) to service_role;
CREATE OR REPLACE FUNCTION public.change_inspector_resource(p_document uuid, p_actor uuid, p_action text, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_category text DEFAULT NULL::text)
 RETURNS inspector_documents
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare d public.inspector_documents%rowtype; result public.inspector_documents%rowtype;
begin
 select * into d from public.inspector_documents where id=p_document for update;
 if not found or d.status<>'active' then raise exception 'Document is no longer active'; end if;
 perform public.regional_event_actor(p_actor,d.division_id,true);
 if p_action='edited' then
  if nullif(btrim(p_title),'') is null or length(p_title)>160 then raise exception 'Invalid document title'; end if;
  if length(coalesce(p_description,''))>1200 then raise exception 'Description is too long'; end if;
  if not exists(select 1 from public.inspector_resource_categories where name=p_category and active=true)
  then raise exception 'Choose an active document category'; end if;
  update public.inspector_documents set title=btrim(p_title),description=coalesce(btrim(p_description),''),
   category=p_category,updated_at=now() where id=p_document returning * into result;
 elsif p_action='deleted' then
  update public.inspector_documents set status='deleted',deleted_at=now(),updated_at=now(),
   pending_path=null,pending_original_name=null,pending_mime_type=null,pending_bytes=null,pending_by=null,pending_at=null
  where id=p_document returning * into result;
 else raise exception 'Invalid document action'; end if;
 insert into public.inspector_resource_history(document_id,actor_id,action,version,file_path,file_name,details)
 values(p_document,p_actor,p_action,d.version,d.storage_path,d.original_name,
  jsonb_build_object('previous_title',d.title,'previous_category',d.category));
 return result;
end $function$
;
CREATE OR REPLACE FUNCTION public.finalize_inspector_resource(p_document uuid, p_actor uuid, p_path text)
 RETURNS inspector_documents
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare d public.inspector_documents%rowtype; stored_bytes bigint; result public.inspector_documents%rowtype; next_version int;
begin
 select * into d from public.inspector_documents where id=p_document for update;
 if not found then raise exception 'Document not found'; end if;
 perform public.regional_event_actor(p_actor,d.division_id,true);
 if d.status not in ('pending','active') then raise exception 'Document is no longer active';end if;
 if p_path not like d.division_id::text||'/'||d.id::text||'/%' then raise exception 'Invalid storage ownership';end if;
 if d.pending_path is null or d.pending_path<>p_path or d.pending_by is distinct from p_actor
 then raise exception 'Upload session expired or not owned by this administrator'; end if;
 if d.pending_at < now()- interval '2 hours' then raise exception 'Upload authorization expired'; end if;
 if d.pending_bytes is null or d.pending_bytes<1 or d.pending_bytes>20971520 then raise exception 'Invalid file size'; end if;
 select nullif(o.metadata->>'size','')::bigint into stored_bytes
 from storage.objects o where o.bucket_id='division-inspector-resources' and o.name=p_path;
 if stored_bytes is null then raise exception 'File upload has not finished'; end if;
 if stored_bytes<>d.pending_bytes then raise exception 'File size does not match the upload'; end if;
 next_version:=d.version+1;
 if d.version>0 and d.status='active' then
   insert into public.inspector_resource_history(document_id,actor_id,action,version,file_path,file_name,details)
   values(d.id,p_actor,'replaced',d.version,d.storage_path,d.original_name,
    jsonb_build_object('replaced_by_version',next_version));
 end if;
 update public.inspector_documents set status='active',storage_path=p_path,
   original_name=d.pending_original_name,mime_type=d.pending_mime_type,bytes=stored_bytes,
   version=next_version,uploaded_by=p_actor,updated_at=now(),published_at=now(),
   pending_path=null,pending_original_name=null,pending_mime_type=null,
   pending_bytes=null,pending_by=null,pending_at=null
 where id=p_document returning * into result;
 insert into public.inspector_resource_history(document_id,actor_id,action,version,file_path,file_name)
 values(p_document,p_actor,case when next_version=1 then 'uploaded' else 'replaced' end,
  next_version,p_path,result.original_name);
 return result;
end
$function$
;
CREATE OR REPLACE FUNCTION public.manage_inspector_resource_category(p_actor uuid, p_action text, p_id uuid DEFAULT NULL::uuid, p_name text DEFAULT NULL::text)
 RETURNS inspector_resource_categories
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
 cat public.inspector_resource_categories%rowtype;
 result public.inspector_resource_categories%rowtype;
 new_name text;
 used_count int;
begin
 if not exists(select 1 from public.staff_accounts s
  where s.id=p_actor and s.role='admin' and s.regional_role='system_admin' and s.division_id is null and s.enabled=true and s.removed_at is null)
 then raise exception 'Administrator access required'; end if;
 if p_action not in ('create','rename','archive','restore') then raise exception 'Unknown category action'; end if;
 if p_action in ('create','rename') then
  new_name=regexp_replace(btrim(coalesce(p_name,'')),'[[:space:]]+',' ','g');
  if length(new_name)<2 or length(new_name)>50 or
     new_name !~ '^[A-Za-z0-9][A-Za-z0-9 _&/().-]*$'
  then raise exception 'Category names must be 2–50 characters (letters, numbers, spaces, &, /, parentheses, period, hyphen)'; end if;
 end if;
 if p_action='create' then
  if (select count(*) from public.inspector_resource_categories)>=40
  then raise exception 'Maximum of 40 document categories reached'; end if;
  if exists(select 1 from public.inspector_resource_categories where lower(name)=lower(new_name))
  then raise exception 'A category with that name already exists'; end if;
  insert into public.inspector_resource_categories(name,created_by)
    values (new_name,p_actor) returning * into result;
 else
  select * into cat from public.inspector_resource_categories where id=p_id for update;
  if not found then raise exception 'Category not found. Refresh Resources'; end if;
  if cat.name='General' and p_action in ('rename','archive')
  then raise exception 'General is the required default category and cannot be renamed or archived'; end if;
  if p_action='rename' then
   if exists(select 1 from public.inspector_resource_categories where lower(name)=lower(new_name) and id<>cat.id)
    then raise exception 'A category with that name already exists'; end if;
   update public.inspector_resource_categories set name=new_name,updated_at=now()
     where id=cat.id returning * into result;
  elsif p_action='archive' then
   if not cat.active then raise exception 'Category already archived'; end if;
   select count(*) into used_count from public.inspector_documents
     where category=cat.name and status in ('active','pending');
   if used_count>0 then raise exception 'Move the % existing document(s) to another category before archiving',used_count; end if;
   update public.inspector_resource_categories set active=false,updated_at=now()
     where id=cat.id returning * into result;
  elsif p_action='restore' then
   update public.inspector_resource_categories set active=true,updated_at=now()
     where id=cat.id returning * into result;
  end if;
 end if;
 return result;
end $function$
;
revoke all on function public.change_inspector_resource(uuid,uuid,text,text,text,text),public.finalize_inspector_resource(uuid,uuid,text),public.manage_inspector_resource_category(uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.change_inspector_resource(uuid,uuid,text,text,text,text),public.finalize_inspector_resource(uuid,uuid,text),public.manage_inspector_resource_category(uuid,text,uuid,text) to service_role;