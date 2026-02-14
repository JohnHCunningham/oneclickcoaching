-- MIGRATION 4: Security Fixes

-- Drop problematic views
DROP VIEW IF EXISTS "User_Messages" CASCADE;
DROP VIEW IF EXISTS "Sent_Messages" CASCADE;
DROP VIEW IF EXISTS "Team_Members" CASCADE;

-- Helper function
CREATE OR REPLACE FUNCTION get_my_account_id()
RETURNS UUID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
STABLE
AS $func$
BEGIN
    RETURN (SELECT account_id FROM "User_Roles" WHERE user_id = auth.uid() LIMIT 1);
END $func$;

-- Enable RLS on legacy tables (no account_id)
ALTER TABLE IF EXISTS "sales" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "weekly_goals" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "daily_stats" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Conversation_Analyses" ENABLE ROW LEVEL SECURITY;

-- Enable RLS on multi-tenant tables
ALTER TABLE IF EXISTS "API_Connections" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Synced_Conversations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Synced_Activities" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Coaching_Messages" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Coaching_Outcomes" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Integration_Sync_Log" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Team_Wins" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Win_Celebrations" ENABLE ROW LEVEL SECURITY;

-- Policies for legacy tables (authenticated users only)
DROP POLICY IF EXISTS "auth_sales" ON "sales";
CREATE POLICY "auth_sales" ON "sales" FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "auth_weekly_goals" ON "weekly_goals";
CREATE POLICY "auth_weekly_goals" ON "weekly_goals" FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "auth_daily_stats" ON "daily_stats";
CREATE POLICY "auth_daily_stats" ON "daily_stats" FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "auth_conversation_analyses" ON "Conversation_Analyses";
CREATE POLICY "auth_conversation_analyses" ON "Conversation_Analyses" FOR ALL USING (auth.role() = 'authenticated');

-- Policies for multi-tenant tables (check if account_id exists first)
DO $block$
BEGIN
    -- API_Connections
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'API_Connections' AND column_name = 'account_id') THEN
        DROP POLICY IF EXISTS "policy_api_connections" ON "API_Connections";
        CREATE POLICY "policy_api_connections" ON "API_Connections"
            FOR ALL USING (account_id = get_my_account_id());
    ELSE
        DROP POLICY IF EXISTS "policy_api_connections" ON "API_Connections";
        CREATE POLICY "policy_api_connections" ON "API_Connections"
            FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- Synced_Conversations
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Synced_Conversations' AND column_name = 'account_id') THEN
        DROP POLICY IF EXISTS "policy_synced_conversations" ON "Synced_Conversations";
        CREATE POLICY "policy_synced_conversations" ON "Synced_Conversations"
            FOR SELECT USING (account_id = get_my_account_id());
    ELSE
        DROP POLICY IF EXISTS "policy_synced_conversations" ON "Synced_Conversations";
        CREATE POLICY "policy_synced_conversations" ON "Synced_Conversations"
            FOR SELECT USING (auth.role() = 'authenticated');
    END IF;

    -- Synced_Activities
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Synced_Activities' AND column_name = 'account_id') THEN
        DROP POLICY IF EXISTS "policy_synced_activities" ON "Synced_Activities";
        CREATE POLICY "policy_synced_activities" ON "Synced_Activities"
            FOR SELECT USING (account_id = get_my_account_id());
    ELSE
        DROP POLICY IF EXISTS "policy_synced_activities" ON "Synced_Activities";
        CREATE POLICY "policy_synced_activities" ON "Synced_Activities"
            FOR SELECT USING (auth.role() = 'authenticated');
    END IF;

    -- Coaching_Messages
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Coaching_Messages' AND column_name = 'account_id') THEN
        DROP POLICY IF EXISTS "policy_coaching_messages" ON "Coaching_Messages";
        CREATE POLICY "policy_coaching_messages" ON "Coaching_Messages"
            FOR ALL USING (account_id = get_my_account_id());
    ELSE
        DROP POLICY IF EXISTS "policy_coaching_messages" ON "Coaching_Messages";
        CREATE POLICY "policy_coaching_messages" ON "Coaching_Messages"
            FOR ALL USING (auth.role() = 'authenticated');
    END IF;

    -- Coaching_Outcomes
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Coaching_Outcomes' AND column_name = 'account_id') THEN
        DROP POLICY IF EXISTS "policy_coaching_outcomes" ON "Coaching_Outcomes";
        CREATE POLICY "policy_coaching_outcomes" ON "Coaching_Outcomes"
            FOR SELECT USING (account_id = get_my_account_id());
    ELSE
        DROP POLICY IF EXISTS "policy_coaching_outcomes" ON "Coaching_Outcomes";
        CREATE POLICY "policy_coaching_outcomes" ON "Coaching_Outcomes"
            FOR SELECT USING (auth.role() = 'authenticated');
    END IF;

    -- Integration_Sync_Log
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Integration_Sync_Log' AND column_name = 'account_id') THEN
        DROP POLICY IF EXISTS "policy_integration_sync_log" ON "Integration_Sync_Log";
        CREATE POLICY "policy_integration_sync_log" ON "Integration_Sync_Log"
            FOR SELECT USING (account_id = get_my_account_id());
    ELSE
        DROP POLICY IF EXISTS "policy_integration_sync_log" ON "Integration_Sync_Log";
        CREATE POLICY "policy_integration_sync_log" ON "Integration_Sync_Log"
            FOR SELECT USING (auth.role() = 'authenticated');
    END IF;
END $block$;

-- Team_Wins policies (we just created this table, it has account_id)
DROP POLICY IF EXISTS "policy_team_wins_view" ON "Team_Wins";
CREATE POLICY "policy_team_wins_view" ON "Team_Wins"
    FOR SELECT USING (account_id = get_my_account_id());

DROP POLICY IF EXISTS "policy_team_wins_manage" ON "Team_Wins";
CREATE POLICY "policy_team_wins_manage" ON "Team_Wins"
    FOR INSERT WITH CHECK (account_id = get_my_account_id());

DROP POLICY IF EXISTS "policy_team_wins_update" ON "Team_Wins";
CREATE POLICY "policy_team_wins_update" ON "Team_Wins"
    FOR UPDATE USING (account_id = get_my_account_id());

DROP POLICY IF EXISTS "policy_team_wins_delete" ON "Team_Wins";
CREATE POLICY "policy_team_wins_delete" ON "Team_Wins"
    FOR DELETE USING (account_id = get_my_account_id());

-- Win_Celebrations policies
DROP POLICY IF EXISTS "policy_win_celebrations" ON "Win_Celebrations";
CREATE POLICY "policy_win_celebrations" ON "Win_Celebrations"
    FOR ALL USING (
        win_id IN (SELECT id FROM "Team_Wins" WHERE account_id = get_my_account_id())
    );

-- Revoke anon access
DO $block$
BEGIN
    EXECUTE 'REVOKE ALL ON "API_Connections" FROM anon';
EXCEPTION WHEN OTHERS THEN NULL;
END $block$;

DO $block$
BEGIN
    EXECUTE 'REVOKE ALL ON "Coaching_Messages" FROM anon';
EXCEPTION WHEN OTHERS THEN NULL;
END $block$;

SELECT 'Migration 4 complete: Security applied' as status;
