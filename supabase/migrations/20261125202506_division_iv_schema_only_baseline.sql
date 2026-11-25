-- NorCal development schema baseline, reconstructed from the live Division IV catalog.
-- Schema only; no production rows, cron jobs, storage objects, or credentials.
-- The platform-provided rls_auto_enable function remains managed by Supabase.
SET LOCAL search_path = public, extensions, pg_catalog;

CREATE TABLE public.bulk_event_imports (id uuid DEFAULT gen_random_uuid() NOT NULL,
  batch_key text NOT NULL,
  filename text NOT NULL,
  importer_staff_id uuid NOT NULL,
  importer_email text NOT NULL,
  status text DEFAULT 'processing'::text NOT NULL,
  source_count integer DEFAULT 0 NOT NULL,
  submitted_count integer DEFAULT 0 NOT NULL,
  skipped_count integer DEFAULT 0 NOT NULL,
  error_count integer DEFAULT 0 NOT NULL,
  results jsonb DEFAULT '[]'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  completed_at timestamp with time zone);

CREATE TABLE public.calendar_jobs (id uuid DEFAULT gen_random_uuid() NOT NULL,
  event_id uuid NOT NULL,
  request_id uuid,
  action text NOT NULL,
  event_version integer NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  attempts integer DEFAULT 0 NOT NULL,
  last_error text,
  google_event_id text,
  idempotency_key text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  finished_at timestamp with time zone);

CREATE TABLE public.districts (district_code text NOT NULL,
  district_name text NOT NULL,
  active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.division_correction_history (id uuid DEFAULT gen_random_uuid() NOT NULL,
  correction_id uuid NOT NULL,
  action text NOT NULL,
  previous_status text,
  new_status text,
  notes text,
  actor_staff_id uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.division_correction_requests (id uuid DEFAULT gen_random_uuid() NOT NULL,
  lodge_name text NOT NULL,
  category text NOT NULL,
  details text NOT NULL,
  reporter_contact text,
  status text DEFAULT 'pending'::text NOT NULL,
  review_notes text,
  handled_by uuid,
  reviewed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  source_fingerprint text);

CREATE TABLE public.email_deliveries (id uuid DEFAULT gen_random_uuid() NOT NULL,
  event_id uuid,
  request_id uuid,
  message_type text NOT NULL,
  recipient_email text NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  attempts integer DEFAULT 0 NOT NULL,
  provider_message_id text,
  last_error text,
  idempotency_key text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  sent_at timestamp with time zone);

CREATE TABLE public.event_attachments (id uuid DEFAULT gen_random_uuid() NOT NULL,
  event_id uuid,
  request_id uuid,
  storage_path text NOT NULL,
  filename text NOT NULL,
  mime_type text,
  size_bytes bigint,
  public_after_approval boolean DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.event_history (id uuid DEFAULT gen_random_uuid() NOT NULL,
  event_id uuid,
  request_id uuid,
  action text NOT NULL,
  actor_staff_id uuid,
  actor_email text,
  before_data jsonb,
  after_data jsonb,
  notes text,
  occurred_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.event_requests (id uuid DEFAULT gen_random_uuid() NOT NULL,
  request_code text NOT NULL,
  event_id uuid,
  request_type text NOT NULL,
  base_event_version integer,
  proposed_fields jsonb DEFAULT '{}'::jsonb NOT NULL,
  requester_name text NOT NULL,
  requester_email text NOT NULL,
  requester_phone text,
  requester_message text,
  status text DEFAULT 'pending'::text NOT NULL,
  reviewer_id uuid,
  reviewer_public_message text,
  reviewer_private_notes text,
  reviewed_at timestamp with time zone,
  approved_event_id uuid,
  submission_source text DEFAULT 'web'::text NOT NULL,
  idempotency_key text,
  submitted_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  inspector_edits jsonb,
  edit_version integer DEFAULT 0 NOT NULL,
  edited_by uuid,
  edited_at timestamp with time zone);

CREATE TABLE public.event_types (id integer GENERATED ALWAYS AS IDENTITY NOT NULL,
  label text NOT NULL,
  sort_order integer NOT NULL,
  enabled boolean DEFAULT true NOT NULL);

CREATE TABLE public.events (id uuid DEFAULT gen_random_uuid() NOT NULL,
  event_code text NOT NULL,
  title text NOT NULL,
  event_type text NOT NULL,
  hosted_by text,
  lodge_id uuid,
  district text,
  starts_at timestamp with time zone NOT NULL,
  ends_at timestamp with time zone NOT NULL,
  timezone text DEFAULT 'America/Los_Angeles'::text NOT NULL,
  event_mode text DEFAULT 'in_person'::text NOT NULL,
  location_name text,
  location_address text,
  location_tbd boolean DEFAULT false NOT NULL,
  virtual_meeting_url text,
  public_description text,
  attire text,
  invited_audience text,
  meal_cost numeric(10,2),
  registration_url text,
  payment_url text,
  flyer_url text,
  hotel_details jsonb DEFAULT '{}'::jsonb NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  version integer DEFAULT 1 NOT NULL,
  google_event_id text,
  calendar_last_synced_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  location_address1 text,
  location_address2 text,
  location_city text,
  location_state text,
  location_zip text,
  poc_name text,
  poc_phone text,
  poc_email text,
  cost_details text,
  poc_position text,
  event_name text,
  calendar_title_override text);

CREATE TABLE public.inspector_admin_history (id uuid DEFAULT gen_random_uuid() NOT NULL,
  actor_staff_id uuid NOT NULL,
  target_staff_id uuid NOT NULL,
  action text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.inspector_documents (id uuid DEFAULT gen_random_uuid() NOT NULL,
  title text NOT NULL,
  description text DEFAULT ''::text NOT NULL,
  category text NOT NULL,
  original_name text NOT NULL,
  storage_path text,
  mime_type text DEFAULT ''::text NOT NULL,
  bytes bigint DEFAULT 0 NOT NULL,
  version integer DEFAULT 0 NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  uploaded_by uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  published_at timestamp with time zone,
  deleted_at timestamp with time zone,
  pending_path text,
  pending_original_name text,
  pending_mime_type text,
  pending_bytes bigint,
  pending_by uuid,
  pending_at timestamp with time zone);

CREATE TABLE public.inspector_resource_categories (id uuid DEFAULT gen_random_uuid() NOT NULL,
  name text NOT NULL,
  active boolean DEFAULT true NOT NULL,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.inspector_resource_history (id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  document_id uuid NOT NULL,
  actor_id uuid NOT NULL,
  action text NOT NULL,
  version integer NOT NULL,
  file_path text,
  file_name text,
  details jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.lodge_change_history (id uuid DEFAULT gen_random_uuid() NOT NULL,
  lodge_id uuid NOT NULL,
  actor_staff_id uuid NOT NULL,
  previous_version integer NOT NULL,
  new_version integer NOT NULL,
  before_data jsonb NOT NULL,
  after_data jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.lodges (id uuid DEFAULT gen_random_uuid() NOT NULL,
  lodge_name text NOT NULL,
  lodge_number text,
  district text,
  active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  address_line1 text,
  city text,
  county text,
  state text DEFAULT 'CA'::text NOT NULL,
  meeting_day text,
  meeting_time text,
  meeting_notes text,
  official_url text,
  record_version integer DEFAULT 1 NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_by uuid,
  abbreviation character varying(20));

CREATE TABLE public.newsletter_event_flags (event_id uuid NOT NULL,
  event_version integer NOT NULL,
  change_kind text NOT NULL,
  dirty boolean DEFAULT true NOT NULL,
  changed_at timestamp with time zone DEFAULT now() NOT NULL,
  announced_at timestamp with time zone);

CREATE TABLE public.newsletter_runs (id uuid DEFAULT gen_random_uuid() NOT NULL,
  issue_key text NOT NULL,
  kind text NOT NULL,
  state text DEFAULT 'prepared'::text NOT NULL,
  content_summary jsonb DEFAULT '{}'::jsonb NOT NULL,
  event_versions jsonb DEFAULT '[]'::jsonb NOT NULL,
  provider_broadcast_id text,
  error_message text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  sent_at timestamp with time zone,
  created_by uuid);

CREATE TABLE public.newsletter_settings (id boolean DEFAULT true NOT NULL,
  sending_enabled boolean DEFAULT false NOT NULL,
  signup_enabled boolean DEFAULT false NOT NULL,
  free_plan_confirmed boolean DEFAULT false NOT NULL,
  resend_segment_id uuid,
  sender_address text,
  monthly_day smallint DEFAULT 1 NOT NULL,
  weekly_day smallint DEFAULT 1 NOT NULL,
  send_hour smallint DEFAULT 8 NOT NULL,
  lookahead_days smallint DEFAULT 60 NOT NULL,
  contact_cap smallint DEFAULT 900 NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_by uuid,
  monthly_enabled boolean DEFAULT false NOT NULL,
  weekly_enabled boolean DEFAULT false NOT NULL,
  monthly_send_hour smallint DEFAULT 8 NOT NULL,
  weekly_send_hour smallint DEFAULT 8 NOT NULL);

CREATE TABLE public.newsletter_signup_limits (key_hash text NOT NULL,
  bucket timestamp with time zone NOT NULL,
  attempts smallint DEFAULT 1 NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.newsletter_subscribers (id uuid DEFAULT gen_random_uuid() NOT NULL,
  email text NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  token_hash text,
  token_expires_at timestamp with time zone,
  requested_at timestamp with time zone DEFAULT now() NOT NULL,
  confirmed_at timestamp with time zone,
  unsubscribed_at timestamp with time zone,
  last_confirmation_sent_at timestamp with time zone,
  provider_contact_id text,
  provider_synced_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.poc_positions (title text NOT NULL,
  active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  sort_order integer);

CREATE TABLE public.staff_accounts (id uuid DEFAULT gen_random_uuid() NOT NULL,
  email text NOT NULL,
  display_name text,
  phone text,
  role text NOT NULL,
  enabled boolean DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  removed_at timestamp with time zone,
  removed_by uuid,
  district text,
  member_number text,
  first_name text,
  middle_name text,
  last_name text,
  office_title text,
  home_phone text,
  mobile_phone text,
  home_address text,
  home_address2 text,
  city text,
  state text,
  zip text);

CREATE TABLE public.submission_verifications (id uuid DEFAULT gen_random_uuid() NOT NULL,
  event_id uuid NOT NULL,
  email text NOT NULL,
  token_hash text NOT NULL,
  purpose text NOT NULL,
  expires_at timestamp with time zone NOT NULL,
  verified_at timestamp with time zone,
  consumed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public.system_settings (setting_key text NOT NULL,
  setting_value jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_by uuid);

ALTER TABLE public."bulk_event_imports" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."calendar_jobs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."districts" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."division_correction_history" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."division_correction_requests" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."email_deliveries" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."event_attachments" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."event_history" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."event_requests" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."event_types" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."events" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."inspector_admin_history" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."inspector_documents" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."inspector_resource_categories" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."inspector_resource_history" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."lodge_change_history" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."lodges" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."newsletter_event_flags" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."newsletter_runs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."newsletter_settings" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."newsletter_signup_limits" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."newsletter_subscribers" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."poc_positions" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."staff_accounts" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."submission_verifications" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public."system_settings" ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bulk_event_imports ADD CONSTRAINT bulk_event_imports_batch_key_key UNIQUE (batch_key);

ALTER TABLE public.bulk_event_imports ADD CONSTRAINT bulk_event_imports_pkey PRIMARY KEY (id);

ALTER TABLE public.bulk_event_imports ADD CONSTRAINT bulk_event_imports_source_count_check CHECK (((source_count >= 0) AND (source_count <= 25)));

ALTER TABLE public.bulk_event_imports ADD CONSTRAINT bulk_event_imports_status_check CHECK ((status = ANY (ARRAY['processing'::text, 'completed'::text])));

ALTER TABLE public.calendar_jobs ADD CONSTRAINT calendar_jobs_action_check CHECK ((action = ANY (ARRAY['upsert'::text, 'cancel'::text])));

ALTER TABLE public.calendar_jobs ADD CONSTRAINT calendar_jobs_idempotency_key_key UNIQUE (idempotency_key);

ALTER TABLE public.calendar_jobs ADD CONSTRAINT calendar_jobs_pkey PRIMARY KEY (id);

ALTER TABLE public.calendar_jobs ADD CONSTRAINT calendar_jobs_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'running'::text, 'succeeded'::text, 'failed'::text])));

ALTER TABLE public.districts ADD CONSTRAINT districts_pkey PRIMARY KEY (district_code);

ALTER TABLE public.division_correction_history ADD CONSTRAINT division_correction_history_pkey PRIMARY KEY (id);

ALTER TABLE public.division_correction_requests ADD CONSTRAINT correction_queue_category_allowed CHECK ((category = ANY (ARRAY['meeting'::text, 'location'::text, 'directory'::text, 'other'::text])));

ALTER TABLE public.division_correction_requests ADD CONSTRAINT correction_queue_details_length CHECK (((char_length(details) >= 15) AND (char_length(details) <= 1600)));

ALTER TABLE public.division_correction_requests ADD CONSTRAINT correction_queue_lodge_length CHECK (((char_length(lodge_name) >= 2) AND (char_length(lodge_name) <= 160)));

ALTER TABLE public.division_correction_requests ADD CONSTRAINT correction_queue_status_allowed CHECK ((status = ANY (ARRAY['pending'::text, 'reviewing'::text, 'completed'::text, 'rejected'::text])));

ALTER TABLE public.division_correction_requests ADD CONSTRAINT division_correction_requests_pkey PRIMARY KEY (id);

ALTER TABLE public.email_deliveries ADD CONSTRAINT email_deliveries_idempotency_key_key UNIQUE (idempotency_key);

ALTER TABLE public.email_deliveries ADD CONSTRAINT email_deliveries_pkey PRIMARY KEY (id);

ALTER TABLE public.email_deliveries ADD CONSTRAINT email_deliveries_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'sending'::text, 'sent'::text, 'failed'::text, 'skipped'::text])));

ALTER TABLE public.event_attachments ADD CONSTRAINT associated_attachment CHECK (((event_id IS NOT NULL) OR (request_id IS NOT NULL)));

ALTER TABLE public.event_attachments ADD CONSTRAINT event_attachments_pkey PRIMARY KEY (id);

ALTER TABLE public.event_attachments ADD CONSTRAINT event_attachments_storage_path_key UNIQUE (storage_path);

ALTER TABLE public.event_history ADD CONSTRAINT event_history_pkey PRIMARY KEY (id);

ALTER TABLE public.event_requests ADD CONSTRAINT event_link_for_modification CHECK ((((request_type = 'new'::text) AND (event_id IS NULL)) OR ((request_type = ANY (ARRAY['change'::text, 'cancel'::text])) AND (event_id IS NOT NULL))));

ALTER TABLE public.event_requests ADD CONSTRAINT event_requests_idempotency_key_key UNIQUE (idempotency_key);

ALTER TABLE public.event_requests ADD CONSTRAINT event_requests_pkey PRIMARY KEY (id);

ALTER TABLE public.event_requests ADD CONSTRAINT event_requests_request_code_key UNIQUE (request_code);

ALTER TABLE public.event_requests ADD CONSTRAINT event_requests_request_type_check CHECK ((request_type = ANY (ARRAY['new'::text, 'change'::text, 'cancel'::text])));

ALTER TABLE public.event_requests ADD CONSTRAINT event_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'needs_correction'::text, 'approved'::text, 'rejected'::text])));

