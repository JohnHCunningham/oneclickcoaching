-- Phase 5: Goals & Leading Indicators

CREATE TABLE IF NOT EXISTS "Goals" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,
  user_id UUID REFERENCES "Users"(id) ON DELETE CASCADE,
  rep_email TEXT,
  goal_type TEXT NOT NULL CHECK (goal_type IN ('contacts', 'discovery_calls', 'sales', 'quota', 'sandler_score')),
  target_value NUMERIC NOT NULL,
  current_value NUMERIC NOT NULL DEFAULT 0,
  period TEXT NOT NULL DEFAULT 'monthly' CHECK (period IN ('weekly', 'monthly', 'quarterly')),
  period_start DATE NOT NULL DEFAULT (date_trunc('month', CURRENT_DATE)::date),
  period_end DATE NOT NULL DEFAULT ((date_trunc('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::date),
  set_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE "Goals" ENABLE ROW LEVEL SECURITY;

-- Managers can manage goals for their account
CREATE POLICY "managers_manage_goals" ON "Goals"
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM "Users"
      WHERE "Users".auth_id = auth.uid()
      AND "Users".account_id = "Goals".account_id
      AND "Users".role IN ('admin', 'manager')
    )
  );

-- Reps can view their own goals
CREATE POLICY "reps_view_own_goals" ON "Goals"
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM "Users"
      WHERE "Users".auth_id = auth.uid()
      AND "Users".account_id = "Goals".account_id
      AND ("Goals".user_id = "Users".id OR "Goals".rep_email = "Users".email)
    )
  );

CREATE INDEX IF NOT EXISTS idx_goals_account ON "Goals"(account_id);
CREATE INDEX IF NOT EXISTS idx_goals_user ON "Goals"(user_id);

SELECT 'Phase 5 goals migration complete' as status;
