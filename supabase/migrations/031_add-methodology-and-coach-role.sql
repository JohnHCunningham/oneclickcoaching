-- ============================================
-- ADD METHODOLOGY TO ACCOUNTS + COACH ROLE
-- One-Click Coaching - Multi-methodology support
-- ============================================

-- ============================================
-- 1. ADD METHODOLOGY TO ACCOUNTS
-- ============================================
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
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'Accounts' AND constraint_name = 'accounts_methodology_check'
    ) THEN
        ALTER TABLE "Accounts"
        ADD CONSTRAINT accounts_methodology_check
        CHECK (methodology IN ('sandler', 'challenger', 'gap', 'meddic'));
        RAISE NOTICE '✅ Added methodology CHECK constraint';
    ELSE
        RAISE NOTICE 'ℹ️ methodology CHECK constraint already exists';
    END IF;
EXCEPTION
    WHEN duplicate_object THEN
        RAISE NOTICE 'ℹ️ methodology CHECK constraint already exists';
END $$;

-- ============================================
-- 2. ADD COACH ROLE TO USER_ROLES
-- ============================================
-- First, drop the existing CHECK constraint
DO $$
BEGIN
    ALTER TABLE "User_Roles" DROP CONSTRAINT IF EXISTS "User_Roles_role_check";
    RAISE NOTICE '✅ Dropped old role CHECK constraint';
EXCEPTION
    WHEN undefined_object THEN
        RAISE NOTICE 'ℹ️ No existing role CHECK constraint to drop';
END $$;

-- Add new CHECK constraint with coach role
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

-- ============================================
-- 3. HELPER FUNCTION: Get methodology config
-- Returns scoring framework based on account methodology
-- ============================================
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
            config := '{
                "name": "Sandler Selling System",
                "components": [
                    "Upfront Contract",
                    "Pain Funnel",
                    "Budget",
                    "Decision Process",
                    "Fulfillment",
                    "Post-Sell",
                    "Bonding & Rapport",
                    "Negative Reverse Selling"
                ]
            }'::JSONB;
        WHEN 'challenger' THEN
            config := '{
                "name": "Challenger Sale",
                "components": [
                    "Teaching",
                    "Tailoring",
                    "Taking Control",
                    "Constructive Tension",
                    "Commercial Insight",
                    "Reframe Thinking"
                ]
            }'::JSONB;
        WHEN 'gap' THEN
            config := '{
                "name": "Gap Selling",
                "components": [
                    "Current State Discovery",
                    "Future State Vision",
                    "Gap Identification",
                    "Problem Quantification",
                    "Root Cause Analysis",
                    "Impact Assessment"
                ]
            }'::JSONB;
        WHEN 'meddic' THEN
            config := '{
                "name": "MEDDIC",
                "components": [
                    "Metrics",
                    "Economic Buyer",
                    "Decision Criteria",
                    "Decision Process",
                    "Identify Pain",
                    "Champion"
                ]
            }'::JSONB;
        ELSE
            config := '{
                "name": "Custom",
                "components": []
            }'::JSONB;
    END CASE;

    RETURN config;
END;
$$;

-- ============================================
-- 4. HELPER FUNCTION: Check if user is coach
-- ============================================
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

-- ============================================
-- 5. UPDATE get_user_account TO INCLUDE METHODOLOGY
-- ============================================
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

