import type {APIRoute} from "astro";
import {buildLlmsTxt} from "../lib/llms";
import {loadCoverage, loadStats} from "../lib/snapshots";

export const prerender = true;

/** Machine-readable map of the canonical pages. See https://llmstxt.org/ */
export const GET: APIRoute = async () => {
  const coverage = await loadCoverage();
  const stats = await loadStats();
  return new Response(buildLlmsTxt({countries: coverage.countries, stats}), {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
    },
  });
};
