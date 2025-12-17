-- ============================================
-- Manager Team Coaching Dashboard - SECURITY DEFINER Functions
-- Run this AFTER admin-team-schema.sql
-- ============================================

-- These functions allow admin users to bypass RLS and query all users' data
-- Security is enforced by checking the caller's email against whitelist

-- ============================================
-- FUNCTION: get_team_overview
-- Returns summary of all users with key metrics and top weakness/strength
-- ============================================
CREATE OR REPLACE FUNCTION get_team_overview(
  admin_email TEXT,
  days_back INTEGER DEFAULT 30
)
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  company TEXT,
  methodology TEXT,
  -- Activity metrics
  total_dials BIGINT,
  total_conversations BIGINT,
  total_meetings BIGINT,
  dial_conv_rate NUMERIC,
  conv_meeting_rate NUMERIC,
  -- Revenue metrics
  total_revenue NUMERIC,
  total_sales BIGINT,
  avg_sale_value NUMERIC,
  -- Quality metrics
  avg_sandler_score NUMERIC,
  active_days INTEGER,
  -- Top weakness/strength (for quick insights)
  top_weakness_metric TEXT,
  top_weakness_rate NUMERIC,
  top_weakness_prompt TEXT,
  top_strength_metric TEXT,
  top_strength_rate NUMERIC,
  -- Performance score
  performance_score NUMERIC
)
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify caller is admin
  IF admin_email NOT IN ('admin@aiadvantagesolutions.com', 'admin@aiadvantagesolutions.ca', 'john@aiadvantagesolutions.com') THEN
    RAISE EXCEPTION 'Unauthorized: Not an admin user';
  END IF;

  -- Return aggregated data for all users (bypassing RLS)
  RETURN QUERY
  WITH user_activity AS (
    SELECT
      dt.user_id,
      SUM(dt.dials) as total_dials,
      SUM(dt.conversations) as total_conversations,
      SUM(dt.discovery_meetings) as total_meetings,
      COUNT(DISTINCT dt.date) as active_days,
      CASE
        WHEN SUM(dt.dials) > 0
        THEN (SUM(dt.conversations)::NUMERIC / SUM(dt.dials)) * 100
        ELSE 0
      END as dial_conv_rate,
      CASE
        WHEN SUM(dt.conversations) > 0
        THEN (SUM(dt.discovery_meetings)::NUMERIC / SUM(dt.conversations)) * 100
        ELSE 0
      END as conv_meeting_rate
    FROM "Daily_Tracker" dt
    WHERE dt.date >= CURRENT_DATE - (days_back || ' days')::INTERVAL
    GROUP BY dt.user_id
  ),
  user_sales AS (
    SELECT
      s.user_id,
      COUNT(*) as total_sales,
      SUM(s.amount_cad) as total_revenue,
      AVG(s.amount_cad) as avg_sale_value
    FROM "Sales" s
    WHERE s.date >= CURRENT_DATE - (days_back || ' days')::INTERVAL
    GROUP BY s.user_id
  ),
  user_quality AS (
    SELECT
      ca.user_id,
      AVG(ca.overall_sandler_score) as avg_sandler_score,
      -- Calculate methodology execution rates for weaknesses/strengths
      AVG(CASE WHEN ca.upfront_contract_set THEN 100 ELSE 0 END) as upfront_contract_rate,
      AVG(CASE WHEN ca.pain_identified THEN 100 ELSE 0 END) as pain_funnel_rate,
      AVG(CASE WHEN ca.budget_discussed THEN 100 ELSE 0 END) as budget_rate,
      AVG(ca.talk_percentage) as avg_talk_pct
    FROM "Conversation_Analyses" ca
    WHERE ca.date >= CURRENT_DATE - (days_back || ' days')::INTERVAL
    GROUP BY ca.user_id
  )
  SELECT
    au.id,
    au.email,
    (au.raw_user_meta_data->>'first_name')::TEXT,
    (au.raw_user_meta_data->>'last_name')::TEXT,
    (au.raw_user_meta_data->>'company')::TEXT,
    (au.raw_user_meta_data->>'methodology')::TEXT,
    COALESCE(ua.total_dials, 0),
    COALESCE(ua.total_conversations, 0),
    COALESCE(ua.total_meetings, 0),
    COALESCE(ua.dial_conv_rate, 0),
    COALESCE(ua.conv_meeting_rate, 0),
    COALESCE(us.total_revenue, 0),
    COALESCE(us.total_sales, 0),
    COALESCE(us.avg_sale_value, 0),
    COALESCE(uq.avg_sandler_score, 0),
    COALESCE(ua.active_days, 0),
    -- Top weakness (lowest execution rate)
    CASE
      WHEN COALESCE(uq.upfront_contract_rate, 100) < COALESCE(uq.pain_funnel_rate, 100)
        AND COALESCE(uq.upfront_contract_rate, 100) < COALESCE(uq.budget_rate, 100)
      THEN 'Upfront Contract'
      WHEN COALESCE(uq.pain_funnel_rate, 100) < COALESCE(uq.budget_rate, 100)
      THEN 'Pain Funnel'
      ELSE 'Budget Discussion'
    END,
    LEAST(
      COALESCE(uq.upfront_contract_rate, 100),
      COALESCE(uq.pain_funnel_rate, 100),
      COALESCE(uq.budget_rate, 100)
    ),
    CASE
      WHEN LEAST(COALESCE(uq.upfront_contract_rate, 100), COALESCE(uq.pain_funnel_rate, 100), COALESCE(uq.budget_rate, 100)) = COALESCE(uq.upfront_contract_rate, 100)
      THEN 'Calls are starting without clear direction - prospects don''t know what to expect.'
      WHEN LEAST(COALESCE(uq.upfront_contract_rate, 100), COALESCE(uq.pain_funnel_rate, 100), COALESCE(uq.budget_rate, 100)) = COALESCE(uq.pain_funnel_rate, 100)
      THEN 'Presenting solutions before understanding the real problem - prospects stay polite but don''t buy.'
      ELSE 'Avoiding money conversations early - creating surprises at proposal time.'
    END,
    -- Top strength (highest execution rate)
    CASE
      WHEN COALESCE(uq.upfront_contract_rate, 0) > COALESCE(uq.pain_funnel_rate, 0)
        AND COALESCE(uq.upfront_contract_rate, 0) > COALESCE(uq.budget_rate, 0)
      THEN 'Upfront Contract'
      WHEN COALESCE(uq.pain_funnel_rate, 0) > COALESCE(uq.budget_rate, 0)
      THEN 'Pain Funnel'
      ELSE 'Budget Discussion'
    END,
    GREATEST(
      COALESCE(uq.upfront_contract_rate, 0),
      COALESCE(uq.pain_funnel_rate, 0),
      COALESCE(uq.budget_rate, 0)
    ),
    -- Performance score (weighted composite)
    (
      COALESCE(ua.dial_conv_rate, 0) * 0.20 +
      COALESCE(ua.conv_meeting_rate, 0) * 0.20 +
      COALESCE(uq.avg_sandler_score, 0) * 10 * 0.30 +
      (COALESCE(ua.active_days, 0)::NUMERIC / NULLIF(days_back, 0) * 100) * 0.30
    )::NUMERIC(5,2)
  FROM auth.users au
  LEFT JOIN user_activity ua ON au.id = ua.user_id
  LEFT JOIN user_sales us ON au.id = us.user_id
  LEFT JOIN user_quality uq ON au.id = uq.user_id
  WHERE au.email NOT IN ('admin@aiadvantagesolutions.com', 'admin@aiadvantagesolutions.ca', 'john@aiadvantagesolutions.com')
  ORDER BY performance_score DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: get_user_categorical_insights
