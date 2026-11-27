/* Inspector-only new event import. Existing approvals and publication stay unchanged. */
(function(){
'use strict';
const el=id=>document.getElementById(id);
const fileInput=el('bulk-file'),preview=el('bulk-preview'),summary=el('bulk-summary'),results=el('bulk-results'),submit=el('bulk-submit'),status=el('bulk-status');
if(!fileInput||!preview||!submit)return;
let parsed=[],items=[],filename='',readerPromise=null,working=false;
const headers=["Event Name","Event type","Hosting lodge or organization","District","Division","Event format","Start date and time","End date and time","Public event description","Location TBD","Online meeting link","Location / Venue Name","Address Line 1","Address Line 2 (optional)","City","State","ZIP Code","Cost (optional)","Dress / attire","Attendees","Registration link","Payment link","Flyer or invitation link","POC name (optional)","POC position / office","POC phone (optional)","POC email (optional)","Name","Email","Telephone (optional)","Message for inspector (optional)"];
const keys=["event_name","event_type","host_input","district_override","division_input","event_mode","start_local","end_local","public_description","location_tbd","virtual_meeting_url","location_name","location_address1","location_address2","location_city","location_state","location_zip","cost_details","attire","invited_audience","registration_url","payment_url","flyer_url","poc_name","poc_position","poc_phone","poc_email","requester_name","requester_email","requester_phone","requester_message"];
function columnKey(label){
 const heading=String(label??'').split(/\r?\n/)[0].trim().toLowerCase();
 const i=headers.findIndex(h=>h.toLowerCase()===heading);
 return i<0?null:keys[i];
}
function mapColumns(headingRow){
 const indexByKey=new Map();
 headingRow.forEach((value,column)=>{
  const key=columnKey(value);if(!key)return;
  if(indexByKey.has(key))throw Error('Repeated spreadsheet heading: '+String(value));
  indexByKey.set(key,column);
 });
 const missing=keys.filter(key=>!indexByKey.has(key));
 if(missing.length)throw Error('Use the approved NorCal template. Missing headings: '+missing.map(k=>headers[keys.indexOf(k)]).join(', ')+'.');
 return indexByKey;
}
function localDateTime(v){
 if(v instanceof Date&&!Number.isNaN(v.getTime()))return new Date(Math.round(v.getTime()/60000)*60000).toISOString().slice(0,16);
 if(typeof v==='number'&&v>=30000&&v<100000)return new Date(Date.UTC(1899,11,30)+Math.round(v*1440)*60000).toISOString().slice(0,16);
 const x=cell(v);if(!x)return '';
 const iso=x.match(/^(\d{4}-\d{2}-\d{2})[ T](\d{1,2}:\d{2})(?::\d{2})?$/);
 if(iso)return iso[1]+'T'+iso[2].padStart(5,'0');
 const us=x.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})\s+(\d{1,2}):(\d{2})\s*(AM|PM)?$/i);
 if(us){let hour=Number(us[4]);if(us[6]){if(hour<1||hour>12)return x;hour=hour%12+(us[6].toUpperCase()==='PM'?12:0)}return us[3]+'-'+us[1].padStart(2,'0')+'-'+us[2].padStart(2,'0')+'T'+String(hour).padStart(2,'0')+':'+us[5]}
 return x;
}
function parseApprovedWorkbook(workbook){
 const heading=10;
 if(!Array.isArray(workbook[heading])||!String(workbook[heading][0]??'').includes('Required except schools of instruction'))throw Error('Use the approved NorCal template: enter events starting on row 12. Do not move the example or header rows.');
 const indexByKey=mapColumns(workbook[heading]);
 const entries=workbook.slice(heading+1).map((raw,index)=>{
  const row={row_number:heading+index+2};
  for(const key of keys)row[key]=raw?.[indexByKey.get(key)]??'';
  return row;
 }).filter(row=>keys.some(k=>cell(row[k])!==''));
 if(!entries.length)throw Error('No new events found. Enter events starting on row 12.');
 if(entries.length>25||entries.some(row=>row.row_number>36))throw Error('Enter up to 25 events in rows 12–36.');
 return entries.map(row=>{
  const out={row_number:row.row_number};
  for(const k of keys)out[k]=cell(row[k]);
  out.start_local=localDateTime(row.start_local);out.end_local=localDateTime(row.end_local);
  out.location_tbd=['YES','TRUE','1'].includes(cell(row.location_tbd).toUpperCase())?true:['','NO','FALSE','0'].includes(cell(row.location_tbd).toUpperCase())?false:cell(row.location_tbd);
  out.event_mode=normalizeEventMode(row.event_mode);
  return out;
 });
}
function msg(text,error=false){status.textContent=text;status.classList.toggle('error',error)}
function cell(v){if(v===null||v===undefined)return '';if(v instanceof Date)return v.toISOString();return String(v).trim()}
function normalizeEventMode(v){const value=cell(v);const normalized=value.toLowerCase().replaceAll(' ','_').replaceAll('-','_');if(normalized==='online_only')return 'online';if(normalized==='hybrid_(in_person_and_online)')return 'hybrid';return normalized==='in_person'||normalized==='inperson'?'in_person':normalized==='online'?'online':normalized==='hybrid'?'hybrid':value;}
function loadReader(){
 if(window.readXlsxFile)return Promise.resolve(window.readXlsxFile);
 if(readerPromise)return readerPromise;
 readerPromise=new Promise((resolve,reject)=>{
  const script=document.createElement('script');
  script.src='https://cdn.jsdelivr.net/npm/read-excel-file@9.3.13/bundle/read-excel-file.min.js';
  script.async=true;
  script.onload=()=>window.readXlsxFile?resolve(window.readXlsxFile):reject(Error('Excel reader did not load.'));
  script.onerror=()=>reject(Error('The Excel reader could not load. Check your internet connection and retry.'));
  document.head.append(script);
 }).catch(e=>{readerPromise=null;throw e});
 return readerPromise;
}
async function api(action,payload){
 const session=await db.auth.getSession();
 if(!session.data.session)throw Error('Sign in to the Inspector Desk first.');
 const response=await fetch(ROOT+'/functions/v1/division-bulk?action='+action,{method:'POST',
  headers:{apikey:KEY,authorization:'Bearer '+session.data.session.access_token,'content-type':'application/json'},
  body:JSON.stringify(payload)});
 const result=await response.json().catch(()=>({error:'Unexpected response from bulk import service'}));
 if(!response.ok||result.error)throw Error(result.error||'Bulk import failed.');
 return result;
}
function make(tag,cls,text){
 const node=document.createElement(tag);
 if(cls)node.className=cls;
 if(text!==undefined)node.textContent=String(text);
 return node;
}
function clear(){preview.replaceChildren();results.replaceChildren();summary.textContent='';submit.disabled=true;submit.classList.add('hidden');items=[];parsed=[]}
function displayPreview(response){
 const stats=response.summary;summary.textContent=parsed.length+' rows found · '+stats.ready+' ready · '+stats.warnings+' possible duplicates · '+stats.invalid+' need correction';
 const table=make('table','bulk-table');const head=make('thead');const tr=make('tr');
 for(const label of ['Row','Division','Calendar title','When (Pacific)','Location','Validation','Action'])tr.append(make('th','',label));
 head.append(tr);table.append(head);const tbody=make('tbody');
 for(const item of response.items){
  const source=parsed.find(x=>x.row_number===item.row_number);
  const row=make('tr');row.append(make('td','',item.row_number),make('td','',item.division_name||'—'),make('td','',item.calendar_title||source?.event_name||'—'));
  row.append(make('td','',source?.start_local?.replace('T',' ')||'—'));
  row.append(make('td','',item.location_summary||'—'));
  const problem=make('td','',item.issues?.join(' ')||item.warnings?.join(' ')||'Ready for queue');
  if(item.status==='invalid')problem.classList.add('bulk-error');
  if(item.status==='warning')problem.classList.add('bulk-warning');
  row.append(problem);
  const action=make('td');
  if(item.status==='warning'){
   const label=make('label','bulk-confirm');const check=document.createElement('input');check.type='checkbox';check.className='bulk-confirm-check';check.value=String(item.row_number);
   check.addEventListener('change',updateButton);label.append(check,document.createTextNode('Intentional duplicate'));action.append(label);
  }else action.textContent=item.status==='invalid'?'Correct spreadsheet':'Will enter queue';
  row.append(action);tbody.append(row);
 }
 table.append(tbody);preview.append(table);items=response.items;updateButton();
}
function updateButton(){
 const approvals=new Set([...document.querySelectorAll('#bulk-preview .bulk-confirm-check:checked')].map(e=>Number(e.value)));
 const eligible=items.length>0&&!items.some(i=>i.status==='invalid')&&items.some(i=>i.status==='ready'||i.status==='warning');
 submit.classList.toggle('hidden',!eligible);
 submit.disabled=working||items.some(i=>i.status==='invalid')||!items.some(i=>i.status==='ready'||i.status==='warning'&&approvals.has(i.row_number));
}
fileInput.addEventListener('change',async()=>{
 clear();const file=fileInput.files?.[0];if(!file)return;
 if(!/\.xlsx$/i.test(file.name)){msg('Choose the NorCal .xlsx spreadsheet.',true);return}
 if(file.size>3*1024*1024){msg('Spreadsheet is too large (3 MB maximum).',true);return}
 working=true;filename=file.name;msg('Reading spreadsheet and checking the calendar…');
 try{
  const reader=await loadReader();
  const workbook=await reader(file,{sheet:'New Events'});
  parsed=parseApprovedWorkbook(workbook);
  const response=await api('preview',{rows:parsed});
  displayPreview(response);msg('Preview ready. Correct invalid rows in Excel; confirm legitimate duplicates before submission.');
 }catch(e){clear();msg(e.message||'Unable to read spreadsheet.',true)}
 finally{working=false;updateButton()}
});
submit.addEventListener('click',async()=>{
 if(working||!parsed.length)return;
 working=true;submit.disabled=true;
 const confirmed_rows=[...document.querySelectorAll('#bulk-preview .bulk-confirm-check:checked')].map(el=>Number(el.value));
 msg('Submitting valid new events to the existing approval queue…');
 try{
  const outcome=await api('submit',{rows:parsed,filename,confirmed_rows});
  results.replaceChildren();
  results.append(make('h4','',outcome.replayed?'Previous import results':'Import results'));
  results.append(make('p','',outcome.submitted+' submitted · '+outcome.skipped+' skipped · '+outcome.errors+' errors. Each submitted event needs individual approval.'));
  const list=make('div','bulk-results-list');
  for(const item of outcome.results||[]){
   const row=make('div','bulk-result-row');
   row.append(make('strong','', 'Row '+item.row_number+' · '+item.status));
   row.append(make('span','',item.request_code||item.message||item.title));
   if(item.request_id){
    const button=make('button','secondary','View submission');button.type='button';
    button.addEventListener('click',()=>window.openBulkSubmission?.(item.request_id));row.append(button);
   }
   list.append(row);
  }
  results.append(list);results.scrollIntoView({behavior:'smooth',block:'nearest'});
  msg(outcome.notice||'Import recorded. Submitted events are awaiting individual verification and publication.');
  submit.disabled=true;submit.classList.add('hidden');fileInput.value='';parsed=[];items=[];
 }catch(e){msg(e.message||'Import could not be completed.',true)}
 finally{working=false;updateButton()}
});
window.loadBulkImport=()=>{if(!fileInput.files?.length&&!results.children.length)msg('Use the New Events sheet. Times are Pacific.');};
})();
