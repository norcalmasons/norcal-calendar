-- Stage 1: additive regional ownership foundation. NorCal development only.
-- All non-IV records remain blocked until every privileged handler is scoped.
create table public.divisions (
  id smallint primary key check (id > 0),
  name text not null unique,
  display_order smallint not null unique,
  onboarded boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.divisions enable row level security;
revoke all on public.divisions from public, anon, authenticated;
grant select, insert, update, delete on public.divisions to service_role;
insert into public.divisions (id,name,display_order,onboarded) values
(1,'Division I',1,false),(2,'Division II',2,false),(3,'Division III',3,false),(4,'Division IV',4,true),(10,'Division X',5,false);

alter table public.districts add column division_id smallint not null default 4 references public.divisions(id);
alter table public.districts add constraint districts_migration_division_iv_only check (division_id=4);
create index districts_division_id_idx on public.districts(division_id);
alter table public.lodges add column division_id smallint not null default 4 references public.divisions(id);
alter table public.lodges add constraint lodges_migration_division_iv_only check (division_id=4);
create index lodges_division_id_idx on public.lodges(division_id);
alter table public.events add column division_id smallint not null default 4 references public.divisions(id);
alter table public.events add constraint events_migration_division_iv_only check (division_id=4);
create index events_division_id_idx on public.events(division_id);
alter table public.event_requests add column division_id smallint not null default 4 references public.divisions(id);
alter table public.event_requests add constraint event_requests_migration_division_iv_only check (division_id=4);
create index event_requests_division_id_idx on public.event_requests(division_id);
alter table public.bulk_event_imports add column division_id smallint not null default 4 references public.divisions(id);
alter table public.bulk_event_imports add constraint bulk_event_imports_migration_division_iv_only check (division_id=4);
create index bulk_event_imports_division_id_idx on public.bulk_event_imports(division_id);
alter table public.division_correction_requests add column division_id smallint not null default 4 references public.divisions(id);
alter table public.division_correction_requests add constraint division_correction_requests_migration_division_iv_only check (division_id=4);
create index division_correction_requests_division_id_idx on public.division_correction_requests(division_id);
alter table public.inspector_documents add column division_id smallint not null default 4 references public.divisions(id);
alter table public.inspector_documents add constraint inspector_documents_migration_division_iv_only check (division_id=4);
create index inspector_documents_division_id_idx on public.inspector_documents(division_id);

-- Keep legacy role and defaults compatible until the authorization cutover.
-- New staff must receive an explicit regional role before regional access is enabled.
alter table public.staff_accounts add column division_id smallint default 4 references public.divisions(id);
alter table public.staff_accounts add column regional_role text;
update public.staff_accounts set division_id=null, regional_role='system_admin'
where enabled and role='admin' and email='northerncaliforniamasons@gmail.com';
update public.staff_accounts set regional_role=case when role='admin' then 'division_admin' else 'inspector' end
where regional_role is null;
alter table public.staff_accounts add constraint staff_regional_role_shape check (
  (regional_role is null and division_id is not null)
  or (regional_role='system_admin' and role='admin' and division_id is null)
  or (regional_role='division_admin' and role='admin' and division_id is not null)
  or (regional_role='inspector' and role='inspector' and division_id is not null)
);
alter table public.staff_accounts add constraint staff_migration_division_iv_only check (division_id is null or division_id=4);
create index staff_accounts_division_id_idx on public.staff_accounts(division_id);

-- Prevent mismatched linked records even when the temporary IV-only gates are eventually removed.
alter table public.districts add constraint districts_code_division_unique unique (district_code,division_id);
alter table public.lodges add constraint lodges_id_division_unique unique (id,division_id);
alter table public.events add constraint events_id_division_unique unique (id,division_id);
alter table public.event_requests add constraint event_requests_id_division_unique unique (id,division_id);
alter table public.lodges add constraint lodges_district_division_fk foreign key (district,division_id) references public.districts(district_code,division_id) on update cascade;
alter table public.events add constraint events_lodge_division_fk foreign key (lodge_id,division_id) references public.lodges(id,division_id);
alter table public.event_requests add constraint event_requests_event_division_fk foreign key (event_id,division_id) references public.events(id,division_id);
alter table public.event_requests add constraint event_requests_approved_division_fk foreign key (approved_event_id,division_id) references public.events(id,division_id);
alter table public.staff_accounts add constraint staff_district_division_fk foreign key (district,division_id) references public.districts(district_code,division_id) on update cascade;
-- Event district strings are legacy free text: defer their FK until the one unmatched value is reviewed.
-- Child history/queue/attachment rows inherit ownership through their parent references; do not duplicate it.
-- No public submission, job scheduling, calendar integration, or newsletter sending is enabled here.