-- Deep analysis of methodology execution for a specific user
-- ============================================
CREATE OR REPLACE FUNCTION get_user_categorical_insights(
  admin_email TEXT,
  target_user_id UUID,
  days_back INTEGER DEFAULT 30
)
RETURNS TABLE (
  category TEXT,
  metric_name TEXT,
  execution_rate NUMERIC,
  calls_analyzed INTEGER,
  calls_executed INTEGER,
  severity TEXT,
  coaching_prompt TEXT
)
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_methodology TEXT;
BEGIN
  -- Verify caller is admin
  IF admin_email NOT IN ('admin@aiadvantagesolutions.com', 'admin@aiadvantagesolutions.ca', 'john@aiadvantagesolutions.com') THEN
    RAISE EXCEPTION 'Unauthorized: Not an admin user';
  END IF;

  -- Get user's methodology
  SELECT raw_user_meta_data->>'methodology' INTO user_methodology
  FROM auth.users WHERE id = target_user_id;

  -- Analyze based on methodology
  IF user_methodology = 'Sandler' THEN
    -- Upfront Contract analysis
    RETURN QUERY
    SELECT
      'Methodology Execution'::TEXT as category,
      'Upfront Contract'::TEXT as metric_name,
      (SUM(CASE WHEN upfront_contract_set THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) * 100,
      COUNT(*)::INTEGER,
      SUM(CASE WHEN upfront_contract_set THEN 1 ELSE 0 END)::INTEGER,
      CASE
        WHEN (SUM(CASE WHEN upfront_contract_set THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) < 0.5 THEN 'high'::TEXT
        WHEN (SUM(CASE WHEN upfront_contract_set THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) < 0.7 THEN 'medium'::TEXT
        ELSE 'low'::TEXT
      END,
      CASE
        WHEN (SUM(CASE WHEN upfront_contract_set THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) < 0.5
        THEN 'Most calls are starting without setting an upfront contract. This is leaving prospects confused about where the conversation is headed. What specific words will you use at the beginning of your next 5 calls to set a clear agenda?'::TEXT
        WHEN (SUM(CASE WHEN upfront_contract_set THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) < 0.7
        THEN 'You''re setting upfront contracts in some calls but not others. What''s different about the calls where you remember vs. where you don''t? Is it certain types of prospects, or time of day?'::TEXT
        ELSE 'Consistently strong on upfront contracts - prospects know exactly what to expect from every conversation with you. This foundation is making everything else easier.'::TEXT
      END
    FROM "Conversation_Analyses"
    WHERE user_id = target_user_id
      AND date >= CURRENT_DATE - (days_back || ' days')::INTERVAL;

    -- Pain Funnel analysis
    RETURN QUERY
    SELECT
      'Methodology Execution'::TEXT,
      'Pain Funnel'::TEXT,
      (SUM(CASE WHEN pain_identified THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) * 100,
      COUNT(*)::INTEGER,
      SUM(CASE WHEN pain_identified THEN 1 ELSE 0 END)::INTEGER,
      CASE
        WHEN (SUM(CASE WHEN pain_identified THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) < 0.5 THEN 'high'::TEXT
        WHEN (SUM(CASE WHEN pain_identified THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) < 0.7 THEN 'medium'::TEXT
        ELSE 'low'::TEXT
      END,
      CASE
        WHEN (SUM(CASE WHEN pain_identified THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) < 0.5
        THEN 'We''re talking about solutions before understanding the problem. Prospects are being polite, but we haven''t earned the right to present yet. Try this: After they mention a challenge, ask "Help me understand - what does that cost you?" then stay silent for 5 seconds.'::TEXT
        WHEN (SUM(CASE WHEN pain_identified THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) < 0.7
        THEN 'You''re identifying surface-level pain but not digging into the emotional impact. When a prospect says "it''s frustrating," what question would help them articulate WHY it matters? What''s at stake personally for them?'::TEXT
        ELSE 'You''re exceptional at uncovering real pain - prospects are opening up about what''s actually keeping them up at night. This is why your close rates are strong.'::TEXT
      END
    FROM "Conversation_Analyses"
    WHERE user_id = target_user_id
      AND date >= CURRENT_DATE - (days_back || ' days')::INTERVAL;

    -- Budget Discussion analysis
    RETURN QUERY
    SELECT
      'Methodology Execution'::TEXT,
      'Budget Discussion'::TEXT,
      (SUM(CASE WHEN budget_discussed THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) * 100,
      COUNT(*)::INTEGER,
      SUM(CASE WHEN budget_discussed THEN 1 ELSE 0 END)::INTEGER,
      CASE
        WHEN (SUM(CASE WHEN budget_discussed THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) < 0.5 THEN 'high'::TEXT
        WHEN (SUM(CASE WHEN budget_discussed THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) < 0.7 THEN 'medium'::TEXT
        ELSE 'low'::TEXT
      END,
      CASE
        WHEN (SUM(CASE WHEN budget_discussed THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) < 0.5
        THEN 'Money isn''t being discussed until late (or not at all) - creating surprises at proposal time. What makes you uncomfortable about asking "What budget have you allocated to solve this?" in the first conversation? Let''s roleplay that.'::TEXT
        WHEN (SUM(CASE WHEN budget_discussed THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) < 0.7
        THEN 'Budget comes up in some calls but you''re still dancing around it in others. Are you asking directly, or hinting? Try: "If I could show you a solution that solves X, what kind of investment range would make sense for you?"'::TEXT
        ELSE 'Money talk doesn''t faze you - prospects appreciate the transparency and it''s saving everyone time. No sticker shock at the end because expectations are set early.'::TEXT
      END
    FROM "Conversation_Analyses"
    WHERE user_id = target_user_id
      AND date >= CURRENT_DATE - (days_back || ' days')::INTERVAL;

    -- Decision Process analysis
    RETURN QUERY
    SELECT
      'Methodology Execution'::TEXT,
      'Decision Process'::TEXT,
      (SUM(CASE WHEN decision_makers_identified THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) * 100,
      COUNT(*)::INTEGER,
      SUM(CASE WHEN decision_makers_identified THEN 1 ELSE 0 END)::INTEGER,
      CASE
        WHEN (SUM(CASE WHEN decision_makers_identified THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) < 0.5 THEN 'high'::TEXT
        WHEN (SUM(CASE WHEN decision_makers_identified THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) < 0.7 THEN 'medium'::TEXT
        ELSE 'low'::TEXT
      END,
      CASE
        WHEN (SUM(CASE WHEN decision_makers_identified THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) < 0.5
        THEN 'You''re spending time with people who seem interested, but can''t actually say yes. We''re getting ghosted because someone we never met killed the deal. When your contact says "I need to run this by my boss," what do you say next? How do we get in that room?'::TEXT
        WHEN (SUM(CASE WHEN decision_makers_identified THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)) < 0.7
        THEN 'Sometimes you''re mapping out the decision-makers, other times you''re taking your contact''s word for it. What clues tell you when your champion actually has authority vs. when they''re just a researcher gathering options for someone else?'::TEXT
        ELSE 'You''re consistently getting to the real decision-makers early - not wasting time with people who ''like it but need to check with leadership.'' This is protecting your pipeline quality.'::TEXT
      END
    FROM "Conversation_Analyses"
    WHERE user_id = target_user_id
      AND date >= CURRENT_DATE - (days_back || ' days')::INTERVAL;

    -- Talk Ratio analysis
    RETURN QUERY
    SELECT
      'Conversation Quality'::TEXT,
      'Talk Ratio'::TEXT,
      AVG(talk_percentage),
      COUNT(*)::INTEGER,
      SUM(CASE WHEN talk_percentage <= 35 THEN 1 ELSE 0 END)::INTEGER, -- Target range
      CASE
        WHEN AVG(talk_percentage) > 50 THEN 'high'::TEXT
        WHEN AVG(talk_percentage) > 35 THEN 'medium'::TEXT
        ELSE 'low'::TEXT
      END,
      CASE
        WHEN AVG(talk_percentage) > 50
        THEN 'You''re doing ' || ROUND(AVG(talk_percentage))::TEXT || '% of the talking - that''s a presentation, not a conversation. Prospects are being polite, but we''re not learning anything about them. Next call: Count to 5 after asking a question. No filling the silence. See what happens.'::TEXT
        WHEN AVG(talk_percentage) > 35
        THEN 'Talk ratio is ' || ROUND(AVG(talk_percentage))::TEXT || '% (target: 30%). You''re close, but still talking more than ideal. What would it feel like to let them talk 70% of the time? What are you afraid you''ll miss if you say less?'::TEXT
        ELSE 'Your talk ratio (' || ROUND(AVG(talk_percentage))::TEXT || '%) shows you''re actually listening - prospects are doing most of the talking, which means they''re telling you exactly how to sell to them. Keep this up.'::TEXT
      END
    FROM "Conversation_Analyses"
    WHERE user_id = target_user_id
      AND date >= CURRENT_DATE - (days_back || ' days')::INTERVAL
    HAVING COUNT(*) > 0;

  ELSE
    -- For non-Sandler methodologies, return generic insights
    RETURN QUERY
    SELECT
      'General Performance'::TEXT,
      'Overall Quality Score'::TEXT,
      AVG(overall_sandler_score) * 10,
      COUNT(*)::INTEGER,
      SUM(CASE WHEN overall_sandler_score >= 7 THEN 1 ELSE 0 END)::INTEGER,
      CASE
        WHEN AVG(overall_sandler_score) < 6 THEN 'high'::TEXT
        WHEN AVG(overall_sandler_score) < 7.5 THEN 'medium'::TEXT
        ELSE 'low'::TEXT
      END,
      'Methodology-specific insights require Sandler methodology selection.'::TEXT
    FROM "Conversation_Analyses"
    WHERE user_id = target_user_id
      AND date >= CURRENT_DATE - (days_back || ' days')::INTERVAL
    HAVING COUNT(*) > 0;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: get_team_benchmarks
-- Returns team-wide averages for comparison
-- ============================================
CREATE OR REPLACE FUNCTION get_team_benchmarks(
  admin_email TEXT,
  days_back INTEGER DEFAULT 30
)
RETURNS TABLE (
  avg_dials NUMERIC,
  avg_conversations NUMERIC,
  avg_meetings NUMERIC,
  avg_dial_conv_rate NUMERIC,
  avg_conv_meeting_rate NUMERIC,
  avg_revenue NUMERIC,
  avg_sandler_score NUMERIC,
  avg_upfront_contract_rate NUMERIC,
  avg_pain_funnel_rate NUMERIC,
  avg_budget_rate NUMERIC,
  avg_talk_percentage NUMERIC
)
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify caller is admin
  IF admin_email NOT IN ('admin@aiadvantagesolutions.com', 'admin@aiadvantagesolutions.ca', 'john@aiadvantagesolutions.com') THEN
    RAISE EXCEPTION 'Unauthorized: Not an admin user';
  END IF;

  -- Calculate team-wide averages
  RETURN QUERY
  WITH team_activity AS (
    SELECT
      user_id,
      SUM(dials)::NUMERIC / COUNT(DISTINCT date) as avg_daily_dials,
      SUM(conversations)::NUMERIC / COUNT(DISTINCT date) as avg_daily_conversations,
      SUM(discovery_meetings)::NUMERIC / COUNT(DISTINCT date) as avg_daily_meetings,
      CASE
        WHEN SUM(dials) > 0
        THEN (SUM(conversations)::NUMERIC / SUM(dials)) * 100
        ELSE 0
      END as dial_conv_rate,
      CASE
        WHEN SUM(conversations) > 0
        THEN (SUM(discovery_meetings)::NUMERIC / SUM(conversations)) * 100
        ELSE 0
      END as conv_meeting_rate
    FROM "Daily_Tracker"
    WHERE date >= CURRENT_DATE - (days_back || ' days')::INTERVAL
    GROUP BY user_id
  ),
  team_revenue AS (
    SELECT
      user_id,
      AVG(amount_cad) as avg_sale
    FROM "Sales"
    WHERE date >= CURRENT_DATE - (days_back || ' days')::INTERVAL
    GROUP BY user_id
  ),
  team_quality AS (
    SELECT
      user_id,
      AVG(overall_sandler_score) as avg_score,
      AVG(CASE WHEN upfront_contract_set THEN 100 ELSE 0 END) as upfront_rate,
      AVG(CASE WHEN pain_identified THEN 100 ELSE 0 END) as pain_rate,
      AVG(CASE WHEN budget_discussed THEN 100 ELSE 0 END) as budget_rate,
      AVG(talk_percentage) as talk_pct
    FROM "Conversation_Analyses"
    WHERE date >= CURRENT_DATE - (days_back || ' days')::INTERVAL
    GROUP BY user_id
  )
  SELECT
    AVG(ta.avg_daily_dials),
    AVG(ta.avg_daily_conversations),
    AVG(ta.avg_daily_meetings),
    AVG(ta.dial_conv_rate),
    AVG(ta.conv_meeting_rate),
    AVG(tr.avg_sale),
    AVG(tq.avg_score),
    AVG(tq.upfront_rate),
    AVG(tq.pain_rate),
    AVG(tq.budget_rate),
    AVG(tq.talk_pct)
  FROM team_activity ta
  LEFT JOIN team_revenue tr ON ta.user_id = tr.user_id
  LEFT JOIN team_quality tq ON ta.user_id = tq.user_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Manager Team Coaching Dashboard - Functions Created!';
    RAISE NOTICE '';
    RAISE NOTICE 'SECURITY DEFINER functions created:';
    RAISE NOTICE '  - get_team_overview(admin_email, days_back)';
    RAISE NOTICE '    Returns all users with metrics and top weakness/strength';
    RAISE NOTICE '';
    RAISE NOTICE '  - get_user_categorical_insights(admin_email, user_id, days_back)';
    RAISE NOTICE '    Deep analysis of Sandler methodology execution';
    RAISE NOTICE '';
    RAISE NOTICE '  - get_team_benchmarks(admin_email, days_back)';
    RAISE NOTICE '    Team-wide averages for comparison';
    RAISE NOTICE '';
    RAISE NOTICE '🔒 Security: Only admins can call these functions';
    RAISE NOTICE '⏭️  NEXT STEP: Create admin-team.html to build the UI';
    RAISE NOTICE '';
END $$;
