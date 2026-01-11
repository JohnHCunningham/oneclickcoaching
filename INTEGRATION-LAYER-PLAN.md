# Coaching Intelligence Layer - Integration Plan
## Fathom + HubSpot API Integration Strategy

**Date:** January 11, 2026
**Purpose:** Strategic plan for pivoting to integration-based coaching loop
**Target Market:** Sales teams already using Fathom + HubSpot

---

## 1. PRODUCT VISION

### What We Build:
**AI-Powered Coaching Intelligence Layer** that sits on top of Fathom (conversations) + HubSpot (activity) to close the coaching accountability loop.

### Core Value Proposition:
*"We turn your conversation data into actionable coaching that gets read, acknowledged, and implemented."*

### What Makes This Different:
- **Fathom/Gong/Chorus** = Conversation intelligence (no coaching loop)
- **HubSpot** = CRM + activity tracking (no AI coaching)
- **Your Product** = AI coaching → Manager approval → Rep accountability → Behavior change

---

## 2. TECHNICAL ARCHITECTURE

### 2.1 Data Sources (APIs)

#### **Fathom API Integration**
**What We Pull:**
- Call transcripts (full text)
- Call metadata (date, duration, participants, recording URL)
- Fathom's AI summary
- Fathom's Sandler/MEDDIC scores (if available)
- Speaker talk time percentages
- Question count

**API Endpoints:**
```
GET /calls - List all calls for team
GET /calls/{id} - Get specific call details
GET /calls/{id}/transcript - Get full transcript
GET /calls/{id}/summary - Get AI summary
```

**Authentication:** OAuth 2.0
**Rate Limits:** ~100 requests/minute (typical)
**Webhook Support:** Yes (real-time call completion notifications)

**Estimated Integration Time:** 2-3 weeks

---

#### **HubSpot API Integration**
**What We Pull:**
- Call activity logs (outbound/inbound call count)
- Email activity (sent, opened, replied)
- Meeting activity (booked, held)
- Deal/Opportunity data (pipeline, closed-won revenue)
- Contact engagement history
- User/Rep roster

**API Endpoints:**
```
GET /crm/v3/objects/calls - Get call activity
GET /crm/v3/objects/emails - Get email activity
GET /crm/v3/objects/meetings - Get meeting activity
GET /crm/v3/objects/deals - Get sales/revenue data
GET /settings/users/v3/users - Get team roster
```

**Authentication:** OAuth 2.0 or Private App Token
**Rate Limits:** 100 requests/10 seconds (standard tier)
**Webhook Support:** Yes (activity updates, deal stage changes)

**Estimated Integration Time:** 3-4 weeks

---

### 2.2 System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    USER INTERFACE                        │
│  Manager Dashboard (your existing radial ring system)   │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│               COACHING INTELLIGENCE ENGINE               │
│  • Methodology-aware AI (Sandler/MEDDIC/Challenger)    │
│  • Longitudinal analysis (trends over time)             │
│  • Coaching message generation                          │
│  • Manager approval workflow                            │
│  • Rep notification + acknowledgment tracking           │
└─────────────────────────────────────────────────────────┘
                           ↓
        ┌──────────────────┴──────────────────┐
        ↓                                      ↓
