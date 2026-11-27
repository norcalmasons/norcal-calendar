alter table public.poc_positions add column if not exists sort_order integer;
update public.poc_positions set sort_order = case title
 when 'Worshipful Master' then 1
 when 'Junior Warden' then 2
 when 'Senior Warden' then 3
 when 'Secretary' then 4
 when 'Committee Chair' then 5
 when 'Inspector' then 6 else sort_order end
where title in ('Worshipful Master','Junior Warden','Senior Warden','Secretary','Committee Chair','Inspector');
