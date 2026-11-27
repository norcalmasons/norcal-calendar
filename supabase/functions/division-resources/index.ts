import { requireLegacyStaff } from '../_shared/regional-auth.mjs';
// Development-only fail-closed project guard. Remove or parameterize for reviewed production release.
if (Deno.env.get('SUPABASE_URL') !== 'https://ltowvwvryodzrxtpattd.supabase.co') throw new Error('Wrong project: NorCal Dev only');
import { createClient } from 'npm:@supabase/supabase-js@2.57.0';
const url=Deno.env.get('SUPABASE_URL')!;
const db=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
const bucket='division-inspector-resources';
const maxBytes=20*1024*1024;
const allowed=new Set(['https://dev.norcalmasons.org','http://localhost:5173','http://127.0.0.1:5173']);

const mimetypes:Record<string,string>={
 pdf:'application/pdf',doc:'application/msword',
 docx:'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
 xls:'application/vnd.ms-excel',
 xlsx:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
 ppt:'application/vnd.ms-powerpoint',
 pptx:'application/vnd.openxmlformats-officedocument.presentationml.presentation',
 txt:'text/plain',csv:'text/csv',png:'image/png',jpg:'image/jpeg',jpeg:'image/jpeg'
};
function respond(body:unknown,origin:string,status=200){
 return new Response(JSON.stringify(body),{status,headers:{
 'content-type':'application/json; charset=utf-8','cache-control':'no-store','vary':'Origin',
 ...(allowed.has(origin)?{'access-control-allow-origin':origin}:{})}});
}
function fail(msg:string,origin:string,status=400){return respond({error:msg},origin,status)}
async function actor(req:Request){return await requireLegacyStaff(db,req)}
async function scopeFor(who:any,adminOnly=false){
 const {data,error}=await db.rpc('regional_event_divisions',{p_staff:who.id,p_requested:null,p_admin_only:adminOnly});
 if(error||!Array.isArray(data)||!data.length)throw Error('No authorized division access');
 return data as number[];
}
function isSystemAdmin(who:any){return who.role==='admin'&&who.regional_role==='system_admin'&&who.division_id===null}
function divisionId(value:unknown){const x=Number(value);if(!Number.isInteger(x)||x<1||x>32767)throw Error('Select a division');return x;}
async function assertPrivateBucket(who:any,create=false){
 const {data,error}=await db.storage.getBucket(bucket);
 if(!error&&data){if(data.public!==false)throw Error('Resource storage is not private');return;}
 if(!create||!isSystemAdmin(who))throw Error('Private resource storage unavailable. Contact the system administrator.');
 // Storage API, not direct SQL modifications. Fail closed if the bucket already exists or creation fails.
 const created=await db.storage.createBucket(bucket,{public:false,fileSizeLimit:maxBytes,allowedMimeTypes:[...new Set(Object.values(mimetypes))]});
 if(created.error)throw Error('Unable to provision private storage: '+created.error.message);
 const checked=await db.storage.getBucket(bucket);
 if(checked.error||checked.data?.public!==false)throw Error('Unable to verify private resource storage');
}
const trim=(s:unknown,n:number)=>typeof s==='string'?s.trim().slice(0,n):'';
const uuid=(s:unknown)=>typeof s==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)?s:'';
async function getCategory(s:unknown){
 const name=trim(s,50)||'General';
 const {data,error}=await db.from('inspector_resource_categories').select('name')
  .eq('name',name).eq('active',true).maybeSingle();
 if(error||!data)throw Error('Choose an active category from the list');
 return data.name;
}
function fileProps(b:any){
 const name=trim(b?.name,240);
 if(!name||/[\/\\\x00-\x1f]/.test(name))throw Error('Choose a valid file name');
 const ext=name.split('.').pop()?.toLowerCase()||'';
 const mime=mimetypes[ext];
 if(!mime)throw Error('Supported files: PDF, Word, Excel, PowerPoint, text, CSV, JPG, PNG');
 const bytes=Number(b?.size);
 if(!Number.isSafeInteger(bytes)||bytes<1||bytes>maxBytes)throw Error('File must be between 1 byte and 20 MB');
 return {name,ext,mime,bytes};
}
const publicDocFields='id,division_id,title,description,category,original_name,mime_type,bytes,version,created_at,updated_at,published_at';
Deno.serve(async req=>{
 const origin=req.headers.get('origin')||'';
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers:{
  'access-control-allow-origin':allowed.has(origin)?origin:'null',
  'access-control-allow-methods':'GET,POST,OPTIONS',
  'access-control-allow-headers':'authorization,apikey,content-type,x-client-info',
  'access-control-max-age':'3600','vary':'Origin'}});
 if(origin&&!allowed.has(origin))return fail('Origin not allowed',origin,403);
 try{
  const action=new URL(req.url).searchParams.get('action')||'list';
  const method=req.method;
  const who=await actor(req);
  const readScope=await scopeFor(who);
  let adminScope:number[]=[];
  // During migration only the legacy system administrator is admitted; scope checks prepare the regional rollout.
  if(isSystemAdmin(who))adminScope=readScope;
  else {const {data,error}=await db.rpc('regional_event_divisions',{p_staff:who.id,p_requested:null,p_admin_only:true});if(!error&&Array.isArray(data))adminScope=data;}
  const selected=new URL(req.url).searchParams.get('division_id');
  const scope=selected===null?readScope:[divisionId(selected)];
  if(scope.some(id=>!readScope.includes(id)))throw Error('Inspector access required for this division');
  if(action==='list'){
   if(method!=='GET')return fail('GET required',origin,405);
   const [documents,categories,divisions]=await Promise.all([
    db.from('inspector_documents').select(publicDocFields)
     .in('division_id',scope).eq('status','active').order('updated_at',{ascending:false}).limit(1000),
    db.from('inspector_resource_categories').select('id,name,active,updated_at')
     .order('name',{ascending:true}).limit(100),
    db.from('divisions').select('id,name').in('id',readScope).order('display_order')
   ]);
   if(documents.error)throw Error('Unable to load resources: '+documents.error.message);
   if(categories.error)throw Error('Unable to load categories: '+categories.error.message);
   if(divisions.error)throw Error('Unable to load divisions');
   const counts=new Map<string,number>();
   for(const item of documents.data||[])counts.set(item.category,(counts.get(item.category)||0)+1);
   return respond({items:(documents.data||[]).map(d=>({...d,can_manage:adminScope.includes(d.division_id)})),can_manage:adminScope.length>0,can_manage_categories:isSystemAdmin(who),divisions:divisions.data||[],admin_divisions:adminScope,
    categories:(categories.data||[]).map((c:any)=>({...c,file_count:counts.get(c.name)||0}))},origin);
  }
  if(action==='download'){
   if(method!=='GET')return fail('GET required',origin,405);
   const id=uuid(new URL(req.url).searchParams.get('id'));if(!id)throw Error('Document not found');
   const {data:d,error}=await db.from('inspector_documents').select('storage_path,original_name,division_id')
     .in('division_id',scope).eq('id',id).eq('status','active').maybeSingle();
   if(error||!d?.storage_path||!d.storage_path.startsWith(d.division_id+'/'+id+'/'))throw Error('Document not found');
   await assertPrivateBucket(who);
   const {data:signed,error:signError}=await db.storage.from(bucket)
    .createSignedUrl(d.storage_path,60,{download:d.original_name});
   if(signError||!signed?.signedUrl)throw Error('Unable to prepare download');
   return respond({url:signed.signedUrl,expires_in:60},origin);
  }
  if(action==='history'){
   if(method!=='GET')return fail('GET required',origin,405);
   const id=uuid(new URL(req.url).searchParams.get('id'));if(!id)throw Error('Document not found');
   const {data:doc}=await db.from('inspector_documents').select('id').in('division_id',scope).eq('id',id).eq('status','active').maybeSingle();
   if(!doc)throw Error('Document not found');
   const {data:history,error}=await db.from('inspector_resource_history').select('action,version,file_name,created_at')
     .eq('document_id',id).order('created_at',{ascending:false}).limit(50);
   if(error)throw Error('Document history unavailable');
   return respond({items:history||[]},origin);
  }
  if(method!=='POST')return fail('POST required',origin,405);
  const b=await req.json();
  if(action==='category-save'){
   if(!isSystemAdmin(who))throw Error('System administrator access required');
   const operation=trim(b?.operation,20);
   if(!['create','rename','archive','restore'].includes(operation))throw Error('Invalid category operation');
   const id=operation==='create'?null:uuid(b?.id);
   if(operation!=='create'&&!id)throw Error('Category not found');
   const name=operation==='create'||operation==='rename'?trim(b?.name,50):null;
   const {data,error}=await db.rpc('manage_inspector_resource_category',{
    p_actor:who.id,p_action:operation,p_id:id,p_name:name
   });
   if(error)throw Error(error.message);
   return respond({ok:true,category:data},origin);
  }
  if(action==='upload-init'){
   const info=fileProps(b);const replaceId=b?.id?uuid(b.id):null;
   if(b?.id&&!replaceId)throw Error('Invalid document');
   const docId=replaceId||crypto.randomUUID();
   let division:number;
   if(replaceId){
    const {data:old,error}=await db.from('inspector_documents').select('status,division_id').in('division_id',adminScope).eq('id',replaceId).maybeSingle();
    if(error||old?.status!=='active')throw Error('Document not found or not active');
    division=old.division_id;
   }else{
    division=b?.division_id==null&&adminScope.length===1?adminScope[0]:divisionId(b?.division_id);
   }
   if(!adminScope.includes(division))throw Error('Administrator access required for this division');
   const key=division+'/'+docId+'/'+crypto.randomUUID()+'.'+info.ext;
   const title=replaceId?null:trim(b?.title,160),description=replaceId?null:trim(b?.description,1200),category=replaceId?null:await getCategory(b?.category);
   if(!replaceId&&!title)throw Error('Enter a document title');
   await assertPrivateBucket(who,true);
   const {data:upload,error:uploadError}=await db.storage.from(bucket).createSignedUploadUrl(key,{upsert:false});
   if(uploadError||!upload?.token)throw Error('Unable to prepare file upload: '+(uploadError?.message||'Storage unavailable'));
   const {data,error:writeError}=await db.rpc('regional_resource_upload_init',{p_actor:who.id,p_document:docId,p_division:division,p_replace:!!replaceId,p_title:title,p_description:description,p_category:category,p_path:key,p_name:info.name,p_mime:info.mime,p_bytes:info.bytes});
   if(writeError||!data)throw Error('Unable to register file upload: '+(writeError?.message||'Unknown problem'));
   return respond({id:docId,path:key,token:upload.token,upload_url:upload.signedUrl,max_bytes:maxBytes,
     mime_type:info.mime},origin);
  }
  if(action==='upload-complete'){
   const id=uuid(b?.id),path=trim(b?.path,320);
   if(!id||!path)throw Error('Upload information missing');
   await assertPrivateBucket(who);
   const {data,error}=await db.rpc('finalize_inspector_resource',
    {p_document:id,p_actor:who.id,p_path:path});
   if(error)throw Error('Upload incomplete: '+error.message);
   return respond({ok:true,item:{id:data.id,title:data.title,version:data.version}},origin);
  }
  if(action==='edit'||action==='remove'){
   const id=uuid(b?.id);if(!id)throw Error('Document not found');
   const t=trim(b?.title,160);const desc=trim(b?.description,1200);
   if(action==='edit'&&!t)throw Error('Enter a document title');
   const {data,error}=await db.rpc('change_inspector_resource',{
    p_document:id,p_actor:who.id,p_action:action==='edit'?'edited':'deleted',
    p_title:action==='edit'?t:null,p_description:action==='edit'?desc:null,
    p_category:action==='edit'?await getCategory(b?.category):null
   });
   if(error)throw Error('Cannot '+(action==='edit'?'update':'remove')+' document: '+error.message);
   return respond({ok:true,item:{id:data.id,title:data.title}},origin);
  }
  return fail('Unknown resource request',origin,404);
 }catch(e){
  const msg=e instanceof Error?e.message:'Unexpected resources error';
  console.error('resources',msg);
  return fail(msg,origin,/sign.in|session|inspector access|administrator access|active inspector|authenticator|mfa/i.test(msg)?403:400);
 }
});