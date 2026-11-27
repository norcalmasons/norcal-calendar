# Division IV historical migrations (reference only)

Captured from live Division IV migration history on 2026-11-25. **Not a tested or deployable NorCal migration set.** The foundational migration's private staff seed statement was removed. No live records, documents, authentication credentials or secret values are included. Historical scripts may contain obsolete permissions, dependencies or data transformations; review against the live catalog before restoring in development. Do not execute unchanged or move into the automatic migrations directory.

| Version | Name | Capture note |
|---|---|---|
| 20261019050334 | division_iv_core_secure_schema | Production staff seed removed |
| 20261019050409 | restrict_rls_auto_enable_execution | Source statements preserved |
| 20261019051328 | atomic_approval_and_queue | Source statements preserved |
| 20261019052237 | request_search_view | Source statements preserved |
| 20261019053011 | preserve_event_optional_fields | Source statements preserved |
| 20261019215819 | enable_calendar_sync_scheduler_extensions | Source statements preserved |
| 20261019221740 | archive_superseded_division_iv_test_email_notifications | Source statements preserved |
| 20261020224535 | structured_event_locations_and_district_options | Source statements preserved |
| 20261020232546 | inspector_request_edit_revisions_and_atomic_audit | Source statements preserved |
| 20261020232627 | atomic_inspector_review_version_check | Source statements preserved |
| 20261020233142 | preserve_optional_attire_and_audience_on_approvals | Source statements preserved |
| 20261020233515 | request_index_displays_inspector_approved_revision_fields | Source statements preserved |
| 20261021002453 | inspector_direct_published_event_edits_with_audit_and_sync | Source statements preserved |
| 20261021043736 | archive_inspector_access_without_deleting_history | Source statements preserved |
| 20261021182753 | inspector_retry_undo_and_dashboard_service_rpc | Source statements preserved |
| 20261021183222 | make_undo_append_only_audit_compliant | Source statements preserved |
| 20261022043125 | add_event_point_of_contact_fields | Source statements preserved |
| 20261022043213 | persist_separate_event_poc_during_approval_and_inspector_edits | Source statements preserved |
| 20261022232116 | event_poc_email_and_public_cost | Source statements preserved |
| 20261022232138 | persist_event_poc_email_and_cost_in_approval_and_edits | Source statements preserved |
| 20261023224428 | lodges_full_public_directory_and_private_inspector_metadata | Source statements preserved |
| 20261023224534 | guarded_inspector_lodge_updates_with_audit_and_optimistic_lock | Source statements preserved |
| 20261024001405 | canonical_district_links_and_history_service_access | Source statements preserved |
| 20261024001919 | inspector_quick_access_toggle_with_atomic_audit | Source statements preserved |
| 20261027030040 | private_lodge_correction_request_queue | Source statements preserved |
| 20261027030112 | secure_lodge_correction_queue_and_status_history | Source statements preserved |
| 20261029155233 | event_poc_positions_and_dynamic_titles | Source statements preserved |
| 20261029155259 | poc_positions_preferred_order | Source statements preserved |
| 20261029162452 | admin_only_lodge_abbreviation_20_chars | Source statements preserved |
| 20261029194434 | division_iv_bulk_new_events_submission_audit_and_dedupe | Source statements preserved |
| 20261031182839 | standardize_division_and_district_soi_titles | Source statements preserved |
| 20261031211618 | division_iv_newsletter_opt_in_flags_and_runs | Source statements preserved |
| 20261031211716 | division_iv_newsletter_signup_rate_limits | Source statements preserved |
| 20261031213856 | newsletter_service_role_access_and_separate_schedules | Source statements preserved |
| 20261031213935 | newsletter_monthly_weekly_separately_paused | Source statements preserved |
