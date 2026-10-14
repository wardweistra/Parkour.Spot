import type {CommunitySource, CommunitySources} from "./types";

export const COMMUNITY_PEOPLE = [
  {
    name: "Daphne Fontijn",
    role: "Art",
    instagramHandle: "daphnefontijn",
  },
  {
    name: "Tim Haerkens",
    role: null as string | null,
    instagramHandle: "tim.haerkens",
  },
  {
    name: "Marily Bronkhorst",
    role: null as string | null,
    instagramHandle: "marilybronk",
  },
] as const;

export function emptyCommunitySources(): CommunitySources {
  return {
    generatedAt: new Date().toISOString(),
    spotSources: [],
    eventSources: [],
  };
}

function normalizeSource(raw: Partial<CommunitySource> | undefined): CommunitySource | null {
  if (!raw || typeof raw.id !== "string" || !raw.id.trim()) return null;
  const name =
    typeof raw.name === "string" && raw.name.trim() ? raw.name.trim() : raw.id;
  return {
    id: raw.id.trim(),
    name,
    publicUrl:
      typeof raw.publicUrl === "string" && raw.publicUrl.trim()
        ? raw.publicUrl.trim()
        : null,
    description:
      typeof raw.description === "string" && raw.description.trim()
        ? raw.description.trim()
        : null,
    instagramHandle:
      typeof raw.instagramHandle === "string" && raw.instagramHandle.trim()
        ? raw.instagramHandle.trim().replace(/^@/, "")
        : null,
    logoUrl:
      typeof raw.logoUrl === "string" && raw.logoUrl.trim()
        ? raw.logoUrl.trim()
        : null,
    spotCount:
      typeof raw.spotCount === "number" && Number.isFinite(raw.spotCount)
        ? Math.max(0, Math.floor(raw.spotCount))
        : undefined,
    eventCount:
      typeof raw.eventCount === "number" && Number.isFinite(raw.eventCount)
        ? Math.max(0, Math.floor(raw.eventCount))
        : undefined,
  };
}

export function normalizeCommunitySources(
  data: Partial<CommunitySources> | undefined,
): CommunitySources {
  if (!data) return emptyCommunitySources();
  return {
    generatedAt:
      typeof data.generatedAt === "string"
        ? data.generatedAt
        : new Date().toISOString(),
    spotSources: (Array.isArray(data.spotSources) ? data.spotSources : [])
      .map((row) => normalizeSource(row))
      .filter((row): row is CommunitySource => row != null),
    eventSources: (Array.isArray(data.eventSources) ? data.eventSources : [])
      .map((row) => normalizeSource(row))
      .filter((row): row is CommunitySource => row != null),
  };
}

/** Top sources for hub highlights: prefer higher counts, then name. */
export function highlightSources(
  sources: CommunitySource[],
  limit: number,
  countKey: "spotCount" | "eventCount",
): CommunitySource[] {
  if (limit <= 0 || sources.length === 0) return [];
  return [...sources]
    .sort((a, b) => {
      const ca = Number(a[countKey]) || 0;
      const cb = Number(b[countKey]) || 0;
      return cb - ca || a.name.localeCompare(b.name, "en", {sensitivity: "base"});
    })
    .slice(0, limit);
}
