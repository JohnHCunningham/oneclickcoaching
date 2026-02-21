import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { analyzeTranscript, generateCoachingFromAnalysis, SANDLER_COMPONENTS } from "./sandler-methodology.ts";
import {
  ragSearch,
  buildCoachingContext,
  normalizeComponentName,
} from "../_shared/rag-utils.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");

// ─── GPT-4 Deep Analysis ───
async function analyzeWithGPT4(transcript: string, priorSuggestions: string[]): Promise<{
  scores: Record<string, { score: number; evidence: string; status: string }>;
  done_well: string[];
  missing: string[];
  weak: string[];
  suggestions: string[];
  scripts: string[];
}> {
  if (!OPENAI_API_KEY) throw new Error("OPENAI_API_KEY not configured");

  const priorContext = priorSuggestions.length > 0
    ? `\n\nIMPORTANT - PRIOR COACHING (DO NOT REPEAT THESE):\n${priorSuggestions.map((s, i) => `${i + 1}. ${s}`).join('\n')}\n\nGenerate NEW, DIFFERENT suggestions. If the same weakness persists, escalate with stronger language like "This is a recurring pattern that needs immediate focus."`
    : "";

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o",
      temperature: 0.3,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content: `You are a Sandler Selling System expert coach. Analyze sales call transcripts and score them against the 8 Sandler components. Be specific, cite evidence from the transcript, and provide actionable coaching.

Score each component 1-10 where:
- 1-3: Component was absent or poorly executed
- 4-6: Partially present, needs significant improvement
- 7-8: Solid execution with minor gaps
- 9-10: Masterful execution

Components to score:
1. Bonding & Rapport - Genuine connection before business
2. Upfront Contract - Clear expectations for the conversation
3. Pain Funnel - Deep emotional/business pain uncovered
4. Budget Step - Honest money conversation before solution
5. Decision Step - Mapped decision process, stakeholders, timeline
6. Fulfillment - Solution tied to stated pain, not feature dumping
7. Post-Sell - Prevented buyer's remorse, clear next steps
8. No Free Consulting - Protected expertise, maintained boundaries

Return JSON with this exact structure:
{
  "scores": {
    "bonding_rapport": { "score": N, "evidence": "quote or observation from transcript", "status": "strong|weak|missing" },
    "upfront_contract": { ... },
    "pain_funnel": { ... },
    "budget_step": { ... },
    "decision_step": { ... },
    "fulfillment": { ... },
    "post_sell": { ... },
    "no_free_consulting": { ... }
  },
  "done_well": ["specific thing with evidence", ...],
  "missing": ["specific step skipped with consequence", ...],
  "weak": ["attempted but poorly executed with why", ...],
  "suggestions": ["specific, actionable coaching point", ...],
  "scripts": ["exact words to say in a specific situation", ...]
}

Be direct. No platitudes. Every suggestion must be specific enough to use on the next call.${priorContext}`
        },
        {
          role: "user",
          content: `Analyze this sales call transcript:\n\n${transcript.substring(0, 12000)}`
        }
      ]
    })
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`OpenAI API error: ${response.status} ${err}`);
  }

  const result = await response.json();
  return JSON.parse(result.choices[0].message.content);
}

// ─── Non-Repetition: Load Prior Suggestions ───
async function loadPriorSuggestions(supabase: any, userId: string, limit = 20): Promise<string[]> {
  const { data } = await supabase
    .from("Coaching_Suggestions_Log")
    .select("suggestion_text")
    .eq("user_id", userId)
    .order("last_flagged_at", { ascending: false })
    .limit(limit);

  return data?.map((r: any) => r.suggestion_text) || [];
}

