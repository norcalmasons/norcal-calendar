grant select, insert, update, delete on public.newsletter_settings, public.newsletter_subscribers, public.newsletter_event_flags, public.newsletter_runs, public.newsletter_signup_limits to service_role;
alter table public.newsletter_settings
 add column if not exists monthly_enabled boolean not null default true,
 add column if not exists weekly_enabled boolean not null default true,
 add column if not exists monthly_send_hour smallint not null default 8 check (monthly_send_hour between 0 and 23),
 add column if not exists weekly_send_hour smallint not null default 8 check (weekly_send_hour between 0 and 23);
comment on column public.newsletter_settings.sending_enabled is 'Master safety switch: false means no automatic or manual newsletter delivery.';
