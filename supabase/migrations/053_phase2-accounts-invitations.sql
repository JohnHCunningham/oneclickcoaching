-- Phase 2: Account & Rep Management Schema Changes

-- Expand role CHECK on Users table to include all roles
ALTER TABLE IF EXISTS "Users"
  DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE IF EXISTS "Users"
  ADD CONSTRAINT users_role_check
  CHECK (role IN ('admin', 'manager', 'coach', 'rep'));

-- Add admin_designation column to Accounts
ALTER TABLE IF EXISTS "Accounts"
  ADD COLUMN IF NOT EXISTS admin_designation TEXT;

-- Create Invitations table
CREATE TABLE IF NOT EXISTS "Invitations" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'rep' CHECK (role IN ('admin', 'manager', 'coach', 'rep')),
  token TEXT NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(32), 'hex'),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired', 'revoked')),
  invited_by UUID REFERENCES auth.users(id),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS on Invitations
ALTER TABLE "Invitations" ENABLE ROW LEVEL SECURITY;

-- Policies for Invitations
CREATE POLICY "admins_manage_invitations" ON "Invitations"
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM "Users"
      WHERE "Users".auth_id = auth.uid()
      AND "Users".account_id = "Invitations".account_id
      AND "Users".role IN ('admin', 'manager')
    )
  );

-- Allow reading own invitation by token (for accept-invite page)
CREATE POLICY "read_own_invitation" ON "Invitations"
  FOR SELECT
  USING (true);

-- Function to accept an invitation
CREATE OR REPLACE FUNCTION accept_invitation(p_token TEXT, p_auth_id UUID)
RETURNS JSON
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $func$
DECLARE
  v_invitation RECORD;
  v_user_id UUID;
BEGIN
  -- Find valid invitation
  SELECT * INTO v_invitation
  FROM "Invitations"
  WHERE token = p_token
    AND status = 'pending'
    AND expires_at > NOW();

  IF NOT FOUND THEN
    RETURN json_build_object('error', 'Invalid or expired invitation');
  END IF;

  -- Create user record linked to account
  INSERT INTO "Users" (auth_id, account_id, role, email)
  VALUES (p_auth_id, v_invitation.account_id, v_invitation.role, v_invitation.email)
  RETURNING id INTO v_user_id;

  -- Mark invitation as accepted
  UPDATE "Invitations"
  SET status = 'accepted', updated_at = NOW()
  WHERE id = v_invitation.id;

  RETURN json_build_object('success', true, 'user_id', v_user_id);
END $func$;

-- Function to create account on signup (admin becomes account owner)
CREATE OR REPLACE FUNCTION create_account_on_signup(
  p_auth_id UUID,
  p_email TEXT,
  p_full_name TEXT,
  p_company_name TEXT
)
RETURNS JSON
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $func$
DECLARE
  v_account_id UUID;
  v_user_id UUID;
BEGIN
  -- Create the account
  INSERT INTO "Accounts" (name, admin_designation)
  VALUES (p_company_name, 'owner')
  RETURNING id INTO v_account_id;

  -- Create the admin user
  INSERT INTO "Users" (auth_id, account_id, role, email, full_name)
  VALUES (p_auth_id, v_account_id, 'admin', p_email, p_full_name)
  RETURNING id INTO v_user_id;

  RETURN json_build_object(
    'success', true,
    'account_id', v_account_id,
    'user_id', v_user_id
  );
END $func$;

-- Index for fast token lookups
CREATE INDEX IF NOT EXISTS idx_invitations_token ON "Invitations"(token);
CREATE INDEX IF NOT EXISTS idx_invitations_account ON "Invitations"(account_id);
CREATE INDEX IF NOT EXISTS idx_users_auth_id ON "Users"(auth_id);

SELECT 'Phase 2 migration complete' as status;
