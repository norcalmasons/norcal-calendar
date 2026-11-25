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
