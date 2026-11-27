/* NorCal division configuration. Draft settings cannot enable live integrations. */
(()=>{
 const el=id=>document.getElementById(id),form=el('regional-settings-form');
 if(!form)return;
 const endpoint=ROOT+'/functions/v1/division-site-settings';
 const booleans=['requested_public_submissions','requested_auto_publish','requested_newsletter_signup','requested_monthly_newsletter','requested_weekly_newsletter'];
 const numbers=['monthly_day','weekly_day','monthly_send_hour','weekly_send_hour','lookahead_days'];
 let divisions=[],rows=[],selected=null,canCalendar=false,busy=false,dirty=false,loadSeq=0;
 const note=(msg,bad=false)=>{const n=el('regional-settings-message');n.textContent=msg;n.classList.toggle('error',bad);};
 async function request(action,body,divisionId){
  const {data:{session}}=await db.auth.getSession();if(!session?.access_token)throw Error('Administrator sign-in required');
  const u=new URL(endpoint);u.searchParams.set('action',action);if(divisionId)u.searchParams.set('division_id',divisionId);
  const r=await fetch(u,{method:body===undefined?'GET':'POST',headers:{apikey:KEY,Authorization:'Bearer '+session.access_token,...(body===undefined?{}:{'Content-Type':'application/json'})},...(body===undefined?{}:{body:JSON.stringify(body)})});
  const o=await r.json().catch(()=>({error:'Unexpected division settings response'}));if(!r.ok||o.error)throw Error(o.error||'Division settings request failed');return o;
 }
 function display(id){
  selected=rows.find(r=>r.division_id===id)||null;
  form.classList.toggle('hidden',!selected);
  el('regional-settings-history').classList.add('hidden');
  if(!selected)return;
  const d=divisions.find(x=>x.id===id);
  el('regional-settings-heading').textContent=d.name+' configuration';
  el('regional-settings-status').textContent=d.onboarded?'Onboarded in development':'Not onboarded — configuration only';
  for(const k of booleans)form.elements[k].checked=!!selected[k];
  for(const k of numbers)form.elements[k].value=String(selected[k]);
  form.elements.calendar_id.value=selected.calendar_id||'';
  form.elements.calendar_id.disabled=!canCalendar;
  form.elements.requested_auto_publish.disabled=!form.elements.requested_public_submissions.checked;
  dirty=false;note('Saved draft · version '+selected.record_version);
 }
 function setBusy(v){busy=v;for(const id of ['regional-settings-save','regional-settings-reload','regional-settings-division','regional-settings-history-button'])el(id).disabled=v;}
 async function load(preferred){
  const seq=++loadSeq;setBusy(true);note('Loading division settings…');
  try{
   const r=await request('division-list');if(seq!==loadSeq)return;
   divisions=r.divisions||[];rows=r.settings||[];canCalendar=r.can_configure_calendar===true;
   const picker=el('regional-settings-division');picker.replaceChildren();
   for(const d of divisions)picker.add(new Option(d.name+(d.onboarded?'':' — pending'),String(d.id)));
   const id=divisions.some(d=>d.id===preferred)?preferred:divisions.some(d=>d.id===selected?.division_id)?selected.division_id:divisions[0]?.id;
   picker.value=id?String(id):'';display(id);
  }catch(e){form.classList.add('hidden');note(e.message,true);}finally{if(seq===loadSeq)setBusy(false);}
 }
 window.loadRegionalSettings=()=>load();
 el('regional-settings-division').onchange=async e=>{
  const target=Number(e.target.value);
  if(dirty&&!await divisionQuestion('Discard unsaved changes to this division?',{title:'Unsaved settings',confirmLabel:'Discard changes'})){e.target.value=String(selected.division_id);return;}
  display(target);
 };
 el('regional-settings-reload').onclick=async()=>{if(!dirty||await divisionQuestion('Discard unsaved changes and reload?',{title:'Reload settings',confirmLabel:'Reload'}))load(selected?.division_id);};
 form.addEventListener('input',()=>{
  if(!form.elements.requested_public_submissions.checked)form.elements.requested_auto_publish.checked=false;
  form.elements.requested_auto_publish.disabled=!form.elements.requested_public_submissions.checked;
  dirty=true;note('Unsaved draft changes.');
 });
 form.onsubmit=async e=>{
  e.preventDefault();if(busy||!selected)return;
  const fields={};
  for(const k of booleans){const value=form.elements[k].checked;if(value!==selected[k])fields[k]=value;}
  for(const k of numbers){const value=Number(form.elements[k].value);if(value!==selected[k])fields[k]=value;}
  if(canCalendar){const value=form.elements.calendar_id.value.trim()||null;if(value!==selected.calendar_id)fields.calendar_id=value;}
  if(!Object.keys(fields).length){note('No changes to save.');return;}
  if(Object.hasOwn(fields,'calendar_id')&&!await divisionQuestion('Save this division’s proposed Google Calendar destination? No calendar will be written to during development.',{title:'Save calendar configuration',confirmLabel:'Save draft'}))return;
  setBusy(true);
  try{const r=await request('division-save',{division_id:selected.division_id,expected_version:selected.record_version,fields});rows=rows.map(x=>x.division_id===selected.division_id?r.settings:x);display(selected.division_id);note('Draft saved. Live publishing and newsletters remain disabled.');}
  catch(e){note(e.message,true);}finally{setBusy(false);}
 };
 el('regional-settings-history-button').onclick=async()=>{
  if(!selected||busy)return;
  const panel=el('regional-settings-history');panel.classList.remove('hidden');panel.textContent='Loading history…';setBusy(true);
  try{
   const r=await request('division-history',undefined,selected.division_id);panel.replaceChildren();
   for(const item of r.items||[]){const div=document.createElement('div');div.className='audit-item';const changed=[...booleans,...numbers,'calendar_id'].filter(k=>JSON.stringify(item.before_data?.[k])!==JSON.stringify(item.after_data?.[k]));div.textContent=new Date(item.occurred_at).toLocaleString()+' · '+changed.map(k=>k.replaceAll('_',' ')).join(', ');panel.append(div);}
   if(!panel.children.length)panel.textContent='No changes recorded.';
  }catch(e){panel.textContent=e.message;}finally{setBusy(false);}
 };
})();