┌──────────────────┐                  ┌──────────────────┐
│   FATHOM API     │                  │  HUBSPOT API     │
│  • Transcripts   │                  │  • Calls         │
│  • AI Summaries  │                  │  • Emails        │
│  • Sandler Score │                  │  • Meetings      │
│  • Talk Time     │                  │  • Deals/Revenue │
└──────────────────┘                  └──────────────────┘
```

---

### 2.3 Data Flow

**Daily Sync Workflow:**

1. **Morning Sync (8 AM):**
   - Pull yesterday's HubSpot activity (calls, emails, meetings, deals)
   - Pull yesterday's Fathom call recordings + transcripts
   - Match Fathom calls to HubSpot activity records
   - Store in local database (Supabase)

2. **AI Analysis (9 AM):**
   - Run coaching intelligence engine on each rep
   - Analyze transcripts for methodology execution
   - Compare to historical performance (longitudinal trends)
   - Generate coaching recommendations
   - Flag critical performance issues

3. **Manager Notification (9:30 AM):**
   - Manager logs in, sees coaching drafts ready for review
   - Can edit/approve/reject each coaching message
   - One-click send to rep

4. **Rep Delivery (Throughout Day):**
   - Rep receives notification (email + in-app)
   - Opens coaching message
   - System tracks read status
   - Rep can respond/acknowledge
   - Manager sees acknowledgment status

5. **Celebration Detection (Real-time):**
   - Achievement unlocked? (streak, personal best, first sale)
   - Trigger confetti + celebration modal
   - Post to team feed
   - Notify manager

---

## 3. FEATURE SCOPE

### 3.1 What We KEEP from Current System

✅ **Manager Performance Dashboard**
- Radial ring visualization (dials, conversations, meetings, sales)
- Rep status indicators (healthy, watch, critical)
- Card view + Table view
- Team celebration feed

✅ **AI Coaching Engine**
- Methodology-specific coaching (Sandler, MEDDIC, Challenger, SPIN, Gap Selling)
- Longitudinal trend analysis
- Specific, actionable recommendations
- Manager approval workflow
- Rep notification + read tracking

✅ **Celebration System**
- Achievement badges (streaks, personal bests, mastery, first wins)
- Confetti animations
- Public celebration feed
- Gamification (but NOT toxic competition)

✅ **Rep Dashboard**
- Performance scoreboard
- Coaching inbox
- Trend charts
- Achievement history

---

### 3.2 What We DROP

❌ **Manual Activity Tracking**
- No more "log your dials" input
- No daily action recording
- HubSpot becomes single source of truth

❌ **Call Transcript Upload**
- Fathom auto-captures this
- No manual upload needed

❌ **Script Generator**
- Out of scope for coaching layer
- Can add back later if needed

❌ **Email Generator**
- Out of scope (Carlos was right - feels tacked on)

❌ **Setup Wizards**
- Methodology selection stays (to configure coaching brain)
- ICP/scripts/templates removed

---

### 3.3 What We ADD

✨ **API Sync Management**
- OAuth connection flow for Fathom + HubSpot
- Sync status dashboard (last sync time, errors)
- Manual re-sync button
- Disconnect/reconnect flows

✨ **Call Matching Intelligence**
- Match Fathom transcript to HubSpot call activity
- Handle edge cases (calls without transcripts, transcripts without HubSpot records)

✨ **Longitudinal Analytics**
- Rep performance trends over 30/60/90 days
- Methodology execution scores trending up/down
- Conversion funnel changes over time
- Manager sees: "Sarah's pain funnel score improved from 6.5 to 8.0 this month"

✨ **Multi-Call Coaching**
- Don't just analyze one call - analyze patterns across all calls this week
- "You asked great questions on 3/5 calls, but rushed on the other 2"

✨ **Rep Response Tracking**
- Rep can reply to coaching message
- Manager sees: "Read ✓" vs "Acknowledged ✓" vs "Implemented ✓"
- Close the accountability loop

---

## 4. DEVELOPMENT TIMELINE

### Phase 1: Foundation (4-5 weeks)
**Week 1-2: Fathom Integration**
- OAuth authentication flow
- Pull call transcripts
- Pull AI summaries + metadata
- Store in Supabase
- Display in manager dashboard (basic view)

**Week 3-4: HubSpot Integration**
- OAuth authentication flow
- Pull activity data (calls, emails, meetings)
- Pull deal/revenue data
- Pull user roster
- Match HubSpot users to your system

**Week 5: Data Sync Engine**
- Scheduled daily sync (cron job)
- Webhook listeners (real-time updates)
- Error handling + retry logic
- Sync status dashboard

**Deliverable:** Manager can see Fathom transcripts + HubSpot activity in your dashboard

---

### Phase 2: Coaching Intelligence (3-4 weeks)
**Week 6-7: AI Coaching Engine v2**
- Analyze Fathom transcripts with Claude/GPT-4
- Methodology-specific prompts (Sandler, MEDDIC, etc.)
- Extract: upfront contract quality, pain questions, talk ratio, etc.
- Generate coaching recommendations
- Store coaching drafts in database

**Week 8: Longitudinal Analysis**
- Pull historical data (last 30/60/90 days)
- Trend calculations (improving vs declining)
- Comparative coaching ("you're doing better on X but need work on Y")

**Week 9: Manager Approval Workflow**
- Manager inbox of coaching drafts
- Edit coaching message
- Approve/reject/schedule send
- Bulk actions (approve all)

**Deliverable:** AI-generated coaching messages ready for manager review

---

### Phase 3: Rep Notification + Accountability (2-3 weeks)
**Week 10: Notification System**
- Email notifications (coaching sent, achievement unlocked)
- In-app notification center
- Push notifications (optional - mobile)

**Week 11: Read Tracking + Acknowledgment**
- Track when rep opens coaching message
- Rep can acknowledge ("Got it - will implement")
- Rep can reply with questions
- Manager sees status dashboard

**Week 12: Celebration Triggers**
- Achievement detection from HubSpot data
- Streak calculation (5/10/30 day streaks)
- Personal best detection
- Auto-celebration posting to team feed

**Deliverable:** Full coaching loop closed (send → read → acknowledge → implement)

---

### Phase 4: Polish + Testing (2 weeks)
**Week 13: Error Handling + Edge Cases**
- What if Fathom call has no HubSpot match?
- What if rep makes calls outside HubSpot?
- Fallback flows
- Manual override options

**Week 14: Beta Testing**
- Test with 2-3 pilot customers
- Fix bugs
- Refine coaching prompts
- UX improvements

**Deliverable:** Production-ready beta

---

### **TOTAL DEVELOPMENT TIME: 11-14 weeks (3-3.5 months)**

**Breakdown:**
- API Integrations: 5 weeks
- Coaching Intelligence: 4 weeks
- Notification/Accountability: 3 weeks
- Testing/Polish: 2 weeks

**Developer Resources:**
- 1 full-time developer = 14 weeks
- 2 developers (frontend + backend) = 7-8 weeks
- You + Claude Code = 12-14 weeks (nights/weekends)

---

## 5. TECHNICAL REQUIREMENTS

### 5.1 Stack (Existing)
- **Frontend:** HTML/CSS/JavaScript (your current dashboard)
- **Backend:** Supabase (PostgreSQL + Edge Functions)
- **AI:** Claude 3.5 Sonnet API (for coaching generation)
- **Hosting:** Vercel or similar (static site + API routes)

### 5.2 New Components Needed

**API Integration Layer:**
- OAuth 2.0 authentication flows (Fathom + HubSpot)
- Token storage + refresh logic
- API request queue with rate limiting
- Webhook receivers

**Database Schema Changes:**
```sql
-- New tables needed

