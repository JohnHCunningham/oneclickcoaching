-- ============================================
-- FIX: Remove NOT NULL constraints for development
-- Run this in Supabase SQL Editor
-- ============================================

-- Make columns nullable for easier development/testing
ALTER TABLE "Coaching_Messages" ALTER COLUMN rep_email DROP NOT NULL;
ALTER TABLE "Coaching_Messages" ALTER COLUMN manager_email DROP NOT NULL;
ALTER TABLE "Coaching_Messages" ALTER COLUMN coaching_content DROP NOT NULL;

-- Also ensure account_id doesn't have a foreign key constraint issue
-- First, check if there's a FK constraint and drop it
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name LIKE '%account%'
        AND table_name = 'Coaching_Messages'
    ) THEN
        -- Just log it for now - we won't drop automatically
        RAISE NOTICE 'Found account_id constraint - may need to drop manually';
    END IF;
END $$;

-- Insert the default account if not exists (in case there's an FK constraint)
INSERT INTO "Accounts" (id, company_name, status)
VALUES ('b33d88bb-4517-46bf-8c5b-7ae10529ebd2', 'Default Account', 'active')
ON CONFLICT (id) DO NOTHING;

-- Verify the table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'Coaching_Messages'
ORDER BY ordinal_position;
