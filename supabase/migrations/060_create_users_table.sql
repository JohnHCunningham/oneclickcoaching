-- Migration 060: Create Users table
-- The frontend expects a "Users" table that combines auth info with account/role.
-- This creates the table and backfills from existing User_Roles + auth.users data.

CREATE TABLE IF NOT EXISTS "Users" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  account_id UUID REFERENCES "Accounts"(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  first_name TEXT,
  role TEXT DEFAULT 'rep' CHECK (role IN ('admin', 'manager', 'coach', 'rep')),
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_auth_id ON "Users"(auth_id);
CREATE INDEX IF NOT EXISTS idx_users_account_id ON "Users"(account_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON "Users"(email);

-- RLS
ALTER TABLE "Users" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own record"
  ON "Users" FOR SELECT
  USING (auth_id = auth.uid());

CREATE POLICY "Users can view teammates in their account"
  ON "Users" FOR SELECT
  USING (account_id IN (
    SELECT account_id FROM "Users" WHERE auth_id = auth.uid()
  ));

CREATE POLICY "Users can update their own record"
  ON "Users" FOR UPDATE
  USING (auth_id = auth.uid());

CREATE POLICY "Admins and managers can manage users in their account"
  ON "Users" FOR ALL
  USING (account_id IN (
    SELECT account_id FROM "Users"
    WHERE auth_id = auth.uid() AND role IN ('admin', 'manager')
  ));

-- Backfill from existing User_Roles + auth.users
INSERT INTO "Users" (auth_id, account_id, email, role, created_at)
SELECT
  ur.user_id AS auth_id,
  ur.account_id,
  au.email,
  CASE
    WHEN ur.role = 'manager' THEN 'manager'
    WHEN ur.role = 'user' THEN 'rep'
    ELSE ur.role
  END AS role,
  ur.created_at
FROM "User_Roles" ur
JOIN auth.users au ON au.id = ur.user_id
ON CONFLICT (auth_id) DO NOTHING;

-- Update trigger
CREATE OR REPLACE FUNCTION update_users_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at
  BEFORE UPDATE ON "Users"
  FOR EACH ROW
  EXECUTE FUNCTION update_users_updated_at();