CREATE TABLE api_connections (
    id UUID PRIMARY KEY,
    account_id UUID REFERENCES accounts(id),
    provider TEXT, -- 'fathom' or 'hubspot'
    access_token TEXT,
    refresh_token TEXT,
    expires_at TIMESTAMP,
    connected_at TIMESTAMP,
    last_sync_at TIMESTAMP
);

CREATE TABLE fathom_calls (
    id UUID PRIMARY KEY,
    account_id UUID,
    fathom_call_id TEXT UNIQUE,
    call_date TIMESTAMP,
    duration_minutes INTEGER,
    participants JSONB,
    transcript TEXT,
    ai_summary TEXT,
    talk_time_data JSONB,
    recording_url TEXT,
    synced_at TIMESTAMP
);

CREATE TABLE hubspot_activities (
    id UUID PRIMARY KEY,
    account_id UUID,
    user_email TEXT,
    activity_type TEXT, -- 'call', 'email', 'meeting'
    activity_date TIMESTAMP,
    hubspot_activity_id TEXT UNIQUE,
    metadata JSONB,
    synced_at TIMESTAMP
);

CREATE TABLE coaching_messages (
    id UUID PRIMARY KEY,
    account_id UUID,
    rep_email TEXT,
    generated_at TIMESTAMP,
    approved_at TIMESTAMP,
    sent_at TIMESTAMP,
    read_at TIMESTAMP,
    acknowledged_at TIMESTAMP,
    coaching_content TEXT,
    methodology TEXT,
    status TEXT -- 'draft', 'approved', 'sent', 'read', 'acknowledged'
);

