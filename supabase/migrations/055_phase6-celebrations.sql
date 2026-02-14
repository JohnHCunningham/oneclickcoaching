-- Phase 6: Gamification / Celebrations

CREATE TABLE IF NOT EXISTS "Celebrations" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES "Accounts"(id) ON DELETE CASCADE,
  user_id UUID REFERENCES "Users"(id) ON DELETE CASCADE,
  rep_email TEXT,
  type TEXT NOT NULL CHECK (type IN ('badge', 'milestone', 'streak', 'achievement')),
  title TEXT NOT NULL,
  description TEXT,
  badge_key TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE "Celebrations" ENABLE ROW LEVEL SECURITY;

-- All users in the account can view celebrations (team feed)
CREATE POLICY "account_view_celebrations" ON "Celebrations"
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM "Users"
      WHERE "Users".auth_id = auth.uid()
      AND "Users".account_id = "Celebrations".account_id
    )
  );

-- System/managers can create celebrations
CREATE POLICY "managers_create_celebrations" ON "Celebrations"
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM "Users"
      WHERE "Users".auth_id = auth.uid()
      AND "Users".account_id = "Celebrations".account_id
    )
  );

CREATE INDEX IF NOT EXISTS idx_celebrations_account ON "Celebrations"(account_id);
CREATE INDEX IF NOT EXISTS idx_celebrations_user ON "Celebrations"(user_id);

SELECT 'Phase 6 celebrations migration complete' as status;
