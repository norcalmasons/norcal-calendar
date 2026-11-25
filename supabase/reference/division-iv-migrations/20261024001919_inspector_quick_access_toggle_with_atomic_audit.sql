alter table public.inspector_admin_history
drop constraint inspector_admin_history_action_check;
alter table public.inspector_admin_history
add constraint inspector_admin_history_action_check
check (action in ('removed','restored','activated','deactivated'));

create or replace function public.set_inspector_enabled(
 p_actor uuid, p_target uuid, p_expected_enabled boolean, p_enabled boolean
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
 actor public.staff_accounts%rowtype;
 target public.staff_accounts%rowtype;
 updated public.staff_accounts%rowtype;
begin
 select * into actor from public.staff_accounts where id=p_actor;
 if not found or actor.role<>'admin' or not actor.enabled or actor.removed_at is not null
 then raise exception 'Administrator access required'; end if;

 if p_target=p_actor then raise exception 'You cannot disable or change your own account with this action'; end if;
 if p_enabled is null or p_expected_enabled is null or p_enabled=p_expected_enabled
 then raise exception 'Invalid activation request'; end if;

 select * into target from public.staff_accounts where id=p_target for update;
 if not found then raise exception 'Inspector not found'; end if;
 if target.role<>'inspector' then raise exception 'Administrator accounts cannot be toggled'; end if;
 if target.removed_at is not null then raise exception 'Removed inspector accounts must be restored instead'; end if;
 if target.enabled is distinct from p_expected_enabled
 then raise exception 'Inspector status has changed. Refresh the list and try again'; end if;

 update public.staff_accounts set enabled=p_enabled,updated_at=now()
 where id=p_target and role='inspector' and removed_at is null
 returning * into updated;
 if not found then raise exception 'Inspector access could not be changed'; end if;

 insert into public.inspector_admin_history(actor_staff_id,target_staff_id,action)
 values(p_actor,p_target,case when p_enabled then 'activated' else 'deactivated' end);
 return jsonb_build_object('id',updated.id,'enabled',updated.enabled,
   'action',case when p_enabled then 'activated' else 'deactivated' end);
end;
$$;

revoke all on function public.set_inspector_enabled(uuid,uuid,boolean,boolean) from public,anon,authenticated;
grant execute on function public.set_inspector_enabled(uuid,uuid,boolean,boolean) to service_role;
