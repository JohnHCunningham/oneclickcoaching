-- ============================================
-- COMPLETE RLS SETUP FOR DAILY TRACKER
-- Run this in your Supabase SQL Editor
-- ============================================

-- First, ensure all tables exist by running their creation scripts if needed
-- Then add user_id columns and set up RLS

-- ============================================
-- STEP 1: Add user_id column to all tables
-- ============================================

-- Daily_Tracker
ALTER TABLE "Daily_Tracker"
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- Sales
ALTER TABLE "Sales"
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- Projects (if you want to protect this too)
ALTER TABLE "Projects"
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- Weekly_Goals
ALTER TABLE "Weekly_Goals"
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- Coaching_Insights
ALTER TABLE "Coaching_Insights"
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- Email_Tracking (note: not capitalized in the schema)
ALTER TABLE Email_Tracking
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- Conversation_Analyses (only if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables
               WHERE table_name = 'Conversation_Analyses') THEN
        ALTER TABLE "Conversation_Analyses"
        ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
    ELSE
        RAISE NOTICE 'Table Conversation_Analyses does not exist - skipping';
    END IF;
END $$;

-- Conversation_Improvement_Trends (only if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables
               WHERE table_name = 'Conversation_Improvement_Trends') THEN
        ALTER TABLE "Conversation_Improvement_Trends"
        ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
    ELSE
        RAISE NOTICE 'Table Conversation_Improvement_Trends does not exist - skipping';
    END IF;
END $$;

-- ============================================
-- STEP 2: Enable RLS on all tables
-- ============================================

ALTER TABLE "Daily_Tracker" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Sales" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Projects" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Weekly_Goals" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Coaching_Insights" ENABLE ROW LEVEL SECURITY;
ALTER TABLE Email_Tracking ENABLE ROW LEVEL SECURITY;

-- Enable RLS on conversation tables if they exist
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables
               WHERE table_name = 'Conversation_Analyses') THEN
        EXECUTE 'ALTER TABLE "Conversation_Analyses" ENABLE ROW LEVEL SECURITY';
    END IF;

    IF EXISTS (SELECT FROM information_schema.tables
               WHERE table_name = 'Conversation_Improvement_Trends') THEN
        EXECUTE 'ALTER TABLE "Conversation_Improvement_Trends" ENABLE ROW LEVEL SECURITY';
    END IF;
END $$;

-- ============================================
-- STEP 3: Create RLS Policies
-- ============================================

-- Daily_Tracker policies
DROP POLICY IF EXISTS "Users can view own tracker data" ON "Daily_Tracker";
CREATE POLICY "Users can view own tracker data"
ON "Daily_Tracker" FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own tracker data" ON "Daily_Tracker";
CREATE POLICY "Users can insert own tracker data"
ON "Daily_Tracker" FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own tracker data" ON "Daily_Tracker";
CREATE POLICY "Users can update own tracker data"
ON "Daily_Tracker" FOR UPDATE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own tracker data" ON "Daily_Tracker";
CREATE POLICY "Users can delete own tracker data"
ON "Daily_Tracker" FOR DELETE
USING (auth.uid() = user_id);

-- Sales policies
DROP POLICY IF EXISTS "Users can view own sales" ON "Sales";
CREATE POLICY "Users can view own sales"
ON "Sales" FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own sales" ON "Sales";
CREATE POLICY "Users can insert own sales"
ON "Sales" FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own sales" ON "Sales";
CREATE POLICY "Users can update own sales"
ON "Sales" FOR UPDATE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own sales" ON "Sales";
CREATE POLICY "Users can delete own sales"
ON "Sales" FOR DELETE
USING (auth.uid() = user_id);

-- Projects policies
DROP POLICY IF EXISTS "Users can view own projects" ON "Projects";
CREATE POLICY "Users can view own projects"
ON "Projects" FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own projects" ON "Projects";
CREATE POLICY "Users can insert own projects"
ON "Projects" FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own projects" ON "Projects";
CREATE POLICY "Users can update own projects"
ON "Projects" FOR UPDATE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own projects" ON "Projects";
CREATE POLICY "Users can delete own projects"
ON "Projects" FOR DELETE
USING (auth.uid() = user_id);

-- Weekly_Goals policies
DROP POLICY IF EXISTS "Users can view own goals" ON "Weekly_Goals";
CREATE POLICY "Users can view own goals"
ON "Weekly_Goals" FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own goals" ON "Weekly_Goals";
CREATE POLICY "Users can insert own goals"
ON "Weekly_Goals" FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own goals" ON "Weekly_Goals";
CREATE POLICY "Users can update own goals"
ON "Weekly_Goals" FOR UPDATE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own goals" ON "Weekly_Goals";
CREATE POLICY "Users can delete own goals"
ON "Weekly_Goals" FOR DELETE
USING (auth.uid() = user_id);

