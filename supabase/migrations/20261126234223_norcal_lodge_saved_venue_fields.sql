alter table public.lodges add column venue_name text check(char_length(venue_name)<=180), add column address_line2 text check(char_length(address_line2)<=240), add column zip_code text check(zip_code ~ '^[0-9]{5}(-[0-9]{4})?$');
CREATE OR REPLACE FUNCTION public.inspector_update_lodge(p_lodge_id uuid, p_staff_id uuid, p_expected_version integer, p_fields jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
 old_lodge public.lodges%rowtype;
 new_lodge public.lodges%rowtype;
 allowed_keys text[] := array['lodge_name','lodge_number','abbreviation','district','venue_name','address_line1','address_line2','zip_code','city','county','state','meeting_day','meeting_time','meeting_notes','official_url'];
 key_name text;
 new_name text;
 new_number text;
 new_abbreviation text;
 new_district text;
 new_address text;
 new_city text;
 new_county text;
 new_state text;
 new_day text;
 new_time text;
 new_notes text;
 new_url text;
begin

 if p_fields is null or jsonb_typeof(p_fields)<>'object' then
  raise exception 'Invalid lodge update';
 end if;
 for key_name in select jsonb_object_keys(p_fields) loop
  if not key_name=any(allowed_keys) then raise exception 'This field cannot be edited: %',key_name; end if;
 end loop;
 select * into old_lodge from public.lodges where id=p_lodge_id for update;
 if not found then raise exception 'Lodge not found'; end if;
 if not exists(select 1 from public.staff_accounts s where s.id=p_staff_id and s.enabled and s.removed_at is null and ((s.role='admin' and s.regional_role='system_admin' and s.division_id is null) or exists(select 1 from public.staff_division_assignments sa join public.divisions d on d.id=sa.division_id where sa.staff_id=s.id and sa.role='division_admin' and sa.division_id=old_lodge.division_id and d.onboarded))) then
  raise exception 'Administrator access required for this division';
 end if;
 if old_lodge.record_version<>p_expected_version then raise exception 'Record was updated by someone else. Reload the lodge before saving.'; end if;

 new_name:=btrim(coalesce(p_fields->>'lodge_name',old_lodge.lodge_name));
 new_number:=btrim(coalesce(p_fields->>'lodge_number',old_lodge.lodge_number));
 new_abbreviation:=btrim(coalesce(p_fields->>'abbreviation',old_lodge.abbreviation,''));
 new_district:=btrim(coalesce(p_fields->>'district',old_lodge.district));
 new_address:=btrim(coalesce(p_fields->>'address_line1',old_lodge.address_line1,''));
 new_city:=btrim(coalesce(p_fields->>'city',old_lodge.city,''));
 new_county:=btrim(coalesce(p_fields->>'county',old_lodge.county,''));
 new_state:=upper(btrim(coalesce(p_fields->>'state',old_lodge.state,'CA')));
 new_day:=btrim(coalesce(p_fields->>'meeting_day',old_lodge.meeting_day,''));
 new_time:=btrim(coalesce(p_fields->>'meeting_time',old_lodge.meeting_time,''));
 new_notes:=btrim(coalesce(p_fields->>'meeting_notes',old_lodge.meeting_notes,''));
 new_url:=btrim(coalesce(p_fields->>'official_url',old_lodge.official_url,''));

 if new_name='' or length(new_name)>150 or new_number='' or length(new_number)>12 then raise exception 'Enter a valid lodge name and number'; end if;
 if char_length(new_abbreviation)>20 then raise exception 'Lodge abbreviation cannot exceed 20 characters'; end if;
 if not exists(select 1 from public.districts d where d.district_code=new_district and d.division_id=old_lodge.division_id and d.active) then raise exception 'Choose an active district in this division'; end if;
 if new_address='' or length(new_address)>240 or new_city='' or length(new_city)>120 or length(new_county)>100 then raise exception 'Enter a valid street address and city'; end if;
 if new_state !~ '^[A-Z]{2}$' or length(new_day)>100 or length(new_time)>40 or length(new_notes)>300 then raise exception 'Invalid state or meeting schedule'; end if;
 if new_url<>'' and (length(new_url)>1000 or new_url !~* '^https?://[^[:space:]]+') then raise exception 'Enter a valid https:// lodge listing URL'; end if;
 if exists(select 1 from public.lodges where lodge_number=new_number and id<>p_lodge_id) then raise exception 'Another lodge already uses that number'; end if;

 update public.lodges set
  lodge_name=new_name,lodge_number=new_number,abbreviation=nullif(new_abbreviation,''),district=new_district,
  venue_name=case when p_fields ? 'venue_name' then nullif(btrim(p_fields->>'venue_name'),'') else old_lodge.venue_name end,
  address_line2=case when p_fields ? 'address_line2' then nullif(btrim(p_fields->>'address_line2'),'') else old_lodge.address_line2 end,
  zip_code=case when p_fields ? 'zip_code' then nullif(btrim(p_fields->>'zip_code'),'') else old_lodge.zip_code end,
  address_line1=new_address,city=new_city,county=new_county,state=new_state,
  meeting_day=new_day,meeting_time=new_time,meeting_notes=new_notes,official_url=new_url,
  record_version=record_version+1,updated_at=now(),updated_by=p_staff_id
 where id=p_lodge_id and record_version=p_expected_version
 returning * into new_lodge;
 if not found then raise exception 'Concurrent update detected. Reload and retry.'; end if;
 insert into public.lodge_change_history(lodge_id,actor_staff_id,previous_version,new_version,before_data,after_data)
 values (p_lodge_id,p_staff_id,old_lodge.record_version,new_lodge.record_version,to_jsonb(old_lodge),to_jsonb(new_lodge));
 return to_jsonb(new_lodge);
end;
$function$
;
revoke all on function public.inspector_update_lodge(uuid,uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function public.inspector_update_lodge(uuid,uuid,integer,jsonb) to service_role;