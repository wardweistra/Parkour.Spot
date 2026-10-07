import type {APIRoute} from "astro";
import {buildLlmsTxt} from "../lib/llms";
import {loadCoverage} from "../lib/snapshots";

export const prerender = true;

/** Machine-readable map of the canonical pages. See https://llmstxt.org/ */
export const GET: APIRoute = async () => {
  const coverage = await loadCoverage();
  return new Response(buildLlmsTxt(coverage), {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
    },
  });
};
