-- ============================================
-- SANDLER REVENUE FACTORY - INTEGRATIONS V2
-- Simplified schema - no DROP statements
-- Safe to run multiple times
-- ============================================

-- ============================================
-- PART 1: Core Tables (Create if missing)
-- ============================================

-- Accounts
CREATE TABLE IF NOT EXISTS "Accounts" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    company_name TEXT NOT NULL,
    industry TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User_Roles
CREATE TABLE IF NOT EXISTS "User_Roles" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    account_id UUID REFERENCES "Accounts"(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('manager', 'user')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, account_id)
);

-- Conversation_Analyses
CREATE TABLE IF NOT EXISTS "Conversation_Analyses" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    account_id UUID REFERENCES "Accounts"(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    call_date TIMESTAMP WITH TIME ZONE,
    transcript TEXT,
    overall_sandler_score DECIMAL(3,1),
    methodology_scores JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- PART 2: Integration Tables
-- ============================================

-- API_Connections
CREATE TABLE IF NOT EXISTS "API_Connections" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    provider_account_id TEXT,
    access_token TEXT,
    refresh_token TEXT,
    token_expires_at TIMESTAMP WITH TIME ZONE,
    scopes TEXT[],
    api_key TEXT,
    api_secret TEXT,
    connected_by UUID REFERENCES auth.users(id),
    connected_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_successful_sync TIMESTAMP WITH TIME ZONE,
    auto_sync_enabled BOOLEAN DEFAULT TRUE,
    sync_frequency_minutes INTEGER DEFAULT 60,
    connection_status TEXT DEFAULT 'active',
    last_error TEXT,
    last_error_at TIMESTAMP WITH TIME ZONE,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(account_id, provider)
);

-- Synced_Activities
CREATE TABLE IF NOT EXISTS "Synced_Activities" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    rep_email TEXT NOT NULL,
    activity_date DATE NOT NULL,
    activity_type TEXT NOT NULL,
    count INTEGER DEFAULT 1,
    metadata JSONB DEFAULT '{}',
    source_provider TEXT NOT NULL,
    source_id TEXT NOT NULL,
    source_url TEXT,
    synced_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(account_id, source_provider, source_id)
);

-- Synced_Conversations
CREATE TABLE IF NOT EXISTS "Synced_Conversations" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    rep_email TEXT NOT NULL,
    conversation_analysis_id UUID REFERENCES "Conversation_Analyses"(id) ON DELETE SET NULL,
    call_date TIMESTAMP WITH TIME ZONE NOT NULL,
    duration_minutes INTEGER,
    participants TEXT[],
    transcript TEXT,
    ai_summary TEXT,
    recording_url TEXT,
    channel TEXT NOT NULL,
    source_provider TEXT NOT NULL,
    source_call_id TEXT NOT NULL,
    source_url TEXT,
    methodology_scores JSONB DEFAULT '{}',
    coaching_generated BOOLEAN DEFAULT FALSE,
    analyzed_at TIMESTAMP WITH TIME ZONE,
    synced_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(account_id, source_provider, source_call_id)
);

-- Integration_Sync_Log
CREATE TABLE IF NOT EXISTS "Integration_Sync_Log" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    sync_started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sync_completed_at TIMESTAMP WITH TIME ZONE,
    sync_status TEXT NOT NULL,
    activities_synced INTEGER DEFAULT 0,
    conversations_synced INTEGER DEFAULT 0,
    errors_count INTEGER DEFAULT 0,
    error_details JSONB DEFAULT '[]',
    duration_seconds INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Coaching_Messages
