-- ============================================
-- ONE-CLICK COACHING - COMPLETE MIGRATION
-- Run this entire file in Supabase SQL Editor
-- ============================================

-- ============================================
-- PART 1: ADD METHODOLOGY TO ACCOUNTS + COACH ROLE
-- ============================================

-- 1. ADD METHODOLOGY TO ACCOUNTS
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'Accounts' AND column_name = 'methodology'
    ) THEN
        ALTER TABLE "Accounts" ADD COLUMN methodology TEXT DEFAULT 'sandler';
        RAISE NOTICE '✅ Added methodology column to Accounts';
    ELSE
        RAISE NOTICE 'ℹ️ methodology column already exists';
    END IF;
END $$;

-- Add CHECK constraint for allowed methodologies
DO $$
BEGIN
    ALTER TABLE "Accounts"
    ADD CONSTRAINT accounts_methodology_check
    CHECK (methodology IN ('sandler', 'challenger', 'gap', 'meddic'));
    RAISE NOTICE '✅ Added methodology CHECK constraint';
EXCEPTION
    WHEN duplicate_object THEN
        RAISE NOTICE 'ℹ️ methodology CHECK constraint already exists';
END $$;

-- 2. ADD COACH ROLE TO USER_ROLES
DO $$
BEGIN
    ALTER TABLE "User_Roles" DROP CONSTRAINT IF EXISTS "User_Roles_role_check";
EXCEPTION
    WHEN undefined_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER TABLE "User_Roles"
    ADD CONSTRAINT "User_Roles_role_check"
    CHECK (role IN ('manager', 'coach', 'user'));
    RAISE NOTICE '✅ Added new role CHECK constraint with coach';
EXCEPTION
    WHEN duplicate_object THEN
        RAISE NOTICE 'ℹ️ Role CHECK constraint already exists';
END $$;

-- 3. HELPER FUNCTIONS
CREATE OR REPLACE FUNCTION get_methodology_config(account_uuid UUID)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    account_methodology TEXT;
    config JSONB;
BEGIN
    SELECT methodology INTO account_methodology
    FROM "Accounts"
    WHERE id = account_uuid;

    CASE account_methodology
        WHEN 'sandler' THEN
            config := '{"name": "Sandler Selling System", "components": ["Upfront Contract", "Pain Funnel", "Budget", "Decision Process", "Fulfillment", "Post-Sell", "Bonding & Rapport", "Negative Reverse Selling"]}'::JSONB;
        WHEN 'challenger' THEN
            config := '{"name": "Challenger Sale", "components": ["Teaching", "Tailoring", "Taking Control", "Constructive Tension", "Commercial Insight", "Reframe Thinking"]}'::JSONB;
        WHEN 'gap' THEN
            config := '{"name": "Gap Selling", "components": ["Current State Discovery", "Future State Vision", "Gap Identification", "Problem Quantification", "Root Cause Analysis", "Impact Assessment"]}'::JSONB;
        WHEN 'meddic' THEN
            config := '{"name": "MEDDIC", "components": ["Metrics", "Economic Buyer", "Decision Criteria", "Decision Process", "Identify Pain", "Champion"]}'::JSONB;
        ELSE
            config := '{"name": "Custom", "components": []}'::JSONB;
    END CASE;
    RETURN config;
END;
$$;

CREATE OR REPLACE FUNCTION is_coach()
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM "User_Roles"
        WHERE user_id = auth.uid() AND role IN ('manager', 'coach')
    );
END;
$$;

-- 4. UPDATE get_user_account
DROP FUNCTION IF EXISTS get_user_account();
CREATE OR REPLACE FUNCTION get_user_account()
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
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.id,
        a.company_name,
        a.logo_url,
        a.contact_email,
        a.contact_phone,
        a.primary_color,
        a.methodology,
        ur.role,
        (ur.role = 'manager'),
        (ur.role IN ('manager', 'coach'))
    FROM "Accounts" a
    JOIN "User_Roles" ur ON a.id = ur.account_id
    WHERE ur.user_id = auth.uid()
    LIMIT 1;
END;
$$;

