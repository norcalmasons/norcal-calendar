// Isolated NorCal Dev smoke test. Run from repository root: node tests/norcal-dev-smoke.mjs [--offline]
// Never calls the old Division IV project. No email, calendar writes, credentials or data changes.
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join, relative } from 'node:path';
const root=process.cwd(),project='ltowvwvryodzrxtpattd',api='https://'+project+'.supabase.co/functions/v1/';
const legacy=['lxvceqshpjnjjlllbpaq','divisionivmasons.org','scottxian.github.io','dd8692800e837b4dd367c15738ed95f5fd198e95a30e9d7f1afb98ac3aa3fea5','wix-site-host.com'];
const roots=['app','shared','calendar','events','inspectors','lodges','supabase/functions'];
const walk=dir=>readdirSync(join(root,dir),{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(join(dir,e.name)):[join(dir,e.name)]);
const paths=[...readdirSync(root,{withFileTypes:true}).filter(e=>e.isFile()).map(e=>e.name),...roots.flatMap(walk)].filter(p=>/\.(?:html|js|mjs|ts|css|webmanifest|xml)$/.test(p)||p==='robots.txt');
for(const p of paths){const content=readFileSync(join(root,p),'utf8');for(const forbidden of legacy)assert.ok(!content.includes(forbidden),p+' contains legacy production reference '+forbidden);}
assert.match(readFileSync(join(root,'app/app.js'),'utf8'),/norcal-dev-calendar-session-v1/);
assert.match(readFileSync(join(root,'robots.txt'),'utf8'),/Disallow:\s*\//);
assert.ok(!readFileSync(join(root,'calendar/index.html'),'utf8').includes('group.calendar.google.com'));
for(const p of paths.filter(p=>p.startsWith('supabase/functions/')&&p.endsWith('/index.ts'))){assert.ok(readFileSync(join(root,p),'utf8').includes('Wrong project: NorCal Dev only'),p+' lacks project guard');}
console.log('Static isolation checks passed for '+paths.length+' runtime files.');
if(process.argv.includes('--offline'))process.exit(0);
const origin='https://dev.norcalmasons.org';
async function probe(path,expected,opts={}){const url=new URL(path,api);assert.equal(url.origin,'https://'+project+'.supabase.co');assert.ok(url.pathname.startsWith('/functions/v1/'));const r=await fetch(url,{redirect:'error',signal:AbortSignal.timeout(15000),...opts,headers:{Origin:origin,...opts.headers}});assert.ok(expected.includes(r.status),path+' HTTP '+r.status);const body=await r.json().catch(()=>({}));if(r.ok)assert.equal(r.headers.get('access-control-allow-origin'),origin,path+' CORS');console.log(path+' -> '+r.status);return body;}
const lodges=await probe('division-stated-meetings',[200]);assert.ok(Array.isArray(lodges.lodges)&&lodges.lodges.length>0);assert.ok(lodges.lodges.every(x=>!('email' in x)&&!('phone' in x)&&!('staff' in x)));
const upcoming=await probe('division-upcoming-events',[200]);assert.ok(Array.isArray(upcoming.events));assert.ok(upcoming.events.every(x=>!('poc_email' in x)&&!('poc_phone' in x)&&!('virtual_meeting_url' in x)&&!('google_event_id' in x)));
const settings=await probe('division-site-settings?action=public',[200]);assert.ok(!settings.settings.calendar_id);
const config=await probe('division-calendar?action=config',[200]);assert.equal(config.public_submissions_enabled,false);assert.equal(config.staff,null);
const newsletter=await probe('division-newsletter?action=status',[200]);assert.equal(newsletter.signup_enabled,false);
for(const path of ['division-calendar?action=requests','division-calendar?action=staff','division-lodges?action=all','division-site-settings?action=admin','division-resources?action=list','division-newsletter?action=admin-status','division-corrections?action=list'])await probe(path,[400,401,403]);
for(const path of ['division-newsletter?action=subscribe','division-newsletter?action=send-now','division-corrections?action=submit'])await probe(path,[403],{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'});
await probe('division-upcoming-events',[403],{headers:{Origin:'https://untrusted.example'}});
console.log('NorCal Dev endpoint isolation checks passed. Authenticated and browser tests still required.');
