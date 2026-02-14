SELECT 1;
SELECT 2;

DROP FUNCTION IF EXISTS cache_embedding(TEXT, vector);
DROP FUNCTION IF EXISTS get_cached_embedding(TEXT);
DROP FUNCTION IF EXISTS search_sandler_content(vector, INT);
DROP FUNCTION IF EXISTS cleanup_old_embeddings();
DROP FUNCTION IF EXISTS create_manager_note(UUID, TEXT);
DROP FUNCTION IF EXISTS create_user_goal(TEXT, INT);
DROP FUNCTION IF EXISTS find_scripts_for_weakness(TEXT);

CREATE OR REPLACE FUNCTION cache_embedding(p_text TEXT, p_embedding vector)
RETURNS void
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $func$
BEGIN
    INSERT INTO "Embedding_Cache" (input_text, embedding)
    VALUES (p_text, p_embedding)
    ON CONFLICT (input_text) DO UPDATE SET embedding = p_embedding, created_at = NOW();
END $func$;

CREATE OR REPLACE FUNCTION get_cached_embedding(p_text TEXT)
RETURNS vector
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $func$
BEGIN
    RETURN (SELECT embedding FROM "Embedding_Cache" WHERE input_text = p_text);
END $func$;

CREATE OR REPLACE FUNCTION search_sandler_content(query_embedding vector, match_count INT DEFAULT 5)
RETURNS TABLE (id UUID, content TEXT, component TEXT, similarity FLOAT)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $func$
BEGIN
    RETURN QUERY
    SELECT sk.id, sk.content, sk.component, 1 - (sk.embedding <=> query_embedding) as similarity
    FROM "Sandler_Knowledge_Base" sk
    ORDER BY sk.embedding <=> query_embedding
    LIMIT match_count;
END $func$;

CREATE OR REPLACE FUNCTION update_goal_progress()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $func$
BEGIN
    RETURN NEW;
END $func$;

CREATE OR REPLACE FUNCTION cleanup_old_embeddings()
RETURNS void
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $func$
BEGIN
    DELETE FROM "Embedding_Cache" WHERE created_at < NOW() - INTERVAL '30 days';
END $func$;

CREATE OR REPLACE FUNCTION create_manager_note(p_rep_id UUID, p_note TEXT)
RETURNS UUID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $func$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO "Manager_Notes" (rep_id, note) VALUES (p_rep_id, p_note) RETURNING id INTO v_id;
    RETURN v_id;
END $func$;

CREATE OR REPLACE FUNCTION create_user_goal(p_goal_type TEXT, p_target_value INT)
RETURNS UUID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $func$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO "user_goals" (user_id, goal_type, target_value)
    VALUES (auth.uid(), p_goal_type, p_target_value)
    RETURNING id INTO v_id;
    RETURN v_id;
END $func$;

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $func$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END $func$;

CREATE OR REPLACE FUNCTION find_scripts_for_weakness(p_weakness TEXT)
RETURNS TABLE (id UUID, script TEXT, component TEXT)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $func$
BEGIN
    RETURN QUERY
    SELECT sk.id, sk.content, sk.component
    FROM "Sandler_Knowledge_Base" sk
    WHERE sk.content_type = 'script' AND sk.component ILIKE '%' || p_weakness || '%'
    LIMIT 10;
END $func$;

CREATE OR REPLACE FUNCTION update_user_settings_timestamp()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $func$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END $func$;

DROP POLICY IF EXISTS "Allow anon all Coaching_Messages" ON "Coaching_Messages";

DROP POLICY IF EXISTS "Allow access to embedding cache" ON "Embedding_Cache";
ALTER TABLE IF EXISTS "Embedding_Cache" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "auth_embedding_cache" ON "Embedding_Cache";
CREATE POLICY "auth_embedding_cache" ON "Embedding_Cache"
    FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow all operations on Email_Tracking" ON "email_tracking";
DROP POLICY IF EXISTS "email_tracking_policy" ON "email_tracking";
ALTER TABLE IF EXISTS "email_tracking" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "auth_email_tracking" ON "email_tracking";
CREATE POLICY "auth_email_tracking" ON "email_tracking"
    FOR ALL USING (auth.role() = 'authenticated');

SELECT 'Migration 6 complete' as status;
