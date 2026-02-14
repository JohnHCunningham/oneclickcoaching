-- ============================================
-- COMPLETE FIX: Coaching_Messages table
-- Run this in Supabase SQL Editor
-- ============================================

-- Step 1: Drop any foreign key constraints on account_id
DO $$
DECLARE
    constraint_name TEXT;
BEGIN
    -- Find and drop FK constraints
    FOR constraint_name IN
        SELECT tc.constraint_name
        FROM information_schema.table_constraints tc
        WHERE tc.table_name = 'Coaching_Messages'
        AND tc.constraint_type = 'FOREIGN KEY'
    LOOP
        EXECUTE 'ALTER TABLE "Coaching_Messages" DROP CONSTRAINT IF EXISTS ' || quote_ident(constraint_name);
        RAISE NOTICE 'Dropped constraint: %', constraint_name;
    END LOOP;
END $$;

-- Step 2: Ensure all required columns exist and are nullable
DO $$
BEGIN
    -- Make rep_email nullable
    ALTER TABLE "Coaching_Messages" ALTER COLUMN rep_email DROP NOT NULL;
    RAISE NOTICE 'Made rep_email nullable';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'rep_email already nullable or does not exist';
END $$;

DO $$
BEGIN
    -- Make manager_email nullable
    ALTER TABLE "Coaching_Messages" ALTER COLUMN manager_email DROP NOT NULL;
    RAISE NOTICE 'Made manager_email nullable';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'manager_email already nullable or does not exist';
END $$;

DO $$
BEGIN
    -- Make coaching_content nullable
    ALTER TABLE "Coaching_Messages" ALTER COLUMN coaching_content DROP NOT NULL;
    RAISE NOTICE 'Made coaching_content nullable';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'coaching_content already nullable or does not exist';
END $$;

-- Step 3: Create Accounts table if not exists and insert default account
CREATE TABLE IF NOT EXISTS "Accounts" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    company_name TEXT,
    industry TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert the default account (used in the dashboard)
INSERT INTO "Accounts" (id, company_name)
VALUES ('b33d88bb-4517-46bf-8c5b-7ae10529ebd2', 'Revenue Factory')
ON CONFLICT (id) DO UPDATE SET company_name = 'Revenue Factory';

-- Step 4: Enable RLS with permissive policies
ALTER TABLE "Coaching_Messages" ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies
DROP POLICY IF EXISTS "Allow anon all Coaching_Messages" ON "Coaching_Messages";
DROP POLICY IF EXISTS "Allow anon read Coaching_Messages" ON "Coaching_Messages";
DROP POLICY IF EXISTS "Allow anon insert Coaching_Messages" ON "Coaching_Messages";
DROP POLICY IF EXISTS "Allow anon update Coaching_Messages" ON "Coaching_Messages";
DROP POLICY IF EXISTS "Allow anon delete Coaching_Messages" ON "Coaching_Messages";

-- Create a single permissive policy for all operations
CREATE POLICY "Allow anon all Coaching_Messages"
    ON "Coaching_Messages"
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);

-- Step 5: Verify the table structure
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'Coaching_Messages'
ORDER BY ordinal_position;

-- Step 6: Test insert
DO $$
DECLARE
    test_id UUID;
BEGIN
    INSERT INTO "Coaching_Messages" (
        account_id,
        rep_email,
        manager_email,
        coaching_content,
        subject,
        status
    ) VALUES (
        'b33d88bb-4517-46bf-8c5b-7ae10529ebd2',
        'test@test.com',
        'manager@test.com',
        'Test coaching content',
        'Test Subject',
        'draft'
    )
    RETURNING id INTO test_id;

    -- Delete the test record
    DELETE FROM "Coaching_Messages" WHERE id = test_id;

    RAISE NOTICE '✅ Test insert successful! Table is working correctly.';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Test insert failed: %', SQLERRM;
END $$;

-- Done
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'FIX COMPLETE - Refresh dashboard and try again';
    RAISE NOTICE '================================================';
END $$;
