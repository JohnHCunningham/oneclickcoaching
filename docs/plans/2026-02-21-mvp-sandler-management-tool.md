# One Click Coaching v2 — Sandler Management Tool MVP

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Strip the existing app down to a focused Sandler sales management tool that a consultant can demo this week. Clean, intuitive, radial KPI dashboard, deep AI coaching brain, daily automation.

**Architecture:** Next.js 14 App Router + Supabase (Postgres + Edge Functions + pg_cron). Single codebase. White-label per account. OpenAI GPT-4 for Sandler analysis, text-embedding-3-small for RAG.

**Tech Stack:** React/TypeScript, Tailwind CSS, shadcn/ui, Lucide React, Chart.js (radial), Supabase, OpenAI, Resend (email)

**Design Tokens:** Deep navy (#0C1030), Teal (#10C3B0), Aqua (#3DE0D2), Pink/Red (#E64563), Gold (#F4B03A). Fonts: Plus Jakarta Sans (headings), DM Sans (body).

---

## URL Structure

```
oneclickcoaching.com                    → Landing page (public marketing site)
oneclickcoaching.com/blog               → Blog (public, Sandler thought leadership)
oneclickcoaching.com/blog/[slug]        → Individual blog post
oneclickcoaching.com/login              → Sign in (existing users)
oneclickcoaching.com/signup             → Create new account (consultant or sales leader)
oneclickcoaching.com/forgot-password    → Password reset
oneclickcoaching.com/accept-invite      → Rep accepts team invitation

--- After login (protected) ---

oneclickcoaching.com/dashboard          → Main KPI dashboard (radial circles, at-a-glance)
oneclickcoaching.com/team               → Team roster, invite reps
oneclickcoaching.com/team/[memberId]    → Individual rep deep-dive
oneclickcoaching.com/calls              → Call history with Sandler scores
oneclickcoaching.com/calls/[callId]     → Single call analysis + coaching
oneclickcoaching.com/coaching           → Coaching inbox (review, approve, send)
oneclickcoaching.com/planning           → Benchmarks & quota setting
oneclickcoaching.com/celebrations       → Team wins & badges
oneclickcoaching.com/integrations       → HubSpot, Fathom, Aircall setup
oneclickcoaching.com/settings           → Account settings, white-label config
```

**Current deployment:** Vercel (daily-tracker-xi.vercel.app) → needs custom domain `oneclickcoaching.com` pointed to Vercel.

**Blog management:** Markdown files in `landing-page/app/blog/posts/`. To add a post, create a new `.md` file with frontmatter (title, date, excerpt, author) and it auto-appears at `/blog/[slug]`.

---

## Phase 0: Trim & Clean (Foundation)

### Task 0.1: Delete Legacy Files

**Files:**
- Delete: `legacy/` (entire directory — 18 HTML files)
- Delete: `fireflies-sync-edge-function.js` (root, unused)
- Delete: `supabase/functions/transcribe-audio/` (stub)
- Delete: `supabase/functions/analyze-conversation/` (stub)
- Delete: `supabase/functions/generate-scripts/` (stub)

**Step 1:** Remove files
```bash
rm -rf legacy/
rm fireflies-sync-edge-function.js
rm -rf supabase/functions/transcribe-audio/
rm -rf supabase/functions/analyze-conversation/
rm -rf supabase/functions/generate-scripts/
```

**Step 2:** Verify no imports reference deleted functions
```bash
grep -r "transcribe-audio\|analyze-conversation\|generate-scripts" landing-page/
```

**Step 3:** Commit
```bash
git add -A && git commit -m "chore: remove legacy files and stub edge functions"
```

---

### Task 0.2: Trim Landing Page Marketing Bloat

**Keep:** Landing page (`page.tsx`), blog routes, login/signup/auth routes
**Remove from landing page components:** Chatbot, Chatbase, AnnouncementBanner
**Simplify:** Reduce marketing sections to: Hero, Problem/Solution, Features (brief), Pricing, CTA, Footer

**Files:**
- Modify: `landing-page/components/` — remove Chatbot.tsx, Chatbase.tsx, AnnouncementBanner.tsx
- Modify: `landing-page/app/page.tsx` — streamline to essential sections
- Keep: `landing-page/app/blog/` — blog stays (Sandler thought leadership)
- Keep: `landing-page/app/(auth)/` — all auth routes stay
- Evaluate: `/about`, `/sandler`, `/privacy`, `/terms`, `/security` — keep privacy/terms (legal requirement), cut or simplify the rest

**Step 1:** Remove unused components and update imports
**Step 2:** Verify landing page renders cleanly
**Step 3:** Commit
```bash
git commit -m "chore: trim landing page to essential marketing sections"
```

---

### Task 0.3: Clean Up Unused Dependencies

**Files:**
- Modify: `landing-page/package.json`

**Step 1:** Remove `framer-motion` if no remaining usage after trim
**Step 2:** Audit and remove any other unused deps
```bash
cd landing-page && npx depcheck
```
**Step 3:** `npm install` to clean lockfile
**Step 4:** Commit

---

## Phase 1: White-Label Foundation

### Task 1.1: Add White-Label Fields to Accounts Table

**Files:**
- Create: `supabase/migrations/056_white_label_accounts.sql`

**Step 1:** Write migration
```sql
ALTER TABLE "Accounts"
  ADD COLUMN IF NOT EXISTS logo_url TEXT,
  ADD COLUMN IF NOT EXISTS primary_color TEXT DEFAULT '#0C1030',
  ADD COLUMN IF NOT EXISTS accent_color TEXT DEFAULT '#10C3B0',
  ADD COLUMN IF NOT EXISTS company_name TEXT,
  ADD COLUMN IF NOT EXISTS email_from_name TEXT;
```

**Step 2:** Apply migration
```bash
supabase db push
```

**Step 3:** Commit

---

### Task 1.2: Create Brand Provider Component

**Files:**
- Create: `landing-page/app/(app)/components/BrandProvider.tsx`
- Modify: `landing-page/app/(app)/layout.tsx` — wrap with BrandProvider

**Step 1:** Build a React context that reads account branding from Supabase and injects CSS custom properties (`--brand-primary`, `--brand-accent`) on the root element.

**Step 2:** Update Tailwind config to reference CSS variables for brand colors.

**Step 3:** Verify dashboard renders with default colors.

**Step 4:** Commit

---

## Phase 2: Radial KPI Dashboard (The Visual Centerpiece)

### Task 2.1: Build ScoreRadial Component

**Files:**
- Modify: `landing-page/app/(app)/components/ScoreRadial.tsx` (exists, enhance it)

**Step 1:** Build a reusable radial/donut chart component using Chart.js (already installed).
- Props: `score` (0-100), `label`, `size`, `colorThresholds` (red < 40, yellow < 70, green >= 70)
- Animated fill on mount
- Center text showing score number
- Clean, minimal design per brand tokens

**Step 2:** Verify renders with test data.

**Step 3:** Commit

---

### Task 2.2: Rebuild Dashboard Page — Leader View

**Files:**
- Modify: `landing-page/app/(app)/dashboard/page.tsx`

**Step 1:** Design the leader dashboard layout:
```
┌─────────────────────────────────────────────────┐
│  Good morning, [Name]          [On-Demand Sync]  │
├────────┬────────┬────────┬────────┬─────────────┤
│ Team   │ Calls  │ Quota  │ Disc.  │ Approaches  │
│ Score  │ This   │ Attain │ Calls  │ This Week   │
│ (rad)  │ Week   │ (rad)  │ (rad)  │ (rad)       │
├────────┴────────┴────────┴────────┴─────────────┤
│  TEAM MEMBERS                                    │
│  ┌──────┬──────┬──────┬──────┬───────┐          │
│  │ Rep  │Score │Calls │Trend │Action │          │
│  │ Name │(rad) │ #    │ ↑↓   │ View  │          │
│  └──────┴──────┴──────┴──────┴───────┘          │
├─────────────────────────────────────────────────┤
│  RECENT COACHING        │  NEEDS ATTENTION       │
│  - Sent to Rep A (Tues) │  - Rep C: Pain Funnel  │
│  - Sent to Rep B (Mon)  │  - Rep D: Budget step  │
└─────────────────────────┴───────────────────────┘
```

**Step 2:** Wire to Supabase queries — pull team members, their latest scores, call counts, coaching status.

**Step 3:** Verify with existing data or seed data.

**Step 4:** Commit

---

### Task 2.3: Build Rep Dashboard View

**Files:**
- Modify: `landing-page/app/(app)/dashboard/page.tsx` (role-conditional rendering)

**Step 1:** Rep sees their own radials:
```
┌─────────────────────────────────────────────────┐
│  Your Performance This Week                      │
├────────┬────────┬────────┬────────┬─────────────┤
│ Sandler│ Calls  │ Disc.  │ Quota  │ Approaches  │
│ Score  │Analyzed│ Calls  │ Attain │ Made        │
│ (rad)  │ (rad)  │ (rad)  │ (rad)  │ (rad)       │
├────────┴────────┴────────┴────────┴─────────────┤
│  SANDLER BREAKDOWN (8 Components)                │
│  ┌────────────┬───────┬──────────────────┐      │
│  │ Component  │ Score │ Trend (last 4wk) │      │
│  │ Bonding    │  8/10 │ ████████░░       │      │
│  │ Upfront    │  5/10 │ █████░░░░░       │      │
│  │ Pain Funnel│  3/10 │ ███░░░░░░░  ⚠️   │      │
│  └────────────┴───────┴──────────────────┘      │
├─────────────────────────────────────────────────┤
│  LATEST COACHING                                 │
│  "Focus on deeper Pain Funnel questions..."      │
│  [Reply to Coach]                                │
└─────────────────────────────────────────────────┘
```

**Step 2:** Wire to Supabase — user's own scores, coaching messages, benchmarks.

**Step 3:** Commit

---

## Phase 3: Planning & Benchmarks

### Task 3.1: Create Planning Page & Schema

**Files:**
- Create: `supabase/migrations/057_planning_benchmarks.sql`
- Create: `landing-page/app/(app)/planning/page.tsx`

**Step 1:** Migration for benchmarks table:
```sql
CREATE TABLE IF NOT EXISTS "Benchmarks" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID REFERENCES "Accounts"(id),
  user_id UUID REFERENCES auth.users(id),  -- NULL = team-wide
  period TEXT NOT NULL DEFAULT 'weekly',     -- weekly, monthly
  approaches_target INT,
  discovery_calls_target INT,
  conversions_target INT,                    -- quota
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

**Step 2:** Build planning page — leader sets targets per rep or team-wide. Display as radial circles showing target vs. actual.

**Step 3:** Commit

---

## Phase 4: Deep Sandler Brain (AI Upgrade)

### Task 4.1: Upgrade analyze-call to GPT-4

**Files:**
- Modify: `supabase/functions/analyze-call/index.ts`
- Modify: `supabase/functions/analyze-call/sandler-methodology.ts`

**Step 1:** Replace keyword-based scoring with GPT-4 structured analysis.

System prompt instructs GPT-4 to:
- Score each of 8 Sandler components (1-10) with specific evidence from transcript
- Identify what was done well (with quotes)
- Identify what was missing (specific steps skipped)
- Identify what was weak (attempted but poorly executed)
- Generate 3-5 specific, actionable coaching suggestions
- Provide exact script examples for improvement areas

**Step 2:** Return structured JSON:
```json
{
  "scores": {
    "bonding_rapport": { "score": 7, "evidence": "...", "status": "strong" },
    "upfront_contract": { "score": 4, "evidence": "...", "status": "weak" },
    ...
  },
  "done_well": ["..."],
  "missing": ["..."],
  "weak": ["..."],
  "suggestions": ["..."],
  "scripts": ["..."]
}
```

**Step 3:** Test with a real transcript.

**Step 4:** Commit

---

### Task 4.2: Non-Repetition Engine

**Files:**
- Create: `supabase/migrations/058_coaching_history.sql`
- Modify: `supabase/functions/analyze-call/index.ts`

**Step 1:** Migration:
```sql
CREATE TABLE IF NOT EXISTS "Coaching_Suggestions_Log" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  call_id UUID,
  suggestion_text TEXT,
  component TEXT,        -- which Sandler component
  weakness_pattern TEXT, -- categorized weakness
  times_flagged INT DEFAULT 1,
  first_flagged_at TIMESTAMPTZ DEFAULT now(),
  last_flagged_at TIMESTAMPTZ DEFAULT now()
);
```

**Step 2:** Before generating new coaching, query this table for the rep's history. Pass prior suggestions into the GPT-4 prompt with instruction: "Do NOT repeat these suggestions. Escalate if the same weakness appears 3+ times."

**Step 3:** After generating coaching, log new suggestions to the table.

**Step 4:** Commit

---

## Phase 5: RAG System Population

### Task 5.1: Seed Sandler Knowledge Base

**Files:**
- Create: `scripts/seed-sandler-knowledge.ts`
- Modify: Supabase `Knowledge_Base_Chunks` table

**Step 1:** Create structured Sandler content for all 8 components:
- What good execution looks like (with example dialogue)
- Common mistakes and how to fix them
- Objection handling scripts per component
- Escalation patterns (when the same issue keeps recurring)

**Step 2:** Generate embeddings and insert into Knowledge_Base_Chunks.

**Step 3:** Verify RAG search returns relevant results for each component.

**Step 4:** Commit

---

### Task 5.2: Wire RAG into Analysis Pipeline

**Files:**
- Modify: `supabase/functions/analyze-call/index.ts`
- Modify: `supabase/functions/_shared/rag-utils.ts`

**Step 1:** After GPT-4 identifies weak areas, query RAG for relevant scripts and coaching content specific to those weaknesses.

**Step 2:** Include RAG results in coaching output so suggestions are backed by proven methodology content.

**Step 3:** Commit

---

## Phase 6: Bi-Directional Email System

### Task 6.1: Configure Resend & Email Templates

**Files:**
- Modify: `supabase/functions/send-coaching-email/index.ts`

**Step 1:** Configure Resend API with production key. Design clean HTML email template:
- From: configurable per account (white-label `email_from_name`)
- Subject: "Coaching Feedback: [Call with Company X]"
- Body: Sandler scores summary, top 3 coaching points, suggested scripts
- CTA: "Reply with your thoughts" button → coaching-reply endpoint

**Step 2:** Test email delivery end to end.

**Step 3:** Commit

---

### Task 6.2: Leader Approval Queue

**Files:**
- Modify: `landing-page/app/(app)/coaching/page.tsx`

**Step 1:** Coaching inbox shows:
- **Pending approval** — AI-generated coaching awaiting leader review
- **Sent** — approved and delivered
- **Replies** — rep responses

Leader can: review AI coaching, edit text, approve & send, or reject.

**Step 2:** Wire approve action to trigger send-coaching-email function.

**Step 3:** Commit

---

## Phase 7: Daily Cron Pipeline

### Task 7.1: Set Up pg_cron for 8am Mon-Fri

**Files:**
- Create: `supabase/migrations/059_daily_cron.sql`

**Step 1:** Create a Supabase pg_cron job that at 8:00 AM EST, Mon-Fri:
1. Triggers hubspot-sync edge function (pull new activities)
2. Triggers fathom-sync edge function (pull new transcripts)
3. Triggers aircall-sync edge function (pull new calls)
4. For each new call with transcript → triggers analyze-call
5. Generated coaching queued for leader approval
6. Leader receives notification email: "You have X new coaching sessions to review"

**Step 2:** Add "Sync Now" button on dashboard for on-demand trigger.

**Step 3:** Commit

---

## Phase 8: Gamification & Celebrations

### Task 8.1: Rebuild Celebrations Page

**Files:**
- Modify: `landing-page/app/(app)/celebrations/page.tsx`

**Step 1:** Focus on Sandler-relevant wins:
- Score improvement badges (rep improved a component by 2+ points)
- Consistency streak (5 consecutive calls with score > 7)
- Quota hit celebrations
- Team milestones (team average above threshold)
- Weekly top performer

**Step 2:** Display as a feed visible to whole team. Leader can highlight/pin wins.

**Step 3:** Commit

---

## Phase 9: Integrations Polish

### Task 9.1: Verify Aircall Integration Parity

**Files:**
- Review: `supabase/functions/aircall-sync/index.ts`

**Step 1:** Ensure Aircall calls flow through same pipeline as HubSpot/Fathom:
- Sync → store in Synced_Conversations → trigger analysis → generate coaching

**Step 2:** Test with Aircall API sandbox if available.

**Step 3:** Commit

---

## Phase 10: Settings & Account Management

### Task 10.1: Build Settings Page

**Files:**
- Modify: `landing-page/app/(app)/settings/page.tsx`

**Step 1:** Settings page with tabs:
- **Account** — company name, logo upload, brand colors
- **Team** — manage roles, who is admin
- **Integrations** — quick links to HubSpot/Fathom/Aircall setup
- **Notifications** — email preferences, cron schedule override
- **Billing** — placeholder for Stripe (future)

**Step 2:** Commit

---

## MVP Demo Scope (This Week)

For the demo, prioritize showing a working loop:

1. **Landing page** (trimmed, clean) → `/`
2. **Login** → `/login`
3. **Leader dashboard** with radial KPIs → `/dashboard`
4. **Call detail** with Sandler AI analysis → `/calls/[callId]`
5. **Coaching approval** → leader reviews and sends → `/coaching`
6. **Rep dashboard** with their own radials → `/dashboard` (as rep)
7. **Planning benchmarks** → `/planning`
8. **Celebrations** → `/celebrations`

Seed with realistic demo data if live integrations aren't connected yet.

---

## Execution Approach

**Option 1: Subagent-Driven (this session)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**Option 2: Parallel Session (separate)** — Open new session with executing-plans, batch execution with checkpoints.

**Which approach?**
