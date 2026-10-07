export type SpotSummary = {
  id: string;
  name: string;
  averageRating: number;
  ratingCount: number;
  ranking: number;
  imageUrl: string | null;
  city: string;
  citySlug: string;
  countryCode: string;
};

export type EventSummary = {
  slug: string;
  eventId: string;
  title: string;
  startAt: string | null;
  endAt: string | null;
  isDateOnly?: boolean;
  timeZone?: string | null;
  city: string | null;
  citySlug: string | null;
  countryCode: string | null;
  imageUrl: string | null;
  websiteUrl?: string | null;
};

export type EventDetail = EventSummary & {
  description: string | null;
  address: string | null;
  latitude: number | null;
  longitude: number | null;
  imageUrls: string[];
};

export type CityRef = {
  city: string;
  citySlug: string;
  /** All public spots. Absent on snapshots written before this field. */
  spotCount?: number;
  eventCount: number;
};

export type CountrySnapshot = {
  countryCode: string;
  generatedAt: string;
  spotCount?: number;
  cities: CityRef[];
  spots: SpotSummary[];
  events: EventSummary[];
};

export type CitySnapshot = {
  countryCode: string;
  city: string;
  citySlug: string;
  generatedAt: string;
  spotCount?: number;
  spots: SpotSummary[];
  events: EventSummary[];
};

/** Site-wide totals from the nightly snapshot. Any field may be missing. */
export type AboutStats = {
  generatedAt?: string;
  activityWindowDays?: number;
  spotCount?: number;
  countryCount?: number;
  cityCount?: number;
  spotSourceCount?: number;
  spotsWithPhotosCount?: number;
  spotsAdded30d?: number;
  upcomingEventCount?: number;
  eventCountryCount?: number;
  deduplicatedCount?: number;
  ratingCount?: number;
  ratings30d?: number;
  checkIns30d?: number;
  trainingPlans30d?: number;
  improvementSuggestionCount?: number;
  monthlyActiveUsers?: number;
};

export type AboutIndex = {
  generatedAt: string;
  countries: Array<{
    code: string;
    cityCount: number;
    spotCount: number;
    eventCount: number;
  }>;
  eventCount: number;
  stats: AboutStats;
};

export type EventsIndex = {
  generatedAt: string;
  events: EventSummary[];
};
