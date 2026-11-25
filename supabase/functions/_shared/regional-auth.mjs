// Central NorCal authorization — transitional gate for unscoped legacy handlers.
// Only Auth getUser-validated tokens are decoded for assurance level checks.
export function roleScope(staff) {
 if (!staff || staff.enabled !== true || staff.removed_at !== null) return null;
 if (staff.regional_role === 'system_admin' && staff.role === 'admin' && staff.division_id === null) return { role:'system_admin', divisionId:null };
 if (!Number.isInteger(staff.division_id) || staff.division_id <= 0) return null;
 if (staff.regional_role === 'division_admin' && staff.role === 'admin') return {role:'division_admin',divisionId:staff.division_id};
 if (staff.regional_role === 'inspector' && staff.role === 'inspector') return {role:'inspector',divisionId:staff.division_id};
 return null;
}

export function canAccessDivision(scope, divisionId) {
 return !!scope && Number.isInteger(divisionId) && divisionId > 0 && (scope.role === 'system_admin' || scope.divisionId === divisionId);
}

export function legacyAllowed(staff) {
 return roleScope(staff)?.role === 'system_admin';
}

export function verifiedClaims(claims, userId) {
 return !!userId && claims?.sub === userId && claims?.aal === 'aal2';
}

export function jwtClaims(token) {
 try {
   const parts=token.split('.');
   if(parts.length!==3)return null;
   const s=parts[1].replace(/-/g,'+').replace(/_/g,'/');
   return JSON.parse(atob(s.padEnd(Math.ceil(s.length/4)*4,'=')));
 } catch { return null; }
}

export async function lookupIdentity(db, req, { regional = false } = {}) {
 const token=(req.headers.get('authorization')||'').match(/^Bearer\s+(\S+)$/i)?.[1]||'';
 const empty={email:'',user:null,staff:null,token:''};
 if(!token)return empty;
 const {data,error}=await db.auth.getUser(token);
 const user=data?.user;
 if(error||!user?.id||!user?.email||!user.email_confirmed_at)return empty;
 const email=user.email.trim().toLowerCase();
 const {data:staff,error:lookup}=await db.from('staff_accounts').select('id,email,display_name,role,enabled,removed_at,phone,district,regional_role,division_id').eq('email',email).eq('enabled',true).is('removed_at',null).maybeSingle();
 if(lookup)throw Error('Unable to verify staff authorization. Try again.');
 // During migration, only system admins can access unscoped legacy handlers.
 return {email,user,staff:(regional ? !!roleScope(staff) : legacyAllowed(staff))?staff:null,token};
}

export async function staffMfaState(db,user,token) {
 if(!user?.id)throw Error('Authenticated user could not be verified for MFA.');
 const {data,error}=await db.auth.admin.mfa.listFactors({userId:user.id});
 if(error||!Array.isArray(data?.factors))throw Error('Unable to verify staff MFA status. Try again.');
 const factor=data.factors.find(f=>f?.status==='verified'&&['totp','phone'].includes(f.factor_type));
 if(!factor)return {required:true,verified:false,needsEnrollment:true};
 const factorId=String(factor.id||'');
 return {required:true,verified:verifiedClaims(jwtClaims(token),user.id),factorId};
}

export async function requireMfa(db,user,token) {
 const state=await staffMfaState(db,user,token);
 if(!state.verified)throw Error(state.needsEnrollment?'Set up an authenticator in Account security before using the Inspector Desk.':'Complete authenticator verification in Account security before accessing the Inspector Desk.');
}

export async function requireLegacyStaff(db,req) {
 const a=await lookupIdentity(db,req);
 if(!a.staff)throw Error('System administrator access required during regional migration.');
 await requireMfa(db,a.user,a.token);
 return a.staff;
}

 // Use only in handlers whose reads and writes have been division-scoped.
 export async function requireRegionalAdmin(db,req) {
  const a=await lookupIdentity(db,req,{regional:true});
  const scope=roleScope(a.staff);
  if(!scope||!['system_admin','division_admin'].includes(scope.role))throw Error('Administrator access required');
  await requireMfa(db,a.user,a.token);
  if(scope.divisionId!==null){
   const {data,error}=await db.from('divisions').select('id,onboarded').eq('id',scope.divisionId).eq('onboarded',true).maybeSingle();
   if(error||!data)throw Error('Administrator division is not available');
  }
  return {...a.staff,scope};
 }
 export function scopeQuery(query,scope) {
  if(scope?.role==='system_admin'&&scope.divisionId===null)return query;
  if(!['division_admin','inspector'].includes(scope?.role)||!Number.isInteger(scope.divisionId)||scope.divisionId<=0)throw Error('Administrator division is required');
  return query.eq('division_id',scope.divisionId);
 }
