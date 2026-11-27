create or replace function public.review_request_checked(p_id uuid,p_staff uuid,p_decision text,p_note text,p_version integer)
returns jsonb language plpgsql security definer set search_path=''
as $review$
declare v int; s text;
begin
 select edit_version,status into v,s from public.event_requests where id=p_id for update;
 if not found then raise exception 'Request not found'; end if;
 if s not in ('pending','needs_correction') then raise exception 'Request already processed'; end if;
 if v is distinct from p_version then raise exception 'Another inspector edited this request. Reload before approval.'; end if;
 return public.approve_request(p_id,p_staff,p_decision,p_note);
end $review$;
revoke all on function public.review_request_checked(uuid,uuid,text,text,integer) from public,anon,authenticated;
grant execute on function public.review_request_checked(uuid,uuid,text,text,integer) to service_role;