-- Coaching_Insights policies
DROP POLICY IF EXISTS "Users can view own insights" ON "Coaching_Insights";
CREATE POLICY "Users can view own insights"
ON "Coaching_Insights" FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own insights" ON "Coaching_Insights";
CREATE POLICY "Users can insert own insights"
ON "Coaching_Insights" FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own insights" ON "Coaching_Insights";
CREATE POLICY "Users can update own insights"
ON "Coaching_Insights" FOR UPDATE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own insights" ON "Coaching_Insights";
CREATE POLICY "Users can delete own insights"
ON "Coaching_Insights" FOR DELETE
USING (auth.uid() = user_id);

-- Email_Tracking policies
DROP POLICY IF EXISTS "Users can view own email tracking" ON Email_Tracking;
CREATE POLICY "Users can view own email tracking"
ON Email_Tracking FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own email tracking" ON Email_Tracking;
CREATE POLICY "Users can insert own email tracking"
ON Email_Tracking FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own email tracking" ON Email_Tracking;
CREATE POLICY "Users can update own email tracking"
ON Email_Tracking FOR UPDATE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own email tracking" ON Email_Tracking;
CREATE POLICY "Users can delete own email tracking"
ON Email_Tracking FOR DELETE
USING (auth.uid() = user_id);

-- Conversation_Analyses policies (only if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables
               WHERE table_name = 'Conversation_Analyses') THEN

        DROP POLICY IF EXISTS "Users can view own analyses" ON "Conversation_Analyses";
        CREATE POLICY "Users can view own analyses"
        ON "Conversation_Analyses" FOR SELECT
        USING (auth.uid() = user_id);

        DROP POLICY IF EXISTS "Users can insert own analyses" ON "Conversation_Analyses";
        CREATE POLICY "Users can insert own analyses"
        ON "Conversation_Analyses" FOR INSERT
        WITH CHECK (auth.uid() = user_id);

        DROP POLICY IF EXISTS "Users can update own analyses" ON "Conversation_Analyses";
        CREATE POLICY "Users can update own analyses"
        ON "Conversation_Analyses" FOR UPDATE
        USING (auth.uid() = user_id);

        DROP POLICY IF EXISTS "Users can delete own analyses" ON "Conversation_Analyses";
        CREATE POLICY "Users can delete own analyses"
        ON "Conversation_Analyses" FOR DELETE
        USING (auth.uid() = user_id);
    END IF;
END $$;

-- Conversation_Improvement_Trends policies (only if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables
               WHERE table_name = 'Conversation_Improvement_Trends') THEN

        DROP POLICY IF EXISTS "Users can view own trends" ON "Conversation_Improvement_Trends";
        CREATE POLICY "Users can view own trends"
        ON "Conversation_Improvement_Trends" FOR SELECT
        USING (auth.uid() = user_id);

        DROP POLICY IF EXISTS "Users can insert own trends" ON "Conversation_Improvement_Trends";
        CREATE POLICY "Users can insert own trends"
        ON "Conversation_Improvement_Trends" FOR INSERT
        WITH CHECK (auth.uid() = user_id);

        DROP POLICY IF EXISTS "Users can update own trends" ON "Conversation_Improvement_Trends";
        CREATE POLICY "Users can update own trends"
        ON "Conversation_Improvement_Trends" FOR UPDATE
        USING (auth.uid() = user_id);
    END IF;
END $$;

-- ============================================
-- STEP 4: Show completion message
-- ============================================

DO $$
DECLARE
    table_count INTEGER;
BEGIN
    -- Count tables with RLS enabled
    SELECT COUNT(*) INTO table_count
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename IN ('Daily_Tracker', 'Sales', 'Projects', 'Weekly_Goals', 'Coaching_Insights',
                      'Email_Tracking', 'Conversation_Analyses', 'Conversation_Improvement_Trends');

    RAISE NOTICE '';
    RAISE NOTICE '✅ RLS SETUP COMPLETE!';
    RAISE NOTICE '';
    RAISE NOTICE 'Tables protected: %', table_count;
    RAISE NOTICE '';
    RAISE NOTICE '🔒 Security features enabled:';
    RAISE NOTICE '   - user_id column added to all tables';
    RAISE NOTICE '   - Row Level Security enabled';
    RAISE NOTICE '   - Policies created (SELECT, INSERT, UPDATE, DELETE)';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  IMPORTANT NEXT STEPS:';
    RAISE NOTICE '   1. Update your index.html to include user_id in all INSERT queries';
    RAISE NOTICE '   2. Test with your current user account';
    RAISE NOTICE '   3. Existing data won''t be visible until you set user_id values';
    RAISE NOTICE '';
END $$;
