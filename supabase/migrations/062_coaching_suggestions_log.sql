-- Non-repetition engine: track coaching suggestions per rep
CREATE TABLE IF NOT EXISTS "Coaching_Suggestions_Log" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID REFERENCES "Accounts"(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  call_id UUID,
  suggestion_text TEXT NOT NULL,
  component TEXT,
  weakness_pattern TEXT,
  times_flagged INT DEFAULT 1,
  first_flagged_at TIMESTAMPTZ DEFAULT now(),
  last_flagged_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE "Coaching_Suggestions_Log" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own coaching history"
  ON "Coaching_Suggestions_Log" FOR SELECT
  USING (
    user_id = auth.uid()
    OR account_id IN (
      SELECT account_id FROM "Users"
      WHERE auth_id = auth.uid() AND role IN ('admin', 'manager', 'coach')
    )
  );

CREATE POLICY "System can insert coaching suggestions"
  ON "Coaching_Suggestions_Log" FOR INSERT
  WITH CHECK (true);
