# Regional authorization migration

## Stage 1 — ownership foundation (NorCal Dev only)
Five division records; migrated test records belong to Division IV. Only IV is currently onboarded; all owned tables and staff assignments have temporary IV-only database gates. Existing legacy roles still drive the deployed application. The new regional role metadata is not an active authorization system. Existing enabled organizational administrator maps to system_admin; disabled legacy admins map to division_admin; disabled legacy inspectors map to inspector. Newly created legacy staff have no regional role until explicitly assigned.

## Required before lifting gates
- Central server-side authorization using verified Auth identity, enabled staff record, MFA AAL2, explicit regional role and division membership; no reliance on client-supplied scope or user metadata.
- System admin: all divisions; division admin: own division management; inspector: own division event approval/edit/cancel, bulk import and authorized document access. District is directory metadata, not an authorization boundary.
- Scope every read and mutation, including request approval RPCs, histories, corrections, staff management, bulk import and storage paths. Derive ownership of linked rows on server, reject mismatches. Public approved events can be read across onboarded divisions. Preserve independent lodge scheduling/verification terminology.
- Ensure no legacy unrestricted service-role handlers remain deployed before lifting IV-only checks. Remove implicit IV defaults from scoped writes once explicit ownership is implemented.
- Test cross-division read/write denials, AAL1 denial, disabled staff denial, system admin access and public approval filtering before onboarding new divisions.
- Review one unmatched event district string; do not silently correct. Queue/history rows use parent ownership; orphan or global rows need explicit treatment. Newsletter subscription selections, consolidated digests, division calendar mapping and AWS SES are separate later migrations. All outbound integrations remain disabled.
- Cutover: update auth site/redirect URLs and both hosted email templates' logo URL to production, PWA configuration and public safeguards only after approval. Division IV production untouched; redirect is separate decision.

## Stage 2A — centralized authentication and transitional lock
All seven privileged handlers import `supabase/functions/_shared/regional-auth.mjs`. The shared code validates the bearer with Supabase Auth, confirmed email, current enabled/nonremoved staff record, explicit matching regional role, and verified MFA factor + AAL2/sub claims. Unscoped legacy routes intentionally accept only system administrators. Other roles cannot be granted working access until their queries and mutations are scoped. Existing public config and original-submitter identity paths remain separate. No migration gates have been lifted. Unit policy and mocked identity tests are included in `tests/regional-auth-smoke.mjs`. Live browser/auth verification is required after deployment; no cross-division endpoint testing is possible with the IV-only gates in place.
