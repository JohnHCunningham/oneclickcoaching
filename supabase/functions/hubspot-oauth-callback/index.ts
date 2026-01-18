// Supabase Edge Function: HubSpot OAuth Callback Handler
// Exchanges authorization code for access token and stores in database

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface OAuthCallbackRequest {
  code: string
  redirect_uri: string
}

interface HubSpotTokenResponse {
  access_token: string
  refresh_token: string
  expires_in: number
  token_type: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Missing authorization header')
    }

    // Create Supabase client with user's auth token
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    )

    // Verify user is authenticated
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      throw new Error('User not authenticated')
    }

    // Get user's account ID and verify they're a manager
    const { data: userRole, error: roleError } = await supabaseClient
      .from('User_Roles')
      .select('account_id, role')
      .eq('user_id', user.id)
      .eq('role', 'manager')
      .single()

    if (roleError || !userRole) {
      throw new Error('Only managers can configure integrations')
    }

    // Parse request body
    const { code, redirect_uri }: OAuthCallbackRequest = await req.json()

    if (!code) {
      throw new Error('Missing authorization code')
    }

    // HubSpot OAuth credentials (from environment variables)
    const clientId = Deno.env.get('HUBSPOT_CLIENT_ID')
    const clientSecret = Deno.env.get('HUBSPOT_CLIENT_SECRET')

    if (!clientId || !clientSecret) {
      throw new Error('HubSpot OAuth not configured - missing client credentials')
    }

    // Exchange code for tokens
    console.log('Exchanging code for tokens...')
    const tokenResponse = await fetch('https://api.hubapi.com/oauth/v1/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: redirect_uri,
        code: code,
      }),
    })

    if (!tokenResponse.ok) {
      const errorText = await tokenResponse.text()
      console.error('HubSpot token exchange failed:', errorText)
      throw new Error(`HubSpot token exchange failed: ${tokenResponse.status}`)
    }

    const tokens: HubSpotTokenResponse = await tokenResponse.json()

    // Get HubSpot account info
    let hubspotAccountId = null
    try {
      const accountInfoResponse = await fetch('https://api.hubapi.com/oauth/v1/access-tokens/' + tokens.access_token)
      if (accountInfoResponse.ok) {
        const accountInfo = await accountInfoResponse.json()
        hubspotAccountId = accountInfo.hub_id?.toString()
      }
    } catch (error) {
      console.error('Failed to get HubSpot account info:', error)
      // Non-fatal error, continue without account ID
    }

    // Save tokens to database using the RPC function
    const { data: connectionId, error: saveError } = await supabaseClient.rpc('save_hubspot_connection', {
      access_token_input: tokens.access_token,
      refresh_token_input: tokens.refresh_token,
      expires_in_seconds: tokens.expires_in,
      scopes_input: [], // HubSpot doesn't return scopes in token response
      hubspot_account_id: hubspotAccountId,
    })

    if (saveError) {
      console.error('Failed to save connection:', saveError)
      throw new Error('Failed to save connection to database')
    }

    console.log('HubSpot connection saved successfully:', connectionId)

    // Trigger initial sync (optional - can be done via cron job instead)
    // This would call another edge function to sync data
    // For now, we'll just return success

    return new Response(
      JSON.stringify({
        success: true,
        provider: 'hubspot',
        connection_id: connectionId,
        message: 'HubSpot connected successfully',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('OAuth callback error:', error)
    return new Response(
      JSON.stringify({
        error: error.message || 'An unexpected error occurred',
        details: error.toString(),
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
