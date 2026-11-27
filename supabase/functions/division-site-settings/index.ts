import { requireLegacyStaff } from '../_shared/regional-auth.mjs';
// Development-only fail-closed project guard. Remove or parameterize for reviewed production release.
if (Deno.env.get('SUPABASE_URL') !== 'https://ltowvwvryodzrxtpattd.supabase.co') throw new Error('Wrong project: NorCal Dev only');
import { createClient } from 'npm:@supabase/supabase-js@2.57.0';
const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
 {auth:{persistSession:false,autoRefreshToken:false}});
const allowed=new Set(['https://dev.norcalmasons.org','http://localhost:5173','http://127.0.0.1:5173']);
const keys=[
 'calendar_id','calendar_timezone','website_event_request_url','website_inspector_desk_url',
 'website_grand_lodge_url','website_site_url','website_calendar_fallback_url','website_navigation'
];
const fallback:Record<string,any>={
 calendar_id:'',
 calendar_timezone:'America/Los_Angeles',
 website_event_request_url:'https://dev.norcalmasons.org/events/',
 website_inspector_desk_url:'https://dev.norcalmasons.org/inspectors/',
 website_grand_lodge_url:'https://member.freemason.org/public_lodges/search',
 website_site_url:'https://dev.norcalmasons.org/',
 website_calendar_fallback_url:'https://dev.norcalmasons.org/calendar/',
 website_navigation:[
  {group:'division',label:'About Division IV',href:'/#about'},
  {group:'division',label:'Community',href:'/#community'},
  {group:'division',label:'Contact',href:'/#contact'},
  {group:'lodges',label:'Lodge Directory',href:'/lodges/'},
  {group:'lodges',label:'Grand Lodge Finder ↗',href:'@grand_lodge'},
  {group:'calendar',label:'View Division IV Calendar',href:'/calendar/'},
  {group:'calendar',label:'Submit / Change Event ↗',href:'@event_requests'}
 ]
};
function reply(body:unknown,status:number,origin:string){
 const headers:Record<string,string>={'content-type':'application/json; charset=utf-8','cache-control':'no-store','vary':'Origin'};
 if(allowed.has(origin))headers['access-control-allow-origin']=origin;
 return new Response(JSON.stringify(body),{status,headers});
}
function fail(message:string,status:number,origin:string){return reply({error:message},status,origin);}
async function requireAdmin(req:Request){return await requireLegacyStaff(db,req)}
async function getSettings(){
 const {data,error}=await db.from('system_settings').select('setting_key,setting_value').in('setting_key',keys);
 if(error)throw Error('Website settings are unavailable');
 const settings={...fallback};
 for(const row of data||[])if(keys.includes(row.setting_key))settings[row.setting_key]=row.setting_value;
 return settings;
}
function httpsUrl(v:unknown,key:string){
 if(typeof v!=='string'||v.length>1000)throw Error('Invalid URL for '+key);
 const raw=v.trim();
 let parsed:URL;
 try{parsed=new URL(raw);}catch{throw Error('Invalid URL for '+key)}
 if(parsed.protocol!=='https:'||!parsed.hostname||parsed.username||parsed.password)
   throw Error('Use a secure HTTPS URL for '+key);
 return parsed.toString();
}
function validateNavigation(value:unknown){
 if(!Array.isArray(value)||value.length<1||value.length>40)throw Error('Please provide 1–40 menu links');
 const permitted=new Set(['division','lodges','calendar','inspectors']);
 const refs=new Set(['@event_requests','@inspector_desk','@grand_lodge','@calendar_fallback','@site_home']);
 const cleaned=value.map((item:any)=>{
  if(!item||typeof item!=='object'||Array.isArray(item))throw Error('Invalid navigation item');
  const group=String(item.group||'').trim();
  const label=String(item.label||'').trim();
  const href=String(item.href||'').trim();
  if(!permitted.has(group))throw Error('Unknown navigation section');
  if(!label||label.length>65||/[<>]/.test(label))throw Error('Menu label must be 1–65 characters');
  if(href.length>1000)throw Error('Menu destination is too long');
  const localPath=href.startsWith('/')&&!href.startsWith('//')&&!/[\\\s<>]/.test(href);
  const legacyLocal=/^(?:index|calendar|lodges)\.html(?:#[a-z0-9_-]+)?$/i.test(href);
  if(!refs.has(href)&&!localPath&&!legacyLocal&&!/^https:\/\//i.test(href))
   throw Error('Use a website path (such as /calendar/), HTTPS URL, or saved website link');
  if(/^https:/i.test(href))httpsUrl(href,'menu destination');
  return {group,label,href};
 }).filter((item:any)=>item.group!=='inspectors');
 if(!cleaned.length)throw Error('Keep at least one public menu link');
 return cleaned;
}
function validate(k:string,value:unknown){
 if(k==='website_navigation')return validateNavigation(value);
 if(k==='calendar_id'){
  if(typeof value!=='string'||value.length>200||!/^[a-zA-Z0-9._+%@-]+$/.test(value)||!value.includes('@'))
   throw Error('Enter a valid Google Calendar ID');
  return value.trim();
 }
 if(k==='calendar_timezone'){
  if(typeof value!=='string'||value.length>80)throw Error('Invalid time zone');
  try{new Intl.DateTimeFormat('en-US',{timeZone:value});}catch{throw Error('Use a valid IANA time zone');}
  return value.trim();
 }
 return httpsUrl(value,k);
}
Deno.serve(async req=>{
 const origin=req.headers.get('origin')||'';
 const cors={
  'access-control-allow-origin':allowed.has(origin)?origin:'null',
  'access-control-allow-methods':'GET,POST,OPTIONS',
  'access-control-allow-headers':'authorization,apikey,content-type,x-client-info',
  'access-control-max-age':'3600','vary':'Origin'
 };
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers:cors});
 try{
  const action=new URL(req.url).searchParams.get('action')||'public';
  if(origin&&!allowed.has(origin))return fail('Origin not allowed',403,origin);
  if(action==='public'){
   if(req.method!=='GET')return fail('GET required',405,origin);
   return reply({settings:await getSettings()},200,origin);
  }
  const admin=await requireAdmin(req);
  if(action==='division-list'||action==='division-save'||action==='division-history'){
   const {data:ids,error:scopeError}=await db.rpc('regional_settings_scope',{p_staff:admin.id});
   if(scopeError||!Array.isArray(ids)||!ids.length)throw Error('Administrator access required');
   const systemAdmin=admin.role==='admin'&&admin.regional_role==='system_admin'&&admin.division_id===null;
   if(action==='division-list'){
    if(req.method!=='GET')return fail('GET required',405,origin);
    const [divisions,settings]=await Promise.all([
     db.from('divisions').select('id,name,onboarded').in('id',ids).order('display_order'),
     db.from('division_settings').select('*').in('division_id',ids)
    ]);
    if(divisions.error||settings.error)throw Error('Unable to load division settings');
    return reply({divisions:divisions.data,settings:settings.data,can_configure_calendar:systemAdmin,development_only:true},200,origin);
   }
   if(action==='division-history'){
    if(req.method!=='GET')return fail('GET required',405,origin);
    const id=Number(new URL(req.url).searchParams.get('division_id'));
    if(!Number.isInteger(id)||!ids.includes(id))throw Error('Administrator access required for this division');
    const {data,error}=await db.from('division_settings_history').select('id,occurred_at,actor_staff_id,before_data,after_data').eq('division_id',id).order('occurred_at',{ascending:false}).limit(25);
    if(error)throw Error('Unable to load division settings history');
    return reply({items:data||[]},200,origin);
   }
   if(req.method!=='POST')return fail('POST required',405,origin);
   const body=await req.json();
   if(!Number.isInteger(body?.division_id)||!ids.includes(body.division_id)||!Number.isInteger(body?.expected_version)||!body?.fields||typeof body.fields!=='object'||Array.isArray(body.fields))throw Error('Invalid division settings request');
   const {data,error}=await db.rpc('regional_save_division_settings',{p_actor:admin.id,p_division:body.division_id,p_expected_version:body.expected_version,p_fields:body.fields});
   if(error)throw Error(error.message);
   return reply({ok:true,settings:data,development_only:true},200,origin);
  }

  if(action==='admin'){
   if(req.method!=='GET')return fail('GET required',405,origin);
   return reply({settings:await getSettings()},200,origin);
  }
  if(action==='save'){
   if(req.method!=='POST')return fail('POST required',405,origin);
   const b=await req.json();
   const entries=b?.settings;
   if(!entries||typeof entries!=='object'||Array.isArray(entries))throw Error('Website settings required');
   const changed=Object.entries(entries);
   if(!changed.length||changed.length>keys.length)throw Error('No valid settings to update');
   for(const [k] of changed)if(!keys.includes(k))throw Error('Setting is not editable: '+k);
   const existing=await getSettings();
   if(Object.hasOwn(entries,'calendar_id')&&entries.calendar_id!==existing.calendar_id)throw Error('External calendar IDs are locked in NorCal Dev.');
   const now=new Date().toISOString();
   const rows=changed.map(([setting_key,val])=>({
     setting_key,setting_value:validate(setting_key,val),updated_at:now,updated_by:admin.id
   }));
   const {error}=await db.from('system_settings').upsert(rows,{onConflict:'setting_key'});
   if(error)throw Error('Unable to save website settings: '+error.message);
   return reply({ok:true,settings:await getSettings(),updated:rows.map(r=>r.setting_key)},200,origin);
  }
  return fail('Unknown request',404,origin);
 }catch(e){
  console.error('website settings failed',e);
  const msg=e instanceof Error?e.message:'Unexpected error';
  return fail(msg,/sign.in|session|administrator|authenticator|mfa/i.test(msg)?403:400,origin);
 }
});