import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { analyzeTranscript, generateCoachingFromAnalysis, SANDLER_COMPONENTS } from "./sandler-methodology.ts";
import {
  ragSearch,
  buildRAGContext,
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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { call_id, use_rag = true } = await req.json();

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

    // Analyze the transcript
    const analysis = analyzeTranscript(call.transcript || "", call.ai_summary || "");

    // Identify weak areas for RAG retrieval
    const weakAreas = analysis.scores
      .filter(s => s.score < 7)
      .sort((a, b) => a.score - b.score)
      .slice(0, 3)
      .map(s => s.component);

    // Retrieve relevant Sandler content via RAG (if enabled and API key available)
    let ragContext = "";
    let ragScripts: Array<{ title: string; text: string; situation: string[] }> = [];

    if (use_rag && OPENAI_API_KEY && weakAreas.length > 0) {
      try {
        // Build coaching context from RAG
        ragContext = await buildCoachingContext(
          supabase,
          OPENAI_API_KEY,
          weakAreas.map(a => normalizeComponentName(a)),
          call.transcript?.substring(0, 1000)
        );

        // Also get specific scripts for the weakest area
        const weakestComponent = weakAreas[0];
        const scriptResults = await ragSearch(supabase, OPENAI_API_KEY, {
          query: `Sales script for ${weakestComponent} improvement`,
          contentTypes: ["script"],
          components: [normalizeComponentName(weakestComponent)],
          matchCount: 3,
          matchThreshold: 0.4,
        });

        ragScripts = scriptResults.map(r => ({
          title: r.chunk_title,
          text: r.chunk_text,
          situation: r.situation_tags,
        }));
      } catch (ragError) {
        console.warn("RAG retrieval failed, continuing without context:", ragError);
        // Continue without RAG if it fails
      }
    }

    // Generate coaching (enhanced with RAG context if available)
    const repName = call.rep_email?.split("@")[0].replace(/[._]/g, " ") || "Rep";
    const callDate = new Date(call.call_date).toLocaleDateString();
    let coaching = generateCoachingFromAnalysis(analysis, repName, callDate);

    // Enhance coaching with RAG-retrieved scripts if available
    if (ragScripts.length > 0) {
      coaching += "\n\n---\n";
      coaching += "RECOMMENDED PRACTICE SCRIPTS (Based on Your Weak Areas)\n\n";

      ragScripts.forEach((script, i) => {
        coaching += `${i + 1}. ${script.title}\n`;
        coaching += `${script.text}\n\n`;
      });
    }

    // Update the call with methodology scores
    await supabase
      .from("Synced_Conversations")
      .update({
        methodology_scores: {
          overall: analysis.overallScore,
          grade: analysis.overallGrade,
          components: analysis.scores.map(s => ({
            name: s.component,
            score: s.score,
            indicators: s.indicators,
            missing: s.missingElements
          })),
          rag_enhanced: ragScripts.length > 0
        },
        analyzed_at: new Date().toISOString()
      })
      .eq("id", call_id);

    return new Response(
      JSON.stringify({
        success: true,
        analysis: {
          overallScore: analysis.overallScore,
          overallGrade: analysis.overallGrade,
          scores: analysis.scores,
          suggestedScripts: analysis.suggestedScripts,
          immediateActions: analysis.immediateActions,
          ragEnhanced: ragScripts.length > 0,
          ragScripts: ragScripts.length > 0 ? ragScripts : undefined
        },
        coaching,
        ragContext: ragContext || undefined,
        call_id
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
