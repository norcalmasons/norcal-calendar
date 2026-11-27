
-- Division IV Calendar: foundational schema. No public direct table access.
create table public.staff_accounts (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  display_name text,
  phone text,
  role text not null check (role in ('admin','inspector')),
  enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint normalized_staff_email check (email = lower(btrim(email)))
);
create table public.lodges (
  id uuid primary key default gen_random_uuid(),
  lodge_name text not null,
  lodge_number text,
  district text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.event_types (
  id integer generated always as identity primary key,
  label text not null unique,
  sort_order integer not null unique,
  enabled boolean not null default true
);
create table public.events (
  id uuid primary key default gen_random_uuid(),
  event_code text not null unique,
  title text not null,
  event_type text not null,
  hosted_by text,
  lodge_id uuid references public.lodges(id) on delete set null,
  district text,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  timezone text not null default 'America/Los_Angeles',
  event_mode text not null default 'in_person' check (event_mode in ('in_person','hybrid','online')),
  location_name text,
  location_address text,
  location_tbd boolean not null default false,
  virtual_meeting_url text,
  public_description text,
  attire text,
  invited_audience text,
  meal_cost numeric(10,2),
  registration_url text,
  payment_url text,
  flyer_url text,
  hotel_details jsonb not null default '{}'::jsonb,
  status text not null default 'active' check (status in ('active','cancelled')),
  version integer not null default 1 check (version > 0),
  google_event_id text,
  calendar_last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint dates_in_order check (ends_at > starts_at),
  constraint nonnegative_meal_cost check (meal_cost is null or meal_cost >= 0)
);
create table public.event_requests (
  id uuid primary key default gen_random_uuid(),
  request_code text not null unique,
  event_id uuid references public.events(id) on delete restrict,
  request_type text not null check (request_type in ('new','change','cancel')),
  base_event_version integer,
  proposed_fields jsonb not null default '{}'::jsonb,
  requester_name text not null,
  requester_email text not null,
  requester_phone text,
  requester_message text,
  status text not null default 'pending' check (status in ('pending','needs_correction','approved','rejected')),
  reviewer_id uuid references public.staff_accounts(id),
  reviewer_public_message text,
  reviewer_private_notes text,
  reviewed_at timestamptz,
  approved_event_id uuid references public.events(id),
  submission_source text not null default 'web',
  idempotency_key text unique,
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint event_link_for_modification check (
    (request_type = 'new' and event_id is null) or
    (request_type in ('change','cancel') and event_id is not null)
  ),
  constraint normalized_requester_email check (requester_email = lower(btrim(requester_email)))
);
create table public.event_history (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events(id),
  request_id uuid references public.event_requests(id),
  action text not null,
  actor_staff_id uuid references public.staff_accounts(id),
  actor_email text,
  before_data jsonb,
  after_data jsonb,
  notes text,
  occurred_at timestamptz not null default now()
);
create table public.calendar_jobs (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  request_id uuid references public.event_requests(id),
  action text not null check (action in ('upsert','cancel')),
  event_version integer not null,
  status text not null default 'pending' check (status in ('pending','running','succeeded','failed')),
  attempts integer not null default 0,
  last_error text,
  google_event_id text,
  idempotency_key text not null unique,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);
create table public.email_deliveries (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events(id),
  request_id uuid references public.event_requests(id),
  message_type text not null,
  recipient_email text not null,
  status text not null default 'pending' check (status in ('pending','sending','sent','failed')),
  attempts integer not null default 0,
  provider_message_id text,
  last_error text,
  idempotency_key text not null unique,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);
create table public.system_settings (
  setting_key text primary key,
  setting_value jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.staff_accounts(id)
);
create table public.submission_verifications (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  email text not null,
  token_hash text not null unique,
  purpose text not null check (purpose in ('change','cancel')),
  expires_at timestamptz not null,
  verified_at timestamptz,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.event_attachments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events(id),
  request_id uuid references public.event_requests(id),
  storage_path text not null unique,
  filename text not null,
  mime_type text,
  size_bytes bigint,
  public_after_approval boolean not null default false,
  created_at timestamptz not null default now(),
  constraint associated_attachment check (event_id is not null or request_id is not null)
);

create index on public.event_requests (status, submitted_at desc);
create index on public.event_requests (event_id, submitted_at desc);
create index on public.events (starts_at, ends_at);
create index on public.events (status, event_type, starts_at);
create index on public.events (lodge_id, starts_at);
create index on public.event_history (event_id, occurred_at desc);
create index on public.calendar_jobs (status, created_at);
create index on public.email_deliveries (status, created_at);
create index on public.submission_verifications (event_id, purpose, expires_at);

-- Defense in depth: every application table requires RLS and is inaccessible
-- directly using browser anon/authenticated roles. Edge Functions will verify
-- callers and perform explicitly permitted actions with server-only credentials.
alter table public.staff_accounts enable row level security;
alter table public.lodges enable row level security;
alter table public.event_types enable row level security;
alter table public.events enable row level security;
alter table public.event_requests enable row level security;
alter table public.event_history enable row level security;
alter table public.calendar_jobs enable row level security;
alter table public.email_deliveries enable row level security;
alter table public.system_settings enable row level security;
alter table public.submission_verifications enable row level security;
alter table public.event_attachments enable row level security;

revoke all on public.staff_accounts, public.lodges, public.event_types,
  public.events, public.event_requests, public.event_history,
  public.calendar_jobs, public.email_deliveries, public.system_settings,
  public.submission_verifications, public.event_attachments
  from anon, authenticated;
grant select, insert, update, delete on public.staff_accounts,
  public.lodges, public.event_types, public.events, public.event_requests,
  public.event_history, public.calendar_jobs, public.email_deliveries,
  public.system_settings, public.submission_verifications, public.event_attachments
  to service_role;
revoke usage on sequence public.event_types_id_seq from anon, authenticated;
grant usage, select on sequence public.event_types_id_seq to service_role;

-- Future objects are opt-in, not automatically exposed through Data API.
alter default privileges for role postgres in schema public
  revoke select, insert, update, delete on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke usage, select on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;

insert into public.event_types(label, sort_order) values
 ('Annual Election',1),
 ('Ceremony',2),
 ('Executive Committee',3),
 ('Fundraiser',4),
 ('Installation of Officers',5),
 ('Lodge Anniversary',6),
 ('Pin Presentation',7),
 ('Reception or other event',8),
 ('Special Event',9),
 ('Special Meetings',10),
 ('Stated Meeting',11),
 ('Virtual Meeting',12),
 ('Visits to other Grand Lodges, Conferences & Trips',13),
 ('Entered Apprentice Degree',14),
 ('Fellow Craft Degree',15),
 ('Master Mason Degree',16),
 ('Hiram Award',17),
 ('Golden Veteran Award',18);

-- NorCal reference: production staff-account seed omitted. Provision authorized staff in target separately.

insert into public.system_settings(setting_key,setting_value)
values ('calendar_auto_publish','false'::jsonb),
       ('calendar_id','null'::jsonb),
       ('calendar_timezone','"America/Los_Angeles"'::jsonb),
       ('public_email_links','""'::jsonb),
       ('public_submissions_enabled','false'::jsonb);

-- Review trail may only be appended to; no rewrites or removals.
create function public.prevent_event_history_rewrite()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'event_history is append-only';
end;
$$;
revoke all on function public.prevent_event_history_rewrite() from public, anon, authenticated;
create trigger event_history_append_only
before update or delete on public.event_history
for each row execute function public.prevent_event_history_rewrite();
