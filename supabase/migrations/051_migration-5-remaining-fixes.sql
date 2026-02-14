SELECT 1;

-- Fix user_goals table RLS
ALTER TABLE IF EXISTS "user_goals" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "auth_user_goals" ON "user_goals";
CREATE POLICY "auth_user_goals" ON "user_goals"
    FOR ALL USING (auth.role() = 'authenticated');

-- Fix is_admin function search_path
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $func$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM "User_Roles"
        WHERE user_id = auth.uid() AND role = 'manager'
    );
END $func$;

-- Fix is_manager function search_path
CREATE OR REPLACE FUNCTION is_manager()
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $func$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM "User_Roles"
        WHERE user_id = auth.uid() AND role = 'manager'
    );
END $func$;

SELECT 'Migration 5 complete' as status;
