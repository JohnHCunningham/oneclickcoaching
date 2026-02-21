-- White-label branding fields for accounts
ALTER TABLE "Accounts"
  ADD COLUMN IF NOT EXISTS logo_url TEXT,
  ADD COLUMN IF NOT EXISTS primary_color TEXT DEFAULT '#0C1030',
  ADD COLUMN IF NOT EXISTS accent_color TEXT DEFAULT '#10C3B0',
  ADD COLUMN IF NOT EXISTS company_name TEXT,
  ADD COLUMN IF NOT EXISTS email_from_name TEXT DEFAULT 'One Click Coaching';
