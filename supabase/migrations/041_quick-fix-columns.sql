-- ============================================
-- QUICK FIX: Add missing columns
-- Run this in Supabase SQL Editor
-- ============================================

-- Add methodology_scores to Synced_Conversations
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'Synced_Conversations' AND column_name = 'methodology_scores'
    ) THEN
        ALTER TABLE "Synced_Conversations" ADD COLUMN methodology_scores JSONB DEFAULT '{}';
        RAISE NOTICE 'Added methodology_scores column to Synced_Conversations';
    ELSE
        RAISE NOTICE 'methodology_scores column already exists';
    END IF;
END $$;

-- Add analyzed_at to Synced_Conversations
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'Synced_Conversations' AND column_name = 'analyzed_at'
    ) THEN
        ALTER TABLE "Synced_Conversations" ADD COLUMN analyzed_at TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE 'Added analyzed_at column to Synced_Conversations';
    ELSE
        RAISE NOTICE 'analyzed_at column already exists';
    END IF;
END $$;

-- Ensure Coaching_Messages has all required columns
DO $$
BEGIN
    -- Check if table exists first
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'Coaching_Messages') THEN
        -- Add manager_email if missing
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'Coaching_Messages' AND column_name = 'manager_email'
        ) THEN
            ALTER TABLE "Coaching_Messages" ADD COLUMN manager_email TEXT;
            RAISE NOTICE 'Added manager_email column';
        END IF;

        -- Add generated_at if missing
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'Coaching_Messages' AND column_name = 'generated_at'
        ) THEN
            ALTER TABLE "Coaching_Messages" ADD COLUMN generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
            RAISE NOTICE 'Added generated_at column';
        END IF;

        -- Add acknowledged_at if missing
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'Coaching_Messages' AND column_name = 'acknowledged_at'
        ) THEN
            ALTER TABLE "Coaching_Messages" ADD COLUMN acknowledged_at TIMESTAMP WITH TIME ZONE;
            RAISE NOTICE 'Added acknowledged_at column';
        END IF;

        -- Add rep_response if missing
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'Coaching_Messages' AND column_name = 'rep_response'
        ) THEN
            ALTER TABLE "Coaching_Messages" ADD COLUMN rep_response TEXT;
            RAISE NOTICE 'Added rep_response column';
        END IF;

        -- Add subject if missing
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'Coaching_Messages' AND column_name = 'subject'
        ) THEN
            ALTER TABLE "Coaching_Messages" ADD COLUMN subject TEXT;
            RAISE NOTICE 'Added subject column';
        END IF;

        -- Add priority if missing
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'Coaching_Messages' AND column_name = 'priority'
        ) THEN
            ALTER TABLE "Coaching_Messages" ADD COLUMN priority TEXT DEFAULT 'medium';
            RAISE NOTICE 'Added priority column';
        END IF;

        RAISE NOTICE 'Coaching_Messages table updated';
    ELSE
        RAISE NOTICE 'Coaching_Messages table does not exist - run integrations-working.sql first';
    END IF;
END $$;

-- Enable RLS but allow anon access for now (development mode)
ALTER TABLE "Synced_Conversations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Coaching_Messages" ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow anon read Synced_Conversations" ON "Synced_Conversations";
DROP POLICY IF EXISTS "Allow anon read Coaching_Messages" ON "Coaching_Messages";
DROP POLICY IF EXISTS "Allow anon insert Coaching_Messages" ON "Coaching_Messages";
DROP POLICY IF EXISTS "Allow anon update Coaching_Messages" ON "Coaching_Messages";

-- Create permissive policies for development
CREATE POLICY "Allow anon read Synced_Conversations"
    ON "Synced_Conversations" FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "Allow anon read Coaching_Messages"
    ON "Coaching_Messages" FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "Allow anon insert Coaching_Messages"
    ON "Coaching_Messages" FOR INSERT
    TO anon
    WITH CHECK (true);

CREATE POLICY "Allow anon update Coaching_Messages"
    ON "Coaching_Messages" FOR UPDATE
    TO anon
    USING (true);

-- Done
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Quick fix complete!';
    RAISE NOTICE 'Refresh your dashboard to test.';
END $$;
