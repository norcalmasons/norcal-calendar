
create table if not exists public.newsletter_settings (
  id boolean primary key default true check (id),
  sending_enabled boolean not null default false,
  signup_enabled boolean not null default false,
  free_plan_confirmed boolean not null default false,
  resend_segment_id uuid,
  sender_address text,
  monthly_day smallint not null default 1 check (monthly_day between 1 and 28),
  weekly_day smallint not null default 1 check (weekly_day between 0 and 6),
  send_hour smallint not null default 8 check (send_hour between 0 and 23),
  lookahead_days smallint not null default 60 check (lookahead_days between 7 and 120),
  contact_cap smallint not null default 900 check (contact_cap between 1 and 1000),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.staff_accounts(id)
);
insert into public.newsletter_settings(id) values (true) on conflict (id) do nothing;
create table if not exists public.newsletter_subscribers (
  id uuid primary key default gen_random_uuid(),
  email text not null unique check (email=lower(btrim(email)) and length(email)<=250),
  status text not null default 'pending' check (status in ('pending','active','unsubscribed')),
  token_hash text,
  token_expires_at timestamptz,
  requested_at timestamptz not null default now(),
  confirmed_at timestamptz,
  unsubscribed_at timestamptz,
  last_confirmation_sent_at timestamptz,
  provider_contact_id text,
  provider_synced_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists newsletter_subscribers_status_idx on public.newsletter_subscribers(status);
create table if not exists public.newsletter_event_flags (
  event_id uuid primary key references public.events(id) on delete cascade,
  event_version integer not null,
  change_kind text not null check (change_kind in ('new','updated','cancelled')),
  dirty boolean not null default true,
  changed_at timestamptz not null default now(),
  announced_at timestamptz
);
create index if not exists newsletter_event_flags_dirty_idx on public.newsletter_event_flags(dirty,changed_at);
create table if not exists public.newsletter_runs (
  id uuid primary key default gen_random_uuid(),
  issue_key text not null unique,
  kind text not null check (kind in ('monthly','weekly','manual')),
  state text not null default 'prepared' check (state in ('prepared','sending','submitted','skipped','needs_review','failed')),
  content_summary jsonb not null default '{}'::jsonb,
  event_versions jsonb not null default '[]'::jsonb,
  provider_broadcast_id text unique,
  error_message text,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  created_by uuid references public.staff_accounts(id)
);
create index if not exists newsletter_runs_created_idx on public.newsletter_runs(created_at desc);
alter table public.newsletter_settings enable row level security;
alter table public.newsletter_subscribers enable row level security;
alter table public.newsletter_event_flags enable row level security;
alter table public.newsletter_runs enable row level security;
revoke all on public.newsletter_settings,public.newsletter_subscribers,public.newsletter_event_flags,public.newsletter_runs from anon,authenticated;
create or replace function public.newsletter_flag_after_calendar_sync() returns trigger
language plpgsql security definer set search_path=public as $$
declare current_version integer; had_previous boolean; existing_kind text; new_kind text;
begin
 if new.status <> 'succeeded' or old.status='succeeded' then return new; end if;
 select version into current_version from public.events where id=new.event_id;
 if current_version is null or current_version<>new.event_version then return new; end if;
 select exists (
  select 1 from public.calendar_jobs j where j.event_id=new.event_id
    and j.id<>new.id and j.status='succeeded'
    and j.event_version<=new.event_version
 ) into had_previous;
 select f.change_kind into existing_kind from public.newsletter_event_flags f
  where f.event_id=new.event_id and f.dirty=true;
 new_kind:=case when new.action='cancel' then 'cancelled'
                when existing_kind='new' then 'new'
                when not had_previous then 'new'
                else 'updated' end;
 insert into public.newsletter_event_flags(event_id,event_version,change_kind,dirty,changed_at)
 values (new.event_id,new.event_version,new_kind,true,now())
 on conflict(event_id) do update set
  event_version=excluded.event_version,change_kind=excluded.change_kind,
  dirty=true,changed_at=now();
 return new;
end $$;
drop trigger if exists newsletter_calendar_success on public.calendar_jobs;
create trigger newsletter_calendar_success after update of status on public.calendar_jobs
for each row when (new.status='succeeded' and old.status is distinct from new.status)
execute function public.newsletter_flag_after_calendar_sync();
revoke all on function public.newsletter_flag_after_calendar_sync() from public,anon,authenticated;
