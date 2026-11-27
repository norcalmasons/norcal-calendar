alter table public.newsletter_settings alter column monthly_enabled set default false, alter column weekly_enabled set default false;
update public.newsletter_settings set monthly_enabled=false, weekly_enabled=false where id=true and sending_enabled=false and free_plan_confirmed=false;
