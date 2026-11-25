
create table if not exists public.newsletter_signup_limits (
  key_hash text primary key,
  bucket timestamptz not null,
  attempts smallint not null default 1 check(attempts between 0 and 100),
  updated_at timestamptz not null default now()
);
alter table public.newsletter_signup_limits enable row level security;
revoke all on public.newsletter_signup_limits from anon,authenticated;
create index if not exists newsletter_signup_limits_updated_idx on public.newsletter_signup_limits(updated_at);
