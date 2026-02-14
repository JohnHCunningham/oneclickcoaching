-- MIGRATION 2: Add Coach Role
-- Run this second

-- Update role constraint
DO $$
BEGIN
    ALTER TABLE "User_Roles" DROP CONSTRAINT IF EXISTS "User_Roles_role_check";
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE "User_Roles"
ADD CONSTRAINT "User_Roles_role_check"
CHECK (role IN ('manager', 'coach', 'user'));

-- Helper function
CREATE OR REPLACE FUNCTION is_coach()
RETURNS BOOLEAN
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM "User_Roles"
        WHERE user_id = auth.uid() AND role IN ('manager', 'coach')
    );
END $$;

-- Update get_user_account to include methodology
DROP FUNCTION IF EXISTS get_user_account();
CREATE FUNCTION get_user_account()
RETURNS TABLE (
    account_id UUID,
    company_name VARCHAR(255),
    logo_url TEXT,
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    primary_color VARCHAR(7),
    methodology TEXT,
    user_role VARCHAR(20),
    is_manager BOOLEAN,
    is_coach BOOLEAN
)
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT a.id, a.company_name, a.logo_url, a.contact_email, a.contact_phone,
           a.primary_color, a.methodology, ur.role,
           (ur.role = 'manager'), (ur.role IN ('manager', 'coach'))
    FROM "Accounts" a
    JOIN "User_Roles" ur ON a.id = ur.account_id
    WHERE ur.user_id = auth.uid()
    LIMIT 1;
END $$;

DO $$ BEGIN RAISE NOTICE '✅ Migration 2 complete: Coach role added'; END $$;
