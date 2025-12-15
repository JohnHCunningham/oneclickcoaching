# Authentication System Setup Guide

## Overview

Your tracker app now has a complete authentication system with:
- User login/signup (login.html, signup.html)
- Protected routes (index.html redirects to login if not authenticated)
- Session management
- User metadata (name, company, methodology)
- Logout functionality

## Files Created

✅ **login.html** - User login page
✅ **signup.html** - New user registration
✅ **index.html** - Updated with auth protection

## Setup Steps

### 1. Enable Email Authentication in Supabase

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project
3. Navigate to **Authentication** → **Providers**
4. Find **Email** provider
5. Toggle **Enable Email provider** to ON
6. Configure settings:
   - ✅ Enable email confirmations (optional - can disable for testing)
   - ✅ Enable signup (required)
   - Click **Save**

### 2. Configure Email Templates (Optional but Recommended)

1. Go to **Authentication** → **Email Templates**
2. Customize:
   - **Confirm signup** - Welcome email
   - **Magic Link** - Passwordless login (optional)
   - **Reset Password** - Password reset email

### 3. Set Up Row Level Security (RLS)

To ensure users can only see their own data:

#### Step 1: Enable RLS on All Tables

Go to **Database** → **Tables** and run these SQL commands:

```sql
-- Enable RLS on all tables
ALTER TABLE "Daily_Tracker" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Sales" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Conversation_Analyses" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Email_Tracking" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Scripts" ENABLE ROW LEVEL SECURITY;
```

#### Step 2: Create User Column

Add a `user_id` column to link records to users:

```sql
-- Add user_id column to Daily_Tracker
ALTER TABLE "Daily_Tracker"
ADD COLUMN user_id UUID REFERENCES auth.users(id);

-- Add user_id column to Sales
ALTER TABLE "Sales"
ADD COLUMN user_id UUID REFERENCES auth.users(id);

-- Add user_id column to Conversation_Analyses
ALTER TABLE "Conversation_Analyses"
ADD COLUMN user_id UUID REFERENCES auth.users(id);

-- Add user_id column to Email_Tracking
ALTER TABLE "Email_Tracking"
ADD COLUMN user_id UUID REFERENCES auth.users(id);

-- Add user_id column to Scripts
ALTER TABLE "Scripts"
ADD COLUMN user_id UUID REFERENCES auth.users(id);
```

#### Step 3: Create RLS Policies

Create policies so users can only access their own data:

```sql
-- Daily_Tracker policies
CREATE POLICY "Users can view own tracker data"
ON "Daily_Tracker" FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own tracker data"
ON "Daily_Tracker" FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own tracker data"
ON "Daily_Tracker" FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own tracker data"
ON "Daily_Tracker" FOR DELETE
USING (auth.uid() = user_id);

-- Sales policies
CREATE POLICY "Users can view own sales"
ON "Sales" FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sales"
ON "Sales" FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sales"
ON "Sales" FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own sales"
ON "Sales" FOR DELETE
USING (auth.uid() = user_id);

-- Conversation_Analyses policies
CREATE POLICY "Users can view own analyses"
ON "Conversation_Analyses" FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own analyses"
ON "Conversation_Analyses" FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Email_Tracking policies
CREATE POLICY "Users can view own email tracking"
ON "Email_Tracking" FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own email tracking"
ON "Email_Tracking" FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Scripts policies
CREATE POLICY "Users can view own scripts"
ON "Scripts" FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own scripts"
ON "Scripts" FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own scripts"
ON "Scripts" FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own scripts"
ON "Scripts" FOR DELETE
USING (auth.uid() = user_id);
```

### 4. Update Your JavaScript Code

In **index.html**, when inserting data, include `user_id`:

**OLD CODE:**
```javascript
const { data, error } = await supabaseClient
    .from('Daily_Tracker')
    .insert({
        date: selectedDate,
        dials: dials,
        conversations: conversations
        // ... other fields
    });
```

**NEW CODE:**
```javascript
const { data, error } = await supabaseClient
    .from('Daily_Tracker')
    .insert({
        user_id: currentUser.id,  // Add this line
        date: selectedDate,
        dials: dials,
        conversations: conversations
        // ... other fields
    });
```

**Search for all `.insert(` calls in index.html and add `user_id: currentUser.id` to each.**

### 5. Test the Authentication System

1. **Deploy** the updated files to Vercel:
   ```bash
   git add .
   git commit -m "Add authentication system"
   git push
   ```

2. **Test Signup:**
   - Go to https://daily-tracker-xi.vercel.app/signup.html
   - Create a test account
   - Should redirect to index.html after signup

3. **Test Login:**
   - Logout
   - Go to https://daily-tracker-xi.vercel.app/login.html
   - Login with your credentials
   - Should redirect to index.html

4. **Test Protected Route:**
   - Open incognito/private browser
   - Try to access https://daily-tracker-xi.vercel.app/index.html
   - Should automatically redirect to login.html

5. **Test Data Isolation:**
   - Create data with User A
   - Logout and login as User B
   - Verify User B cannot see User A's data

## Admin Dashboard Authentication

For **admin.html**, you have two options:

### Option A: Admin-Only Access (Recommended)

Create an admin role and only allow specific users:

```sql
-- Add is_admin column to user metadata
-- Set manually in Supabase Dashboard for admin users
-- Then check in admin.html:

async function checkAdminAuth() {
    const { data: { session } } = await supabaseClient.auth.getSession();

    if (!session) {
        window.location.href = 'login.html';
        return;
    }

    // Check if user is admin
    const isAdmin = session.user.user_metadata?.is_admin;

    if (!isAdmin) {
        alert('Admin access only');
        window.location.href = 'index.html';
        return;
    }
}
```

### Option B: All Authenticated Users Can Access

Simply add the same auth check as index.html to admin.html.

## Troubleshooting

### "Invalid login credentials" error
- Verify email/password are correct
- Check if email confirmation is required in Supabase settings
- Confirm user exists in Supabase Dashboard → Authentication → Users

### User can see other users' data
- Verify RLS policies are created correctly
- Check that `user_id` is being set on all inserts
- Test policies in Supabase SQL Editor

### Session expires immediately
- Check Supabase JWT settings
- Verify SUPABASE_URL and SUPABASE_ANON_KEY are correct
- Check browser console for errors

### "Auth session missing" error
- User needs to login again
- Session may have expired
- Clear browser cache and cookies

## Security Best Practices

✅ **Never commit secrets** - SUPABASE_ANON_KEY is safe to expose (it's public)
✅ **Use RLS** - Always enable Row Level Security on all tables
✅ **Validate on server** - Don't trust client-side validation alone
✅ **Use HTTPS** - Always deploy with HTTPS (Vercel does this automatically)
✅ **Email verification** - Consider enabling email confirmation for production

## Next Steps

1. Enable Supabase Auth (Step 1 above)
2. Set up RLS (Steps 2-3 above)
3. Update all `.insert()` calls to include `user_id`
4. Test thoroughly
5. Deploy to production

## Support

If you run into issues:
1. Check Supabase Dashboard → Logs
2. Check browser console for errors
3. Verify RLS policies are correct
4. Test with SQL Editor in Supabase

Your authentication system is now ready to protect your tracker app! 🔒
