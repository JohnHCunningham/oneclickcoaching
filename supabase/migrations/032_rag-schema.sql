-- ============================================
-- RAG SYSTEM SCHEMA FOR SANDLER REVENUE FACTORY
-- Retrieval-Augmented Generation for AI Coaching
-- ============================================

-- IMPORTANT: You must enable the pgvector extension in Supabase Dashboard first!
-- Go to: Database > Extensions > Search for "vector" > Enable it
--
-- Or run this in SQL Editor (requires superuser/service_role):
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;

-- If the above fails, the extension needs to be enabled via the Dashboard:
-- 1. Go to your Supabase project
-- 2. Navigate to Database > Extensions
-- 3. Search for "vector"
-- 4. Click the toggle to enable it
-- 5. Then re-run this schema

-- ============================================
-- TABLE: Sandler_Knowledge_Base
-- Stores chunked Sandler methodology content with embeddings
-- ============================================

CREATE TABLE IF NOT EXISTS "Sandler_Knowledge_Base" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Content categorization
    content_type TEXT NOT NULL,                    -- 'component', 'script', 'objection', 'best_practice'
    component_name TEXT,                           -- 'PAIN_FUNNEL', 'UPFRONT_CONTRACT', etc.
    chunk_title TEXT NOT NULL,                     -- Human-readable title
    chunk_text TEXT NOT NULL,                      -- The actual content

    -- Tagging for retrieval
    situation_tags TEXT[] DEFAULT '{}',            -- ['cold_call', 'discovery', 'objection']
    weakness_tags TEXT[] DEFAULT '{}',             -- ['pain_funnel', 'budget']

    -- Embedding for semantic search
    embedding vector(1536),                        -- OpenAI text-embedding-3-small

    -- Metadata
    source_file TEXT,                              -- Original source file
    chunk_index INTEGER,                           -- Order within source
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for vector similarity search (IVFFlat for cost-effective search)
CREATE INDEX IF NOT EXISTS sandler_kb_embedding_idx
ON "Sandler_Knowledge_Base"
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Create index for filtered queries
CREATE INDEX IF NOT EXISTS sandler_kb_content_type_idx ON "Sandler_Knowledge_Base" (content_type);
CREATE INDEX IF NOT EXISTS sandler_kb_component_name_idx ON "Sandler_Knowledge_Base" (component_name);
CREATE INDEX IF NOT EXISTS sandler_kb_active_idx ON "Sandler_Knowledge_Base" (is_active);

-- GIN index for array tag searches
CREATE INDEX IF NOT EXISTS sandler_kb_situation_tags_idx ON "Sandler_Knowledge_Base" USING GIN (situation_tags);
CREATE INDEX IF NOT EXISTS sandler_kb_weakness_tags_idx ON "Sandler_Knowledge_Base" USING GIN (weakness_tags);

-- ============================================
-- TABLE: Embedding_Cache
-- Caches embeddings to reduce API costs
-- ============================================

CREATE TABLE IF NOT EXISTS "Embedding_Cache" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    text_hash TEXT NOT NULL UNIQUE,                -- SHA-256 hash of input text
    original_text TEXT NOT NULL,                   -- The text that was embedded
    embedding vector(1536),                        -- The embedding vector
    model TEXT DEFAULT 'text-embedding-3-small',   -- Model used
    hit_count INTEGER DEFAULT 1,                   -- Cache hit counter
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_accessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS embedding_cache_hash_idx ON "Embedding_Cache" (text_hash);

-- ============================================
-- FUNCTION: search_sandler_content
-- Semantic search over knowledge base
-- ============================================

