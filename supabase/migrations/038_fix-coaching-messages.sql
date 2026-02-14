-- ============================================
-- FIX: Coaching_Messages table columns
-- Run this in Supabase SQL Editor
-- ============================================

-- Check if table exists, if not create it
CREATE TABLE IF NOT EXISTS "Coaching_Messages" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    account_id UUID,
    rep_email TEXT NOT NULL,
    manager_email TEXT NOT NULL,
    status TEXT DEFAULT 'draft',
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    approved_at TIMESTAMP WITH TIME ZONE,
    sent_at TIMESTAMP WITH TIME ZONE,
    read_at TIMESTAMP WITH TIME ZONE,
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    coaching_content TEXT NOT NULL,
    methodology TEXT,
    based_on_calls JSONB DEFAULT '[]',
    based_on_date_range JSONB,
    rep_response TEXT,
    responded_at TIMESTAMP WITH TIME ZONE,
    reply_token TEXT UNIQUE,
    email_opened_at TIMESTAMP WITH TIME ZONE,
    last_error TEXT,
    email_provider_id TEXT,
    subject TEXT,
    priority TEXT DEFAULT 'medium',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add any missing columns
DO $$
BEGIN
    -- manager_email
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Coaching_Messages' AND column_name = 'manager_email') THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN manager_email TEXT;
    END IF;

    -- generated_at
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Coaching_Messages' AND column_name = 'generated_at') THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;

    -- rep_email
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Coaching_Messages' AND column_name = 'rep_email') THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN rep_email TEXT;
    END IF;

    -- status
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Coaching_Messages' AND column_name = 'status') THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN status TEXT DEFAULT 'draft';
    END IF;

    -- coaching_content
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Coaching_Messages' AND column_name = 'coaching_content') THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN coaching_content TEXT;
    END IF;

    -- sent_at
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Coaching_Messages' AND column_name = 'sent_at') THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN sent_at TIMESTAMP WITH TIME ZONE;
    END IF;

    -- read_at
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Coaching_Messages' AND column_name = 'read_at') THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN read_at TIMESTAMP WITH TIME ZONE;
    END IF;

    -- rep_response
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Coaching_Messages' AND column_name = 'rep_response') THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN rep_response TEXT;
    END IF;

    -- responded_at
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Coaching_Messages' AND column_name = 'responded_at') THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN responded_at TIMESTAMP WITH TIME ZONE;
    END IF;

    -- acknowledged_at
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Coaching_Messages' AND column_name = 'acknowledged_at') THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN acknowledged_at TIMESTAMP WITH TIME ZONE;
    END IF;

    -- reply_token
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Coaching_Messages' AND column_name = 'reply_token') THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN reply_token TEXT UNIQUE;
    END IF;

    -- subject
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Coaching_Messages' AND column_name = 'subject') THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN subject TEXT;
    END IF;

    -- priority
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Coaching_Messages' AND column_name = 'priority') THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN priority TEXT DEFAULT 'medium';
    END IF;

    -- methodology
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Coaching_Messages' AND column_name = 'methodology') THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN methodology TEXT;
    END IF;

    RAISE NOTICE 'All columns verified/added';
END $$;

-- Enable RLS
ALTER TABLE "Coaching_Messages" ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Allow anon all Coaching_Messages" ON "Coaching_Messages";
DROP POLICY IF EXISTS "Allow anon read Coaching_Messages" ON "Coaching_Messages";
DROP POLICY IF EXISTS "Allow anon insert Coaching_Messages" ON "Coaching_Messages";
DROP POLICY IF EXISTS "Allow anon update Coaching_Messages" ON "Coaching_Messages";

-- Create permissive policy for development
CREATE POLICY "Allow anon all Coaching_Messages"
    ON "Coaching_Messages"
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_coaching_messages_manager
    ON "Coaching_Messages"(manager_email, generated_at DESC);

CREATE INDEX IF NOT EXISTS idx_coaching_messages_rep
    ON "Coaching_Messages"(rep_email, sent_at DESC);

-- Done
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Coaching_Messages table fixed!';
    RAISE NOTICE 'Refresh the dashboard to test.';
END $$;
