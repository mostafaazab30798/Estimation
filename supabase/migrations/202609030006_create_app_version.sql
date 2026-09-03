-- Create app_version table for in-app update checks
CREATE TABLE IF NOT EXISTS public.app_version (
  id             INT PRIMARY KEY DEFAULT 1,
  latest_version TEXT NOT NULL,
  version_code   INT NOT NULL DEFAULT 1,
  release_notes  TEXT NOT NULL DEFAULT '',
  download_url   TEXT NOT NULL DEFAULT '',
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT single_row CHECK (id = 1)
);

-- Seed row 1 if not exists
INSERT INTO public.app_version (id, latest_version, version_code, release_notes, download_url)
VALUES (1, '1.12.1', 24, 'سهرة ورق — الإصدار 1.12.1', '')
ON CONFLICT (id) DO NOTHING;

-- Enable RLS & public read access
ALTER TABLE public.app_version ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'app_version' AND policyname = 'Allow read access to everyone'
  ) THEN
    CREATE POLICY "Allow read access to everyone"
    ON public.app_version FOR SELECT
    USING (true);
  END IF;
END $$;
