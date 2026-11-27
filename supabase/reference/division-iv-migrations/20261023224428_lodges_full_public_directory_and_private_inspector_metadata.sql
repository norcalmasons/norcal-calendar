
alter table public.lodges
 add column if not exists address_line1 text,
 add column if not exists city text,
 add column if not exists county text,
 add column if not exists state text not null default 'CA',
 add column if not exists meeting_day text,
 add column if not exists meeting_time text,
 add column if not exists meeting_notes text,
 add column if not exists official_url text,
 add column if not exists record_version integer not null default 1,
 add column if not exists updated_at timestamptz not null default now(),
 add column if not exists updated_by uuid references public.staff_accounts(id);

alter table public.staff_accounts
 add column if not exists district text,
 add column if not exists member_number text;

create table if not exists public.lodge_change_history (
 id uuid primary key default gen_random_uuid(),
 lodge_id uuid not null references public.lodges(id),
 actor_staff_id uuid not null references public.staff_accounts(id),
 previous_version integer not null,
 new_version integer not null,
 before_data jsonb not null,
 after_data jsonb not null,
 created_at timestamptz not null default now()
);
alter table public.lodge_change_history enable row level security;
revoke all on public.lodge_change_history from anon, authenticated;
create index if not exists lodge_change_history_lodge_at_idx on public.lodge_change_history(lodge_id,created_at desc);
create index if not exists staff_accounts_district_idx on public.staff_accounts(district);