ALTER TABLE public.event_requests ADD CONSTRAINT normalized_requester_email CHECK ((requester_email = lower(btrim(requester_email))));

ALTER TABLE public.event_types ADD CONSTRAINT event_types_label_key UNIQUE (label);

ALTER TABLE public.event_types ADD CONSTRAINT event_types_pkey PRIMARY KEY (id);

ALTER TABLE public.event_types ADD CONSTRAINT event_types_sort_order_key UNIQUE (sort_order);

ALTER TABLE public.events ADD CONSTRAINT dates_in_order CHECK ((ends_at > starts_at));

ALTER TABLE public.events ADD CONSTRAINT events_event_code_key UNIQUE (event_code);

ALTER TABLE public.events ADD CONSTRAINT events_event_mode_check CHECK ((event_mode = ANY (ARRAY['in_person'::text, 'hybrid'::text, 'online'::text])));

ALTER TABLE public.events ADD CONSTRAINT events_pkey PRIMARY KEY (id);

ALTER TABLE public.events ADD CONSTRAINT events_poc_position_length_check CHECK (((poc_position IS NULL) OR (char_length(poc_position) <= 120)));

ALTER TABLE public.events ADD CONSTRAINT events_status_check CHECK ((status = ANY (ARRAY['active'::text, 'cancelled'::text])));

ALTER TABLE public.events ADD CONSTRAINT events_version_check CHECK ((version > 0));

ALTER TABLE public.events ADD CONSTRAINT nonnegative_meal_cost CHECK (((meal_cost IS NULL) OR (meal_cost >= (0)::numeric)));

ALTER TABLE public.inspector_admin_history ADD CONSTRAINT inspector_admin_history_action_check CHECK ((action = ANY (ARRAY['removed'::text, 'restored'::text, 'activated'::text, 'deactivated'::text])));

ALTER TABLE public.inspector_admin_history ADD CONSTRAINT inspector_admin_history_pkey PRIMARY KEY (id);

ALTER TABLE public.inspector_documents ADD CONSTRAINT inspector_documents_bytes_check CHECK ((bytes >= 0));

ALTER TABLE public.inspector_documents ADD CONSTRAINT inspector_documents_description_check CHECK ((length(description) <= 1200));

ALTER TABLE public.inspector_documents ADD CONSTRAINT inspector_documents_original_name_check CHECK (((length(original_name) >= 1) AND (length(original_name) <= 240)));

ALTER TABLE public.inspector_documents ADD CONSTRAINT inspector_documents_pkey PRIMARY KEY (id);

ALTER TABLE public.inspector_documents ADD CONSTRAINT inspector_documents_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'deleted'::text])));

ALTER TABLE public.inspector_documents ADD CONSTRAINT inspector_documents_title_check CHECK (((length(title) >= 1) AND (length(title) <= 160)));

ALTER TABLE public.inspector_documents ADD CONSTRAINT inspector_documents_version_check CHECK ((version >= 0));

ALTER TABLE public.inspector_resource_categories ADD CONSTRAINT inspector_resource_categories_name_key UNIQUE (name);

ALTER TABLE public.inspector_resource_categories ADD CONSTRAINT inspector_resource_categories_pkey PRIMARY KEY (id);

ALTER TABLE public.inspector_resource_categories ADD CONSTRAINT inspector_resource_category_name_check CHECK ((((length(name) >= 2) AND (length(name) <= 50)) AND (name ~ '^[A-Za-z0-9][A-Za-z0-9 _&/().-]*$'::text) AND (name = btrim(name))));

ALTER TABLE public.inspector_resource_history ADD CONSTRAINT inspector_resource_history_action_check CHECK ((action = ANY (ARRAY['uploaded'::text, 'replaced'::text, 'edited'::text, 'deleted'::text])));

ALTER TABLE public.inspector_resource_history ADD CONSTRAINT inspector_resource_history_pkey PRIMARY KEY (id);

ALTER TABLE public.lodge_change_history ADD CONSTRAINT lodge_change_history_pkey PRIMARY KEY (id);

ALTER TABLE public.lodges ADD CONSTRAINT lodges_pkey PRIMARY KEY (id);

ALTER TABLE public.newsletter_event_flags ADD CONSTRAINT newsletter_event_flags_change_kind_check CHECK ((change_kind = ANY (ARRAY['new'::text, 'updated'::text, 'cancelled'::text])));

ALTER TABLE public.newsletter_event_flags ADD CONSTRAINT newsletter_event_flags_pkey PRIMARY KEY (event_id);

ALTER TABLE public.newsletter_runs ADD CONSTRAINT newsletter_runs_issue_key_key UNIQUE (issue_key);

ALTER TABLE public.newsletter_runs ADD CONSTRAINT newsletter_runs_kind_check CHECK ((kind = ANY (ARRAY['monthly'::text, 'weekly'::text, 'manual'::text])));

ALTER TABLE public.newsletter_runs ADD CONSTRAINT newsletter_runs_pkey PRIMARY KEY (id);

ALTER TABLE public.newsletter_runs ADD CONSTRAINT newsletter_runs_provider_broadcast_id_key UNIQUE (provider_broadcast_id);

