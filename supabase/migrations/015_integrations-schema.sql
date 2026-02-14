-- ============================================
-- SANDLER REVENUE FACTORY - API INTEGRATIONS
-- HubSpot + Fathom + Aircall Integration Layer
-- ============================================

-- ============================================
-- TABLE: API_Connections
-- Store OAuth tokens and API keys for integrations
-- ============================================
CREATE TABLE IF NOT EXISTS "API_Connections" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,

    -- Provider info
    provider TEXT NOT NULL, -- 'hubspot', 'fathom', 'aircall', 'salesforce', 'gong'
    provider_account_id TEXT, -- Their internal account ID

    -- OAuth credentials (for HubSpot, Fathom)
    access_token TEXT,
    refresh_token TEXT,
    token_expires_at TIMESTAMP WITH TIME ZONE,
    scopes TEXT[], -- Array of OAuth scopes granted

    -- API Key credentials (for Aircall, simpler integrations)
    api_key TEXT,
    api_secret TEXT,

    -- Connection metadata
    connected_by UUID REFERENCES auth.users(id),
    connected_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_successful_sync TIMESTAMP WITH TIME ZONE,

    -- Sync settings
    auto_sync_enabled BOOLEAN DEFAULT TRUE,
    sync_frequency_minutes INTEGER DEFAULT 60, -- Sync every hour

    -- Status tracking
    connection_status TEXT DEFAULT 'active', -- 'active', 'expired', 'revoked', 'error'
    last_error TEXT,
    last_error_at TIMESTAMP WITH TIME ZONE,

    -- Settings per provider (JSONB for flexibility)
    settings JSONB DEFAULT '{}',

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- One connection per provider per account
    UNIQUE(account_id, provider)
);

-- ============================================
-- TABLE: Synced_Activities
-- Normalized activity data from all sources (HubSpot, Salesforce, etc.)
-- ============================================
CREATE TABLE IF NOT EXISTS "Synced_Activities" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Links
    account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    rep_email TEXT NOT NULL, -- Match reps across systems by email

    -- Activity data
    activity_date DATE NOT NULL,
    activity_type TEXT NOT NULL, -- 'call', 'email', 'meeting', 'task', 'note'
    count INTEGER DEFAULT 1,

    -- Metadata from source system
    metadata JSONB DEFAULT '{}', -- Store any provider-specific data

    -- Source tracking
    source_provider TEXT NOT NULL, -- 'hubspot', 'salesforce', etc.
    source_id TEXT NOT NULL, -- Their unique ID for this activity
    source_url TEXT, -- Link back to source system

    -- Sync tracking
    synced_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Prevent duplicate syncs
    UNIQUE(account_id, source_provider, source_id)
);

-- ============================================
-- TABLE: Synced_Conversations
-- Normalized conversation/call data from all sources (Fathom, Aircall, Gong, etc.)
-- ============================================
CREATE TABLE IF NOT EXISTS "Synced_Conversations" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Links
    account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    rep_email TEXT NOT NULL,

    -- Link to existing conversation analysis (if AI analyzed)
    conversation_analysis_id UUID REFERENCES "Conversation_Analyses"(id) ON DELETE SET NULL,

    -- Call metadata
    call_date TIMESTAMP WITH TIME ZONE NOT NULL,
    duration_minutes INTEGER,
    participants TEXT[], -- Array of participant names/emails

    -- Content
    transcript TEXT,
    ai_summary TEXT, -- Summary from Fathom/Gong if available
    recording_url TEXT,

    -- Channel classification
    channel TEXT NOT NULL, -- 'zoom', 'phone', 'teams', 'in_person', 'voice_note'

    -- Source tracking
    source_provider TEXT NOT NULL, -- 'fathom', 'aircall', 'gong', 'fireflies', 'manual'
    source_call_id TEXT NOT NULL,
    source_url TEXT,

    -- AI Analysis (our analysis)
    methodology_scores JSONB DEFAULT '{}', -- {upfront_contract: 8, pain_funnel: 7, ...}
    coaching_generated BOOLEAN DEFAULT FALSE,
    analyzed_at TIMESTAMP WITH TIME ZONE,

    -- Sync tracking
    synced_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Prevent duplicate syncs
    UNIQUE(account_id, source_provider, source_call_id)
);

-- ============================================
-- TABLE: Integration_Sync_Log
-- Track sync history for debugging and monitoring
-- ============================================
CREATE TABLE IF NOT EXISTS "Integration_Sync_Log" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,

    -- Sync details
    sync_started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sync_completed_at TIMESTAMP WITH TIME ZONE,
    sync_status TEXT NOT NULL, -- 'running', 'success', 'partial', 'failed'

    -- Results
    activities_synced INTEGER DEFAULT 0,
    conversations_synced INTEGER DEFAULT 0,
    errors_count INTEGER DEFAULT 0,
    error_details JSONB DEFAULT '[]',

    -- Performance
    duration_seconds INTEGER,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- TABLE: Coaching_Messages (Enhanced from existing)