CREATE TABLE rep_responses (
    id UUID PRIMARY KEY,
    coaching_message_id UUID REFERENCES coaching_messages(id),
    responded_at TIMESTAMP,
    response_text TEXT
);
```

**Edge Functions (Supabase):**
- `sync-fathom-calls` (scheduled daily)
- `sync-hubspot-activity` (scheduled daily)
- `generate-coaching` (scheduled or on-demand)
- `send-coaching-notification` (triggered)
- `detect-achievements` (scheduled)

**Third-Party Services:**
- Email delivery (Resend or SendGrid) - $10-50/month
- OAuth management (Supabase Auth handles this)
- Cron scheduler (Supabase has built-in cron)

---

## 6. PRICING STRATEGY

### 6.1 Pricing Models to Consider

#### **Option A: Per-User Pricing (SaaS Standard)**
- $49/user/month (billed monthly)
- $39/user/month (billed annually)

**For 10-rep team:**
- Monthly: $490/month = $5,880/year
- Annual: $390/month = $4,680/year

**Margins:**
- Fathom cost: $19/user = $190/month (you don't pay this - customer already has it)
- HubSpot cost: $0 (customer already has it)
- Your costs: ~$50/month (API calls, hosting, email) + Claude API ~$100/month
- **Gross margin: ~70-75%**

**Market Position:**
- Positioned as "coaching layer" add-on
- Customers already spending $500-1000/month on Fathom + HubSpot
- Your $490/month is ~30-50% add-on cost for coaching intelligence

---

#### **Option B: Flat Team Pricing (Simplified)**
- $495/month for up to 10 users
- $895/month for 11-25 users
- $1,495/month for 26-50 users

**For 10-rep team:**
- $495/month = $5,940/year

**Pros:**
- Simple, predictable pricing
- No per-seat calculations
- Room to grow team without price shocks

**Cons:**
- Leaves money on table for larger teams
- Not standard SaaS pricing model

---

#### **Option C: Coaching Volume Pricing**
- $295/month base (manager access + dashboard)
- $29/user/month for AI coaching

**For 10-rep team:**
- $295 + ($29 × 10) = $585/month = $7,020/year

**Pros:**
- Acknowledges manager is main user
- Scales with team size
- Lower entry point

---

### 6.2 Recommended Pricing

**🎯 RECOMMENDED: Option A with tiering**

```
STARTER (1-10 users)
$49/user/month or $39/user/month annual
• Fathom + HubSpot integration
• Daily activity sync
• AI coaching generation
• Manager approval workflow
• Read/acknowledgment tracking
• Achievement celebrations
• Email support

PROFESSIONAL (11-25 users)
$39/user/month or $32/user/month annual
• Everything in Starter
• Multi-manager support
• Custom methodology training
• Advanced analytics
• Priority support

ENTERPRISE (26+ users)
Custom pricing
• Everything in Professional
• White-label option (for Sandler network!)
• API access
• Dedicated success manager
• Custom integrations
```

**10-user team pricing:**
- Starter: $490/month ($5,880/year)
- With annual discount: $390/month ($4,680/year)

---

### 6.3 Comparison to Current Model

**Current All-In-One Model:**
- $1,495/month flat rate
- 50 clients = $74,750/month = $897K/year

**New Integration Model:**
- $490/month per 10-user team (avg)
- Need 153 clients to match $74,750/month
- **3x more customers needed for same revenue**

**BUT:**
- Larger addressable market (anyone with Fathom/HubSpot)
- Easier sales cycle (solves one problem really well)
- Lower churn (integrated into existing workflow)
- White-label opportunity with Sandler network

---

### 6.4 White-Label Pricing (For Sandler Network)

**Carlos's Use Case:**
- He has 7-10 Sandler companies in his inner circle (~40 people)
- Broader network is hundreds of Sandler franchises
- Each franchise has dozens to hundreds of clients

**White-Label Model:**
```
Sandler Network pays you:
- $25/user/month wholesale
- They mark up to $59/user/month to their clients
- They make $34/user/month margin

