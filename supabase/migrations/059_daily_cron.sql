-- Migration 059: Daily Coaching Pipeline Cron Job
-- Runs at 8:00 AM EST (13:00 UTC) Monday through Friday
-- Chains: sync integrations → analyze new calls → notify leader
--
-- Prerequisites:
--   1. Enable pg_cron extension in Supabase Dashboard → Database → Extensions
--   2. Enable pg_net extension for HTTP calls from within Postgres
--   3. Set project URL and service role key as secrets:
--      ALTER DATABASE postgres SET app.supabase_url = 'https://your-project.supabase.co';
--      ALTER DATABASE postgres SET app.service_role_key = 'your-service-role-key';

-- Enable extensions (pg_cron must also be enabled via Dashboard)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ============================================
-- Helper: Invoke a Supabase Edge Function
-- ============================================
CREATE OR REPLACE FUNCTION invoke_edge_function(
  function_name TEXT,
  payload JSONB DEFAULT '{}'::JSONB
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  project_url TEXT;
  service_key TEXT;
  request_id BIGINT;
BEGIN
  project_url := current_setting('app.supabase_url', true);
  service_key := current_setting('app.service_role_key', true);

  IF project_url IS NULL OR service_key IS NULL THEN
    RAISE WARNING 'Missing app.supabase_url or app.service_role_key settings. Skipping edge function call.';
    RETURN NULL;
  END IF;

  SELECT net.http_post(
    url := project_url || '/functions/v1/' || function_name,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body := payload
  ) INTO request_id;

  RETURN request_id;
END;
$$;

-- ============================================
-- Daily Pipeline: Sync all integrations for all active accounts
-- ============================================
CREATE OR REPLACE FUNCTION run_daily_coaching_pipeline()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  account RECORD;
  connection RECORD;
BEGIN
  RAISE LOG '[coaching-pipeline] Starting daily coaching pipeline at %', now();

  -- Loop through all active accounts
  FOR account IN
    SELECT id FROM "Accounts" WHERE status = 'active' OR status IS NULL
  LOOP
    RAISE LOG '[coaching-pipeline] Processing account %', account.id;

    -- Trigger sync for each active integration connection
    FOR connection IN
      SELECT provider, id
      FROM "API_Connections"
      WHERE account_id = account.id
        AND connection_status = 'active'
    LOOP
      -- Dispatch sync based on provider
      CASE connection.provider
        WHEN 'hubspot' THEN
          PERFORM invoke_edge_function('hubspot-sync', jsonb_build_object(
            'account_id', account.id
          ));
          RAISE LOG '[coaching-pipeline] Triggered hubspot-sync for account %', account.id;

        WHEN 'fathom' THEN
          PERFORM invoke_edge_function('fathom-sync', jsonb_build_object(
            'account_id', account.id
          ));
          RAISE LOG '[coaching-pipeline] Triggered fathom-sync for account %', account.id;

        WHEN 'aircall' THEN
          PERFORM invoke_edge_function('aircall-sync', jsonb_build_object(
            'account_id', account.id
          ));
          RAISE LOG '[coaching-pipeline] Triggered aircall-sync for account %', account.id;

        ELSE
          RAISE LOG '[coaching-pipeline] Unknown provider % for account %', connection.provider, account.id;
      END CASE;
    END LOOP;

    -- After syncs dispatched, trigger analysis of unanalyzed conversations
    -- (Small delay to allow syncs to land — edge functions are async via pg_net)
    PERFORM pg_sleep(2);

    PERFORM invoke_edge_function('analyze-call', jsonb_build_object(
      'account_id', account.id,
      'mode', 'batch',
      'use_rag', true
    ));
    RAISE LOG '[coaching-pipeline] Triggered batch analysis for account %', account.id;

  END LOOP;

  RAISE LOG '[coaching-pipeline] Daily pipeline complete at %', now();
END;
$$;

-- ============================================
-- Leader Notification: Send digest of pending coaching
-- ============================================
CREATE OR REPLACE FUNCTION notify_leaders_pending_coaching()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  leader RECORD;
  pending_count INT;
BEGIN
  -- Find leaders with pending coaching messages
  FOR leader IN
    SELECT DISTINCT u.id AS user_id, u.email, u.account_id, u.first_name
    FROM "Users" u
    WHERE u.role IN ('admin', 'manager', 'coach')
  LOOP
    -- Count pending coaching for their account
    SELECT COUNT(*) INTO pending_count
    FROM "Coaching_Messages" cm
    WHERE cm.account_id = leader.account_id
      AND cm.status = 'generated'
      AND cm.created_at > now() - interval '24 hours';

    IF pending_count > 0 THEN
      PERFORM invoke_edge_function('send-coaching-email', jsonb_build_object(
        'type', 'leader_digest',
        'leader_email', leader.email,
        'leader_name', leader.first_name,
        'pending_count', pending_count,
        'account_id', leader.account_id
      ));
      RAISE LOG '[coaching-pipeline] Notified leader % of % pending coaching messages', leader.email, pending_count;
    END IF;
  END LOOP;
END;
$$;

-- ============================================
-- Schedule the cron jobs
-- ============================================
-- Note: pg_cron uses UTC. 8:00 AM EST = 13:00 UTC (or 12:00 UTC during EDT)
-- Using 13:00 UTC for EST. Adjust to 12:00 for EDT if needed.

-- Main pipeline: 8:00 AM EST, Monday-Friday
SELECT cron.schedule(
  'daily-coaching-pipeline',
  '0 13 * * 1-5',
  $$SELECT run_daily_coaching_pipeline()$$
);

-- Leader notification: 8:15 AM EST, Monday-Friday (15 min after pipeline to allow processing)
SELECT cron.schedule(
  'notify-leaders-pending',
  '15 13 * * 1-5',
  $$SELECT notify_leaders_pending_coaching()$$
);

-- ============================================
-- Tracking table for pipeline runs
-- ============================================
CREATE TABLE IF NOT EXISTS "Pipeline_Runs" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  started_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ,
  accounts_processed INT DEFAULT 0,
  calls_analyzed INT DEFAULT 0,
  coaching_generated INT DEFAULT 0,
  errors TEXT[],
  status TEXT DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed'))
);

-- Index for recent runs lookup
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_started
  ON "Pipeline_Runs" (started_at DESC);

COMMENT ON FUNCTION run_daily_coaching_pipeline() IS 'Daily 8am EST pipeline: syncs integrations, analyzes new calls, queues coaching for leader approval';
COMMENT ON FUNCTION notify_leaders_pending_coaching() IS 'Sends digest email to leaders with pending coaching to review';
COMMENT ON FUNCTION invoke_edge_function(TEXT, JSONB) IS 'Helper to call Supabase Edge Functions from within Postgres via pg_net';