ALTER TABLE public.newsletter_runs ADD CONSTRAINT newsletter_runs_state_check CHECK ((state = ANY (ARRAY['prepared'::text, 'sending'::text, 'submitted'::text, 'skipped'::text, 'needs_review'::text, 'failed'::text])));

ALTER TABLE public.newsletter_settings ADD CONSTRAINT newsletter_settings_contact_cap_check CHECK (((contact_cap >= 1) AND (contact_cap <= 1000)));

ALTER TABLE public.newsletter_settings ADD CONSTRAINT newsletter_settings_id_check CHECK (id);

ALTER TABLE public.newsletter_settings ADD CONSTRAINT newsletter_settings_lookahead_days_check CHECK (((lookahead_days >= 7) AND (lookahead_days <= 120)));

ALTER TABLE public.newsletter_settings ADD CONSTRAINT newsletter_settings_monthly_day_check CHECK (((monthly_day >= 1) AND (monthly_day <= 28)));

ALTER TABLE public.newsletter_settings ADD CONSTRAINT newsletter_settings_monthly_send_hour_check CHECK (((monthly_send_hour >= 0) AND (monthly_send_hour <= 23)));

ALTER TABLE public.newsletter_settings ADD CONSTRAINT newsletter_settings_pkey PRIMARY KEY (id);

ALTER TABLE public.newsletter_settings ADD CONSTRAINT newsletter_settings_send_hour_check CHECK (((send_hour >= 0) AND (send_hour <= 23)));

ALTER TABLE public.newsletter_settings ADD CONSTRAINT newsletter_settings_weekly_day_check CHECK (((weekly_day >= 0) AND (weekly_day <= 6)));

ALTER TABLE public.newsletter_settings ADD CONSTRAINT newsletter_settings_weekly_send_hour_check CHECK (((weekly_send_hour >= 0) AND (weekly_send_hour <= 23)));

ALTER TABLE public.newsletter_signup_limits ADD CONSTRAINT newsletter_signup_limits_attempts_check CHECK (((attempts >= 0) AND (attempts <= 100)));

ALTER TABLE public.newsletter_signup_limits ADD CONSTRAINT newsletter_signup_limits_pkey PRIMARY KEY (key_hash);

ALTER TABLE public.newsletter_subscribers ADD CONSTRAINT newsletter_subscribers_email_check CHECK (((email = lower(btrim(email))) AND (length(email) <= 250)));

ALTER TABLE public.newsletter_subscribers ADD CONSTRAINT newsletter_subscribers_email_key UNIQUE (email);

ALTER TABLE public.newsletter_subscribers ADD CONSTRAINT newsletter_subscribers_pkey PRIMARY KEY (id);

ALTER TABLE public.newsletter_subscribers ADD CONSTRAINT newsletter_subscribers_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'unsubscribed'::text])));

ALTER TABLE public.poc_positions ADD CONSTRAINT poc_positions_pkey PRIMARY KEY (title);

ALTER TABLE public.poc_positions ADD CONSTRAINT poc_positions_title_valid CHECK ((((char_length(btrim(title)) >= 1) AND (char_length(btrim(title)) <= 120)) AND (title = btrim(title))));

ALTER TABLE public.staff_accounts ADD CONSTRAINT normalized_staff_email CHECK ((email = lower(btrim(email))));

ALTER TABLE public.staff_accounts ADD CONSTRAINT staff_accounts_email_key UNIQUE (email);

ALTER TABLE public.staff_accounts ADD CONSTRAINT staff_accounts_pkey PRIMARY KEY (id);

ALTER TABLE public.staff_accounts ADD CONSTRAINT staff_accounts_role_check CHECK ((role = ANY (ARRAY['admin'::text, 'inspector'::text])));

ALTER TABLE public.submission_verifications ADD CONSTRAINT submission_verifications_pkey PRIMARY KEY (id);

ALTER TABLE public.submission_verifications ADD CONSTRAINT submission_verifications_purpose_check CHECK ((purpose = ANY (ARRAY['change'::text, 'cancel'::text])));

ALTER TABLE public.submission_verifications ADD CONSTRAINT submission_verifications_token_hash_key UNIQUE (token_hash);

ALTER TABLE public.system_settings ADD CONSTRAINT system_settings_pkey PRIMARY KEY (setting_key);

CREATE INDEX calendar_jobs_status_created_at_idx ON public.calendar_jobs USING btree (status, created_at);

CREATE INDEX division_correction_history_lookup ON public.division_correction_history USING btree (correction_id, created_at DESC);

CREATE INDEX division_correction_queue_created_at ON public.division_correction_requests USING btree (created_at DESC);

CREATE INDEX division_correction_queue_rate ON public.division_correction_requests USING btree (source_fingerprint, created_at DESC);

CREATE INDEX email_deliveries_status_created_at_idx ON public.email_deliveries USING btree (status, created_at);

CREATE INDEX event_history_event_id_occurred_at_idx ON public.event_history USING btree (event_id, occurred_at DESC);

CREATE INDEX event_requests_status_submitted_at_idx ON public.event_requests USING btree (status, submitted_at DESC);

CREATE INDEX event_requests_event_id_submitted_at_idx ON public.event_requests USING btree (event_id, submitted_at DESC);

CREATE INDEX events_starts_at_ends_at_idx ON public.events USING btree (starts_at, ends_at);

CREATE INDEX events_status_event_type_starts_at_idx ON public.events USING btree (status, event_type, starts_at);

CREATE INDEX events_lodge_id_starts_at_idx ON public.events USING btree (lodge_id, starts_at);

CREATE INDEX inspector_documents_status_idx ON public.inspector_documents USING btree (status, category, updated_at DESC);

CREATE UNIQUE INDEX inspector_resource_categories_lower_name_uq ON public.inspector_resource_categories USING btree (lower(name));

CREATE INDEX inspector_resource_history_doc_idx ON public.inspector_resource_history USING btree (document_id, created_at DESC);

CREATE INDEX lodge_change_history_lodge_at_idx ON public.lodge_change_history USING btree (lodge_id, created_at DESC);

CREATE INDEX newsletter_event_flags_dirty_idx ON public.newsletter_event_flags USING btree (dirty, changed_at);

CREATE INDEX newsletter_runs_created_idx ON public.newsletter_runs USING btree (created_at DESC);

CREATE INDEX newsletter_signup_limits_updated_idx ON public.newsletter_signup_limits USING btree (updated_at);

CREATE INDEX newsletter_subscribers_status_idx ON public.newsletter_subscribers USING btree (status);

CREATE INDEX staff_accounts_active_idx ON public.staff_accounts USING btree (enabled, removed_at);

CREATE INDEX staff_accounts_district_idx ON public.staff_accounts USING btree (district);

CREATE INDEX submission_verifications_event_id_purpose_expires_at_idx ON public.submission_verifications USING btree (event_id, purpose, expires_at);

ALTER TABLE public.bulk_event_imports ADD CONSTRAINT bulk_event_imports_importer_staff_id_fkey FOREIGN KEY (importer_staff_id) REFERENCES staff_accounts(id);

ALTER TABLE public.calendar_jobs ADD CONSTRAINT calendar_jobs_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id);

ALTER TABLE public.calendar_jobs ADD CONSTRAINT calendar_jobs_request_id_fkey FOREIGN KEY (request_id) REFERENCES event_requests(id);

ALTER TABLE public.division_correction_history ADD CONSTRAINT division_correction_history_correction_id_fkey FOREIGN KEY (correction_id) REFERENCES division_correction_requests(id);

ALTER TABLE public.email_deliveries ADD CONSTRAINT email_deliveries_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id);

ALTER TABLE public.email_deliveries ADD CONSTRAINT email_deliveries_request_id_fkey FOREIGN KEY (request_id) REFERENCES event_requests(id);

ALTER TABLE public.event_attachments ADD CONSTRAINT event_attachments_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id);

ALTER TABLE public.event_attachments ADD CONSTRAINT event_attachments_request_id_fkey FOREIGN KEY (request_id) REFERENCES event_requests(id);

ALTER TABLE public.event_history ADD CONSTRAINT event_history_actor_staff_id_fkey FOREIGN KEY (actor_staff_id) REFERENCES staff_accounts(id);

ALTER TABLE public.event_history ADD CONSTRAINT event_history_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id);

ALTER TABLE public.event_history ADD CONSTRAINT event_history_request_id_fkey FOREIGN KEY (request_id) REFERENCES event_requests(id);

ALTER TABLE public.event_requests ADD CONSTRAINT event_requests_approved_event_id_fkey FOREIGN KEY (approved_event_id) REFERENCES events(id);

ALTER TABLE public.event_requests ADD CONSTRAINT event_requests_edited_by_fkey FOREIGN KEY (edited_by) REFERENCES staff_accounts(id);

ALTER TABLE public.event_requests ADD CONSTRAINT event_requests_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE RESTRICT;

ALTER TABLE public.event_requests ADD CONSTRAINT event_requests_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES staff_accounts(id);

ALTER TABLE public.events ADD CONSTRAINT events_lodge_id_fkey FOREIGN KEY (lodge_id) REFERENCES lodges(id) ON DELETE SET NULL;

ALTER TABLE public.inspector_admin_history ADD CONSTRAINT inspector_admin_history_actor_staff_id_fkey FOREIGN KEY (actor_staff_id) REFERENCES staff_accounts(id);

ALTER TABLE public.inspector_admin_history ADD CONSTRAINT inspector_admin_history_target_staff_id_fkey FOREIGN KEY (target_staff_id) REFERENCES staff_accounts(id);

ALTER TABLE public.inspector_documents ADD CONSTRAINT inspector_documents_category_fkey FOREIGN KEY (category) REFERENCES inspector_resource_categories(name) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.inspector_documents ADD CONSTRAINT inspector_documents_pending_by_fkey FOREIGN KEY (pending_by) REFERENCES staff_accounts(id);

ALTER TABLE public.inspector_documents ADD CONSTRAINT inspector_documents_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES staff_accounts(id);

ALTER TABLE public.inspector_resource_categories ADD CONSTRAINT inspector_resource_categories_created_by_fkey FOREIGN KEY (created_by) REFERENCES staff_accounts(id);

ALTER TABLE public.inspector_resource_history ADD CONSTRAINT inspector_resource_history_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES staff_accounts(id);

ALTER TABLE public.inspector_resource_history ADD CONSTRAINT inspector_resource_history_document_id_fkey FOREIGN KEY (document_id) REFERENCES inspector_documents(id);

