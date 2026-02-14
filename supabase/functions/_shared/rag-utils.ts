// ============================================
// RAG UTILITIES FOR SANDLER REVENUE FACTORY
// Shared utilities for embedding generation and semantic search
// ============================================

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

// Types
export interface EmbeddingResult {
  embedding: number[];
  cached: boolean;
  model: string;
}

export interface RAGSearchResult {
  id: string;
  content_type: string;
  component_name: string;
  chunk_title: string;
  chunk_text: string;
  situation_tags: string[];
  weakness_tags: string[];
  similarity: number;
}

export interface RAGSearchOptions {
  query: string;
  contentTypes?: string[];
  components?: string[];
  weaknessTags?: string[];
  situationTags?: string[];
  matchThreshold?: number;
  matchCount?: number;
}

// ============================================
// EMBEDDING GENERATION
// ============================================

const OPENAI_EMBEDDING_MODEL = "text-embedding-3-small";
const EMBEDDING_DIMENSIONS = 1536;

/**
 * Generate a SHA-256 hash of text for cache key
 */
async function hashText(text: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(text);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Generate embedding for text using OpenAI API
 * Includes caching to reduce API costs
 */
export async function generateEmbedding(
  text: string,
  supabase: SupabaseClient,
  openaiApiKey: string
): Promise<EmbeddingResult> {
  // Normalize text
  const normalizedText = text.trim().toLowerCase();
  const textHash = await hashText(normalizedText);

  // Check cache first
  const { data: cachedData } = await supabase.rpc("get_cached_embedding", {
    input_hash: textHash,
  });

  if (cachedData) {
    return {
      embedding: cachedData,
      cached: true,
      model: OPENAI_EMBEDDING_MODEL,
    };
  }

  // Generate new embedding via OpenAI
  const response = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${openaiApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      input: normalizedText,
      model: OPENAI_EMBEDDING_MODEL,
      dimensions: EMBEDDING_DIMENSIONS,
    }),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(`OpenAI API error: ${error.error?.message || "Unknown error"}`);
  }

  const result = await response.json();
  const embedding = result.data[0].embedding;

  // Cache the embedding
  await supabase.rpc("cache_embedding", {
    input_hash: textHash,
    input_text: normalizedText.substring(0, 5000), // Limit stored text
    input_embedding: `[${embedding.join(",")}]`,
    input_model: OPENAI_EMBEDDING_MODEL,
  });

  return {
    embedding,
    cached: false,
    model: OPENAI_EMBEDDING_MODEL,
  };
}

/**
 * Generate embeddings for multiple texts in batch
 * More efficient for bulk operations
 */
export async function generateEmbeddingsBatch(
  texts: string[],
  supabase: SupabaseClient,
  openaiApiKey: string
): Promise<EmbeddingResult[]> {
  const results: EmbeddingResult[] = [];
  const uncachedTexts: { index: number; text: string }[] = [];

  // Check cache for all texts
  for (let i = 0; i < texts.length; i++) {
    const normalizedText = texts[i].trim().toLowerCase();
    const textHash = await hashText(normalizedText);

    const { data: cachedData } = await supabase.rpc("get_cached_embedding", {
      input_hash: textHash,
    });

    if (cachedData) {
      results[i] = {
        embedding: cachedData,
        cached: true,
        model: OPENAI_EMBEDDING_MODEL,
      };
    } else {
      uncachedTexts.push({ index: i, text: normalizedText });
    }
  }

  // Batch generate uncached embeddings
  if (uncachedTexts.length > 0) {
    const response = await fetch("https://api.openai.com/v1/embeddings", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openaiApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        input: uncachedTexts.map((t) => t.text),
        model: OPENAI_EMBEDDING_MODEL,
        dimensions: EMBEDDING_DIMENSIONS,
      }),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(`OpenAI API error: ${error.error?.message || "Unknown error"}`);
    }

    const result = await response.json();

    // Store results and cache
    for (let j = 0; j < uncachedTexts.length; j++) {
      const { index, text } = uncachedTexts[j];
      const embedding = result.data[j].embedding;

      results[index] = {
        embedding,
        cached: false,
        model: OPENAI_EMBEDDING_MODEL,
      };

      // Cache asynchronously
      const textHash = await hashText(text);
      supabase.rpc("cache_embedding", {
        input_hash: textHash,
        input_text: text.substring(0, 5000),
        input_embedding: `[${embedding.join(",")}]`,
        input_model: OPENAI_EMBEDDING_MODEL,
      });
    }
  }

  return results;
}

// ============================================
// RAG SEARCH
// ============================================

/**
 * Perform semantic search over Sandler knowledge base
 */
