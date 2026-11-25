alter table public.email_deliveries drop constraint if exists email_deliveries_status_check;
alter table public.email_deliveries add constraint email_deliveries_status_check
 check (status in ('pending','sending','sent','failed','skipped'));
update public.email_deliveries d
set status='skipped',
    last_error='Superseded system test notification — intentionally skipped before Resend activation. Never delivered.'
from public.event_requests r
where d.request_id=r.id
  and d.status='pending'
  and r.request_code in (
    'DIV4-20261019-C1A065E2',
    'DIV4-20261019-E5A20C3B',
    'DIV4-20261019-DC916DD2',
    'DIV4-20261019-115EEB06',
    'DIV4-20261019-0B690A6B',
    'DIV4-20261019-5631818A'
  );