ALTER TABLE public.lodge_change_history ADD CONSTRAINT lodge_change_history_actor_staff_id_fkey FOREIGN KEY (actor_staff_id) REFERENCES staff_accounts(id);

ALTER TABLE public.lodge_change_history ADD CONSTRAINT lodge_change_history_lodge_id_fkey FOREIGN KEY (lodge_id) REFERENCES lodges(id);

ALTER TABLE public.lodges ADD CONSTRAINT lodges_district_fkey FOREIGN KEY (district) REFERENCES districts(district_code) ON UPDATE CASCADE;

ALTER TABLE public.lodges ADD CONSTRAINT lodges_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES staff_accounts(id);

ALTER TABLE public.newsletter_event_flags ADD CONSTRAINT newsletter_event_flags_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;

ALTER TABLE public.newsletter_runs ADD CONSTRAINT newsletter_runs_created_by_fkey FOREIGN KEY (created_by) REFERENCES staff_accounts(id);

ALTER TABLE public.newsletter_settings ADD CONSTRAINT newsletter_settings_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES staff_accounts(id);

ALTER TABLE public.staff_accounts ADD CONSTRAINT staff_accounts_district_fkey FOREIGN KEY (district) REFERENCES districts(district_code) ON UPDATE CASCADE;

ALTER TABLE public.staff_accounts ADD CONSTRAINT staff_accounts_removed_by_fkey FOREIGN KEY (removed_by) REFERENCES staff_accounts(id);

ALTER TABLE public.submission_verifications ADD CONSTRAINT submission_verifications_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id);

ALTER TABLE public.system_settings ADD CONSTRAINT system_settings_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES staff_accounts(id);

CREATE VIEW public.request_index WITH (security_invoker=true) AS  SELECT r.id,
    r.request_code,
    r.event_id,
    r.request_type,
    r.proposed_fields,
    r.requester_name,
    r.requester_email,
    r.status,
    r.submitted_at,
    r.reviewed_at,
    r.approved_event_id,
    COALESCE(COALESCE(r.inspector_edits, r.proposed_fields) ->> 'title'::text, e.title, r.request_type || ' request'::text) AS event_title,
    COALESCE(COALESCE(r.inspector_edits, r.proposed_fields) ->> 'event_type'::text, e.event_type) AS event_type,
    COALESCE(COALESCE(r.inspector_edits, r.proposed_fields) ->> 'hosted_by'::text, e.hosted_by) AS lodge,
    COALESCE((((COALESCE(r.inspector_edits, r.proposed_fields) ->> 'start_local'::text)::timestamp without time zone) AT TIME ZONE 'America/Los_Angeles'::text), e.starts_at) AS event_starts
   FROM event_requests r
     LEFT JOIN events e ON e.id = r.event_id;

