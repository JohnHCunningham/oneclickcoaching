-- ============================================
-- PART 1: PREPARE EXISTING TABLES
-- Run this first, then run part 2
-- ============================================

-- Create Accounts table
CREATE TABLE IF NOT EXISTS "Accounts" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    company_name TEXT NOT NULL,
    industry TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create User_Roles table if it doesn't exist
CREATE TABLE IF NOT EXISTS "User_Roles" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('manager', 'user')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add account_id column to User_Roles if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'User_Roles' AND column_name = 'account_id'
    ) THEN
        ALTER TABLE "User_Roles" ADD COLUMN account_id UUID REFERENCES "Accounts"(id) ON DELETE CASCADE;
        RAISE NOTICE '✓ Added account_id column to User_Roles';
    ELSE
        RAISE NOTICE '✓ account_id column already exists';
    END IF;
END $$;

-- Add unique constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'User_Roles_user_id_account_id_key'
    ) THEN
        ALTER TABLE "User_Roles" ADD CONSTRAINT "User_Roles_user_id_account_id_key" UNIQUE(user_id, account_id);
        RAISE NOTICE '✓ Added unique constraint';
    END IF;
END $$;

-- Create a default account and link existing users
DO $$
DECLARE
    default_account_id UUID;
BEGIN
    -- Create default account if none exists
    IF NOT EXISTS (SELECT 1 FROM "Accounts" LIMIT 1) THEN
        INSERT INTO "Accounts" (company_name, industry)
        VALUES ('Default Company', 'Technology')
        RETURNING id INTO default_account_id;

        RAISE NOTICE '✓ Created default account: %', default_account_id;

        -- Update existing User_Roles records
        UPDATE "User_Roles"
        SET account_id = default_account_id
        WHERE account_id IS NULL;

        RAISE NOTICE '✓ Linked existing users to default account';
    ELSE
        RAISE NOTICE '✓ Account already exists';
    END IF;
END $$;

-- Create Conversation_Analyses table
CREATE TABLE IF NOT EXISTS "Conversation_Analyses" (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    account_id UUID REFERENCES "Accounts"(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    call_date TIMESTAMP WITH TIME ZONE,
    transcript TEXT,
    overall_sandler_score DECIMAL(3,1),
    methodology_scores JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '======================================';
    RAISE NOTICE '✅ PART 1 COMPLETE';
    RAISE NOTICE '======================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Prepared:';
    RAISE NOTICE '  • Accounts table';
    RAISE NOTICE '  • User_Roles table with account_id';
    RAISE NOTICE '  • Conversation_Analyses table';
    RAISE NOTICE '  • Default account created';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Now run: integrations-part2-tables.sql';
    RAISE NOTICE '';
END $$;
