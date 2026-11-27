-- Configuration only. The live calendar worker, publication gate and newsletter sender do not consume these draft settings yet.
create table public.division_settings (
 division_id smallint primary key references public.divisions(id),
 calendar_id text unique check(calendar_id is null or (length(calendar_id)<=200 and calendar_id ~ '^[A-Za-z0-9._+%@-]+@[A-Za-z0-9._%-]+$')),
 requested_public_submissions boolean not null default false,
 requested_auto_publish boolean not null default false,
 requested_newsletter_signup boolean not null default false,
 requested_monthly_newsletter boolean not null default false,
 requested_weekly_newsletter boolean not null default false,
 monthly_day smallint not null default 1 check(monthly_day between 1 and 28),
 weekly_day smallint not null default 1 check(weekly_day between 0 and 6),
 monthly_send_hour smallint not null default 8 check(monthly_send_hour between 0 and 23),
 weekly_send_hour smallint not null default 8 check(weekly_send_hour between 0 and 23),
 lookahead_days smallint not null default 60 check(lookahead_days between 7 and 365),
 record_version integer not null default 1 check(record_version>0),
 updated_at timestamptz not null default now(),
 updated_by uuid references public.staff_accounts(id),
 check(not requested_auto_publish or requested_public_submissions)
);
create table public.division_settings_history (
 id uuid primary key default gen_random_uuid(),
 division_id smallint not null references public.divisions(id),
 actor_staff_id uuid not null references public.staff_accounts(id),
 occurred_at timestamptz not null default now(),
 before_data jsonb not null, after_data jsonb not null
);
create index division_settings_history_scope_idx on public.division_settings_history(division_id,occurred_at desc);
alter table public.division_settings enable row level security;
alter table public.division_settings_history enable row level security;
revoke all on public.division_settings,public.division_settings_history from public,anon,authenticated;
grant select,insert,update on public.division_settings to service_role;
grant select,insert on public.division_settings_history to service_role;
insert into public.division_settings(division_id) select id from public.divisions;
create function public.regional_seed_division_settings() returns trigger language plpgsql security invoker set search_path='' as $$
begin insert into public.division_settings(division_id) values(new.id); return new;end $$;
revoke all on function public.regional_seed_division_settings() from public,anon,authenticated;
grant execute on function public.regional_seed_division_settings() to service_role;
create trigger regional_seed_division_settings after insert on public.divisions for each row execute function public.regional_seed_division_settings();
create function public.regional_settings_scope(p_staff uuid) returns smallint[] language plpgsql stable security invoker set search_path='' as $$
declare ids smallint[];
begin
 select array_agg(d.id order by d.display_order) into ids from public.divisions d where exists(
 select 1 from public.staff_accounts s where s.id=p_staff and s.enabled and s.removed_at is null and
 ((s.role='admin' and s.regional_role='system_admin' and s.division_id is null) or
 (d.onboarded and exists(select 1 from public.staff_division_assignments a where a.staff_id=s.id and a.division_id=d.id and a.role='division_admin'))));
 if coalesce(cardinality(ids),0)=0 then raise exception 'Administrator access required';end if;
 return ids;
end $$;
create function public.regional_save_division_settings(p_actor uuid,p_division smallint,p_expected_version integer,p_fields jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare old_row public.division_settings%rowtype; new_row public.division_settings%rowtype; k text; v jsonb; system_admin boolean; cal text;
begin
 if not (p_division=any(public.regional_settings_scope(p_actor))) or p_division is null then raise exception 'Administrator access required for this division';end if;
 select exists(select 1 from public.staff_accounts where id=p_actor and role='admin' and regional_role='system_admin' and division_id is null and enabled and removed_at is null) into system_admin;
 if jsonb_typeof(p_fields) is distinct from 'object' or p_fields='{}'::jsonb then raise exception 'No settings supplied';end if;
 select * into old_row from public.division_settings where division_id=p_division for update;
 if not found then raise exception 'Division settings not found';end if;
 if old_row.record_version is distinct from p_expected_version then raise exception 'Settings changed. Reload before saving.';end if;
 for k,v in select key,value from jsonb_each(p_fields) loop
  if k='calendar_id' then
   if not system_admin then raise exception 'Only the system administrator can configure calendar IDs';end if;
   if jsonb_typeof(v) not in ('string','null') then raise exception 'Invalid calendar ID';end if;
  elsif k in ('requested_public_submissions','requested_auto_publish','requested_newsletter_signup','requested_monthly_newsletter','requested_weekly_newsletter') then
   if jsonb_typeof(v) is distinct from 'boolean' then raise exception 'Invalid setting: %',k;end if;
  elsif k in ('monthly_day','weekly_day','monthly_send_hour','weekly_send_hour','lookahead_days') then
   if jsonb_typeof(v) is distinct from 'number' or v::text !~ '^[0-9]+$' then raise exception 'Invalid setting: %',k;end if;
  else raise exception 'Setting is not editable: %',k;
  end if;
 end loop;
 -- All settings are drafts; live integrations remain independently disabled.
 new_row:=jsonb_populate_record(old_row,p_fields);
 new_row.calendar_id:=nullif(lower(btrim(new_row.calendar_id)),'');
 if new_row.calendar_id is not null and exists(select 1 from public.system_settings where setting_key='calendar_id' and lower(setting_value#>>'{}')=new_row.calendar_id) then raise exception 'Calendar ID is already assigned to the master calendar';end if;
 update public.division_settings set calendar_id=new_row.calendar_id,requested_public_submissions=new_row.requested_public_submissions,requested_auto_publish=new_row.requested_auto_publish,requested_newsletter_signup=new_row.requested_newsletter_signup,requested_monthly_newsletter=new_row.requested_monthly_newsletter,requested_weekly_newsletter=new_row.requested_weekly_newsletter,monthly_day=new_row.monthly_day,weekly_day=new_row.weekly_day,monthly_send_hour=new_row.monthly_send_hour,weekly_send_hour=new_row.weekly_send_hour,lookahead_days=new_row.lookahead_days,record_version=old_row.record_version+1,updated_at=clock_timestamp(),updated_by=p_actor where division_id=p_division returning * into new_row;
 insert into public.division_settings_history(division_id,actor_staff_id,before_data,after_data) values(p_division,p_actor,to_jsonb(old_row),to_jsonb(new_row));
 return to_jsonb(new_row);
end $$;
revoke all on function public.regional_settings_scope(uuid),public.regional_save_division_settings(uuid,smallint,integer,jsonb) from public,anon,authenticated;
grant execute on function public.regional_settings_scope(uuid),public.regional_save_division_settings(uuid,smallint,integer,jsonb) to service_role;