CREATE OR REPLACE FUNCTION public.resolve_calendar_title(p_event_name text, p_hosted_by text, p_event_type text, p_district text, p_override text DEFAULT NULL::text, p_fallback text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
 nm text:=btrim(coalesce(p_event_name,''));
 host text:=btrim(coalesce(p_hosted_by,''));
 pref text;
 abbrevi text;
 result_title text;
begin
 -- Explicit title overrides remain restricted to authorized inspector/admin operations.
 if nullif(btrim(coalesce(p_override,'')),'') is not null then
   result_title:=btrim(p_override);
 elsif p_event_type='District School of Instruction' then
   if btrim(coalesce(p_district,'')) !~ '^[0-9]{3,4}$' then
     raise exception 'A valid district number is required for District Schools of Instruction';
   end if;
   result_title:='District '||btrim(p_district)||' School of Instruction';
 elsif p_event_type='Division School of Instruction' then
   result_title:='Division IV School of Instruction';
 elsif nm='' then
   result_title:=btrim(coalesce(p_fallback,''));
 else
   if host='' then raise exception 'A hosting lodge or organization is required'; end if;
   select nullif(btrim(l.abbreviation),'') into abbrevi
   from public.lodges l
   where l.active and (
     lower(host)=lower(l.lodge_name||' Lodge No. '||l.lodge_number) or
     lower(host)=lower(l.lodge_name||' No. '||l.lodge_number) or
     lower(host)=lower(coalesce(l.abbreviation,'')) or
     lower(host)=lower(l.lodge_name)
   )
   order by l.lodge_number limit 1;
   pref:=coalesce(abbrevi,host);
   if lower(left(nm,length(pref)+2))=lower(pref||': ') then
     nm:=btrim(substr(nm,length(pref)+3));
   elsif lower(left(nm,length(host)+2))=lower(host||': ') then
     nm:=btrim(substr(nm,length(host)+3));
   end if;
   result_title:=pref||': '||nm;
 end if;
 if result_title='' then raise exception 'A calendar title is required'; end if;
 if length(result_title)>180 then raise exception 'Calendar title exceeds 180 characters'; end if;
 return result_title;
end
$function$;

CREATE OR REPLACE FUNCTION public.admin_undo_last_published_edit(p_event_id uuid, p_history_id uuid, p_staff uuid, p_expected_version integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 e public.events%rowtype;
 h public.event_history%rowtype;
 newest uuid;
 result jsonb;
 actor text;
 restore_log public.event_history%rowtype;
begin
 select email into actor from public.staff_accounts where id=p_staff and enabled=true and role='admin';
 if actor is null then raise exception 'Administrator permission required';end if;
 select * into e from public.events where id=p_event_id for update;
 if not found then raise exception 'Event not found';end if;
 if e.status<>'active' then raise exception 'Cannot undo an edit to a cancelled event';end if;
 if e.version is distinct from p_expected_version then raise exception 'Event changed. Reload before undoing';end if;
 select id into newest from public.event_history where event_id=p_event_id and action in
 ('inspector_updated_published','inspector_undo_published') order by occurred_at desc,id desc limit 1;
 if newest is null or newest<>p_history_id then raise exception 'Only the most recent inspector edit can be undone';end if;
 select * into h from public.event_history where id=p_history_id and event_id=p_event_id;
 if (h.after_data->>'version')::integer is distinct from e.version then
  raise exception 'Newer changes exist. Undo is no longer safe';
 end if;
 if jsonb_typeof(h.before_data->'fields')<>'object' then raise exception 'Previous event details unavailable';end if;
 result:=public.inspector_update_published_event(p_event_id,p_staff,p_expected_version,h.before_data->'fields');
 select * into restore_log from public.event_history
   where event_id=p_event_id and action='inspector_updated_published'
   and (after_data->>'version')::integer=(p_expected_version+1)
   order by occurred_at desc,id desc limit 1;
 if not found then raise exception 'Undo audit could not be recorded';end if;
 insert into public.event_history(event_id,action,actor_staff_id,actor_email,before_data,after_data,notes)
 values(p_event_id,'inspector_undo_published',p_staff,actor,
  restore_log.before_data,
  restore_log.after_data||jsonb_build_object('undone_history_id',p_history_id,'restoration_history_id',restore_log.id),
  'Administrator reversed inspector edit '||p_history_id::text);
 return result||jsonb_build_object('undone_history_id',p_history_id,'notice','Prior version restored. Calendar update queued.');
end $function$;

CREATE OR REPLACE FUNCTION public.approve_request(p_id uuid, p_staff uuid, p_decision text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.event_requests%rowtype; e public.events%rowtype; p jsonb; eid uuid; ver int; who text;
begin
select email into who from public.staff_accounts where id=p_staff and enabled;
if who is null then raise exception 'Reviewer disabled'; end if;
if p_decision not in ('approved','needs_correction','rejected') then raise exception 'Bad decision'; end if;
select * into r from public.event_requests where id=p_id for update;
if not found or r.status not in ('pending','needs_correction') then raise exception 'Request already processed; refresh'; end if;
p:=coalesce(r.inspector_edits,r.proposed_fields);
if p_decision='approved' then
 if r.request_type='new' then
  insert into public.events(event_code,title,event_name,calendar_title_override,event_type,hosted_by,district,starts_at,ends_at,event_mode,location_name,location_address,location_address1,location_address2,location_city,location_state,location_zip,location_tbd,public_description,attire,invited_audience,registration_url,payment_url,flyer_url,poc_name,poc_position,poc_phone,poc_email,cost_details)
  values(r.request_code,p->>'title',nullif(p->>'event_name',''),nullif(p->>'calendar_title_override',''),p->>'event_type',p->>'hosted_by',p->>'district',
    (p->>'start_local')::timestamp at time zone 'America/Los_Angeles',
    (p->>'end_local')::timestamp at time zone 'America/Los_Angeles',
    coalesce(p->>'event_mode','in_person'),nullif(p->>'location_name',''),nullif(concat_ws(', ',nullif(concat_ws(' ',nullif(p->>'location_address1',''),nullif(p->>'location_address2','')),''),nullif(p->>'location_city',''),nullif(p->>'location_state',''),nullif(p->>'location_zip','')),''),nullif(p->>'location_address1',''),nullif(p->>'location_address2',''),nullif(p->>'location_city',''),nullif(p->>'location_state',''),nullif(p->>'location_zip',''),
    coalesce((p->>'location_tbd')::boolean,false),p->>'public_description',p->>'attire',p->>'invited_audience',p->>'registration_url',p->>'payment_url',p->>'flyer_url',nullif(btrim(p->>'poc_name'),''),nullif(btrim(p->>'poc_position'),''),nullif(btrim(p->>'poc_phone'),''),nullif(btrim(p->>'poc_email'),''),nullif(btrim(p->>'cost_details'),''))
  returning id,version into eid,ver;
 else
  select * into e from public.events where id=r.event_id for update;
  if not found or e.version is distinct from r.base_event_version then raise exception 'Event changed since request; refresh'; end if;
  if r.request_type='cancel' then
   update public.events set status='cancelled',version=version+1,updated_at=now() where id=e.id returning id,version into eid,ver;
  else
   update public.events set
     title=public.resolve_calendar_title(case when p ? 'event_name' then nullif(p->>'event_name','') else e.event_name end,coalesce(p->>'hosted_by',e.hosted_by),coalesce(p->>'event_type',e.event_type),coalesce(p->>'district',e.district),case when p ? 'calendar_title_override' then nullif(p->>'calendar_title_override','') else e.calendar_title_override end,coalesce(p->>'title',e.title)),
     event_name=case when p ? 'event_name' then nullif(p->>'event_name','') else e.event_name end,
     calendar_title_override=case when p ? 'calendar_title_override' then nullif(p->>'calendar_title_override','') else e.calendar_title_override end,
     event_type=coalesce(p->>'event_type',event_type),
     hosted_by=coalesce(p->>'hosted_by',hosted_by),district=coalesce(p->>'district',district),
     starts_at=case when p ? 'start_local' then (p->>'start_local')::timestamp at time zone 'America/Los_Angeles' else starts_at end,
     ends_at=case when p ? 'end_local' then (p->>'end_local')::timestamp at time zone 'America/Los_Angeles' else ends_at end,
     event_mode=coalesce(p->>'event_mode',event_mode),
     location_name=case when coalesce((p->>'location_tbd')::boolean,false) then null when p ? 'location_name' then nullif(p->>'location_name','') else location_name end,
     location_address=case when coalesce((p->>'location_tbd')::boolean,false) then null when p ? 'location_address1' or p ? 'location_address2' or p ? 'location_city' or p ? 'location_state' or p ? 'location_zip' then nullif(concat_ws(', ',nullif(concat_ws(' ',nullif(coalesce(p->>'location_address1',location_address1),''),nullif(coalesce(p->>'location_address2',location_address2),'')),''),nullif(coalesce(p->>'location_city',location_city),''),nullif(coalesce(p->>'location_state',location_state),''),nullif(coalesce(p->>'location_zip',location_zip),'')),'') else location_address end,
     location_address1=case when coalesce((p->>'location_tbd')::boolean,false) then null when p ? 'location_address1' then nullif(p->>'location_address1','') else location_address1 end,
     location_address2=case when coalesce((p->>'location_tbd')::boolean,false) then null when p ? 'location_address2' then nullif(p->>'location_address2','') else location_address2 end,
     location_city=case when coalesce((p->>'location_tbd')::boolean,false) then null when p ? 'location_city' then nullif(p->>'location_city','') else location_city end,
     location_state=case when coalesce((p->>'location_tbd')::boolean,false) then null when p ? 'location_state' then nullif(p->>'location_state','') else location_state end,
     location_zip=case when coalesce((p->>'location_tbd')::boolean,false) then null when p ? 'location_zip' then nullif(p->>'location_zip','') else location_zip end,
     location_tbd=coalesce((p->>'location_tbd')::boolean,location_tbd),
     public_description=coalesce(p->>'public_description',public_description),
     attire=coalesce(p->>'attire',attire),invited_audience=coalesce(p->>'invited_audience',invited_audience),
     registration_url=coalesce(p->>'registration_url',registration_url),
     payment_url=coalesce(p->>'payment_url',payment_url),flyer_url=coalesce(p->>'flyer_url',flyer_url),
     poc_name=case when p ? 'poc_name' then nullif(btrim(p->>'poc_name'),'') else poc_name end,
     poc_position=case when p ? 'poc_position' then nullif(btrim(p->>'poc_position'),'') else poc_position end,
     poc_phone=case when p ? 'poc_phone' then nullif(btrim(p->>'poc_phone'),'') else poc_phone end,
     poc_email=case when p ? 'poc_email' then nullif(btrim(p->>'poc_email'),'') else poc_email end,
     cost_details=case when p ? 'cost_details' then nullif(btrim(p->>'cost_details'),'') else cost_details end,
     version=version+1,updated_at=now() where id=e.id returning id,version into eid,ver;
  end if;
 end if;
 insert into public.calendar_jobs(event_id,request_id,action,event_version,idempotency_key)
 values(eid,r.id,case when r.request_type='cancel' then 'cancel' else 'upsert' end,ver,eid::text||':'||ver::text)
 on conflict(idempotency_key) do nothing;
end if;
update public.event_requests set status=p_decision,reviewer_id=p_staff,reviewer_public_message=p_note,
 reviewed_at=now(),updated_at=now(),approved_event_id=case when p_decision='approved' then eid else null end where id=r.id;
insert into public.event_history(event_id,request_id,action,actor_staff_id,actor_email,before_data,after_data)
values(eid,r.id,p_decision,p_staff,who,jsonb_build_object('status',r.status),jsonb_build_object('status',p_decision,'changes',p));
insert into public.email_deliveries(event_id,request_id,message_type,recipient_email,idempotency_key)
values(eid,r.id,'decision',r.requester_email,r.id::text||':decision') on conflict do nothing;
return jsonb_build_object('status',p_decision,'event_id',eid,'calendar_queued',p_decision='approved');
end $function$;

CREATE OR REPLACE FUNCTION public.bulk_import_new_request(p_code text, p_fields jsonb, p_requester_name text, p_requester_email text, p_requester_phone text, p_requester_message text, p_dedupe_key text, p_actor_email text, p_staff_id uuid, p_batch_id uuid, p_row integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_id uuid; v_code text; v_is_new boolean := false;
begin
 if auth.role() <> 'service_role' then
   raise exception 'Bulk imports are service-only';
 end if;
 if p_row < 1 or p_row > 200 then raise exception 'Invalid spreadsheet row'; end if;
 if not exists (select 1 from public.bulk_event_imports where id=p_batch_id and importer_staff_id=p_staff_id and status='processing') then
   raise exception 'Bulk import batch is not active';
 end if;
 insert into public.event_requests(
   request_code,event_id,request_type,proposed_fields,requester_name,
   requester_email,requester_phone,requester_message,submission_source,idempotency_key)
 values(p_code,null,'new',p_fields,p_requester_name,lower(trim(p_requester_email)),
    p_requester_phone,p_requester_message,'bulk',p_dedupe_key)
 on conflict (idempotency_key) do nothing
 returning id,request_code into v_id,v_code;
 if v_id is null then
   select id,request_code into v_id,v_code from public.event_requests where idempotency_key=p_dedupe_key;
   if v_id is null then raise exception 'Unable to resolve duplicate import'; end if;
 else
   v_is_new := true;
   insert into public.event_history(event_id,request_id,action,actor_staff_id,actor_email,after_data,notes)
   values(null,v_id,'submitted',p_staff_id,p_actor_email,
     jsonb_build_object('kind','new','source','bulk','batch_id',p_batch_id,'row',p_row),
     'Created via authenticated inspector bulk spreadsheet import');
 end if;
 return jsonb_build_object('id',v_id,'request_code',v_code,'created',v_is_new);
end
$function$;

CREATE OR REPLACE FUNCTION public.capture_event_poc_position()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if nullif(btrim(new.poc_position),'') is not null then
  insert into public.poc_positions(title) values (btrim(new.poc_position))
  on conflict(title) do nothing;
 end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION public.change_inspector_resource(p_document uuid, p_actor uuid, p_action text, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_category text DEFAULT NULL::text)
 RETURNS inspector_documents
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare d public.inspector_documents%rowtype; result public.inspector_documents%rowtype;
begin
 if not exists(select 1 from public.staff_accounts s
  where s.id=p_actor and s.role='admin' and s.enabled=true and s.removed_at is null)
 then raise exception 'Administrator access required'; end if;
 select * into d from public.inspector_documents where id=p_document for update;
 if not found or d.status<>'active' then raise exception 'Document is no longer active'; end if;
 if p_action='edited' then
  if nullif(btrim(p_title),'') is null or length(p_title)>160 then raise exception 'Invalid document title'; end if;
  if length(coalesce(p_description,''))>1200 then raise exception 'Description is too long'; end if;
  if not exists(select 1 from public.inspector_resource_categories where name=p_category and active=true)
  then raise exception 'Choose an active document category'; end if;
  update public.inspector_documents set title=btrim(p_title),description=coalesce(btrim(p_description),''),
   category=p_category,updated_at=now() where id=p_document returning * into result;
 elsif p_action='deleted' then
  update public.inspector_documents set status='deleted',deleted_at=now(),updated_at=now(),
   pending_path=null,pending_original_name=null,pending_mime_type=null,pending_bytes=null,pending_by=null,pending_at=null
  where id=p_document returning * into result;
 else raise exception 'Invalid document action'; end if;
 insert into public.inspector_resource_history(document_id,actor_id,action,version,file_path,file_name,details)
 values(p_document,p_actor,p_action,d.version,d.storage_path,d.original_name,
  jsonb_build_object('previous_title',d.title,'previous_category',d.category));
 return result;
end $function$;

CREATE OR REPLACE FUNCTION public.finalize_inspector_resource(p_document uuid, p_actor uuid, p_path text)
 RETURNS inspector_documents
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare d public.inspector_documents%rowtype; stored_bytes bigint; result public.inspector_documents%rowtype; next_version int;
begin
 select * into d from public.inspector_documents where id=p_document for update;
 if not found then raise exception 'Document not found'; end if;
 if not exists(select 1 from public.staff_accounts s
   where s.id=p_actor and s.role='admin' and s.enabled=true and s.removed_at is null)
 then raise exception 'Administrator access required'; end if;
 if d.pending_path is null or d.pending_path<>p_path or d.pending_by is distinct from p_actor
 then raise exception 'Upload session expired or not owned by this administrator'; end if;
 if d.pending_at < now()- interval '2 hours' then raise exception 'Upload authorization expired'; end if;
 if d.pending_bytes is null or d.pending_bytes<1 or d.pending_bytes>20971520 then raise exception 'Invalid file size'; end if;
 select nullif(o.metadata->>'size','')::bigint into stored_bytes
 from storage.objects o where o.bucket_id='division-inspector-resources' and o.name=p_path;
 if stored_bytes is null then raise exception 'File upload has not finished'; end if;
 if stored_bytes<>d.pending_bytes then raise exception 'File size does not match the upload'; end if;
 next_version:=d.version+1;
 if d.version>0 and d.status='active' then
   insert into public.inspector_resource_history(document_id,actor_id,action,version,file_path,file_name,details)
   values(d.id,p_actor,'replaced',d.version,d.storage_path,d.original_name,
    jsonb_build_object('replaced_by_version',next_version));
 end if;
 update public.inspector_documents set status='active',storage_path=p_path,
   original_name=d.pending_original_name,mime_type=d.pending_mime_type,bytes=stored_bytes,
   version=next_version,uploaded_by=p_actor,updated_at=now(),published_at=now(),
   pending_path=null,pending_original_name=null,pending_mime_type=null,
   pending_bytes=null,pending_by=null,pending_at=null
 where id=p_document returning * into result;
 insert into public.inspector_resource_history(document_id,actor_id,action,version,file_path,file_name)
 values(p_document,p_actor,case when next_version=1 then 'uploaded' else 'replaced' end,
  next_version,p_path,result.original_name);
 return result;
end
$function$;

CREATE OR REPLACE FUNCTION public.inspector_dashboard_data()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
with
 status_counts as (
   select count(*) filter(where status='pending')::integer as pending,
          count(*) filter(where status='needs_correction')::integer as corrections
   from public.event_requests
 ),
 live_jobs as (
  select e.id as event_id,e.title,e.event_code,e.hosted_by,e.version,e.status as event_status,
         j.id as job_id,j.status as job_status,j.action as job_action,j.last_error,j.created_at as job_created
  from public.events e
  left join lateral (
   select * from public.calendar_jobs c where c.event_id=e.id
   and c.event_version=e.version
   and c.action=(case when e.status='cancelled' then 'cancel' else 'upsert' end)
   order by c.created_at desc,c.id desc limit 1
  ) j on true
 ),
 sync_counts as(
  select count(*) filter(where job_status='failed')::integer as failed,
         count(*) filter(where job_status in ('pending','running'))::integer as queued
  from live_jobs
 ),
 pending_list as(
  select coalesce(jsonb_agg(q.data order by q.submitted_at desc),'[]'::jsonb) as arr from (
   select r.submitted_at,jsonb_build_object('id',r.id,'code',r.request_code,
      'title',coalesce(nullif(r.proposed_fields->>'title',''),e.title,'Event request'),
      'status',r.status,'request_type',r.request_type,'submitted_at',r.submitted_at) as data
   from public.event_requests r left join public.events e on e.id=r.event_id
   where r.status in ('pending','needs_correction')
   order by r.submitted_at desc limit 8
  ) q
 ),
 failed_list as (
  select coalesce(jsonb_agg(f.data order by f.job_created desc),'[]'::jsonb) as arr from (
    select job_created, jsonb_build_object('id',event_id,'title',title,'code',event_code,
      'event_status',event_status,'error',last_error,'job_id',job_id) as data
    from live_jobs where job_status='failed' order by job_created desc limit 8
  ) f
 ),
 recent_list as(
  select coalesce(jsonb_agg(a.data order by a.occurred_at desc),'[]'::jsonb) as arr from (
   select h.occurred_at,jsonb_build_object('id',h.id,'action',h.action,
      'event_id',h.event_id,'request_id',h.request_id,
      'event_title',coalesce(e.title,r.proposed_fields->>'title','Event request'),
      'actor',h.actor_email,'at',h.occurred_at) as data
   from public.event_history h
   left join public.events e on e.id=h.event_id
   left join public.event_requests r on r.id=h.request_id
   order by h.occurred_at desc limit 8
  ) a
 )
select jsonb_build_object('counts',jsonb_build_object('pending',(select pending from status_counts),
 'corrections',(select corrections from status_counts),
 'failed',(select failed from sync_counts),
 'queued',(select queued from sync_counts)),
 'requests',(select arr from pending_list),
 'failures',(select arr from failed_list),
 'recent',(select arr from recent_list));
$function$;

CREATE OR REPLACE FUNCTION public.inspector_retry_calendar_sync(p_event_id uuid, p_staff uuid, p_expected_version integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 e public.events%rowtype;
 j public.calendar_jobs%rowtype;
 actor text;
 required_action text;
begin
 select email into actor from public.staff_accounts where id=p_staff and enabled=true;
 if actor is null then raise exception 'Inspector access required';end if;
 select * into e from public.events where id=p_event_id for update;
 if not found then raise exception 'Event not found';end if;
 if e.version is distinct from p_expected_version then raise exception 'Event changed. Reload and try again';end if;
 required_action:=case when e.status='cancelled' then 'cancel' else 'upsert' end;
 select * into j from public.calendar_jobs where event_id=p_event_id and event_version=e.version
 and action=required_action order by created_at desc,id desc limit 1 for update;
 if not found then raise exception 'No calendar delivery record for the current event version';end if;
 if j.status<>'failed' then raise exception 'Only failed calendar updates can be retried. Refresh the event status';end if;
 update public.calendar_jobs set status='pending',last_error=null,finished_at=null where id=j.id;
 insert into public.event_history(event_id,action,actor_staff_id,actor_email,before_data,after_data,notes)
 values(p_event_id,'calendar_retry_requested',p_staff,actor,
  jsonb_build_object('job_id',j.id,'error',j.last_error,'attempts',j.attempts),
  jsonb_build_object('job_id',j.id,'status','pending','version',e.version),
  'Inspector queued manual Google Calendar retry');
 return jsonb_build_object('ok',true,'job_id',j.id,'event_id',p_event_id,'status','pending');
end $function$;

CREATE OR REPLACE FUNCTION public.inspector_update_lodge(p_lodge_id uuid, p_staff_id uuid, p_expected_version integer, p_fields jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
 old_lodge public.lodges%rowtype;
 new_lodge public.lodges%rowtype;
 allowed_keys text[] := array['lodge_name','lodge_number','abbreviation','district','address_line1','city','county','state','meeting_day','meeting_time','meeting_notes','official_url'];
 key_name text;
 new_name text;
 new_number text;
 new_abbreviation text;
 new_district text;
 new_address text;
 new_city text;
 new_county text;
 new_state text;
 new_day text;
 new_time text;
 new_notes text;
 new_url text;
begin
 if not exists(select 1 from public.staff_accounts where id=p_staff_id and enabled is true and removed_at is null and role='admin') then
  raise exception 'Administrator access required';
 end if;
 if p_fields is null or jsonb_typeof(p_fields)<>'object' then
  raise exception 'Invalid lodge update';
 end if;
 for key_name in select jsonb_object_keys(p_fields) loop
  if not key_name=any(allowed_keys) then raise exception 'This field cannot be edited: %',key_name; end if;
 end loop;
 select * into old_lodge from public.lodges where id=p_lodge_id for update;
 if not found then raise exception 'Lodge not found'; end if;
 if old_lodge.record_version<>p_expected_version then raise exception 'Record was updated by someone else. Reload the lodge before saving.'; end if;

 new_name:=btrim(coalesce(p_fields->>'lodge_name',old_lodge.lodge_name));
 new_number:=btrim(coalesce(p_fields->>'lodge_number',old_lodge.lodge_number));
 new_abbreviation:=btrim(coalesce(p_fields->>'abbreviation',old_lodge.abbreviation,''));
 new_district:=btrim(coalesce(p_fields->>'district',old_lodge.district));
 new_address:=btrim(coalesce(p_fields->>'address_line1',old_lodge.address_line1,''));
 new_city:=btrim(coalesce(p_fields->>'city',old_lodge.city,''));
 new_county:=btrim(coalesce(p_fields->>'county',old_lodge.county,''));
 new_state:=upper(btrim(coalesce(p_fields->>'state',old_lodge.state,'CA')));
 new_day:=btrim(coalesce(p_fields->>'meeting_day',old_lodge.meeting_day,''));
 new_time:=btrim(coalesce(p_fields->>'meeting_time',old_lodge.meeting_time,''));
 new_notes:=btrim(coalesce(p_fields->>'meeting_notes',old_lodge.meeting_notes,''));
 new_url:=btrim(coalesce(p_fields->>'official_url',old_lodge.official_url,''));

 if new_name='' or length(new_name)>150 or new_number='' or length(new_number)>12 then raise exception 'Enter a valid lodge name and number'; end if;
 if char_length(new_abbreviation)>20 then raise exception 'Lodge abbreviation cannot exceed 20 characters'; end if;
 if new_district not in ('402','404','410','414','418','422','428','438') then raise exception 'Choose an assigned Division IV district'; end if;
 if new_address='' or length(new_address)>240 or new_city='' or length(new_city)>120 or length(new_county)>100 then raise exception 'Enter a valid street address and city'; end if;
 if new_state !~ '^[A-Z]{2}$' or length(new_day)>100 or length(new_time)>40 or length(new_notes)>300 then raise exception 'Invalid state or meeting schedule'; end if;
 if new_url<>'' and (length(new_url)>1000 or new_url !~* '^https?://[^[:space:]]+') then raise exception 'Enter a valid https:// lodge listing URL'; end if;
 if exists(select 1 from public.lodges where lodge_number=new_number and id<>p_lodge_id) then raise exception 'Another lodge already uses that number'; end if;

 update public.lodges set
  lodge_name=new_name,lodge_number=new_number,abbreviation=nullif(new_abbreviation,''),district=new_district,
  address_line1=new_address,city=new_city,county=new_county,state=new_state,
  meeting_day=new_day,meeting_time=new_time,meeting_notes=new_notes,official_url=new_url,
  record_version=record_version+1,updated_at=now(),updated_by=p_staff_id
 where id=p_lodge_id and record_version=p_expected_version
 returning * into new_lodge;
 if not found then raise exception 'Concurrent update detected. Reload and retry.'; end if;
 insert into public.lodge_change_history(lodge_id,actor_staff_id,previous_version,new_version,before_data,after_data)
 values (p_lodge_id,p_staff_id,old_lodge.record_version,new_lodge.record_version,to_jsonb(old_lodge),to_jsonb(new_lodge));
 return to_jsonb(new_lodge);
end;
$function$;

CREATE OR REPLACE FUNCTION public.inspector_update_published_event(p_id uuid, p_staff uuid, p_expected_version integer, p_fields jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 old_row public.events%rowtype;
 updated_row public.events%rowtype;
 actor text;
 request_id uuid;
 recipient text;
 stored_values jsonb;
 before_fields jsonb;
 delta jsonb:='{}'::jsonb;
 allowed_districts jsonb;
 item text;
 items text[]:=array['title','event_name','calendar_title_override','event_type','hosted_by','district','start_local','end_local','event_mode','public_description','location_tbd','location_name','location_address1','location_address2','location_city','location_state','location_zip','attire','invited_audience','registration_url','payment_url','flyer_url','poc_name','poc_phone','poc_email','cost_details'];
begin
 select email into actor from public.staff_accounts where id=p_staff and enabled=true;
 if actor is null then raise exception 'Inspector access is required'; end if;
 select * into old_row from public.events where id=p_id for update;
 if not found then raise exception 'Event not found'; end if;
 if old_row.status<>'active' then raise exception 'Cancelled events cannot be edited'; end if;
 if old_row.version is distinct from p_expected_version then raise exception 'This event has changed. Reload before editing'; end if;
 if jsonb_typeof(p_fields)<>'object' then raise exception 'Invalid event fields'; end if;
 foreach item in array items loop
  if not p_fields ? item and item not in ('poc_name','poc_phone','poc_email','cost_details','event_name','calendar_title_override') then raise exception 'Missing field: %', item; end if;
 end loop;
 if trim(coalesce(p_fields->>'title',''))='' or trim(coalesce(p_fields->>'hosted_by',''))='' or
    trim(coalesce(p_fields->>'public_description',''))='' then
   raise exception 'Title, hosting lodge and public description are required';
 end if;
 if length(p_fields->>'title')>180 or length(p_fields->>'public_description')>4000 then raise exception 'Text is too long'; end if;
 if (p_fields->>'event_mode') not in ('in_person','hybrid','online') then raise exception 'Invalid event format'; end if;
 select setting_value into allowed_districts from public.system_settings where setting_key='district_numbers';
 if p_fields->>'event_type'<>'Division School of Instruction' and not coalesce(allowed_districts ? (p_fields->>'district'),false) then raise exception 'Invalid district'; end if;
 if not exists(select 1 from public.event_types where enabled=true and label=p_fields->>'event_type') then raise exception 'Invalid event type'; end if;
 if coalesce(p_fields->>'start_local','') !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$' or
    coalesce(p_fields->>'end_local','') !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$' then raise exception 'Invalid event date'; end if;
 if (p_fields->>'end_local')::timestamp <= (p_fields->>'start_local')::timestamp then raise exception 'End must be after start'; end if;
 if not coalesce((p_fields->>'location_tbd')::boolean,false) then
   if trim(coalesce(p_fields->>'location_name',''))='' or trim(coalesce(p_fields->>'location_address1',''))='' or
      trim(coalesce(p_fields->>'location_city',''))='' or trim(coalesce(p_fields->>'location_state',''))='' or
      trim(coalesce(p_fields->>'location_zip',''))='' then
     raise exception 'Complete the location or select Location TBD';
   end if;
   if p_fields->>'location_state' !~ '^[A-Z]{2}$' or p_fields->>'location_zip' !~ '^\d{5}(-\d{4})?$' then
     raise exception 'Check the state abbreviation and ZIP code';
   end if;
 end if;
 before_fields:=jsonb_build_object(
 'title',old_row.title,'event_name',old_row.event_name,'calendar_title_override',old_row.calendar_title_override,'event_type',old_row.event_type,'hosted_by',old_row.hosted_by,'district',old_row.district,
 'start_local',to_char(old_row.starts_at at time zone 'America/Los_Angeles','YYYY-MM-DD"T"HH24:MI'),
 'end_local',to_char(old_row.ends_at at time zone 'America/Los_Angeles','YYYY-MM-DD"T"HH24:MI'),
 'event_mode',old_row.event_mode,'public_description',old_row.public_description,
 'location_tbd',old_row.location_tbd,'location_name',old_row.location_name,
 'location_address1',old_row.location_address1,'location_address2',old_row.location_address2,
 'location_city',old_row.location_city,'location_state',old_row.location_state,'location_zip',old_row.location_zip,
 'attire',old_row.attire,'invited_audience',old_row.invited_audience,'registration_url',old_row.registration_url,
 'payment_url',old_row.payment_url,'flyer_url',old_row.flyer_url,
 'poc_name',old_row.poc_name,'poc_phone',old_row.poc_phone,
 'poc_email',old_row.poc_email,'cost_details',old_row.cost_details);
 foreach item in array items loop
  if p_fields ? item and coalesce(before_fields->>item,'') is distinct from coalesce(p_fields->>item,'') then
    delta:=delta||jsonb_build_object(item,p_fields->item);
  end if;
 end loop;
 if delta='{}'::jsonb then raise exception 'No changes to save'; end if;
 update public.events set
 title=public.resolve_calendar_title(case when p_fields ? 'event_name' then nullif(trim(p_fields->>'event_name'),'') else old_row.event_name end,
 trim(p_fields->>'hosted_by'),p_fields->>'event_type',p_fields->>'district',
 case when p_fields ? 'calendar_title_override' then nullif(trim(p_fields->>'calendar_title_override'),'') else old_row.calendar_title_override end,old_row.title),
 event_name=case when p_fields ? 'event_name' then nullif(trim(p_fields->>'event_name'),'') else event_name end,
 calendar_title_override=case when p_fields ? 'calendar_title_override' then nullif(trim(p_fields->>'calendar_title_override'),'') else calendar_title_override end,
 event_type=p_fields->>'event_type',hosted_by=trim(p_fields->>'hosted_by'),
 district=p_fields->>'district',starts_at=(p_fields->>'start_local')::timestamp at time zone 'America/Los_Angeles',
 ends_at=(p_fields->>'end_local')::timestamp at time zone 'America/Los_Angeles',
 event_mode=p_fields->>'event_mode',public_description=trim(p_fields->>'public_description'),
 location_tbd=coalesce((p_fields->>'location_tbd')::boolean,false),
 location_name=case when (p_fields->>'location_tbd')::boolean then null else nullif(trim(p_fields->>'location_name'),'') end,
 location_address1=case when (p_fields->>'location_tbd')::boolean then null else nullif(trim(p_fields->>'location_address1'),'') end,
 location_address2=case when (p_fields->>'location_tbd')::boolean then null else nullif(trim(p_fields->>'location_address2'),'') end,
 location_city=case when (p_fields->>'location_tbd')::boolean then null else nullif(trim(p_fields->>'location_city'),'') end,
 location_state=case when (p_fields->>'location_tbd')::boolean then null else nullif(trim(p_fields->>'location_state'),'') end,
 location_zip=case when (p_fields->>'location_tbd')::boolean then null else nullif(trim(p_fields->>'location_zip'),'') end,
 location_address=case when (p_fields->>'location_tbd')::boolean then null else
 nullif(concat_ws(', ',nullif(concat_ws(' ',nullif(trim(p_fields->>'location_address1'),''),nullif(trim(p_fields->>'location_address2'),'')),''),nullif(trim(p_fields->>'location_city'),''),nullif(trim(p_fields->>'location_state'),''),nullif(trim(p_fields->>'location_zip'),'')),'') end,
 attire=nullif(trim(p_fields->>'attire'),''),invited_audience=nullif(trim(p_fields->>'invited_audience'),''),
 registration_url=nullif(trim(p_fields->>'registration_url'),''),payment_url=nullif(trim(p_fields->>'payment_url'),''),
 flyer_url=nullif(trim(p_fields->>'flyer_url'),''),
 poc_name=case when p_fields ? 'poc_name' then nullif(trim(p_fields->>'poc_name'),'') else poc_name end,
 poc_phone=case when p_fields ? 'poc_phone' then nullif(trim(p_fields->>'poc_phone'),'') else poc_phone end,
 poc_email=case when p_fields ? 'poc_email' then nullif(trim(p_fields->>'poc_email'),'') else poc_email end,
 cost_details=case when p_fields ? 'cost_details' then nullif(trim(p_fields->>'cost_details'),'') else cost_details end,
 version=version+1,updated_at=now()
 where id=p_id returning * into updated_row;
 insert into public.event_history(event_id,action,actor_staff_id,actor_email,before_data,after_data,notes)
 values(p_id,'inspector_updated_published',p_staff,actor,
 jsonb_build_object('fields',before_fields,'version',old_row.version),
 jsonb_build_object('fields',p_fields,'changes',delta,'version',updated_row.version),
 'Inspector corrected published event');
 insert into public.calendar_jobs(event_id,action,event_version,idempotency_key)
 values(p_id,'upsert',updated_row.version,p_id::text||':'||updated_row.version::text)
 on conflict(idempotency_key) do nothing;
 select id,requester_email into request_id,recipient from public.event_requests
 where request_type='new' and approved_event_id=p_id order by submitted_at asc limit 1;
 if request_id is not null and recipient is not null then
  insert into public.email_deliveries(event_id,request_id,message_type,recipient_email,idempotency_key)
  values(p_id,request_id,'inspector_update',recipient,p_id::text||':'||updated_row.version::text||':inspector_update')
  on conflict do nothing;
 end if;
 return jsonb_build_object('ok',true,'event_id',p_id,'version',updated_row.version,
    'changes',delta,'calendar_status','queued');
end $function$;

CREATE OR REPLACE FUNCTION public.manage_inspector_resource_category(p_actor uuid, p_action text, p_id uuid DEFAULT NULL::uuid, p_name text DEFAULT NULL::text)
 RETURNS inspector_resource_categories
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
 cat public.inspector_resource_categories%rowtype;
 result public.inspector_resource_categories%rowtype;
 new_name text;
 used_count int;
begin
 if not exists(select 1 from public.staff_accounts s
  where s.id=p_actor and s.role='admin' and s.enabled=true and s.removed_at is null)
 then raise exception 'Administrator access required'; end if;
 if p_action not in ('create','rename','archive','restore') then raise exception 'Unknown category action'; end if;
 if p_action in ('create','rename') then
  new_name=regexp_replace(btrim(coalesce(p_name,'')),'[[:space:]]+',' ','g');
  if length(new_name)<2 or length(new_name)>50 or
     new_name !~ '^[A-Za-z0-9][A-Za-z0-9 _&/().-]*$'
  then raise exception 'Category names must be 2–50 characters (letters, numbers, spaces, &, /, parentheses, period, hyphen)'; end if;
 end if;
 if p_action='create' then
  if (select count(*) from public.inspector_resource_categories)>=40
  then raise exception 'Maximum of 40 document categories reached'; end if;
  if exists(select 1 from public.inspector_resource_categories where lower(name)=lower(new_name))
  then raise exception 'A category with that name already exists'; end if;
  insert into public.inspector_resource_categories(name,created_by)
    values (new_name,p_actor) returning * into result;
 else
  select * into cat from public.inspector_resource_categories where id=p_id for update;
  if not found then raise exception 'Category not found. Refresh Resources'; end if;
  if cat.name='General' and p_action in ('rename','archive')
  then raise exception 'General is the required default category and cannot be renamed or archived'; end if;
  if p_action='rename' then
   if exists(select 1 from public.inspector_resource_categories where lower(name)=lower(new_name) and id<>cat.id)
    then raise exception 'A category with that name already exists'; end if;
   update public.inspector_resource_categories set name=new_name,updated_at=now()
     where id=cat.id returning * into result;
  elsif p_action='archive' then
   if not cat.active then raise exception 'Category already archived'; end if;
   select count(*) into used_count from public.inspector_documents
     where category=cat.name and status in ('active','pending');
   if used_count>0 then raise exception 'Move the % existing document(s) to another category before archiving',used_count; end if;
   update public.inspector_resource_categories set active=false,updated_at=now()
     where id=cat.id returning * into result;
  elsif p_action='restore' then
   update public.inspector_resource_categories set active=true,updated_at=now()
     where id=cat.id returning * into result;
  end if;
 end if;
 return result;
end $function$;

CREATE OR REPLACE FUNCTION public.newsletter_flag_after_calendar_sync()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare current_version integer; had_previous boolean; existing_kind text; new_kind text;
begin
 if new.status <> 'succeeded' or old.status='succeeded' then return new; end if;
 select version into current_version from public.events where id=new.event_id;
 if current_version is null or current_version<>new.event_version then return new; end if;
 select exists (
  select 1 from public.calendar_jobs j where j.event_id=new.event_id
    and j.id<>new.id and j.status='succeeded'
    and j.event_version<=new.event_version
 ) into had_previous;
 select f.change_kind into existing_kind from public.newsletter_event_flags f
  where f.event_id=new.event_id and f.dirty=true;
 new_kind:=case when new.action='cancel' then 'cancelled'
                when existing_kind='new' then 'new'
                when not had_previous then 'new'
                else 'updated' end;
 insert into public.newsletter_event_flags(event_id,event_version,change_kind,dirty,changed_at)
 values (new.event_id,new.event_version,new_kind,true,now())
 on conflict(event_id) do update set
  event_version=excluded.event_version,change_kind=excluded.change_kind,
  dirty=true,changed_at=now();
 return new;
end $function$;

CREATE OR REPLACE FUNCTION public.populate_new_event_extras()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare p jsonb;
begin
 select proposed_fields into p from public.event_requests
 where request_code=new.event_code and request_type='new' limit 1;
 if p is not null then
  new.attire:=nullif(p->>'attire','');
  new.invited_audience:=nullif(p->>'invited_audience','');
  new.virtual_meeting_url:=nullif(p->>'virtual_meeting_url','');
 end if;
 return new;
end;$function$;

CREATE OR REPLACE FUNCTION public.prevent_event_history_rewrite()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  raise exception 'event_history is append-only';
end;
$function$;

CREATE OR REPLACE FUNCTION public.review_request_checked(p_id uuid, p_staff uuid, p_decision text, p_note text, p_version integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v int; s text;
begin
 select edit_version,status into v,s from public.event_requests where id=p_id for update;
 if not found then raise exception 'Request not found'; end if;
 if s not in ('pending','needs_correction') then raise exception 'Request already processed'; end if;
 if v is distinct from p_version then raise exception 'Another inspector edited this request. Reload before approval.'; end if;
 return public.approve_request(p_id,p_staff,p_decision,p_note);
end $function$;

CREATE OR REPLACE FUNCTION public.save_inspector_request_edit(p_id uuid, p_staff uuid, p_version integer, p_fields jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.event_requests%rowtype; who text; new_version int;
begin
 select email into who from public.staff_accounts where id=p_staff and enabled=true;
 if who is null then raise exception 'Enabled inspector required'; end if;
 select * into r from public.event_requests where id=p_id for update;
 if not found or r.status not in ('pending','needs_correction') then raise exception 'Request is no longer editable'; end if;
 if r.request_type not in ('new','change') then raise exception 'Only new and change requests can be edited'; end if;
 if r.edit_version is distinct from p_version then raise exception 'Another inspector saved a newer revision. Reload before editing.'; end if;
 if jsonb_typeof(p_fields)<>'object' then raise exception 'Invalid edit details'; end if;
 new_version:=r.edit_version+1;
 update public.event_requests set inspector_edits=p_fields,edit_version=new_version,edited_by=p_staff,edited_at=now(),updated_at=now() where id=p_id;
 insert into public.event_history(event_id,request_id,action,actor_staff_id,actor_email,before_data,after_data)
 values(r.event_id,r.id,'inspector_edited',p_staff,who,
 jsonb_build_object('fields',coalesce(r.inspector_edits,r.proposed_fields),'revision',r.edit_version),
 jsonb_build_object('fields',p_fields,'revision',new_version));
 return jsonb_build_object('ok',true,'edit_version',new_version);
end $function$;

CREATE OR REPLACE FUNCTION public.set_inspector_enabled(p_actor uuid, p_target uuid, p_expected_enabled boolean, p_enabled boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
 actor public.staff_accounts%rowtype;
 target public.staff_accounts%rowtype;
 updated public.staff_accounts%rowtype;
begin
 select * into actor from public.staff_accounts where id=p_actor;
 if not found or actor.role<>'admin' or not actor.enabled or actor.removed_at is not null
 then raise exception 'Administrator access required'; end if;

 if p_target=p_actor then raise exception 'You cannot disable or change your own account with this action'; end if;
 if p_enabled is null or p_expected_enabled is null or p_enabled=p_expected_enabled
 then raise exception 'Invalid activation request'; end if;

 select * into target from public.staff_accounts where id=p_target for update;
 if not found then raise exception 'Inspector not found'; end if;
 if target.role<>'inspector' then raise exception 'Administrator accounts cannot be toggled'; end if;
 if target.removed_at is not null then raise exception 'Removed inspector accounts must be restored instead'; end if;
 if target.enabled is distinct from p_expected_enabled
 then raise exception 'Inspector status has changed. Refresh the list and try again'; end if;

 update public.staff_accounts set enabled=p_enabled,updated_at=now()
 where id=p_target and role='inspector' and removed_at is null
 returning * into updated;
 if not found then raise exception 'Inspector access could not be changed'; end if;

 insert into public.inspector_admin_history(actor_staff_id,target_staff_id,action)
 values(p_actor,p_target,case when p_enabled then 'activated' else 'deactivated' end);
 return jsonb_build_object('id',updated.id,'enabled',updated.enabled,
   'action',case when p_enabled then 'activated' else 'deactivated' end);
end;
$function$;

CREATE OR REPLACE FUNCTION public.validate_inspector_document_category()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if not exists(select 1 from public.inspector_resource_categories
   where name=new.category and active=true)
 then raise exception 'Choose an active document category'; end if;
 return new;
end $function$;

CREATE TRIGGER newsletter_calendar_success AFTER UPDATE OF status ON calendar_jobs FOR EACH ROW WHEN (new.status = 'succeeded'::text AND old.status IS DISTINCT FROM new.status) EXECUTE FUNCTION newsletter_flag_after_calendar_sync();

CREATE TRIGGER event_history_append_only BEFORE DELETE OR UPDATE ON event_history FOR EACH ROW EXECUTE FUNCTION prevent_event_history_rewrite();

CREATE TRIGGER event_new_extra_fields BEFORE INSERT ON events FOR EACH ROW EXECUTE FUNCTION populate_new_event_extras();

CREATE TRIGGER trg_capture_event_poc_position AFTER INSERT OR UPDATE OF poc_position ON events FOR EACH ROW EXECUTE FUNCTION capture_event_poc_position();

CREATE TRIGGER inspector_documents_category_active_trigger BEFORE INSERT OR UPDATE OF category ON inspector_documents FOR EACH ROW EXECUTE FUNCTION validate_inspector_document_category();

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC, anon, authenticated;

REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, anon, authenticated;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon, authenticated;

GRANT INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.bulk_event_imports TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.calendar_jobs TO service_role;

GRANT REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE public.districts TO service_role;

GRANT INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE public.division_correction_history TO service_role;

GRANT INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.division_correction_requests TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.email_deliveries TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.event_attachments TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.event_history TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.event_requests TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.event_types TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.events TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.inspector_admin_history TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.inspector_documents TO service_role;

GRANT INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.inspector_resource_categories TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.inspector_resource_history TO service_role;

GRANT INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE public.lodge_change_history TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.lodges TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.newsletter_event_flags TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.newsletter_runs TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.newsletter_settings TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.newsletter_signup_limits TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.newsletter_subscribers TO service_role;

GRANT REFERENCES, TRIGGER, TRUNCATE ON TABLE public.poc_positions TO service_role;

GRANT REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE public.request_index TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.staff_accounts TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.submission_verifications TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.system_settings TO service_role;

GRANT USAGE, SELECT ON SEQUENCE public.event_types_id_seq TO service_role;

GRANT USAGE, SELECT ON SEQUENCE public.inspector_resource_history_id_seq TO service_role;

GRANT EXECUTE ON FUNCTION public.resolve_calendar_title(text, text, text, text, text, text) TO service_role;

GRANT EXECUTE ON FUNCTION public.admin_undo_last_published_edit(uuid, uuid, uuid, integer) TO service_role;

GRANT EXECUTE ON FUNCTION public.approve_request(uuid, uuid, text, text) TO service_role;

GRANT EXECUTE ON FUNCTION public.bulk_import_new_request(text, jsonb, text, text, text, text, text, text, uuid, uuid, integer) TO service_role;

GRANT EXECUTE ON FUNCTION public.capture_event_poc_position() TO service_role;

GRANT EXECUTE ON FUNCTION public.change_inspector_resource(uuid, uuid, text, text, text, text) TO service_role;

GRANT EXECUTE ON FUNCTION public.finalize_inspector_resource(uuid, uuid, text) TO service_role;

GRANT EXECUTE ON FUNCTION public.inspector_dashboard_data() TO service_role;

GRANT EXECUTE ON FUNCTION public.inspector_retry_calendar_sync(uuid, uuid, integer) TO service_role;

GRANT EXECUTE ON FUNCTION public.inspector_update_lodge(uuid, uuid, integer, jsonb) TO service_role;

GRANT EXECUTE ON FUNCTION public.inspector_update_published_event(uuid, uuid, integer, jsonb) TO service_role;

GRANT EXECUTE ON FUNCTION public.manage_inspector_resource_category(uuid, text, uuid, text) TO service_role;

GRANT EXECUTE ON FUNCTION public.review_request_checked(uuid, uuid, text, text, integer) TO service_role;

GRANT EXECUTE ON FUNCTION public.save_inspector_request_edit(uuid, uuid, integer, jsonb) TO service_role;

GRANT EXECUTE ON FUNCTION public.set_inspector_enabled(uuid, uuid, boolean, boolean) TO service_role;

GRANT EXECUTE ON FUNCTION public.validate_inspector_document_category() TO service_role;
