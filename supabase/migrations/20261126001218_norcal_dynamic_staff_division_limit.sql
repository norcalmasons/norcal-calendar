CREATE OR REPLACE FUNCTION public.regional_staff_save(p_actor uuid, p_profile jsonb, p_assignments jsonb, p_expected_updated_at timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare old_row public.staff_accounts%rowtype; saved public.staff_accounts%rowtype;
  entry jsonb; div smallint; chosen_district text; assignment_role text;
  legacy_role text; legacy_district text; email_value text; enabled_value boolean;
begin
 if not exists(select 1 from public.staff_accounts where id=p_actor and enabled and removed_at is null and role='admin' and regional_role='system_admin' and division_id is null) then raise exception 'System administrator access required'; end if;
 if jsonb_typeof(p_profile) is distinct from 'object' or jsonb_typeof(p_assignments) is distinct from 'array' then raise exception 'Invalid account or assignments'; end if;
 email_value:=lower(btrim(p_profile->>'email'));
 if email_value is null or length(email_value)>250 or email_value !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Valid email required'; end if;
 if jsonb_typeof(p_profile->'enabled') is distinct from 'boolean' then raise exception 'Invalid enabled status'; end if;
 enabled_value:=(p_profile->>'enabled')::boolean;
 select * into old_row from public.staff_accounts where email=email_value for update;
 if found then
   if old_row.removed_at is not null then raise exception 'Restore removed account before editing'; end if;
   if p_expected_updated_at is null or old_row.updated_at<>p_expected_updated_at then raise exception 'Account changed. Refresh before saving'; end if;
 else
   if p_expected_updated_at is not null then raise exception 'Account not found'; end if;
 end if;
 if old_row.regional_role='system_admin' then
   if not enabled_value or jsonb_array_length(p_assignments)<>0 then raise exception 'System administrator access cannot be changed here'; end if;
 else
   if jsonb_array_length(p_assignments)<1 or jsonb_array_length(p_assignments)>(select count(*) from public.divisions) then raise exception 'Select at least one division'; end if;
 end if;
 for entry in select value from jsonb_array_elements(p_assignments) loop
   if jsonb_typeof(entry) is distinct from 'object' or jsonb_typeof(entry->'division_id') is distinct from 'number' or (entry->>'division_id') !~ '^[0-9]+$' then raise exception 'Invalid division assignment'; end if;
   div:=(entry->>'division_id')::smallint;
   assignment_role:=entry->>'role';
   chosen_district:=nullif(btrim(entry->>'district'),'');
   if assignment_role is null or assignment_role not in ('inspector','division_admin') or not exists(select 1 from public.divisions where id=div) then raise exception 'Invalid division or access level'; end if;
   if chosen_district is not null and not exists(select 1 from public.districts d where d.district_code=chosen_district and d.division_id=div and d.active) then raise exception 'District does not belong to selected division'; end if;
 end loop;
 if (select count(distinct value->>'division_id') from jsonb_array_elements(p_assignments))<>jsonb_array_length(p_assignments) then raise exception 'Duplicate division assignment'; end if;
 legacy_role:=case when old_row.regional_role='system_admin' or exists(select 1 from jsonb_array_elements(p_assignments) a where a->>'role'='division_admin') then 'admin' else 'inspector' end;
 select nullif(btrim(value->>'district'),'') into legacy_district from jsonb_array_elements(p_assignments) where value->>'division_id'='4';
 if old_row.id is null then
   insert into public.staff_accounts(email,role,enabled,division_id,regional_role,district) values(email_value,legacy_role,enabled_value,4,null,legacy_district) returning * into old_row;
 end if;
 update public.staff_accounts set
 display_name=p_profile->>'display_name',phone=p_profile->>'phone',first_name=p_profile->>'first_name',middle_name=p_profile->>'middle_name',last_name=p_profile->>'last_name',office_title=coalesce(old_row.office_title,case when old_row.regional_role='system_admin' then 'System Administrator' when legacy_role='admin' then 'Division Administrator' else 'Inspector' end),member_number=nullif(p_profile->>'member_number',''),home_phone=p_profile->>'home_phone',mobile_phone=p_profile->>'mobile_phone',home_address=p_profile->>'home_address',home_address2=p_profile->>'home_address2',city=p_profile->>'city',state=p_profile->>'state',zip=p_profile->>'zip',
 role=legacy_role,enabled=enabled_value,district=legacy_district,updated_at=clock_timestamp()
 where id=old_row.id returning * into saved;
 delete from public.staff_division_assignments where staff_id=saved.id;
 insert into public.staff_division_assignments(staff_id,division_id,role,district)
 select saved.id,(value->>'division_id')::smallint,value->>'role',nullif(btrim(value->>'district'),'') from jsonb_array_elements(p_assignments);
 return jsonb_build_object('id',saved.id,'updated_at',saved.updated_at);
end $function$
;
