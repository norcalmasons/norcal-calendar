
-- Canonical district records. Preserve existing lodge and staff district values.
create table if not exists public.districts (
 district_code text primary key,
 district_name text not null,
 active boolean not null default true,
 created_at timestamptz not null default now()
);
insert into public.districts(district_code,district_name)
values ('402','District 402'),('404','District 404'),('410','District 410'),
 ('414','District 414'),('418','District 418'),('422','District 422'),
 ('428','District 428'),('438','District 438')
on conflict (district_code) do nothing;
alter table public.districts enable row level security;
revoke all on public.districts from anon,authenticated;
grant select on public.districts to service_role;

-- Link both tables to the exact same district keys.
alter table public.lodges
 add constraint lodges_district_fkey
 foreign key (district) references public.districts(district_code)
 on update cascade;
alter table public.staff_accounts
 add constraint staff_accounts_district_fkey
 foreign key (district) references public.districts(district_code)
 on update cascade;

-- Restore the missing privileges used by the already-authenticated edge function.
grant select, insert on public.lodge_change_history to service_role;
comment on table public.districts is 'One district shared by lodge and inspector records; inspector contact details remain private.';
