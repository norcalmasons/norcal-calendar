CREATE OR REPLACE FUNCTION public.resolve_calendar_title(
 p_event_name text, p_hosted_by text, p_event_type text, p_district text,
 p_override text DEFAULT NULL::text, p_fallback text DEFAULT NULL::text
) RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $function$
declare
 nm text:=btrim(coalesce(p_event_name,''));
 host text:=btrim(coalesce(p_hosted_by,''));
 pref text;
 abbrevi text;
 result_title text;
begin
 -- Explicit title overrides remain restricted to authorized inspector/admin operations.
 if nullif(btrim(coalesce(p_override,'')),'') is not null then
   result_title:=btrim(p_override);
 elsif p_event_type='District School of Instruction' then
   if btrim(coalesce(p_district,'')) !~ '^[0-9]{3,4}$' then
     raise exception 'A valid district number is required for District Schools of Instruction';
   end if;
   result_title:='District '||btrim(p_district)||' School of Instruction';
 elsif p_event_type='Division School of Instruction' then
   result_title:='Division IV School of Instruction';
 elsif nm='' then
   result_title:=btrim(coalesce(p_fallback,''));
 else
   if host='' then raise exception 'A hosting lodge or organization is required'; end if;
   select nullif(btrim(l.abbreviation),'') into abbrevi
   from public.lodges l
   where l.active and (
     lower(host)=lower(l.lodge_name||' Lodge No. '||l.lodge_number) or
     lower(host)=lower(l.lodge_name||' No. '||l.lodge_number) or
     lower(host)=lower(coalesce(l.abbreviation,'')) or
     lower(host)=lower(l.lodge_name)
   )
   order by l.lodge_number limit 1;
   pref:=coalesce(abbrevi,host);
   if lower(left(nm,length(pref)+2))=lower(pref||': ') then
     nm:=btrim(substr(nm,length(pref)+3));
   elsif lower(left(nm,length(host)+2))=lower(host||': ') then
     nm:=btrim(substr(nm,length(host)+3));
   end if;
   result_title:=pref||': '||nm;
 end if;
 if result_title='' then raise exception 'A calendar title is required'; end if;
 if length(result_title)>180 then raise exception 'Calendar title exceeds 180 characters'; end if;
 return result_title;
end
$function$;
