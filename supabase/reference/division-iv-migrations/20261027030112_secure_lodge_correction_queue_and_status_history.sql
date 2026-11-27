ALTER TABLE public.division_correction_requests
 ADD COLUMN IF NOT EXISTS source_fingerprint text,
 ADD CONSTRAINT correction_queue_status_allowed CHECK (status IN ('pending','reviewing','completed','rejected')),
 ADD CONSTRAINT correction_queue_category_allowed CHECK (category IN ('meeting','location','directory','other')),
 ADD CONSTRAINT correction_queue_lodge_length CHECK (char_length(lodge_name) BETWEEN 2 AND 160),
 ADD CONSTRAINT correction_queue_details_length CHECK (char_length(details) BETWEEN 15 AND 1600);
CREATE INDEX IF NOT EXISTS division_correction_queue_created_at ON public.division_correction_requests (created_at DESC);
CREATE INDEX IF NOT EXISTS division_correction_queue_rate ON public.division_correction_requests (source_fingerprint,created_at DESC);
REVOKE ALL ON public.division_correction_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT,INSERT,UPDATE ON public.division_correction_requests TO service_role;
CREATE TABLE IF NOT EXISTS public.division_correction_history (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 correction_id uuid NOT NULL REFERENCES public.division_correction_requests(id),
 action text NOT NULL,
 previous_status text,
 new_status text,
 notes text,
 actor_staff_id uuid,
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.division_correction_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.division_correction_history FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT ON public.division_correction_history TO service_role;
CREATE INDEX IF NOT EXISTS division_correction_history_lookup ON public.division_correction_history (correction_id,created_at DESC);