CREATE TABLE IF NOT EXISTS "Coaching_Messages" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Coaching_Outcomes
CREATE TABLE IF NOT EXISTS "Coaching_Outcomes" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    coaching_message_id UUID REFERENCES "Coaching_Messages"(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,
    rep_email TEXT NOT NULL,
    methodology_focus TEXT,
    initial_score DECIMAL(3,1),
    follow_up_score DECIMAL(3,1),
    performance_change DECIMAL(5,2),
    worked BOOLEAN,
    coaching_sent_at TIMESTAMP WITH TIME ZONE,
    measured_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    time_to_improvement_days INTEGER,
    coaching_technique TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- PART 3: Indexes
-- ============================================

CREATE INDEX IF NOT EXISTS idx_api_connections_account ON "API_Connections"(account_id);
CREATE INDEX IF NOT EXISTS idx_api_connections_status ON "API_Connections"(connection_status);
CREATE INDEX IF NOT EXISTS idx_synced_activities_account ON "Synced_Activities"(account_id, activity_date DESC);
CREATE INDEX IF NOT EXISTS idx_synced_activities_rep ON "Synced_Activities"(rep_email, activity_date DESC);
CREATE INDEX IF NOT EXISTS idx_synced_conversations_account ON "Synced_Conversations"(account_id, call_date DESC);
CREATE INDEX IF NOT EXISTS idx_synced_conversations_rep ON "Synced_Conversations"(rep_email, call_date DESC);
CREATE INDEX IF NOT EXISTS idx_sync_log_account ON "Integration_Sync_Log"(account_id, sync_started_at DESC);
CREATE INDEX IF NOT EXISTS idx_coaching_messages_account ON "Coaching_Messages"(account_id, generated_at DESC);
CREATE INDEX IF NOT EXISTS idx_coaching_outcomes_message ON "Coaching_Outcomes"(coaching_message_id);

-- ============================================
-- PART 4: RPC Functions
-- ============================================

-- Save HubSpot connection
CREATE OR REPLACE FUNCTION save_hubspot_connection(
    access_token_input TEXT,
    refresh_token_input TEXT,
    expires_in_seconds INTEGER,
    scopes_input TEXT[],
    hubspot_account_id TEXT DEFAULT NULL
)
RETURNS UUID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    user_account_id UUID;
    connection_id UUID;
BEGIN
    SELECT account_id INTO user_account_id
    FROM "User_Roles"
    WHERE user_id = auth.uid() AND role = 'manager'
    LIMIT 1;

    IF user_account_id IS NULL THEN
        RAISE EXCEPTION 'Only managers can configure integrations';
    END IF;

    INSERT INTO "API_Connections" (
        account_id, provider, provider_account_id,
        access_token, refresh_token, token_expires_at,
        scopes, connected_by, connection_status
    ) VALUES (
        user_account_id, 'hubspot', hubspot_account_id,
        access_token_input, refresh_token_input,
        NOW() + (expires_in_seconds || ' seconds')::INTERVAL,
        scopes_input, auth.uid(), 'active'
    )
    ON CONFLICT (account_id, provider)
    DO UPDATE SET
        access_token = access_token_input,
        refresh_token = refresh_token_input,
        token_expires_at = NOW() + (expires_in_seconds || ' seconds')::INTERVAL,
        scopes = scopes_input,
        connection_status = 'active',
        last_error = NULL,
        updated_at = NOW()
    RETURNING id INTO connection_id;

    RETURN connection_id;
END;
$$;

-- Get HubSpot connection
CREATE OR REPLACE FUNCTION get_hubspot_connection()
RETURNS TABLE (
    id UUID,
    access_token TEXT,
    refresh_token TEXT,
    token_expires_at TIMESTAMP WITH TIME ZONE,
    connection_status TEXT,
    last_successful_sync TIMESTAMP WITH TIME ZONE,
    activities_synced BIGINT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    user_account_id UUID;
BEGIN
    SELECT account_id INTO user_account_id
    FROM "User_Roles"
    WHERE user_id = auth.uid()
    LIMIT 1;

    IF user_account_id IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        ac.id, ac.access_token, ac.refresh_token,
        ac.token_expires_at, ac.connection_status,
        ac.last_successful_sync,
        COUNT(sa.id) as activities_synced
    FROM "API_Connections" ac
    LEFT JOIN "Synced_Activities" sa ON sa.account_id = ac.account_id AND sa.source_provider = 'hubspot'
    WHERE ac.account_id = user_account_id AND ac.provider = 'hubspot'
    GROUP BY ac.id, ac.access_token, ac.refresh_token, ac.token_expires_at, ac.connection_status, ac.last_successful_sync;
END;
$$;

-- Save Fathom connection
CREATE OR REPLACE FUNCTION save_fathom_connection(
    access_token_input TEXT,
    refresh_token_input TEXT DEFAULT NULL,
    expires_in_seconds INTEGER DEFAULT 31536000
)
RETURNS UUID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    user_account_id UUID;
    connection_id UUID;
BEGIN
    SELECT account_id INTO user_account_id
    FROM "User_Roles"
    WHERE user_id = auth.uid() AND role = 'manager'
    LIMIT 1;

    IF user_account_id IS NULL THEN
        RAISE EXCEPTION 'Only managers can configure integrations';
    END IF;

    INSERT INTO "API_Connections" (
        account_id, provider, access_token, refresh_token,
        token_expires_at, connected_by, connection_status
    ) VALUES (
        user_account_id, 'fathom', access_token_input, refresh_token_input,
        NOW() + (expires_in_seconds || ' seconds')::INTERVAL,
        auth.uid(), 'active'
    )
    ON CONFLICT (account_id, provider)
    DO UPDATE SET
        access_token = access_token_input,
        refresh_token = COALESCE(refresh_token_input, "API_Connections".refresh_token),
        token_expires_at = NOW() + (expires_in_seconds || ' seconds')::INTERVAL,
        connection_status = 'active',
        last_error = NULL,
        updated_at = NOW()
    RETURNING id INTO connection_id;

    RETURN connection_id;
END;
$$;

-- Get Fathom connection
CREATE OR REPLACE FUNCTION get_fathom_connection()
RETURNS TABLE (
    id UUID,
    access_token TEXT,
    connection_status TEXT,
    last_successful_sync TIMESTAMP WITH TIME ZONE,
    conversations_synced BIGINT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    user_account_id UUID;
BEGIN
    SELECT account_id INTO user_account_id
    FROM "User_Roles"
    WHERE user_id = auth.uid()
    LIMIT 1;

    IF user_account_id IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        ac.id, ac.access_token, ac.connection_status,
        ac.last_successful_sync,
        COUNT(sc.id) as conversations_synced
    FROM "API_Connections" ac
    LEFT JOIN "Synced_Conversations" sc ON sc.account_id = ac.account_id AND sc.source_provider = 'fathom'
    WHERE ac.account_id = user_account_id AND ac.provider = 'fathom'
    GROUP BY ac.id, ac.access_token, ac.connection_status, ac.last_successful_sync;
END;
$$;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '✅ Integration Tables Created Successfully!';
    RAISE NOTICE '';
    RAISE NOTICE 'Tables:';
    RAISE NOTICE '  ✓ API_Connections';
    RAISE NOTICE '  ✓ Synced_Activities';
    RAISE NOTICE '  ✓ Synced_Conversations';
    RAISE NOTICE '  ✓ Integration_Sync_Log';
    RAISE NOTICE '  ✓ Coaching_Messages';
    RAISE NOTICE '  ✓ Coaching_Outcomes';
    RAISE NOTICE '';
    RAISE NOTICE 'Functions:';
    RAISE NOTICE '  ✓ save_hubspot_connection()';
    RAISE NOTICE '  ✓ get_hubspot_connection()';
    RAISE NOTICE '  ✓ save_fathom_connection()';
    RAISE NOTICE '  ✓ get_fathom_connection()';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Ready for integrations!';
    RAISE NOTICE '📖 Next: Follow HUBSPOT-INTEGRATION-SETUP.md';
END $$;
