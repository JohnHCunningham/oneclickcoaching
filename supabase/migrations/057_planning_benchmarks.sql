-- Planning & benchmarks table for quota and target tracking
CREATE TABLE IF NOT EXISTS "Benchmarks" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID REFERENCES "Accounts"(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  period TEXT NOT NULL DEFAULT 'weekly' CHECK (period IN ('daily', 'weekly', 'monthly')),
  approaches_target INT DEFAULT 0,
  discovery_calls_target INT DEFAULT 0,
  conversions_target INT DEFAULT 0,
  approaches_actual INT DEFAULT 0,
  discovery_calls_actual INT DEFAULT 0,
  conversions_actual INT DEFAULT 0,
  week_start DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE "Benchmarks" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view benchmarks in their account"
  ON "Benchmarks" FOR SELECT
  USING (account_id IN (SELECT account_id FROM "Users" WHERE auth_id = auth.uid()));

CREATE POLICY "Leaders can manage benchmarks"
  ON "Benchmarks" FOR ALL
  USING (account_id IN (
    SELECT account_id FROM "Users"
    WHERE auth_id = auth.uid() AND role IN ('admin', 'manager', 'coach')
  ));