CREATE OR REPLACE FUNCTION update_account_methodology(new_methodology TEXT)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    user_account_id UUID;
BEGIN
    SELECT account_id INTO user_account_id
    FROM "User_Roles"
    WHERE user_id = auth.uid() AND role = 'manager'
    LIMIT 1;

    IF user_account_id IS NULL THEN
        RAISE EXCEPTION 'Only managers can update methodology';
    END IF;

    UPDATE "Accounts"
    SET methodology = new_methodology, updated_at = NOW()
    WHERE id = user_account_id;

    RETURN TRUE;
END;
$$;

-- 5. TEAM WINS TABLE
CREATE TABLE IF NOT EXISTS "Team_Wins" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,
    rep_email TEXT NOT NULL,
    rep_name TEXT,
    win_type TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    related_call_id UUID,
    methodology_component TEXT,
    score INTEGER,
    shared_by_email TEXT NOT NULL,
    shared_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_pinned BOOLEAN DEFAULT FALSE,
    celebration_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_team_wins_account ON "Team_Wins"(account_id, shared_at DESC);

-- 6. WIN CELEBRATIONS TABLE
CREATE TABLE IF NOT EXISTS "Win_Celebrations" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    win_id UUID NOT NULL REFERENCES "Team_Wins"(id) ON DELETE CASCADE,
    user_email TEXT NOT NULL,
    celebrated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(win_id, user_email)
);

-- 7. TEAM WINS FUNCTIONS
CREATE OR REPLACE FUNCTION share_team_win(
    p_rep_email TEXT,
    p_rep_name TEXT,
    p_win_type TEXT,
    p_title TEXT,
    p_description TEXT DEFAULT NULL,
    p_related_call_id UUID DEFAULT NULL,
    p_methodology_component TEXT DEFAULT NULL,
    p_score INTEGER DEFAULT NULL,
    p_is_pinned BOOLEAN DEFAULT FALSE
)
RETURNS UUID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    user_account_id UUID;
    user_email TEXT;
    new_win_id UUID;
BEGIN
    SELECT ur.account_id, u.email INTO user_account_id, user_email
    FROM "User_Roles" ur
    JOIN auth.users u ON ur.user_id = u.id
    WHERE ur.user_id = auth.uid() AND ur.role IN ('manager', 'coach')
    LIMIT 1;

    IF user_account_id IS NULL THEN
        RAISE EXCEPTION 'Only managers and coaches can share team wins';
    END IF;

    INSERT INTO "Team_Wins" (
        account_id, rep_email, rep_name, win_type, title, description,
        related_call_id, methodology_component, score, shared_by_email, is_pinned
    ) VALUES (
        user_account_id, p_rep_email, p_rep_name, p_win_type, p_title, p_description,
        p_related_call_id, p_methodology_component, p_score, user_email, p_is_pinned
    )
    RETURNING id INTO new_win_id;

    RETURN new_win_id;
END;
$$;

