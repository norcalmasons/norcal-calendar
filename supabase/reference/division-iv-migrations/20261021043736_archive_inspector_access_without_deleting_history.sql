alter table public.staff_accounts
add column if not exists removed_at timestamptz,
add column if not exists removed_by uuid references public.staff_accounts(id);
create index if not exists staff_accounts_active_idx on public.staff_accounts (enabled,removed_at);
create table if not exists public.inspector_admin_history (
 id uuid primary key default gen_random_uuid(),
 actor_staff_id uuid not null references public.staff_accounts(id),
 target_staff_id uuid not null references public.staff_accounts(id),
 action text not null check (action in ('removed','restored')),
 created_at timestamptz not null default now()
);
alter table public.inspector_admin_history enable row level security;
revoke all on table public.inspector_admin_history from public,anon,authenticated;
grant all on table public.inspector_admin_history to service_role;