-- ============================================
-- 6. FUNCTION: Update account methodology
-- ============================================
CREATE OR REPLACE FUNCTION update_account_methodology(
    new_methodology TEXT
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    user_account_id UUID;
BEGIN
    -- Get user's account (must be manager)
    SELECT account_id INTO user_account_id
    FROM "User_Roles"
    WHERE user_id = auth.uid() AND role = 'manager'
    LIMIT 1;

    IF user_account_id IS NULL THEN
        RAISE EXCEPTION 'Only managers can update methodology';
    END IF;

    -- Validate methodology
    IF new_methodology NOT IN ('sandler', 'challenger', 'gap', 'meddic') THEN
        RAISE EXCEPTION 'Invalid methodology: %. Must be sandler, challenger, gap, or meddic', new_methodology;
    END IF;

    UPDATE "Accounts"
    SET methodology = new_methodology, updated_at = NOW()
    WHERE id = user_account_id;

    RETURN TRUE;
END;
$$;

-- ============================================
-- 7. TEAM WINS TABLE
-- Public celebrations shared with all reps
-- ============================================
CREATE TABLE IF NOT EXISTS "Team_Wins" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,

    -- Who achieved the win
    rep_email TEXT NOT NULL,
    rep_name TEXT,

    -- The win
    win_type TEXT NOT NULL,  -- 'high_score', 'streak', 'personal_best', 'closed_deal', 'breakthrough', 'custom'
    title TEXT NOT NULL,     -- "Crushed it on discovery!"
    description TEXT,        -- Optional details

    -- Context
    related_call_id UUID REFERENCES "Synced_Conversations"(id) ON DELETE SET NULL,
    methodology_component TEXT,  -- Which skill area (e.g., "Pain Funnel")
    score INTEGER,               -- If score-based win

    -- Sharing
    shared_by_email TEXT NOT NULL,  -- Coach/manager who shared it
    shared_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_pinned BOOLEAN DEFAULT FALSE,  -- Keep at top of feed

    -- Engagement
    celebration_count INTEGER DEFAULT 0,  -- Emoji reactions / high-fives

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for Team Wins
CREATE INDEX IF NOT EXISTS idx_team_wins_account ON "Team_Wins"(account_id, shared_at DESC);
CREATE INDEX IF NOT EXISTS idx_team_wins_rep ON "Team_Wins"(rep_email, shared_at DESC);
CREATE INDEX IF NOT EXISTS idx_team_wins_pinned ON "Team_Wins"(account_id, is_pinned, shared_at DESC);

-- ============================================
-- 8. WIN CELEBRATIONS (Reactions)
-- Reps can celebrate each other's wins
-- ============================================
CREATE TABLE IF NOT EXISTS "Win_Celebrations" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    win_id UUID NOT NULL REFERENCES "Team_Wins"(id) ON DELETE CASCADE,
    user_email TEXT NOT NULL,
    celebrated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- One celebration per user per win
    UNIQUE(win_id, user_email)
);

CREATE INDEX IF NOT EXISTS idx_win_celebrations_win ON "Win_Celebrations"(win_id);

-- ============================================
-- 9. FUNCTION: Share a team win
-- ============================================
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
    -- Get user's account and email (must be manager or coach)
    SELECT ur.account_id, u.email INTO user_account_id, user_email
    FROM "User_Roles" ur
    JOIN auth.users u ON ur.user_id = u.id
    WHERE ur.user_id = auth.uid() AND ur.role IN ('manager', 'coach')
    LIMIT 1;

    IF user_account_id IS NULL THEN
        RAISE EXCEPTION 'Only managers and coaches can share team wins';
    END IF;

    -- Validate win_type
    IF p_win_type NOT IN ('high_score', 'streak', 'personal_best', 'closed_deal', 'breakthrough', 'custom') THEN
        RAISE EXCEPTION 'Invalid win_type: %', p_win_type;
    END IF;

    INSERT INTO "Team_Wins" (
        account_id,
        rep_email,
        rep_name,
        win_type,
        title,
        description,
        related_call_id,
        methodology_component,
        score,
        shared_by_email,
        is_pinned
    ) VALUES (
        user_account_id,
        p_rep_email,
        p_rep_name,
        p_win_type,
        p_title,
        p_description,
        p_related_call_id,
        p_methodology_component,
        p_score,
        user_email,
        p_is_pinned
    )
    RETURNING id INTO new_win_id;

    RETURN new_win_id;
END;
$$;

-- ============================================
-- 10. FUNCTION: Get team wins feed
-- ============================================
CREATE OR REPLACE FUNCTION get_team_wins(
    p_limit INTEGER DEFAULT 20
)
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
    -- Get user's account
    SELECT account_id INTO user_account_id
    FROM "User_Roles"
    WHERE user_id = auth.uid()
    LIMIT 1;

    IF user_account_id IS NULL THEN
        RAISE EXCEPTION 'User not found in any account';
    END IF;

    RETURN QUERY
    SELECT
        tw.id,
        tw.rep_email,
        tw.rep_name,
        tw.win_type,
        tw.title,
        tw.description,
        tw.methodology_component,
        tw.score,
        tw.shared_by_email,
        tw.shared_at,
        tw.is_pinned,
        tw.celebration_count
    FROM "Team_Wins" tw
    WHERE tw.account_id = user_account_id
    ORDER BY tw.is_pinned DESC, tw.shared_at DESC
    LIMIT p_limit;
END;
$$;

