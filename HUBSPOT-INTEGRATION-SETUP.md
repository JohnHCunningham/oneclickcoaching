# 🚀 HubSpot Integration Setup Guide
## Complete Step-by-Step Instructions

**Time Required:** 30-45 minutes
**Difficulty:** Intermediate
**Prerequisites:** Supabase account, HubSpot account (free or paid)

---

## 📋 Overview

This guide will walk you through setting up the HubSpot OAuth integration so that Sandler Revenue Factory can automatically sync activity data (calls, emails, meetings, deals) from HubSpot.

**What You'll Do:**
1. Create database tables in Supabase
2. Create a HubSpot developer account and app
3. Configure OAuth credentials
4. Deploy Supabase Edge Functions
5. Test the integration

---

## Step 1: Create Database Tables (5 minutes)

### 1.1 Open Supabase SQL Editor

1. Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Select your project: `qwqlsbccwnwrdpcaccjz`
3. Click **SQL Editor** in the left sidebar
4. Click **New Query**

### 1.2 Run Integration Schema

1. Open the file: `integrations-schema.sql` (in your project root)
2. Copy the **entire contents** of the file
3. Paste into Supabase SQL Editor
4. Click **Run** (or press Cmd+Enter)

**Expected Result:**
```
✅ Sandler Revenue Factory Integrations Created!
   📊 API_Connections - Store OAuth tokens
   📞 Synced_Activities - Activity data from HubSpot/Salesforce
   🎙️  Synced_Conversations - Calls from Fathom/Aircall
   📝 Coaching_Messages - AI coaching workflow
   🎯 Coaching_Outcomes - RAG learning system

🚀 Ready for HubSpot + Fathom + Aircall integration!
```

If you see this message, you're good to proceed!

### 1.3 Verify Tables Created

1. In Supabase, click **Table Editor** in left sidebar
2. You should see these new tables:
   - `API_Connections`
   - `Synced_Activities`
   - `Synced_Conversations`
   - `Integration_Sync_Log`
   - `Coaching_Messages`
   - `Coaching_Outcomes`

---

## Step 2: Create HubSpot Developer Account (10 minutes)

### 2.1 Sign Up for HubSpot Developer Account

