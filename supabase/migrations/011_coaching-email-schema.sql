-- ============================================
-- COACHING EMAIL WORKFLOW SCHEMA UPDATE
-- Adds reply_token and enhances Coaching_Messages
-- ============================================

-- Add reply_token column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'Coaching_Messages' AND column_name = 'reply_token'
    ) THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN reply_token TEXT UNIQUE;
        RAISE NOTICE 'Added reply_token column';
    ELSE
        RAISE NOTICE 'reply_token column already exists';
    END IF;
END $$;

-- Add email tracking columns
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'Coaching_Messages' AND column_name = 'email_opened_at'
    ) THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN email_opened_at TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE 'Added email_opened_at column';
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'Coaching_Messages' AND column_name = 'last_error'
    ) THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN last_error TEXT;
        RAISE NOTICE 'Added last_error column';
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'Coaching_Messages' AND column_name = 'email_provider_id'
    ) THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN email_provider_id TEXT;
        RAISE NOTICE 'Added email_provider_id column';
    END IF;
END $$;

-- Add subject line column
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'Coaching_Messages' AND column_name = 'subject'
    ) THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN subject TEXT;
        RAISE NOTICE 'Added subject column';
    END IF;
END $$;

-- Add priority column
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'Coaching_Messages' AND column_name = 'priority'
    ) THEN
        ALTER TABLE "Coaching_Messages" ADD COLUMN priority TEXT DEFAULT 'medium';
        RAISE NOTICE 'Added priority column';
    END IF;
END $$;

-- Index for reply token lookups
CREATE INDEX IF NOT EXISTS idx_coaching_messages_reply_token
ON "Coaching_Messages"(reply_token) WHERE reply_token IS NOT NULL;

-- Index for manager inbox (unread replies)
CREATE INDEX IF NOT EXISTS idx_coaching_messages_replied
ON "Coaching_Messages"(manager_email, responded_at DESC) WHERE rep_response IS NOT NULL;

-- ============================================
-- RPC: Create coaching message (for AI generation)
-- ============================================
CREATE OR REPLACE FUNCTION create_coaching_message(
    p_rep_email TEXT,
    p_manager_email TEXT,
    p_coaching_content TEXT,
    p_methodology TEXT DEFAULT NULL,
    p_subject TEXT DEFAULT NULL,
    p_priority TEXT DEFAULT 'medium',
    p_based_on_calls JSONB DEFAULT '[]'::JSONB
)
RETURNS UUID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    account_uuid UUID;
    message_id UUID;
BEGIN
    -- Get account ID
    SELECT id INTO account_uuid FROM "Accounts" LIMIT 1;

    IF account_uuid IS NULL THEN
        RAISE EXCEPTION 'No account found';
    END IF;

    INSERT INTO "Coaching_Messages" (
        account_id,
        rep_email,
        manager_email,
        coaching_content,
        methodology,
        subject,
        priority,
        based_on_calls,
        status,
        generated_at
    ) VALUES (
        account_uuid,
        p_rep_email,
        p_manager_email,
        p_coaching_content,
        p_methodology,
        COALESCE(p_subject, 'Coaching Feedback: ' || COALESCE(p_methodology, 'Performance')),
        p_priority,
        p_based_on_calls,
        'draft',
        NOW()
    )
    RETURNING id INTO message_id;

    RETURN message_id;
END;
$$;

-- ============================================
-- RPC: Approve and send coaching message
-- ============================================
CREATE OR REPLACE FUNCTION approve_coaching_message(
    p_message_id UUID,
    p_edited_content TEXT DEFAULT NULL
)
RETURNS JSON
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    updated_msg RECORD;
BEGIN
    UPDATE "Coaching_Messages"
    SET
        coaching_content = COALESCE(p_edited_content, coaching_content),
        status = 'approved',
        approved_at = NOW()
    WHERE id = p_message_id
    RETURNING * INTO updated_msg;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'Message not found');
    END IF;

    RETURN json_build_object(
        'success', true,
        'message_id', updated_msg.id,
        'rep_email', updated_msg.rep_email,
        'status', updated_msg.status
    );
END;
$$;

-- ============================================
-- RPC: Get manager's coaching inbox
-- ============================================
CREATE OR REPLACE FUNCTION get_coaching_inbox(
    p_manager_email TEXT
)
RETURNS TABLE (
    id UUID,
    rep_email TEXT,
    subject TEXT,
    coaching_content TEXT,
    methodology TEXT,
    priority TEXT,
    status TEXT,
    generated_at TIMESTAMP WITH TIME ZONE,
    approved_at TIMESTAMP WITH TIME ZONE,
    sent_at TIMESTAMP WITH TIME ZONE,
    read_at TIMESTAMP WITH TIME ZONE,
    rep_response TEXT,
    responded_at TIMESTAMP WITH TIME ZONE
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        cm.id,
        cm.rep_email,
        cm.subject,
        cm.coaching_content,
        cm.methodology,
        cm.priority,
        cm.status,
        cm.generated_at,
        cm.approved_at,
        cm.sent_at,
        cm.read_at,
        cm.rep_response,
        cm.responded_at
    FROM "Coaching_Messages" cm
    WHERE cm.manager_email = p_manager_email
    ORDER BY
        CASE
            WHEN cm.rep_response IS NOT NULL AND cm.acknowledged_at IS NULL THEN 0  -- Unread replies first
            WHEN cm.status = 'draft' THEN 1  -- Then drafts
            ELSE 2
        END,
        cm.generated_at DESC
    LIMIT 50;
END;
$$;

-- ============================================
-- RPC: Get unread reply count for manager
-- ============================================
CREATE OR REPLACE FUNCTION get_unread_reply_count(
    p_manager_email TEXT
)
RETURNS INTEGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    unread_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO unread_count
    FROM "Coaching_Messages"
    WHERE manager_email = p_manager_email
      AND rep_response IS NOT NULL
      AND acknowledged_at IS NULL;

    RETURN unread_count;
END;
$$;

-- ============================================
-- RPC: Mark reply as acknowledged
-- ============================================
CREATE OR REPLACE FUNCTION acknowledge_reply(
    p_message_id UUID
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE "Coaching_Messages"
    SET acknowledged_at = NOW()
    WHERE id = p_message_id;

    RETURN FOUND;
END;
$$;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Coaching Email Schema Updated!';
    RAISE NOTICE '';
    RAISE NOTICE 'New columns added:';
    RAISE NOTICE '  - reply_token (for email reply links)';
    RAISE NOTICE '  - email_opened_at (tracking)';
    RAISE NOTICE '  - last_error (error tracking)';
    RAISE NOTICE '  - email_provider_id (Resend ID)';
    RAISE NOTICE '  - subject (email subject)';
    RAISE NOTICE '  - priority (low/medium/high)';
    RAISE NOTICE '';
    RAISE NOTICE 'RPC Functions:';
    RAISE NOTICE '  - create_coaching_message()';
    RAISE NOTICE '  - approve_coaching_message()';
    RAISE NOTICE '  - get_coaching_inbox()';
    RAISE NOTICE '  - get_unread_reply_count()';
    RAISE NOTICE '  - acknowledge_reply()';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Ready for coaching email workflow!';
END $$;