CREATE OR REPLACE FUNCTION search_sandler_content(
    query_embedding vector(1536),
    match_threshold FLOAT DEFAULT 0.5,
    match_count INT DEFAULT 5,
    filter_content_types TEXT[] DEFAULT NULL,
    filter_components TEXT[] DEFAULT NULL,
    filter_weakness_tags TEXT[] DEFAULT NULL,
    filter_situation_tags TEXT[] DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    content_type TEXT,
    component_name TEXT,
    chunk_title TEXT,
    chunk_text TEXT,
    situation_tags TEXT[],
    weakness_tags TEXT[],
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        kb.id,
        kb.content_type,
        kb.component_name,
        kb.chunk_title,
        kb.chunk_text,
        kb.situation_tags,
        kb.weakness_tags,
        1 - (kb.embedding <=> query_embedding) AS similarity
    FROM "Sandler_Knowledge_Base" kb
    WHERE
        kb.is_active = TRUE
        AND (filter_content_types IS NULL OR kb.content_type = ANY(filter_content_types))
        AND (filter_components IS NULL OR kb.component_name = ANY(filter_components))
        AND (filter_weakness_tags IS NULL OR kb.weakness_tags && filter_weakness_tags)
        AND (filter_situation_tags IS NULL OR kb.situation_tags && filter_situation_tags)
        AND 1 - (kb.embedding <=> query_embedding) > match_threshold
    ORDER BY kb.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- ============================================
-- FUNCTION: get_or_create_embedding_cache
-- Returns cached embedding or NULL if not found
-- ============================================

CREATE OR REPLACE FUNCTION get_cached_embedding(input_hash TEXT)
RETURNS vector(1536)
LANGUAGE plpgsql
AS $$
DECLARE
    cached_embedding vector(1536);
BEGIN
    -- Update hit count and last accessed, return embedding
    UPDATE "Embedding_Cache"
    SET
        hit_count = hit_count + 1,
        last_accessed_at = NOW()
    WHERE text_hash = input_hash
    RETURNING embedding INTO cached_embedding;

    RETURN cached_embedding;
END;
$$;

-- ============================================
-- FUNCTION: cache_embedding
-- Stores a new embedding in cache
-- ============================================

CREATE OR REPLACE FUNCTION cache_embedding(
    input_hash TEXT,
    input_text TEXT,
    input_embedding vector(1536),
    input_model TEXT DEFAULT 'text-embedding-3-small'
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "Embedding_Cache" (text_hash, original_text, embedding, model)
    VALUES (input_hash, input_text, input_embedding, input_model)
    ON CONFLICT (text_hash)
    DO UPDATE SET
        hit_count = "Embedding_Cache".hit_count + 1,
        last_accessed_at = NOW();
END;
$$;

-- ============================================
-- FUNCTION: find_related_scripts
-- Quick helper to find scripts for weak areas
-- ============================================

CREATE OR REPLACE FUNCTION find_scripts_for_weakness(
    weak_component TEXT,
    limit_count INT DEFAULT 3
)
RETURNS TABLE (
    chunk_title TEXT,
    chunk_text TEXT,
    situation_tags TEXT[]
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        kb.chunk_title,
        kb.chunk_text,
        kb.situation_tags
    FROM "Sandler_Knowledge_Base" kb
    WHERE
        kb.is_active = TRUE
        AND kb.content_type = 'script'
        AND (
            kb.component_name = weak_component
            OR weak_component = ANY(kb.weakness_tags)
        )
    ORDER BY RANDOM()
    LIMIT limit_count;
END;
$$;

-- ============================================
-- ROW LEVEL SECURITY (Optional - for multi-tenant)
-- ============================================

-- Enable RLS
ALTER TABLE "Sandler_Knowledge_Base" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Embedding_Cache" ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read knowledge base
CREATE POLICY "Allow read access to knowledge base"
ON "Sandler_Knowledge_Base"
FOR SELECT
USING (true);

-- Allow service role to manage knowledge base
CREATE POLICY "Allow service role to manage knowledge base"
ON "Sandler_Knowledge_Base"
FOR ALL
USING (auth.role() = 'service_role');

-- Allow all to read/write embedding cache
CREATE POLICY "Allow access to embedding cache"
ON "Embedding_Cache"
FOR ALL
USING (true);

-- ============================================
-- CLEANUP FUNCTION: Remove old cache entries
-- ============================================

CREATE OR REPLACE FUNCTION cleanup_old_embeddings()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete cache entries not accessed in 30 days with low hit count
    DELETE FROM "Embedding_Cache"
    WHERE
        last_accessed_at < NOW() - INTERVAL '30 days'
        AND hit_count < 3;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

-- ============================================
-- COMMENTS
-- ============================================

COMMENT ON TABLE "Sandler_Knowledge_Base" IS 'Chunked Sandler methodology content with vector embeddings for RAG';
COMMENT ON TABLE "Embedding_Cache" IS 'Cache for text embeddings to reduce OpenAI API costs';
COMMENT ON FUNCTION search_sandler_content IS 'Semantic similarity search over Sandler knowledge base';
COMMENT ON FUNCTION find_scripts_for_weakness IS 'Find practice scripts for a specific weak component';