-- ============================================
-- 11. FUNCTION: Celebrate a win (high-five)
-- ============================================
CREATE OR REPLACE FUNCTION celebrate_win(
    p_win_id UUID
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    user_email TEXT;
    user_account_id UUID;
    win_account_id UUID;
BEGIN
    -- Get user info
    SELECT u.email, ur.account_id INTO user_email, user_account_id
    FROM auth.users u
    JOIN "User_Roles" ur ON u.id = ur.user_id
    WHERE u.id = auth.uid()
    LIMIT 1;

    -- Verify win belongs to same account
    SELECT account_id INTO win_account_id
    FROM "Team_Wins"
    WHERE id = p_win_id;

    IF win_account_id IS NULL OR win_account_id != user_account_id THEN
        RAISE EXCEPTION 'Win not found or access denied';
    END IF;

    -- Add celebration (ignore if already exists)
    INSERT INTO "Win_Celebrations" (win_id, user_email)
    VALUES (p_win_id, user_email)
    ON CONFLICT (win_id, user_email) DO NOTHING;

    -- Update count
    UPDATE "Team_Wins"
    SET celebration_count = (
        SELECT COUNT(*) FROM "Win_Celebrations" WHERE win_id = p_win_id
    )
    WHERE id = p_win_id;

    RETURN TRUE;
END;
$$;

-- ============================================
-- 12. FUNCTION: Auto-detect wins from calls
-- Call this after analyzing a call to check for achievements
-- ============================================
CREATE OR REPLACE FUNCTION check_for_wins(
    p_rep_email TEXT,
    p_call_id UUID,
    p_overall_score DECIMAL
)
RETURNS TABLE (
    win_type TEXT,
    title TEXT,
    description TEXT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    rep_best_score DECIMAL;
    rep_streak INTEGER;
    account_id UUID;
BEGIN
    -- Get account
    SELECT sc.account_id INTO account_id
    FROM "Synced_Conversations" sc
    WHERE sc.id = p_call_id;

    -- Check for personal best
    SELECT MAX(ca.overall_sandler_score) INTO rep_best_score
    FROM "Conversation_Analyses" ca
    WHERE ca.user_id IN (
        SELECT u.id FROM auth.users u WHERE u.email = p_rep_email
    )
    AND ca.id != p_call_id;

    IF p_overall_score > COALESCE(rep_best_score, 0) AND p_overall_score >= 85 THEN
        RETURN QUERY SELECT
            'personal_best'::TEXT,
            'New Personal Best!'::TEXT,
            format('Scored %s%% - beating previous best of %s%%',
                   ROUND(p_overall_score),
                   COALESCE(ROUND(rep_best_score), 0))::TEXT;
    END IF;

    -- Check for high score (90+)
    IF p_overall_score >= 90 THEN
        RETURN QUERY SELECT
            'high_score'::TEXT,
            'Exceptional Call!'::TEXT,
            format('Scored %s%% - outstanding execution', ROUND(p_overall_score))::TEXT;
    END IF;

    -- More win detection logic can be added here
    -- (streaks, breakthrough moments, etc.)

    RETURN;
END;
$$;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '✅ METHODOLOGY, COACH ROLE & TEAM WINS ADDED';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Schema changes:';
    RAISE NOTICE '  ✓ Accounts.methodology (sandler, challenger, gap, meddic)';
    RAISE NOTICE '  ✓ User_Roles.role now allows: manager, coach, user';
    RAISE NOTICE '  ✓ Team_Wins table (shared celebrations)';
    RAISE NOTICE '  ✓ Win_Celebrations table (high-fives)';
    RAISE NOTICE '';
    RAISE NOTICE 'New functions:';
    RAISE NOTICE '  ✓ get_methodology_config(account_id)';
    RAISE NOTICE '  ✓ is_coach()';
    RAISE NOTICE '  ✓ update_account_methodology(methodology)';
    RAISE NOTICE '  ✓ share_team_win(...) - coach shares a win';
    RAISE NOTICE '  ✓ get_team_wins(limit) - feed for all reps';
    RAISE NOTICE '  ✓ celebrate_win(win_id) - high-five a teammate';
    RAISE NOTICE '  ✓ check_for_wins(...) - auto-detect achievements';
    RAISE NOTICE '';
    RAISE NOTICE 'Updated functions:';
    RAISE NOTICE '  ✓ get_user_account() - includes methodology';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 One-Click Coaching ready!';
    RAISE NOTICE '🎉 Team wins can now be shared with all reps!';
    RAISE NOTICE '';
END $$;