1. Go to [https://developers.hubspot.com](https://developers.hubspot.com)
2. Click **Get Started** or **Sign In**
3. If you have a HubSpot account, sign in
4. If not, create a free account (no credit card required)

### 2.2 Create a New App

1. Once logged in, go to **Apps** → **Create app**
2. Fill in the app details:
   - **App name:** Sandler Revenue Factory
   - **Description:** AI-powered sales coaching intelligence for Sandler-trained teams
   - **Support email:** Your email
   - **Logo:** (optional - can skip for now)

3. Click **Create app**

### 2.3 Configure OAuth Settings

1. In your new app, click **Auth** tab on the left
2. Under **Redirect URLs**, click **Add redirect URL**
3. Enter your callback URL:
   ```
   https://YOUR_DOMAIN/integrations-callback.html
   ```

   **Examples:**
   - Local testing: `http://localhost:3000/integrations-callback.html`
   - Production: `https://sandlerrevenuefactory.com/integrations-callback.html`
   - If using Netlify/Vercel: `https://your-site.netlify.app/integrations-callback.html`

4. Click **Add**

### 2.4 Select Required Scopes

Still in the **Auth** tab, scroll down to **Scopes**

**Required Scopes** (check these boxes):
- ✅ `crm.objects.contacts.read` - Read contact data
- ✅ `crm.objects.companies.read` - Read company data
- ✅ `crm.objects.deals.read` - Read deals
- ✅ `sales-email-read` - Read sales emails
- ✅ `timeline` - Read timeline events (calls, meetings, notes)

Click **Save** at the bottom

### 2.5 Get Your OAuth Credentials

1. Still in the **Auth** tab, find the **App credentials** section
2. You'll see:
   - **Client ID** - Copy this
   - **Client secret** - Click **Show** then copy this

**⚠️ IMPORTANT:** Keep these credentials safe! You'll need them in the next step.

---

## Step 3: Configure Supabase Edge Functions (15 minutes)

### 3.1 Install Supabase CLI (if not already installed)

Open your terminal and run:

```bash
# macOS
brew install supabase/tap/supabase

# Or using npm
npm install -g supabase
```

Verify installation:
```bash
supabase --version
```

### 3.2 Link Your Supabase Project

```bash
# Navigate to your project directory
cd /Users/johncunningham/Daily-Tracker

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref qwqlsbccwnwrdpcaccjz
```

It will ask for your database password (the one you set when creating the Supabase project).

### 3.3 Set Up Environment Secrets

You need to store your HubSpot OAuth credentials as Supabase secrets.

```bash
# Set HubSpot Client ID
supabase secrets set HUBSPOT_CLIENT_ID="your_client_id_here"

# Set HubSpot Client Secret
supabase secrets set HUBSPOT_CLIENT_SECRET="your_client_secret_here"
```

Replace `your_client_id_here` and `your_client_secret_here` with the actual values from Step 2.5.

**Verify secrets were set:**
```bash
supabase secrets list
```

You should see:
```
HUBSPOT_CLIENT_ID
HUBSPOT_CLIENT_SECRET
```

### 3.4 Deploy Edge Functions

Deploy the HubSpot OAuth callback function:

```bash
supabase functions deploy hubspot-oauth-callback
```

**Expected output:**
```
Deploying function hubspot-oauth-callback...
Function URL: https://qwqlsbccwnwrdpcaccjz.supabase.co/functions/v1/hubspot-oauth-callback
✅ Deployed successfully!
```

Deploy the Fathom callback function (for later):
```bash
supabase functions deploy fathom-oauth-callback
```

### 3.5 Test Edge Function Deployment

Test that the function is accessible:

```bash
curl https://qwqlsbccwnwrdpcaccjz.supabase.co/functions/v1/hubspot-oauth-callback
```

You should get a response (even if it's an error - that's fine, it means the function is deployed).

---

## Step 4: Update Frontend Configuration (5 minutes)

### 4.1 Open integrations.html

Open the file: `/Users/johncunningham/Daily-Tracker/integrations.html`

### 4.2 Update OAuth Configuration

Find this section near the top of the `<script>` tag (around line 370):

```javascript
// OAuth Configuration (These will need to be replaced with actual values)
const HUBSPOT_CLIENT_ID = 'YOUR_HUBSPOT_CLIENT_ID';
const HUBSPOT_REDIRECT_URI = `${window.location.origin}/integrations-callback.html`;
```

Replace `'YOUR_HUBSPOT_CLIENT_ID'` with your actual Client ID from Step 2.5:

```javascript
const HUBSPOT_CLIENT_ID = 'abc123-your-actual-client-id-here';
```

**Do NOT change the REDIRECT_URI** - it automatically uses your current domain.

### 4.3 Save the File

Save `integrations.html` with the updated Client ID.

---

## Step 5: Test the Integration (5 minutes)

### 5.1 Open Integrations Page

1. Make sure you're logged into your Sandler Revenue Factory account
2. Navigate to: `https://your-domain/integrations.html`
   - Or locally: `http://localhost:3000/integrations.html`

### 5.2 Connect HubSpot

1. You should see the integrations page with three cards:
   - HubSpot (with "Connect HubSpot" button)
   - Fathom (with "Connect Fathom" button)
   - Aircall (Coming Soon)

2. Click **Connect HubSpot** button

3. You'll be redirected to HubSpot's authorization page

4. **Choose which HubSpot account to connect** (if you have multiple)

5. Review the permissions requested:
   - Read contacts
   - Read deals
   - Read sales emails
   - Read timeline events

6. Click **Grant access** or **Connect app**

### 5.3 Verify Connection

1. You'll be redirected back to your integrations page
2. You should see a success message: "HubSpot connected successfully!"
3. The HubSpot card should now show:
   - Status badge: **Connected** (green)
   - Activities Synced: 0 (will increase after first sync)
   - Last Sync: Never (will update after first sync)
   - Auto-Sync: Enabled

4. The button should now say **Disconnect** (red)

**If you see this, congratulations! HubSpot is connected! 🎉**

---

## Step 6: Verify Database Connection

### 6.1 Check API_Connections Table

1. Go back to Supabase Dashboard
2. Click **Table Editor** → **API_Connections**
3. You should see a new row with:
   - `provider`: hubspot
   - `connection_status`: active
   - `access_token`: (encrypted)
   - `refresh_token`: (encrypted)
   - `connected_at`: (today's timestamp)

### 6.2 Check Supabase Logs

1. In Supabase, click **Logs** in left sidebar
2. Click **Functions** tab
3. You should see logs from `hubspot-oauth-callback`
4. Look for: `HubSpot connection saved successfully`

---

## 🎯 Next Steps

Now that HubSpot is connected, you need to:

### Week 1 Remaining Tasks:
- [ ] Build HubSpot data sync function (pulls calls, emails, meetings)
- [ ] Create daily cron job to sync data automatically
- [ ] Display HubSpot data in manager dashboard

### Week 2 Tasks:
- [ ] Match HubSpot activities to reps (by email)
- [ ] Store activities in `Synced_Activities` table
- [ ] Replace static demo data with real HubSpot data

See **SANDLER-REVENUE-FACTORY-START-HERE.md** for the complete roadmap.

---

## 🐛 Troubleshooting

### Error: "Missing authorization header"

**Cause:** User not logged in

**Fix:** Log in to your account first, then try connecting HubSpot again

---

### Error: "Only managers can configure integrations"

**Cause:** Your user role is not set to 'manager'

**Fix:**
1. Go to Supabase → Table Editor → User_Roles
2. Find your user record
3. Change `role` to `'manager'`
4. Try again

---

### Error: "HubSpot OAuth not configured"

**Cause:** Environment secrets not set in Supabase

**Fix:**
1. Re-run: `supabase secrets set HUBSPOT_CLIENT_ID="your_id"`
2. Re-run: `supabase secrets set HUBSPOT_CLIENT_SECRET="your_secret"`
3. Re-deploy function: `supabase functions deploy hubspot-oauth-callback`

---

### Error: "Invalid redirect URI"

**Cause:** Redirect URI in HubSpot app doesn't match your callback URL

**Fix:**
1. Go to HubSpot Developer Portal
2. Edit your app → Auth tab
3. Make sure redirect URL exactly matches: `https://your-domain/integrations-callback.html`
4. Save changes
5. Try connecting again

---

### Connection works but no data syncing

**Cause:** Data sync function not built yet (that's Week 1 task #2)

**Next Step:** Build the HubSpot data sync Edge Function to pull activity data

---

## 📚 Reference

### HubSpot API Documentation
- [OAuth Guide](https://developers.hubspot.com/docs/api/oauth)
- [CRM API](https://developers.hubspot.com/docs/api/crm/understanding-the-crm)
- [Timeline Events](https://developers.hubspot.com/docs/api/crm/timeline)

### Supabase Documentation
- [Edge Functions](https://supabase.com/docs/guides/functions)
- [Secrets Management](https://supabase.com/docs/guides/functions/secrets)
- [RPC Functions](https://supabase.com/docs/guides/database/functions)

### Your Files
- `integrations-schema.sql` - Database schema
- `integrations.html` - Integration management UI
- `integrations-callback.html` - OAuth callback handler
- `supabase/functions/hubspot-oauth-callback/index.ts` - Token exchange function

---

## ✅ Success Checklist

- [ ] Database tables created in Supabase
- [ ] HubSpot developer account created
- [ ] HubSpot app created with OAuth configured
- [ ] Redirect URI added to HubSpot app
- [ ] Required scopes selected (contacts, deals, emails, timeline)
- [ ] Client ID and Client Secret copied
- [ ] Supabase CLI installed and linked
- [ ] Environment secrets set (HUBSPOT_CLIENT_ID, HUBSPOT_CLIENT_SECRET)
- [ ] Edge function deployed (`hubspot-oauth-callback`)
- [ ] Frontend updated with Client ID
- [ ] Integration page tested
- [ ] HubSpot connected successfully
- [ ] Connection verified in database

**Once all boxes are checked, you're ready for Week 1 Task #2: Build HubSpot data sync!**

---

**Questions?** Check the troubleshooting section or review the Sandler Revenue Factory roadmap in SANDLER-REVENUE-FACTORY-START-HERE.md