// ─── Non-Repetition: Log New Suggestions ───
async function logSuggestions(
  supabase: any,
  accountId: string,
  userId: string,
  callId: string,
  suggestions: string[],
  components: string[]
) {
  for (let i = 0; i < suggestions.length; i++) {
    const suggestion = suggestions[i];
    const component = components[i] || "general";

    // Check if similar suggestion exists
    const { data: existing } = await supabase
      .from("Coaching_Suggestions_Log")
      .select("id, times_flagged")
      .eq("user_id", userId)
      .eq("weakness_pattern", component)
      .limit(1);

    if (existing && existing.length > 0) {
      // Increment counter
      await supabase
        .from("Coaching_Suggestions_Log")
        .update({
          times_flagged: existing[0].times_flagged + 1,
          last_flagged_at: new Date().toISOString(),
          call_id: callId,
        })
        .eq("id", existing[0].id);
    } else {
      await supabase.from("Coaching_Suggestions_Log").insert({
        account_id: accountId,
        user_id: userId,
        call_id: callId,
        suggestion_text: suggestion,
        component,
        weakness_pattern: component,
      });
    }
  }
}

// ─── Main Handler ───
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const call_id = body.call_id || body.conversation_id;
    const use_rag = body.use_rag !== false;

    if (!call_id) {
      return new Response(
        JSON.stringify({ error: "call_id is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Fetch the call
    const { data: call, error: callError } = await supabase
      .from("Synced_Conversations")
      .select("*")
      .eq("id", call_id)
      .single();

    if (callError || !call) {
      return new Response(
        JSON.stringify({ error: "Call not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const transcript = call.transcript || call.ai_summary || "";
    if (!transcript) {
      return new Response(
        JSON.stringify({ error: "No transcript available for analysis" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Find the rep user ID for non-repetition
    let repUserId: string | null = null;
    if (call.rep_email) {
      const { data: repUser } = await supabase
        .from("Users")
        .select("auth_id")
        .eq("email", call.rep_email)
        .eq("account_id", call.account_id)
        .single();
      repUserId = repUser?.auth_id || null;
    }

    // Load prior coaching suggestions for this rep (non-repetition)
    const priorSuggestions = repUserId
      ? await loadPriorSuggestions(supabase, repUserId)
      : [];

    // Try GPT-4 deep analysis first, fall back to keyword analysis
    let gptAnalysis: any = null;
    let keywordAnalysis = analyzeTranscript(transcript, call.ai_summary || "");
    let coaching: string;
    let methodologyScores: Record<string, number> = {};

    if (OPENAI_API_KEY) {
      try {
        gptAnalysis = await analyzeWithGPT4(transcript, priorSuggestions);

        // Build methodology_scores from GPT-4 output
        const componentNameMap: Record<string, string> = {
          bonding_rapport: "Bonding & Rapport",
          upfront_contract: "Upfront Contract",
          pain_funnel: "Pain Funnel",
          budget_step: "Budget Step",
          decision_step: "Decision Step",
          fulfillment: "Fulfillment",
          post_sell: "Post-Sell",
          no_free_consulting: "No Free Consulting",
        };

        for (const [key, data] of Object.entries(gptAnalysis.scores)) {
          const name = componentNameMap[key] || key;
          methodologyScores[name] = (data as any).score;
        }

        // Build rich coaching content
        coaching = `📊 SANDLER ANALYSIS\n\n`;

        // Done well
        if (gptAnalysis.done_well.length > 0) {
          coaching += `✅ WHAT YOU DID WELL\n`;
          gptAnalysis.done_well.forEach((item: string) => {
            coaching += `• ${item}\n`;
          });
          coaching += `\n`;
        }

        // Missing
        if (gptAnalysis.missing.length > 0) {
          coaching += `❌ WHAT WAS MISSING\n`;
          gptAnalysis.missing.forEach((item: string) => {
            coaching += `• ${item}\n`;
          });
          coaching += `\n`;
        }

        // Weak
        if (gptAnalysis.weak.length > 0) {
          coaching += `⚠️ NEEDS IMPROVEMENT\n`;
          gptAnalysis.weak.forEach((item: string) => {
            coaching += `• ${item}\n`;
          });
          coaching += `\n`;
        }

        // Suggestions
        if (gptAnalysis.suggestions.length > 0) {
          coaching += `🎯 COACHING SUGGESTIONS\n`;
          gptAnalysis.suggestions.forEach((item: string, i: number) => {
            coaching += `${i + 1}. ${item}\n`;
          });
          coaching += `\n`;
        }

        // Scripts
        if (gptAnalysis.scripts.length > 0) {
          coaching += `💬 SCRIPTS TO PRACTICE\n`;
          gptAnalysis.scripts.forEach((item: string) => {
            coaching += `• "${item}"\n`;
          });
        }

        // Log suggestions for non-repetition
        if (repUserId && gptAnalysis.suggestions.length > 0) {
          const weakComponents = Object.entries(gptAnalysis.scores)
            .filter(([_, data]) => (data as any).status === 'weak' || (data as any).status === 'missing')
            .map(([key]) => key);

          await logSuggestions(
            supabase,
            call.account_id,
            repUserId,
            call_id,
            gptAnalysis.suggestions,
            weakComponents
          );
        }

      } catch (gptError) {
        console.warn("GPT-4 analysis failed, using keyword fallback:", gptError);
        gptAnalysis = null;
      }
    }

    // Fallback to keyword analysis if GPT-4 failed
    if (!gptAnalysis) {
      keywordAnalysis.scores.forEach(s => {
        methodologyScores[s.component] = s.score;
      });
      const repName = call.rep_email?.split("@")[0].replace(/[._]/g, " ") || "Rep";
      const callDate = new Date(call.call_date).toLocaleDateString();
      coaching = generateCoachingFromAnalysis(keywordAnalysis, repName, callDate);
    }

    // RAG enhancement for weak areas
    let ragScripts: any[] = [];
    const weakAreas = Object.entries(methodologyScores)
      .filter(([_, score]) => score < 7)
      .sort(([_, a], [__, b]) => a - b)
      .slice(0, 3)
      .map(([name]) => name);

    if (use_rag && OPENAI_API_KEY && weakAreas.length > 0) {
      try {
        const weakestComponent = weakAreas[0];
        const scriptResults = await ragSearch(supabase, OPENAI_API_KEY, {
          query: `Sales script for ${weakestComponent} improvement`,
          contentTypes: ["script"],
          components: [normalizeComponentName(weakestComponent)],
          matchCount: 3,
          matchThreshold: 0.4,
        });

        ragScripts = scriptResults.map((r: any) => ({
          title: r.chunk_title,
          text: r.chunk_text,
          situation: r.situation_tags,
        }));

        if (ragScripts.length > 0) {
          coaching += `\n\n---\nRECOMMENDED SCRIPTS\n\n`;
          ragScripts.forEach((script: any, i: number) => {
            coaching += `${i + 1}. ${script.title}\n${script.text}\n\n`;
          });
        }
      } catch (ragError) {
        console.warn("RAG retrieval failed:", ragError);
      }
    }

    // Update the call record
    await supabase
      .from("Synced_Conversations")
      .update({
        methodology_scores: methodologyScores,
        ai_summary: gptAnalysis
          ? `Done well: ${gptAnalysis.done_well.join('; ')}. Missing: ${gptAnalysis.missing.join('; ')}. Weak: ${gptAnalysis.weak.join('; ')}.`
          : call.ai_summary,
        analyzed_at: new Date().toISOString(),
      })
      .eq("id", call_id);

    // Auto-generate coaching message for leader approval
    await supabase.from("Coaching_Messages").insert({
      account_id: call.account_id,
      rep_email: call.rep_email,
      manager_email: null,
      coaching_content: coaching!,
      methodology: "Sandler",
      status: "generated",
      generated_at: new Date().toISOString(),
      call_id: call_id,
    });

    return new Response(
      JSON.stringify({
        success: true,
        scores: methodologyScores,
        coaching: coaching!,
        gpt4_powered: !!gptAnalysis,
        rag_enhanced: ragScripts.length > 0,
        call_id,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Analysis error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
