-- ============================================
-- Conversation Analysis Table - FIXED VERSION
-- Run this in Supabase SQL Editor
-- ============================================

CREATE TABLE IF NOT EXISTS "Conversation_Analyses" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL DEFAULT CURRENT_DATE,

    -- Conversation Details
    conversation_title VARCHAR(255) NOT NULL,
    conversation_type VARCHAR(50) DEFAULT 'discovery',
    duration_minutes INTEGER,
    prospect_name VARCHAR(255),
    transcript TEXT,

    -- Sandler Scoring (1-10)
    overall_sandler_score DECIMAL(3, 1) CHECK (overall_sandler_score >= 0 AND overall_sandler_score <= 10),
    upfront_contract_score DECIMAL(3, 1),
    pain_funnel_score DECIMAL(3, 1),
    budget_discussion_score DECIMAL(3, 1),
    decision_process_score DECIMAL(3, 1),
    bonding_rapport_score DECIMAL(3, 1),

    -- Boolean Metrics (for categorical insights)
    talk_percentage INTEGER,
    pain_identified BOOLEAN DEFAULT FALSE,
    budget_discussed BOOLEAN DEFAULT FALSE,
    decision_makers_identified BOOLEAN DEFAULT FALSE,
    upfront_contract_set BOOLEAN DEFAULT FALSE,
    negative_reverse_used BOOLEAN DEFAULT FALSE,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_conversation_user ON "Conversation_Analyses"(user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_conversation_date ON "Conversation_Analyses"(date DESC);

-- RLS Policies
ALTER TABLE "Conversation_Analyses" ENABLE ROW LEVEL SECURITY;

-- Users can view their own conversations
CREATE POLICY "Users can view own conversations"
ON "Conversation_Analyses" FOR SELECT TO authenticated
USING (user_id = auth.uid());

-- Users can insert their own conversations
CREATE POLICY "Users can insert own conversations"
ON "Conversation_Analyses" FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

-- Users can update their own conversations
CREATE POLICY "Users can update own conversations"
ON "Conversation_Analyses" FOR UPDATE TO authenticated
USING (user_id = auth.uid());

-- Users can delete their own conversations
CREATE POLICY "Users can delete own conversations"
ON "Conversation_Analyses" FOR DELETE TO authenticated
USING (user_id = auth.uid());

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Conversation_Analyses table created successfully!';
END $$;
