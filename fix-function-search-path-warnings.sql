-- ============================================
-- FIX FUNCTION SEARCH PATH WARNINGS
-- Adds search_path security to trigger functions
-- ============================================

-- Fix: update_updated_at_column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Fix: update_manager_tables_timestamp
CREATE OR REPLACE FUNCTION update_manager_tables_timestamp()
RETURNS TRIGGER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Function search_path warnings fixed!';
    RAISE NOTICE 'Both functions now have SET search_path = public for security.';
END $$;
