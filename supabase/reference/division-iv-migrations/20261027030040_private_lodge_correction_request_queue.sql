create table if not exists public.division_correction_requests (
 id uuid primary key default gen_random_uuid(),
 lodge_name text not null,
 category text not null,
 details text not null,
 reporter_contact text,
 status text not null default 'pending',
 review_notes text,
 handled_by uuid,
 reviewed_at timestamptz,
 created_at timestamptz not null default now()
);
alter table public.division_correction_requests enable row level security;
revoke all on public.division_correction_requests from anon, authenticated;
