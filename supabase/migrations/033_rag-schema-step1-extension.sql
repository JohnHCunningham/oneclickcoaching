-- STEP 1: Enable pgvector extension
-- Run this FIRST, then run rag-schema-step2-tables.sql

-- This requires the extension to be enabled via Dashboard first
-- Go to: Database > Extensions > Search "vector" > Enable

-- Verify the extension is enabled:
SELECT * FROM pg_extension WHERE extname = 'vector';