-- Extends existing coaching_messages table
-- ============================================
-- Note: Check if this table already exists before running
CREATE TABLE IF NOT EXISTS "Coaching_Messages" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,
    rep_email TEXT NOT NULL,
    manager_email TEXT NOT NULL,

    -- Workflow status
    status TEXT DEFAULT 'draft', -- 'draft', 'approved', 'sent', 'read', 'acknowledged'

    -- Timestamps for workflow tracking
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    approved_at TIMESTAMP WITH TIME ZONE,
    sent_at TIMESTAMP WITH TIME ZONE,
    read_at TIMESTAMP WITH TIME ZONE,
    acknowledged_at TIMESTAMP WITH TIME ZONE,

    -- Content
    coaching_content TEXT NOT NULL,
    methodology TEXT, -- 'sandler', 'meddic', 'challenger', etc.

    -- Based on which calls?
    based_on_calls JSONB DEFAULT '[]', -- Array of synced_conversation IDs
    based_on_date_range JSONB, -- {start: '2026-01-10', end: '2026-01-17'}

    -- Rep response
    rep_response TEXT,
    responded_at TIMESTAMP WITH TIME ZONE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- TABLE: Coaching_Outcomes (For RAG - Learning System)
-- Track which coaching messages led to performance improvements
-- ============================================
CREATE TABLE IF NOT EXISTS "Coaching_Outcomes" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    coaching_message_id UUID REFERENCES "Coaching_Messages"(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,
    rep_email TEXT NOT NULL,

    -- What was coached?
    methodology_focus TEXT, -- 'upfront_contract', 'pain_funnel', 'budget', 'decision_process'
    initial_score DECIMAL(3,1), -- Score before coaching (0-10)

    -- Did it improve?
    follow_up_score DECIMAL(3,1), -- Score after coaching (0-10)
    performance_change DECIMAL(5,2), -- Percentage change in overall performance
    worked BOOLEAN, -- Did coaching lead to improvement?

    -- Timing
    coaching_sent_at TIMESTAMP WITH TIME ZONE,
    measured_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    time_to_improvement_days INTEGER,

    -- What technique was used?
    coaching_technique TEXT, -- Extract from coaching message

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================

-- API Connections
CREATE INDEX IF NOT EXISTS idx_api_connections_account ON "API_Connections"(account_id);
CREATE INDEX IF NOT EXISTS idx_api_connections_status ON "API_Connections"(connection_status);

-- Synced Activities
CREATE INDEX IF NOT EXISTS idx_synced_activities_account ON "Synced_Activities"(account_id, activity_date DESC);
CREATE INDEX IF NOT EXISTS idx_synced_activities_rep ON "Synced_Activities"(rep_email, activity_date DESC);
CREATE INDEX IF NOT EXISTS idx_synced_activities_source ON "Synced_Activities"(source_provider, source_id);

-- Synced Conversations
CREATE INDEX IF NOT EXISTS idx_synced_conversations_account ON "Synced_Conversations"(account_id, call_date DESC);
CREATE INDEX IF NOT EXISTS idx_synced_conversations_rep ON "Synced_Conversations"(rep_email, call_date DESC);
CREATE INDEX IF NOT EXISTS idx_synced_conversations_source ON "Synced_Conversations"(source_provider, source_call_id);
CREATE INDEX IF NOT EXISTS idx_synced_conversations_analysis ON "Synced_Conversations"(conversation_analysis_id);

-- Integration Sync Log
CREATE INDEX IF NOT EXISTS idx_sync_log_account ON "Integration_Sync_Log"(account_id, sync_started_at DESC);
CREATE INDEX IF NOT EXISTS idx_sync_log_provider ON "Integration_Sync_Log"(provider, sync_started_at DESC);

-- Coaching Messages
CREATE INDEX IF NOT EXISTS idx_coaching_messages_account ON "Coaching_Messages"(account_id, generated_at DESC);
CREATE INDEX IF NOT EXISTS idx_coaching_messages_rep ON "Coaching_Messages"(rep_email, status);
CREATE INDEX IF NOT EXISTS idx_coaching_messages_status ON "Coaching_Messages"(status);

-- Coaching Outcomes
CREATE INDEX IF NOT EXISTS idx_coaching_outcomes_message ON "Coaching_Outcomes"(coaching_message_id);
CREATE INDEX IF NOT EXISTS idx_coaching_outcomes_rep ON "Coaching_Outcomes"(rep_email, worked);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE "API_Connections" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Synced_Activities" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Synced_Conversations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Integration_Sync_Log" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Coaching_Messages" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Coaching_Outcomes" ENABLE ROW LEVEL SECURITY;

-- Managers can manage API connections for their account
CREATE POLICY "Managers can manage API connections"
    ON "API_Connections" FOR ALL
    USING (
        account_id IN (
            SELECT account_id FROM "User_Roles"
            WHERE user_id = auth.uid() AND role = 'manager'
        )
    );

-- Users can view synced activities from their account
CREATE POLICY "Users can view synced activities"
    ON "Synced_Activities" FOR SELECT
    USING (
        account_id IN (
            SELECT account_id FROM "User_Roles"
            WHERE user_id = auth.uid()
        )
    );

-- System can insert synced activities (via service key)
CREATE POLICY "System can insert synced activities"
    ON "Synced_Activities" FOR INSERT
    WITH CHECK (true);

-- Users can view synced conversations from their account
CREATE POLICY "Users can view synced conversations"
    ON "Synced_Conversations" FOR SELECT
    USING (
        user_id = auth.uid() OR
        account_id IN (
            SELECT account_id FROM "User_Roles"
            WHERE user_id = auth.uid()
        )
    );

-- System can insert/update synced conversations
CREATE POLICY "System can manage synced conversations"
    ON "Synced_Conversations" FOR ALL
    WITH CHECK (true);

-- Users can view sync logs from their account
CREATE POLICY "Users can view sync logs"
    ON "Integration_Sync_Log" FOR SELECT
    USING (
        account_id IN (
            SELECT account_id FROM "User_Roles"
            WHERE user_id = auth.uid()
        )
    );

-- System can insert sync logs
CREATE POLICY "System can insert sync logs"
    ON "Integration_Sync_Log" FOR INSERT
    WITH CHECK (true);

-- Managers can view all coaching messages for their account
CREATE POLICY "Managers can view all coaching messages"
    ON "Coaching_Messages" FOR SELECT
    USING (
        account_id IN (
            SELECT account_id FROM "User_Roles"
            WHERE user_id = auth.uid() AND role = 'manager'
        )
    );

-- Reps can view their own coaching messages
CREATE POLICY "Reps can view their own coaching"
    ON "Coaching_Messages" FOR SELECT
    USING (
        rep_email = (SELECT email FROM auth.users WHERE id = auth.uid())
    );

-- System can manage coaching messages
CREATE POLICY "System can manage coaching messages"
    ON "Coaching_Messages" FOR ALL
    WITH CHECK (true);

-- Coaching outcomes viewable by managers
CREATE POLICY "Managers can view coaching outcomes"
    ON "Coaching_Outcomes" FOR SELECT
    USING (
        account_id IN (
            SELECT account_id FROM "User_Roles"
            WHERE user_id = auth.uid() AND role = 'manager'
        )
    );

-- ============================================
-- TRIGGERS
-- ============================================

CREATE TRIGGER update_api_connections_updated_at
    BEFORE UPDATE ON "API_Connections"
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- FUNCTIONS: HubSpot Integration
-- ============================================

-- Save HubSpot OAuth tokens
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
    -- Get user's account
    SELECT account_id INTO user_account_id
    FROM "User_Roles"
    WHERE user_id = auth.uid() AND role = 'manager'
    LIMIT 1;

    IF user_account_id IS NULL THEN
        RAISE EXCEPTION 'Only managers can configure integrations';
    END IF;

    -- Upsert connection
    INSERT INTO "API_Connections" (
        account_id,
        provider,
        provider_account_id,
        access_token,
        refresh_token,
        token_expires_at,
        scopes,
        connected_by,
        connection_status
    ) VALUES (
        user_account_id,
        'hubspot',
        hubspot_account_id,
        access_token_input,
        refresh_token_input,
        NOW() + (expires_in_seconds || ' seconds')::INTERVAL,
        scopes_input,
        auth.uid(),
        'active'
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

-- Get HubSpot connection details
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
    -- Get user's account
    SELECT account_id INTO user_account_id
    FROM "User_Roles"
    WHERE user_id = auth.uid()
    LIMIT 1;

    IF user_account_id IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        ac.id,
        ac.access_token,
        ac.refresh_token,
        ac.token_expires_at,
        ac.connection_status,
        ac.last_successful_sync,
        COUNT(sa.id) as activities_synced
    FROM "API_Connections" ac
    LEFT JOIN "Synced_Activities" sa ON sa.account_id = ac.account_id AND sa.source_provider = 'hubspot'
    WHERE ac.account_id = user_account_id AND ac.provider = 'hubspot'
    GROUP BY ac.id, ac.access_token, ac.refresh_token, ac.token_expires_at, ac.connection_status, ac.last_successful_sync;
END;
$$;

-- ============================================
-- FUNCTIONS: Fathom Integration
-- ============================================

-- Save Fathom OAuth tokens
CREATE OR REPLACE FUNCTION save_fathom_connection(
    access_token_input TEXT,
    refresh_token_input TEXT DEFAULT NULL,
    expires_in_seconds INTEGER DEFAULT 31536000 -- Default 1 year
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
        account_id,
        provider,
        access_token,
        refresh_token,
        token_expires_at,
        connected_by,
        connection_status
    ) VALUES (
        user_account_id,
        'fathom',
        access_token_input,
        refresh_token_input,
        NOW() + (expires_in_seconds || ' seconds')::INTERVAL,
        auth.uid(),
        'active'
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

-- Get Fathom connection details
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
        ac.id,
        ac.access_token,
        ac.connection_status,
        ac.last_successful_sync,
        COUNT(sc.id) as conversations_synced
    FROM "API_Connections" ac
    LEFT JOIN "Synced_Conversations" sc ON sc.account_id = ac.account_id AND sc.source_provider = 'fathom'
    WHERE ac.account_id = user_account_id AND ac.provider = 'fathom'
    GROUP BY ac.id, ac.access_token, ac.connection_status, ac.last_successful_sync;
END;
$$;

-- ============================================
-- VIEWS
-- ============================================

-- Recent activity across all sources
CREATE OR REPLACE VIEW "Recent_Synced_Activities" AS
SELECT
    sa.id,
    sa.activity_date,
    sa.activity_type,
    sa.count,
    sa.source_provider,
    sa.synced_at,
    sa.rep_email,
    u.raw_user_meta_data->>'full_name' as rep_name,
    ac.provider as provider_name
FROM "Synced_Activities" sa
LEFT JOIN auth.users u ON sa.user_id = u.id
LEFT JOIN "API_Connections" ac ON sa.source_provider = ac.provider AND sa.account_id = ac.account_id
WHERE sa.account_id IN (
    SELECT account_id FROM "User_Roles" WHERE user_id = auth.uid()
)
ORDER BY sa.activity_date DESC, sa.synced_at DESC;

-- Recent conversations across all sources
CREATE OR REPLACE VIEW "Recent_Synced_Conversations" AS
SELECT
    sc.id,
    sc.call_date,
    sc.duration_minutes,
    sc.channel,
    sc.source_provider,
    sc.coaching_generated,
    sc.synced_at,
    sc.rep_email,
    u.raw_user_meta_data->>'full_name' as rep_name,
    ca.overall_sandler_score,
    sc.transcript IS NOT NULL as has_transcript
FROM "Synced_Conversations" sc
LEFT JOIN auth.users u ON sc.user_id = u.id
LEFT JOIN "Conversation_Analyses" ca ON sc.conversation_analysis_id = ca.id
WHERE sc.account_id IN (
    SELECT account_id FROM "User_Roles" WHERE user_id = auth.uid()
)
ORDER BY sc.call_date DESC;

-- Integration health dashboard
CREATE OR REPLACE VIEW "Integration_Health" AS
SELECT
    ac.provider,
    ac.connection_status,
    ac.last_successful_sync,
    ac.last_error,
    COUNT(DISTINCT CASE WHEN sa.synced_at > NOW() - INTERVAL '7 days' THEN sa.id END) as activities_last_7_days,
    COUNT(DISTINCT CASE WHEN sc.synced_at > NOW() - INTERVAL '7 days' THEN sc.id END) as conversations_last_7_days
FROM "API_Connections" ac
LEFT JOIN "Synced_Activities" sa ON sa.account_id = ac.account_id AND sa.source_provider = ac.provider
LEFT JOIN "Synced_Conversations" sc ON sc.account_id = ac.account_id AND sc.source_provider = ac.provider
WHERE ac.account_id IN (
    SELECT account_id FROM "User_Roles" WHERE user_id = auth.uid()
)
GROUP BY ac.provider, ac.connection_status, ac.last_successful_sync, ac.last_error;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '✅ Sandler Revenue Factory Integrations Created!';
    RAISE NOTICE '   📊 API_Connections - Store OAuth tokens';
    RAISE NOTICE '   📞 Synced_Activities - Activity data from HubSpot/Salesforce';
    RAISE NOTICE '   🎙️  Synced_Conversations - Calls from Fathom/Aircall';
    RAISE NOTICE '   📝 Coaching_Messages - AI coaching workflow';
    RAISE NOTICE '   🎯 Coaching_Outcomes - RAG learning system';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Ready for HubSpot + Fathom + Aircall integration!';
    RAISE NOTICE '📖 Next: Build OAuth connection UI';
END $$;