export async function ragSearch(
  supabase: SupabaseClient,
  openaiApiKey: string,
  options: RAGSearchOptions
): Promise<RAGSearchResult[]> {
  const {
    query,
    contentTypes = null,
    components = null,
    weaknessTags = null,
    situationTags = null,
    matchThreshold = 0.5,
    matchCount = 5,
  } = options;

  // Generate embedding for query
  const { embedding } = await generateEmbedding(query, supabase, openaiApiKey);

  // Search using pgvector
  const { data, error } = await supabase.rpc("search_sandler_content", {
    query_embedding: `[${embedding.join(",")}]`,
    match_threshold: matchThreshold,
    match_count: matchCount,
    filter_content_types: contentTypes,
    filter_components: components,
    filter_weakness_tags: weaknessTags,
    filter_situation_tags: situationTags,
  });

  if (error) {
    console.error("RAG search error:", error);
    throw new Error(`RAG search failed: ${error.message}`);
  }

  return data || [];
}

/**
 * Find scripts for specific weak areas
 * Quick lookup without embedding generation
 */
export async function findScriptsForWeakness(
  supabase: SupabaseClient,
  weakComponent: string,
  limit: number = 3
): Promise<{ chunk_title: string; chunk_text: string; situation_tags: string[] }[]> {
  const { data, error } = await supabase.rpc("find_scripts_for_weakness", {
    weak_component: weakComponent,
    limit_count: limit,
  });

  if (error) {
    console.error("Find scripts error:", error);
    return [];
  }

  return data || [];
}

// ============================================
// CONTEXT BUILDING
// ============================================

/**
 * Build a context string from RAG search results
 * For inclusion in AI prompts
 */
export function buildRAGContext(results: RAGSearchResult[]): string {
  if (!results || results.length === 0) {
    return "";
  }

  return results
    .map((r, i) => {
      const header = r.component_name
        ? `[${r.component_name}] ${r.chunk_title}`
        : r.chunk_title;
      return `--- Reference ${i + 1}: ${header} ---\n${r.chunk_text}`;
    })
    .join("\n\n");
}

/**
 * Build coaching context from weaknesses
 * Retrieves relevant scripts and examples for coaching
 */
export async function buildCoachingContext(
  supabase: SupabaseClient,
  openaiApiKey: string,
  weakAreas: string[],
  transcript?: string
): Promise<string> {
  const contexts: string[] = [];

  // Search for content related to weak areas
  const searchQuery = `Coaching for sales rep weakness in: ${weakAreas.join(", ")}. ${
    transcript ? `Call context: ${transcript.substring(0, 500)}` : ""
  }`;

  const results = await ragSearch(supabase, openaiApiKey, {
    query: searchQuery,
    contentTypes: ["script", "component"],
    weaknessTags: weakAreas.map((a) => a.toLowerCase().replace(/\s+/g, "_")),
    matchCount: 5,
    matchThreshold: 0.4,
  });

  if (results.length > 0) {
    contexts.push("## Relevant Sandler Techniques\n" + buildRAGContext(results));
  }

  // Also get direct script matches for each weak area
  for (const area of weakAreas.slice(0, 2)) {
    const scripts = await findScriptsForWeakness(supabase, area, 2);
    if (scripts.length > 0) {
      const scriptText = scripts
        .map((s) => `**${s.chunk_title}**\n${s.chunk_text}`)
        .join("\n\n");
      contexts.push(`## Scripts for ${area}\n${scriptText}`);
    }
  }

  return contexts.join("\n\n---\n\n");
}

// ============================================
// COMPONENT NAME MAPPING
// ============================================

export const COMPONENT_NAME_MAP: Record<string, string> = {
  "Bonding & Rapport": "BONDING_RAPPORT",
  "Upfront Contract": "UPFRONT_CONTRACT",
  "Pain Funnel": "PAIN_FUNNEL",
  "Budget Step": "BUDGET",
  "Decision Step": "DECISION",
  "Fulfillment": "FULFILLMENT",
  "Post-Sell": "POST_SELL",
  "No Free Consulting": "NO_FREE_CONSULTING",
};

export const REVERSE_COMPONENT_MAP: Record<string, string> = Object.fromEntries(
  Object.entries(COMPONENT_NAME_MAP).map(([k, v]) => [v, k])
);

export function normalizeComponentName(name: string): string {
  return COMPONENT_NAME_MAP[name] || name.toUpperCase().replace(/\s+/g, "_");
}

export function displayComponentName(name: string): string {
  return REVERSE_COMPONENT_MAP[name] || name.replace(/_/g, " ").replace(/\b\w/g, (l) => l.toUpperCase());
}
