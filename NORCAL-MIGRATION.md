# NorCal migration preparation — 2026-11-25

Source: Division IV Calendar (read-only). Target: NorCal Masons Dev (initially empty). This branch does not deploy anything.

## Captured backend
- 35 historical SQL migrations, in reference-only paths, with the private staff seed removed.
- Eight existing function directories verified against deployed source; two missing application functions recovered (site settings and resources). Site settings' original Google Calendar fallback ID is replaced with an empty value.
- Two legacy staging function sources captured separately; do not deploy.
- 26 application tables, 1 view, 20 public-schema SQL functions; 1 private resource bucket (15 objects at inventory); 3 scheduled jobs (calendar, email, newsletter).

## Isolation gates
- The copied CNAME is removed and legacy CI workflow is disabled by removing it from .github/workflows. The workflow is preserved as a reference file.
- Keep GitHub Pages and Actions disabled in repository settings. Copied site, tests and functions still contain Division IV URLs and references. **Do not run the site or tests against live endpoints.** Reconfigure and test before deployment.
- Do not copy production auth sessions, staff details, subscriber lists, file objects, provider IDs or credentials into the public repository or development database.
- No schedules, mail, calendar writes, or real recipients in development. Use fresh secrets and isolated test resources. Do not copy operational queues.

## Next steps
1. Review historical statements and compare to current live catalog (including constraints, grants, triggers, indexes and functions). Live changes may not be recorded in migration history. Restore a reviewed baseline in NorCal Dev, compare catalog, then seed public directory/reference data and synthetic test records.
2. Keep direct data API access restricted; verify RLS on all app tables and restrict service-role operations. Revoke unnecessary legacy grants on poc_positions; audit all RPC access.
3. Implement three roles: system admin globally; division admin (AGL) within division; inspector event access across assigned division. All inspectors and division admins receive division event notifications; district is not an authorization or routing boundary.
4. Add division scope, six calendar destinations, email delivery and division subscriber preferences. Rework public homepage into five compact division rows with manual scroll for events and stated meetings.
5. Isolated functional/security tests before production migration; actual staff/subscribers/documents and complete historical records migrate securely at cutover.

This is preparation, not a verified backup, restored database, or production-ready release.

## Development restoration

A schema-only baseline has been applied to NorCal Dev and recorded under `supabase/migrations/`. A second migration explicitly aligns all 18 UUID defaults to the PostgreSQL built-in generator. Historical migrations remain reference-only. No source rows, storage objects, auth users, secrets, cron or network extensions were copied. The legacy direct anon/authenticated grants were revoked. Platform-provided functions and catalog-managed metadata are not recreated. Table/column comments and storage configuration require a separate check.

## Verified catalog comparison (2026-11-25)

Source and target each have 557 compared objects: 320 columns (including the view), 123 constraints, 63 indexes, 19 application functions, 5 triggers, 1 view and 26 RLS states. After aligning 18 UUID defaults, 555 definitions match exactly. The two remaining check constraints (`inspector_resource_category_name_check` and `poc_positions_title_valid`) differ only in redundant AND-expression grouping, with equivalent conditions. No objects are missing or extra in these categories. Catalog comments, platform metadata, and full runtime behavior were not compared.

Target contains zero events, staff accounts, authentication users, subscribers, calendar jobs, email jobs or buckets. No pg_cron or pg_net extension installed; no deployed application functions. No direct public/anon/authenticated table or routine grants. Security advisor reports only 26 informational RLS-without-policies findings, expected under the current deny-by-default service-role gateway. This is not yet a multi-division authorization audit.

Next: seed safe reference data, reconfigure frontend and Edge Functions for Dev, create isolated test accounts and verify functional behavior; keep all delivery and publication disabled.