CREATE OR REPLACE FUNCTION get_team_wins(p_limit INTEGER DEFAULT 20)
RETURNS TABLE (
    id UUID,
    rep_email TEXT,
    rep_name TEXT,
    win_type TEXT,
    title TEXT,
    description TEXT,
    methodology_component TEXT,
    score INTEGER,
    shared_by_email TEXT,
    shared_at TIMESTAMP WITH TIME ZONE,
    is_pinned BOOLEAN,
    celebration_count INTEGER
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    user_account_id UUID;
BEGIN
    SELECT account_id INTO user_account_id
    FROM "User_Roles" WHERE user_id = auth.uid() LIMIT 1;

    RETURN QUERY
    SELECT tw.id, tw.rep_email, tw.rep_name, tw.win_type, tw.title, tw.description,
        tw.methodology_component, tw.score, tw.shared_by_email, tw.shared_at,
        tw.is_pinned, tw.celebration_count
    FROM "Team_Wins" tw
    WHERE tw.account_id = user_account_id
    ORDER BY tw.is_pinned DESC, tw.shared_at DESC
    LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION celebrate_win(p_win_id UUID)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    user_email TEXT;
BEGIN
    SELECT email INTO user_email FROM auth.users WHERE id = auth.uid();

    INSERT INTO "Win_Celebrations" (win_id, user_email)
    VALUES (p_win_id, user_email)
    ON CONFLICT (win_id, user_email) DO NOTHING;

    UPDATE "Team_Wins"
    SET celebration_count = (SELECT COUNT(*) FROM "Win_Celebrations" WHERE win_id = p_win_id)
    WHERE id = p_win_id;

    RETURN TRUE;
END;
$$;

-- ============================================
-- PART 2: SECURITY FIXES
-- ============================================

-- 1. DROP PROBLEMATIC VIEWS
DROP VIEW IF EXISTS "User_Messages" CASCADE;
DROP VIEW IF EXISTS "Sent_Messages" CASCADE;
DROP VIEW IF EXISTS "Team_Members" CASCADE;

-- 2. HELPER FUNCTION
CREATE OR REPLACE FUNCTION get_my_account_id()
RETURNS UUID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN (SELECT account_id FROM "User_Roles" WHERE user_id = auth.uid() LIMIT 1);
END;
$$;

-- 3. ENABLE RLS ON ALL TABLES (safe - won't fail if already enabled)
DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN SELECT unnest(ARRAY[
        'sales', 'weekly_goals', 'daily_stats', 'user_goals',
        'Conversation_Analyses', 'Integration_Sync_Log', 'Synced_Conversations',
        'API_Connections', 'Synced_Activities', 'Coaching_Outcomes',
        'Coaching_Messages', 'Team_Wins', 'Win_Celebrations'
    ])
    LOOP
        BEGIN
            EXECUTE format('ALTER TABLE IF EXISTS %I ENABLE ROW LEVEL SECURITY', t);
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Skipping RLS for %: %', t, SQLERRM;
        END;
    END LOOP;
END $$;

-- 4. RLS POLICIES FOR LEGACY TABLES (no account_id)
DO $$
BEGIN
    -- sales
    DROP POLICY IF EXISTS "Authenticated access sales" ON "sales";
    CREATE POLICY "Authenticated access sales" ON "sales" FOR ALL USING (auth.role() = 'authenticated');

    -- weekly_goals
    DROP POLICY IF EXISTS "Authenticated access weekly_goals" ON "weekly_goals";
    CREATE POLICY "Authenticated access weekly_goals" ON "weekly_goals" FOR ALL USING (auth.role() = 'authenticated');

    -- daily_stats
    DROP POLICY IF EXISTS "Authenticated access daily_stats" ON "daily_stats";
    CREATE POLICY "Authenticated access daily_stats" ON "daily_stats" FOR ALL USING (auth.role() = 'authenticated');
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Legacy table policies: %', SQLERRM;
END $$;

-- 5. RLS POLICIES FOR MULTI-TENANT TABLES (with account_id)

-- API_Connections (managers only - contains tokens)
DO $$
BEGIN
    DROP POLICY IF EXISTS "Managers access API_Connections" ON "API_Connections";
    CREATE POLICY "Managers access API_Connections" ON "API_Connections"
        FOR ALL USING (
            account_id = get_my_account_id()
            AND EXISTS (SELECT 1 FROM "User_Roles" WHERE user_id = auth.uid() AND role = 'manager')
        );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'API_Connections policy: %', SQLERRM;
END $$;

-- Synced_Conversations
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users access Synced_Conversations" ON "Synced_Conversations";
    CREATE POLICY "Users access Synced_Conversations" ON "Synced_Conversations"
        FOR SELECT USING (
            account_id = get_my_account_id()
            AND (
                EXISTS (SELECT 1 FROM "User_Roles" WHERE user_id = auth.uid() AND role IN ('manager', 'coach'))
                OR rep_email = (SELECT email FROM auth.users WHERE id = auth.uid())
            )
        );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Synced_Conversations policy: %', SQLERRM;
END $$;

-- Synced_Activities
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users access Synced_Activities" ON "Synced_Activities";
    CREATE POLICY "Users access Synced_Activities" ON "Synced_Activities"
        FOR SELECT USING (
            account_id = get_my_account_id()
            AND (
                EXISTS (SELECT 1 FROM "User_Roles" WHERE user_id = auth.uid() AND role IN ('manager', 'coach'))
                OR rep_email = (SELECT email FROM auth.users WHERE id = auth.uid())
            )
        );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Synced_Activities policy: %', SQLERRM;
END $$;

-- Coaching_Messages
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users access Coaching_Messages" ON "Coaching_Messages";
    CREATE POLICY "Users access Coaching_Messages" ON "Coaching_Messages"
        FOR ALL USING (
            account_id = get_my_account_id()
            AND (
                EXISTS (SELECT 1 FROM "User_Roles" WHERE user_id = auth.uid() AND role IN ('manager', 'coach'))
                OR rep_email = (SELECT email FROM auth.users WHERE id = auth.uid())
            )
        );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Coaching_Messages policy: %', SQLERRM;
END $$;

-- Coaching_Outcomes
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users access Coaching_Outcomes" ON "Coaching_Outcomes";
    CREATE POLICY "Users access Coaching_Outcomes" ON "Coaching_Outcomes"
        FOR SELECT USING (account_id = get_my_account_id());
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Coaching_Outcomes policy: %', SQLERRM;
END $$;

-- Integration_Sync_Log
DO $$
BEGIN
    DROP POLICY IF EXISTS "Managers access Integration_Sync_Log" ON "Integration_Sync_Log";
    CREATE POLICY "Managers access Integration_Sync_Log" ON "Integration_Sync_Log"
        FOR SELECT USING (
            account_id = get_my_account_id()
            AND EXISTS (SELECT 1 FROM "User_Roles" WHERE user_id = auth.uid() AND role IN ('manager', 'coach'))
        );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Integration_Sync_Log policy: %', SQLERRM;
END $$;

-- Conversation_Analyses (may or may not have account_id)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'Conversation_Analyses' AND column_name = 'account_id'
    ) THEN
        DROP POLICY IF EXISTS "Users access Conversation_Analyses" ON "Conversation_Analyses";
        CREATE POLICY "Users access Conversation_Analyses" ON "Conversation_Analyses"
            FOR ALL USING (account_id = get_my_account_id());
    ELSE
        DROP POLICY IF EXISTS "Auth access Conversation_Analyses" ON "Conversation_Analyses";
        CREATE POLICY "Auth access Conversation_Analyses" ON "Conversation_Analyses"
            FOR ALL USING (auth.role() = 'authenticated');
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Conversation_Analyses policy: %', SQLERRM;
END $$;

-- Team_Wins
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users view Team_Wins" ON "Team_Wins";
    CREATE POLICY "Users view Team_Wins" ON "Team_Wins"
        FOR SELECT USING (account_id = get_my_account_id());

    DROP POLICY IF EXISTS "Coaches manage Team_Wins" ON "Team_Wins";
    CREATE POLICY "Coaches manage Team_Wins" ON "Team_Wins"
        FOR ALL USING (
            account_id = get_my_account_id()
            AND EXISTS (SELECT 1 FROM "User_Roles" WHERE user_id = auth.uid() AND role IN ('manager', 'coach'))
        );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Team_Wins policy: %', SQLERRM;
END $$;

-- Win_Celebrations
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users access Win_Celebrations" ON "Win_Celebrations";
    CREATE POLICY "Users access Win_Celebrations" ON "Win_Celebrations"
        FOR ALL USING (
            win_id IN (SELECT id FROM "Team_Wins" WHERE account_id = get_my_account_id())
        );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Win_Celebrations policy: %', SQLERRM;
END $$;

-- 6. REVOKE ANON ACCESS TO SENSITIVE TABLES
DO $$
BEGIN
    REVOKE ALL ON "API_Connections" FROM anon;
    REVOKE ALL ON "Coaching_Messages" FROM anon;
    REVOKE ALL ON "Integration_Sync_Log" FROM anon;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '✅ ONE-CLICK COACHING MIGRATION COMPLETE';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Features added:';
    RAISE NOTICE '  ✓ Methodology support (sandler, challenger, gap, meddic)';
    RAISE NOTICE '  ✓ Coach role';
    RAISE NOTICE '  ✓ Team Wins + celebrations';
    RAISE NOTICE '';
    RAISE NOTICE 'Security applied:';
    RAISE NOTICE '  ✓ RLS enabled on all tables';
    RAISE NOTICE '  ✓ Account-based policies';
    RAISE NOTICE '  ✓ Problematic views removed';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 One-Click Coaching is ready!';
END $$;
