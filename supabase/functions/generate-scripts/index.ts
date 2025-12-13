// Supabase Edge Function: Generate Sales Scripts with Claude
// This generates customized sales scripts based on business description

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')!

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      }
    })
  }

  try {
    // Get request body
    const { businessDescription, methodology = 'meddic' } = await req.json()

    if (!businessDescription) {
      return new Response(
        JSON.stringify({ error: 'Business description is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Build the script generation prompt
    const scriptPrompt = `
You are an expert sales script writer specializing in ${methodology.toUpperCase()} methodology.

BUSINESS DESCRIPTION:
${businessDescription}

TASK: Generate professional, effective sales scripts for this business using ${methodology.toUpperCase()} principles.

Generate the following scripts:

1. OPENING SCRIPT (Cold Call)
   - Brief, respectful, and engaging
   - Establish credibility quickly
   - Use pattern interrupt if appropriate
   - Include local connection if mentioned in business description

2. VALUE PROPOSITION
   - Clear, specific, and quantifiable
   - Focus on outcomes, not features
   - Use "I help [WHO] achieve [WHAT] by [HOW]" structure
   - Include specific numbers/metrics if possible

3. CALL TO ACTION (CTA)
   - Assumptive but respectful
   - Offer specific time commitment (e.g., "15-minute meeting")
   - Give choice between two options (alternative close)
   - Remove pressure

4. OBJECTION HANDLING TEMPLATE
   - Empathetic acknowledgment
   - Social proof (reference other clients)
   - Reframe to specific outcome
   - Ask a question to uncover real concern

IMPORTANT:
- Keep each script concise (2-3 sentences max)
- Use conversational language, not corporate jargon
- Include placeholders like [Name], [Company], [Specific Benefit]
- Make them specific to this business
- Follow ${methodology.toUpperCase()} principles

Return JSON in this exact format:
{
  "opening": "The opening script here",
  "valueProp": "The value proposition here",
  "cta": "The call to action here",
  "objections": "The objection handling template here"
}
`

    // Call Claude API
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-5-20250929',
        max_tokens: 2000,
        messages: [{
          role: 'user',
          content: scriptPrompt
        }]
      })
    })

    if (!response.ok) {
      const error = await response.text()
      throw new Error(`Claude API error: ${response.status} ${error}`)
    }

    const data = await response.json()
    const scriptText = data.content[0].text

    // Parse JSON from Claude's response
    const jsonMatch = scriptText.match(/\{[\s\S]*\}/)
    if (!jsonMatch) {
      throw new Error('Could not parse JSON from Claude response')
    }

    const scripts = JSON.parse(jsonMatch[0])

    // Return the generated scripts
    return new Response(
      JSON.stringify({ scripts }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      }
    )
  }
})
