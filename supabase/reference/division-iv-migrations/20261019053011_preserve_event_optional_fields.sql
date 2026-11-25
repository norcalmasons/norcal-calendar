
create or replace function public.populate_new_event_extras()
returns trigger language plpgsql set search_path='' as $$
declare p jsonb;
begin
 select proposed_fields into p from public.event_requests
 where request_code=new.event_code and request_type='new' limit 1;
 if p is not null then
  new.attire:=nullif(p->>'attire','');
  new.invited_audience:=nullif(p->>'invited_audience','');
  new.virtual_meeting_url:=nullif(p->>'virtual_meeting_url','');
 end if;
 return new;
end;$$;
revoke all on function public.populate_new_event_extras() from public,anon,authenticated;
create trigger event_new_extra_fields
before insert on public.events for each row
execute function public.populate_new_event_extras();