10-user client:
- Client pays Sandler: $590/month
- Sandler pays you: $250/month
- Sandler profit: $340/month per client

If Sandler network gets 100 clients:
- You make: $25,000/month = $300K/year
- Sandler makes: $34,000/month = $408K/year
- Win-win
```

**Your pricing to Sandler:**
- 1-100 users: $25/user/month
- 101-500 users: $22/user/month
- 501+ users: $20/user/month

**Volume potential:**
- Sandler has 250+ franchises globally
- If each gets 5 clients with avg 15 users = 18,750 users
- At $22/user = $412,500/month = **$4.95M/year**

---

## 7. GO-TO-MARKET STRATEGY

### 7.1 Ideal Customer Profile

**Primary Target:**
- Sales teams already using Fathom + HubSpot
- 10-50 reps
- $5-50M revenue
- 1-2 sales managers (overworked, need coaching automation)
- Using Sandler/MEDDIC/Challenger methodology
- Pain point: "We record calls but don't have time to coach from them"

**Secondary Target:**
- Sandler/MEDDIC training franchises (white-label partners)
- Want recurring revenue from clients post-training
- Need proof that training is sticking

---

### 7.2 Competitive Positioning

**vs. Fathom:**
- Fathom captures conversations ✅
- Fathom doesn't auto-generate coaching ❌
- Fathom doesn't track if coaching was read/implemented ❌

**vs. Gong/Chorus:**
- They analyze calls ✅
- They don't have manager approval workflow ❌
- They don't close accountability loop ❌
- They cost 3-4x more 💰

**vs. Your Current Product:**
- No manual data entry needed ✅
- Leverages tools customers already use ✅
- Focused on ONE problem (coaching loop) ✅
- Lower price point ✅

**Your Unique Position:**
*"The only coaching intelligence platform that closes the accountability loop from call → AI insight → manager review → rep action → behavior change."*

---

### 7.3 Sales Channels

**Channel 1: Direct Sales (SMB/Mid-Market)**
- Outbound to companies using Fathom (can see this on LinkedIn)
- Messaging: "You're recording calls but not coaching from them. We fix that."
- Sell to sales managers, VPs of Sales

**Channel 2: Fathom/HubSpot Partner Program**
- Get listed as integration partner
- Fathom recommends you to their customers
- Revenue share or co-marketing deals

**Channel 3: Sandler/MEDDIC White-Label**
- Partner with training franchises
- They sell to their existing client base
- You provide white-labeled product
- They own customer relationship

**Channel 4: Sales Methodology Consultants**
- Independent Sandler/Challenger trainers
- Use your product as post-training reinforcement tool
- Affiliate commission or revenue share

---

## 8. RISKS & MITIGATION

### Risk 1: API Dependency
**Risk:** Fathom or HubSpot changes API, breaks integration
**Mitigation:**
- Build abstraction layer (if Fathom breaks, can swap in Gong)
- Monitor API changelog
- Maintain fallback manual upload option

### Risk 2: Market Size
**Risk:** Not enough companies using BOTH Fathom AND HubSpot
**Mitigation:**
- Support multiple conversation tools (Fathom, Gong, Chorus, Fireflies)
- Support multiple CRMs (HubSpot, Salesforce, Pipedrive)
- Start with one integration, expand based on demand

### Risk 3: Pricing Too Low
**Risk:** $49/user is too cheap, leaves money on table
**Mitigation:**
- Start at $69/user, test willingness to pay
- Annual contracts lock in pricing
- Enterprise tier at custom pricing captures large deals

### Risk 4: Competition from Fathom/HubSpot
**Risk:** They build this feature themselves
**Mitigation:**
- Move fast - 3 months to market
- Methodology-specific coaching is your moat (they won't build Sandler/MEDDIC expertise)
- Partner with them instead of compete

### Risk 5: Carlos/Sandler Doesn't Buy
**Risk:** Demo didn't convince him
**Mitigation:**
- Build beta first, show working product
- Offer free pilot to his inner circle (7 companies)
- Prove ROI with data (reps who get coached improve by X%)

---

## 9. SUCCESS METRICS

### Beta Phase (Months 1-3)
- 3-5 pilot customers using product
- 80%+ of coaching messages get read by reps
- 60%+ of reps acknowledge coaching
- Managers save 5+ hours/week on coaching prep

### Launch Phase (Months 4-6)
- 20 paying customers
- $10K+ MRR (monthly recurring revenue)
- <10% churn
- NPS score >40

### Scale Phase (Months 7-12)
- 50+ paying customers
- $30K+ MRR
- 1 white-label partner signed (Sandler or similar)
- Featured in Fathom or HubSpot marketplace

---

## 10. DECISION FRAMEWORK

### When to Build This:

✅ **BUILD if:**
- 3+ SMB prospects say "I'd pay for this TODAY"
- You can get 3-5 beta customers committed
- You have 3-4 months to dedicate to development
- You're willing to pivot from all-in-one to coaching layer

❌ **DON'T BUILD if:**
- SMB prospects love your current all-in-one system
- You can close 10+ customers at $1,495/month with current product
- API integrations feel too risky/complex
- You prefer owning full stack vs being integration layer

---

## 11. NEXT STEPS (This Week)

### **Test 1: SMB Market Validation**
Call 5 companies with 10-20 person sales teams:
- Do they use Fathom? HubSpot? Neither?
- Do they manually track activity or is it auto-captured?
- Would they pay $1,495/month for all-in-one system?
- **Decision:** If 3+ say yes → stick with all-in-one

### **Test 2: Integration Market Validation**
Call 5 companies that DO use Fathom + HubSpot:
- Are they coaching from Fathom transcripts?
- How do they track if coaching gets implemented?
- Would they pay $49/user for automated coaching loop?
- **Decision:** If 3+ say yes → build integration layer

### **Test 3: Sandler Network**
Reach out to Carlos's inner circle (with his intro):
- Would they white-label this for their clients?
- What pricing makes sense for them?
- What features are must-haves?
- **Decision:** If 2+ want to partner → build with white-label in mind

---

## 12. RECOMMENDATION

**My gut: Do BOTH.**

1. **Build integration layer first** (3 months)
   - Serves enterprise market (Carlos's world)
   - White-label opportunity with Sandler network
   - Easier to sell into existing Fathom/HubSpot users
   - Lower development risk (leverage existing tools)

2. **Keep all-in-one as "entry tier"** for SMB
   - For companies WITHOUT Fathom/HubSpot
   - Price at $995/month (cheaper than integration pricing)
   - Manual data entry version
   - Upsell to integration tier when they grow

**Two products, two markets:**
- **"Coaching Loop Pro"** - Integration layer - $49/user - Enterprise/Mid-Market
- **"Coaching Loop Starter"** - All-in-one - $995/month - SMB

**Total addressable market = Fathom users + Non-Fathom users**

---

## FINAL THOUGHT

Carlos gave you a gift: **He showed you the gap in a billion-dollar funded tool.**

Fathom has raised hundreds of millions. They STILL don't have the coaching accountability loop.

That means:
1. It's hard to build (defensible moat)
2. It's valuable (people want it)
3. It's unsexy infrastructure (they won't prioritize it)

**You can own this niche.**

Build the coaching loop. Make it methodology-aware. Close the accountability gap.

Let Fathom capture conversations.
Let HubSpot track activity.
**You turn it into behavior change.**

---

**Questions to answer this week:**
1. Can you get 3 beta customers for integration version?
2. Can you get 3 beta customers for all-in-one version?
3. Is Sandler white-label real or pipe dream?

**Then decide: Integration layer, all-in-one, or both.**

Good luck with your testing. 🚀
