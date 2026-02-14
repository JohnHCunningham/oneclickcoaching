-- MIGRATION 3: Team Wins Tables

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

CREATE TABLE IF NOT EXISTS "Win_Celebrations" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    win_id UUID NOT NULL REFERENCES "Team_Wins"(id) ON DELETE CASCADE,
    user_email TEXT NOT NULL,
    celebrated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(win_id, user_email)
);

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
AS $func$
DECLARE
    v_account_id UUID;
    v_email TEXT;
    v_win_id UUID;
BEGIN
    SELECT ur.account_id, u.email INTO v_account_id, v_email
    FROM "User_Roles" ur
    JOIN auth.users u ON ur.user_id = u.id
    WHERE ur.user_id = auth.uid() AND ur.role IN ('manager', 'coach')
    LIMIT 1;

    INSERT INTO "Team_Wins" (
        account_id, rep_email, rep_name, win_type, title, description,
        related_call_id, methodology_component, score, shared_by_email, is_pinned
    ) VALUES (
        v_account_id, p_rep_email, p_rep_name, p_win_type, p_title, p_description,
        p_related_call_id, p_methodology_component, p_score, v_email, p_is_pinned
    )
    RETURNING id INTO v_win_id;

    RETURN v_win_id;
END $func$;

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
AS $func$
BEGIN
    RETURN QUERY
    SELECT tw.id, tw.rep_email, tw.rep_name, tw.win_type, tw.title, tw.description,
        tw.methodology_component, tw.score, tw.shared_by_email, tw.shared_at,
        tw.is_pinned, tw.celebration_count
    FROM "Team_Wins" tw
    WHERE tw.account_id = (SELECT account_id FROM "User_Roles" WHERE user_id = auth.uid() LIMIT 1)
    ORDER BY tw.is_pinned DESC, tw.shared_at DESC
    LIMIT p_limit;
END $func$;

CREATE OR REPLACE FUNCTION celebrate_win(p_win_id UUID)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $func$
BEGIN
    INSERT INTO "Win_Celebrations" (win_id, user_email)
    VALUES (p_win_id, (SELECT email FROM auth.users WHERE id = auth.uid()))
    ON CONFLICT DO NOTHING;

    UPDATE "Team_Wins"
    SET celebration_count = (SELECT COUNT(*) FROM "Win_Celebrations" WHERE win_id = p_win_id)
    WHERE id = p_win_id;

    RETURN TRUE;
END $func$;

SELECT 'Migration 3 complete: Team Wins added' as status;
