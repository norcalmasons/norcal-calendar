-- Shared routing for web and future bulk importer.
insert into public.event_types(label,sort_order,enabled) select 'Division Event',max(sort_order)+1,true from public.event_types;
create function public.regional_resolve_event_division(p_district text,p_type text,p_division smallint default null,p_host text default null)
returns smallint language plpgsql stable security invoker set search_path='' as $$
declare resolved smallint; host_matches integer; host_district text; district_value text:=nullif(btrim(p_district),'');
begin
 if p_type in ('Division School of Instruction','Division Event') then
  if district_value is not null then raise exception 'Division-wide events must not select a district'; end if;
  if p_division is null then raise exception 'Select the division for this division-wide event'; end if;
  resolved:=p_division;
 else
  if district_value is null then raise exception 'Choose an active district'; end if;
  select d.division_id into resolved from public.districts d where d.district_code=district_value and d.active;
  if resolved is null then raise exception 'Choose an active district'; end if;
  if p_division is not null and p_division<>resolved then raise exception 'Selected district belongs to a different division'; end if;
  select count(*),min(l.district) into host_matches,host_district from public.lodges l
  where l.active and lower(btrim(coalesce(p_host,''))) in (lower(l.lodge_name),lower(l.lodge_name||' Lodge No. '||l.lodge_number),lower(l.lodge_name||' No. '||l.lodge_number),lower(nullif(l.abbreviation,'')));
  if host_matches=1 and host_district is not null and host_district<>district_value then raise exception 'Selected district does not match the hosting lodge'; end if;
 end if;
 if not exists(select 1 from public.divisions d where d.id=resolved and d.onboarded) then raise exception 'This division is not available for submissions yet'; end if;
 return resolved;
end $$;
revoke all on function public.regional_resolve_event_division(text,text,smallint,text) from public,anon,authenticated;
grant execute on function public.regional_resolve_event_division(text,text,smallint,text) to service_role;
create or replace function public.regional_validate_event_district(p_division smallint,p_type text,p_district text)
returns void language plpgsql stable security invoker set search_path='' as $$
begin
 if p_type in ('Division School of Instruction','Division Event') then
  if nullif(btrim(p_district),'') is not null then raise exception 'Division-wide events must not select a district';end if;
  return;
 end if;
 if not exists(select 1 from public.districts d where d.division_id=p_division and d.active and d.district_code=p_district) then raise exception 'Choose an active district in this division'; end if;
end $$;
