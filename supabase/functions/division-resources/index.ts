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
async function verifiedMfaRequired(user:any,token:string){
 if(!user?.id)throw Error('Authenticated user could not be verified for MFA.');
 // Auth getUser() does not guarantee the MFA enrollment list is present.
 // Server-side Auth Admin is authoritative; lookup failures must deny access.
 const {data,error}=await db.auth.admin.mfa.listFactors({userId:user.id});
 if(error||!Array.isArray(data?.factors)){
  console.error('Administrator MFA enrollment lookup failed',error?.message||'Unexpected response');
  throw Error('Unable to verify administrator MFA status. Try again.');
 }
 const enrolled=data.factors.some((f:any)=>f?.status==='verified'&&['totp','phone'].includes(f.factor_type));
 if(!enrolled)throw Error('Set up an authenticator in Account security before using the Inspector Desk.');
 try{
  const middle=token.split('.')[1]||'';
  const claims=JSON.parse(atob(middle.replace(/-/g,'+').replace(/_/g,'/')));
  // Supabase getUser(token) already verified this JWT and identified its user.
  if(claims.aal==='aal2'&&claims.sub===user.id)return;
 }catch{}
 throw Error('Complete the authenticator verification in Account security.');
}
async function actor(req:Request,admin=false){
 const token=(req.headers.get('authorization')||'').replace(/^Bearer\s+/i,'');
 if(!token)throw Error('Inspector sign-in required');
 const {data,error}=await db.auth.getUser(token);
 if(error||!data.user?.email)throw Error('Inspector session expired. Sign in again.');
 const {data:staff,error:err}=await db.from('staff_accounts').select('id,role,enabled,removed_at,display_name,email')
  .eq('email',data.user.email.toLowerCase()).eq('enabled',true).is('removed_at',null).maybeSingle();
 if(err||!staff||!['admin','inspector'].includes(staff.role))throw Error('Active inspector access required');
 if(admin&&staff.role!=='admin')throw Error('Administrator access required');
 await verifiedMfaRequired(data.user,token);
 return staff;
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
const publicDocFields='id,title,description,category,original_name,mime_type,bytes,version,created_at,updated_at,published_at';
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
  const who=await actor(req,action!=='list'&&action!=='download'&&action!=='history');
  if(action==='list'){
   if(method!=='GET')return fail('GET required',origin,405);
   const [documents,categories]=await Promise.all([
    db.from('inspector_documents').select(publicDocFields)
     .eq('status','active').order('updated_at',{ascending:false}).limit(1000),
    db.from('inspector_resource_categories').select('id,name,active,updated_at')
     .order('name',{ascending:true}).limit(100)
   ]);
   if(documents.error)throw Error('Unable to load resources: '+documents.error.message);
   if(categories.error)throw Error('Unable to load categories: '+categories.error.message);
   const counts=new Map<string,number>();
   for(const item of documents.data||[])counts.set(item.category,(counts.get(item.category)||0)+1);
   return respond({items:documents.data||[],can_manage:who.role==='admin',
    categories:(categories.data||[]).map((c:any)=>({...c,file_count:counts.get(c.name)||0}))},origin);
  }
  if(action==='download'){
   if(method!=='GET')return fail('GET required',origin,405);
   const id=uuid(new URL(req.url).searchParams.get('id'));if(!id)throw Error('Document not found');
   const {data:d,error}=await db.from('inspector_documents').select('storage_path,original_name')
    .eq('id',id).eq('status','active').maybeSingle();
   if(error||!d?.storage_path)throw Error('Document not found');
   const {data:signed,error:signError}=await db.storage.from(bucket)
    .createSignedUrl(d.storage_path,60,{download:d.original_name});
   if(signError||!signed?.signedUrl)throw Error('Unable to prepare download');
   return respond({url:signed.signedUrl,expires_in:60},origin);
  }
  if(action==='history'){
   if(method!=='GET')return fail('GET required',origin,405);
   const id=uuid(new URL(req.url).searchParams.get('id'));if(!id)throw Error('Document not found');
   const {data:doc}=await db.from('inspector_documents').select('id').eq('id',id).eq('status','active').maybeSingle();
   if(!doc)throw Error('Document not found');
   const {data:history,error}=await db.from('inspector_resource_history').select('action,version,file_name,created_at')
     .eq('document_id',id).order('created_at',{ascending:false}).limit(50);
   if(error)throw Error('Document history unavailable');
   return respond({items:history||[]},origin);
  }
  if(method!=='POST')return fail('POST required',origin,405);
  const b=await req.json();
  if(action==='category-save'){
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
   if(replaceId){
    const {data:old,error}=await db.from('inspector_documents').select('status')
      .eq('id',replaceId).maybeSingle();
    if(error||old?.status!=='active')throw Error('Document not found or not active');
   }
   const key=docId+'/'+crypto.randomUUID()+'.'+info.ext;
   const {data:upload,error:uploadError}=await db.storage.from(bucket).createSignedUploadUrl(key);
   if(uploadError||!upload?.token)throw Error('Unable to prepare file upload: '+(uploadError?.message||'Storage unavailable'));
   let data,writeError;
   if(replaceId){
    ({data,error:writeError}=await db.from('inspector_documents')
     .update({pending_path:key,pending_original_name:info.name,pending_mime_type:info.mime,
       pending_bytes:info.bytes,pending_by:who.id,pending_at:new Date().toISOString()})
     .eq('id',docId).eq('status','active').select('id').single());
   }else{
    const title=trim(b?.title,160);
    if(!title)throw Error('Enter a document title');
    const description=trim(b?.description,1200),category=await getCategory(b?.category);
    ({data,error:writeError}=await db.from('inspector_documents').insert({
     id:docId,title,description,category,original_name:info.name,uploaded_by:who.id,
     pending_path:key,pending_original_name:info.name,pending_mime_type:info.mime,
     pending_bytes:info.bytes,pending_by:who.id,pending_at:new Date().toISOString()
    }).select('id').single());
   }
   if(writeError||!data)throw Error('Unable to register file upload: '+(writeError?.message||'Unknown problem'));
   return respond({id:docId,path:key,token:upload.token,upload_url:upload.signedUrl,max_bytes:maxBytes,
     mime_type:info.mime},origin);
  }
  if(action==='upload-complete'){
   const id=uuid(b?.id),path=trim(b?.path,320);
   if(!id||!path)throw Error('Upload information missing');
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