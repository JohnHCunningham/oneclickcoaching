-- MIGRATION 1: Add Methodology to Accounts

-- Step 1: Add methodology column if it doesn't exist
ALTER TABLE "Accounts" ADD COLUMN IF NOT EXISTS methodology TEXT DEFAULT 'sandler';

-- Step 2: Add constraint (will skip if exists)
DO $$
BEGIN
    ALTER TABLE "Accounts" ADD CONSTRAINT accounts_methodology_check
    CHECK (methodology IN ('sandler', 'challenger', 'gap', 'meddic'));
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- Step 3: Create helper function
CREATE OR REPLACE FUNCTION get_methodology_config(account_uuid UUID)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $func$
DECLARE
    m TEXT;
BEGIN
    SELECT methodology INTO m FROM "Accounts" WHERE id = account_uuid;

    IF m = 'sandler' THEN
        RETURN '{"name":"Sandler","components":["Upfront Contract","Pain Funnel","Budget","Decision Process","Fulfillment","Post-Sell","Bonding & Rapport","Negative Reverse Selling"]}'::JSONB;
    ELSIF m = 'challenger' THEN
        RETURN '{"name":"Challenger","components":["Teaching","Tailoring","Taking Control","Constructive Tension","Commercial Insight","Reframe Thinking"]}'::JSONB;
    ELSIF m = 'gap' THEN
        RETURN '{"name":"Gap Selling","components":["Current State","Future State","Gap Identification","Problem Quantification","Root Cause","Impact Assessment"]}'::JSONB;
    ELSIF m = 'meddic' THEN
        RETURN '{"name":"MEDDIC","components":["Metrics","Economic Buyer","Decision Criteria","Decision Process","Identify Pain","Champion"]}'::JSONB;
    ELSE
        RETURN '{"name":"Custom","components":[]}'::JSONB;
    END IF;
END $func$;

-- Done
SELECT 'Migration 1 complete: Methodology added' as status;
