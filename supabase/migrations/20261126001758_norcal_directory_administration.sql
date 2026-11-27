-- Allow directory preparation, not regional operations. All other IV-only gates stay in place.
alter table public.districts drop constraint districts_migration_division_iv_only;
alter table public.districts alter column division_id drop default;
create table public.division_directory_history (
 id uuid primary key default gen_random_uuid(),
 actor_staff_id uuid not null references public.staff_accounts(id),
 division_id smallint not null references public.divisions(id),
 operation text not null check(operation in ('division_created','division_updated','district_created','district_updated')),
 before_data jsonb,
 after_data jsonb not null,
 created_at timestamptz not null default now()
);
alter table public.division_directory_history enable row level security;
revoke all on public.division_directory_history from public,anon,authenticated;
grant select,insert on public.division_directory_history to service_role;

create function public.regional_directory_save(p_actor uuid,p_action text,p_division smallint,p_fields jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare old_data jsonb; new_data jsonb; div_name text; sort_num smallint; district_key text; district_label text;
begin
 if not exists(select 1 from public.staff_accounts s where s.id=p_actor and s.enabled and s.removed_at is null and s.role='admin' and s.regional_role='system_admin' and s.division_id is null) then raise exception 'System administrator access required'; end if;
 if p_division is null or p_division<1 or jsonb_typeof(p_fields) is distinct from 'object' then raise exception 'Invalid directory entry'; end if;
 if p_action in ('division_created','division_updated') then
  div_name:=btrim(p_fields->>'name');
  if div_name is null or length(div_name) not between 2 and 100 or coalesce(p_fields->>'display_order','') !~ '^[1-9][0-9]{0,4}$' then raise exception 'Enter a division name and positive display order'; end if;
  sort_num:=(p_fields->>'display_order')::smallint;
  if p_action='division_created' then
   insert into public.divisions(id,name,display_order,onboarded) values(p_division,div_name,sort_num,false) returning to_jsonb(divisions) into new_data;
  else
   select to_jsonb(d) into old_data from public.divisions d where d.id=p_division for update;
   if not found then raise exception 'Division not found'; end if;
   update public.divisions set name=div_name,display_order=sort_num where id=p_division returning to_jsonb(divisions) into new_data;
  end if;
 elsif p_action in ('district_created','district_updated') then
  district_key:=btrim(p_fields->>'district_code'); district_label:=btrim(p_fields->>'district_name');
  if district_key is null or district_key !~ '^[0-9]{1,12}$' or district_label is null or length(district_label) not between 2 and 100 then raise exception 'Enter a numeric district code and district name'; end if;
  if not exists(select 1 from public.divisions d where d.id=p_division) then raise exception 'Division not found'; end if;
  if p_action='district_created' then
   insert into public.districts(district_code,district_name,division_id,active) values(district_key,district_label,p_division,true) returning to_jsonb(districts) into new_data;
  else
   select to_jsonb(d) into old_data from public.districts d where d.district_code=district_key and d.division_id=p_division for update;
   if not found then raise exception 'District not found in this division'; end if;
   update public.districts set district_name=district_label where district_code=district_key and division_id=p_division returning to_jsonb(districts) into new_data;
  end if;
 else raise exception 'Invalid directory operation'; end if;
 insert into public.division_directory_history(actor_staff_id,division_id,operation,before_data,after_data) values(p_actor,p_division,p_action,old_data,new_data);
 return new_data;
end $$;
revoke all on function public.regional_directory_save(uuid,text,smallint,jsonb) from public,anon,authenticated;
grant execute on function public.regional_directory_save(uuid,text,smallint,jsonb) to service_role;
