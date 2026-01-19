-- ============================================
-- CREATE RPC FUNCTIONS ONLY
-- Tables already exist, just add functions
-- ============================================

-- Function: save_hubspot_connection
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
    -- Get first account from Accounts table
    SELECT id INTO user_account_id FROM "Accounts" LIMIT 1;

    IF user_account_id IS NULL THEN
        RAISE EXCEPTION 'No account found in database';
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

-- Function: get_hubspot_connection
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
BEGIN
    RETURN QUERY
    SELECT
        ac.id, ac.access_token, ac.refresh_token,
        ac.token_expires_at, ac.connection_status,
        ac.last_successful_sync,
        COUNT(sa.id) as activities_synced
    FROM "API_Connections" ac
    LEFT JOIN "Synced_Activities" sa ON sa.account_id = ac.account_id AND sa.source_provider = 'hubspot'
    WHERE ac.provider = 'hubspot'
    GROUP BY ac.id, ac.access_token, ac.refresh_token, ac.token_expires_at, ac.connection_status, ac.last_successful_sync
    LIMIT 1;
END;
$$;

-- Function: save_fathom_connection
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
    SELECT id INTO user_account_id FROM "Accounts" LIMIT 1;

    IF user_account_id IS NULL THEN
        RAISE EXCEPTION 'No account found in database';
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

-- Function: get_fathom_connection
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
BEGIN
    RETURN QUERY
    SELECT
        ac.id, ac.access_token, ac.connection_status,
        ac.last_successful_sync,
        COUNT(sc.id) as conversations_synced
    FROM "API_Connections" ac
    LEFT JOIN "Synced_Conversations" sc ON sc.account_id = ac.account_id AND sc.source_provider = 'fathom'
    WHERE ac.provider = 'fathom'
    GROUP BY ac.id, ac.access_token, ac.connection_status, ac.last_successful_sync
    LIMIT 1;
END;
$$;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '✅ RPC FUNCTIONS CREATED!';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Created 4 functions:';
    RAISE NOTICE '  ✓ save_hubspot_connection()';
    RAISE NOTICE '  ✓ get_hubspot_connection()';
    RAISE NOTICE '  ✓ save_fathom_connection()';
    RAISE NOTICE '  ✓ get_fathom_connection()';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Integration infrastructure complete!';
    RAISE NOTICE '📖 Next: Open integrations.html';
    RAISE NOTICE '';
    RAISE NOTICE 'Tables already exist:';
    RAISE NOTICE '  ✓ API_Connections';
    RAISE NOTICE '  ✓ Synced_Activities';
    RAISE NOTICE '  ✓ Synced_Conversations';
    RAISE NOTICE '  ✓ Integration_Sync_Log';
    RAISE NOTICE '  ✓ Coaching_Messages';
    RAISE NOTICE '  ✓ Coaching_Outcomes';
    RAISE NOTICE '';
END $$;
