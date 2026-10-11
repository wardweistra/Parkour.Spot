const {
  renderSeoContentHtml,
  generatePageTypeJsonLd,
  generateHtmlBody,
  generateHtmlPage,
} = require("../html-template");

describe("renderSeoContentHtml", () => {
  it("returns empty when seoContent is missing", () => {
    expect(renderSeoContentHtml(null)).toBe("");
    expect(renderSeoContentHtml({})).toBe("");
  });

  it("renders title, jumpflix links, credit, and skips empty sections", () => {
    const html = renderSeoContentHtml({
      title: "South Bank - Imax 1",
      locationLine: "London, GB",
      description: "Famous walls",
      address: "GV4P+4H London, UK",
      latitude: 51.5,
      longitude: -0.1,
      mapUrl: "https://www.google.com/maps?q=51.5,-0.1",
      rating: {value: 5, count: 3},
      access: "Public",
      features: ["Walls low"],
      goodFor: [],
      facilities: [],
      youtubeVideos: [],
      jumpflixVideos: [{
        title: "Parkour Changed Our Lives",
        url: "https://www.jumpflix.tv/movie/parkour-changed-our-lives",
      }],
      sourceName: "PK London",
      breadcrumbs: [
        {name: "Home", url: "/"},
        {name: "London", url: "/gb/london"},
      ],
    }, "parkour.spot");

    expect(html).toContain("id=\"seo-content\"");
    expect(html).toContain("<h1>South Bank - Imax 1</h1>");
    expect(html).toContain("Famous walls");
    expect(html).toContain("As seen in");
    expect(html).toContain("href=\"https://www.jumpflix.tv/movie/parkour-changed-our-lives\"");
    expect(html).toContain("Parkour Changed Our Lives — watch on Jumpflix");
    expect(html).toContain("Film locations provided by");
    expect(html).toContain("href=\"https://www.jumpflix.tv/\"");
    expect(html).toContain("Source:");
    expect(html).toContain("PK London");
    expect(html).toContain("href=\"https://parkour.spot/gb/london\"");
    expect(html).not.toContain("<h2>Good for</h2>");
    expect(html).not.toContain("<h2>Videos</h2>");
  });

  it("escapes HTML in titles and descriptions", () => {
    const html = renderSeoContentHtml({
      title: "<script>alert(1)</script>",
      description: "A & B",
      features: [],
      goodFor: [],
      facilities: [],
      youtubeVideos: [],
      jumpflixVideos: [],
      breadcrumbs: [],
    });
    expect(html).toContain("&lt;script&gt;");
    expect(html).toContain("A &amp; B");
    expect(html).not.toContain("<script>alert(1)</script>");
  });

  it("omits Jumpflix section when there are no films", () => {
    const html = renderSeoContentHtml({
      title: "Bare spot",
      features: [],
      goodFor: [],
      facilities: [],
      youtubeVideos: [],
      jumpflixVideos: [],
      breadcrumbs: [],
    });
    expect(html).not.toContain("As seen in");
    expect(html).not.toContain("Jumpflix");
  });
});

describe("generatePageTypeJsonLd enrichment", () => {
  it("includes geo, aggregateRating, image, and subjectOf", () => {
    const script = generatePageTypeJsonLd({
      url: "https://parkour.spot/gb/london/abc",
      pageType: "SportsActivityLocation",
      name: "Test spot",
      description: "A spot",
      address: "Somewhere",
      geo: {latitude: 51.5, longitude: -0.1},
      aggregateRating: {ratingValue: 4.5, ratingCount: 10},
      image: "https://example.com/img.jpg",
      subjectOf: [{
        name: "Parkour Changed Our Lives",
        url: "https://www.jumpflix.tv/movie/foo",
        type: "Movie",
      }],
    });
    const json = JSON.parse(script.replace(/<\/?script[^>]*>/g, "").trim());
    expect(json.geo).toEqual({
      "@type": "GeoCoordinates",
      "latitude": 51.5,
      "longitude": -0.1,
    });
    expect(json.aggregateRating.ratingCount).toBe(10);
    expect(json.image).toBe("https://example.com/img.jpg");
    expect(json.subjectOf["@type"]).toBe("Movie");
    expect(json.subjectOf.url).toContain("jumpflix.tv");
  });
});

describe("generateHtmlBody with seoContent", () => {
  it("includes seo article, loading cover, and flutter bootstrap", () => {
    const body = generateHtmlBody({
      url: "https://parkour.spot/gb/london/abc",
      seoContent: {
        title: "Spot",
        features: [],
        goodFor: [],
        facilities: [],
        youtubeVideos: [],
        jumpflixVideos: [],
        breadcrumbs: [],
      },
    });
    expect(body).toContain("id=\"seo-content\"");
    expect(body).toContain("id=\"app-loading-cover\"");
    expect(body).toContain("background: #186584");
    expect(body).toContain("flutter_bootstrap.js");
    expect(body).toContain("dismissSeoShell");
    expect(body).toContain("#app-loading-cover { display: none !important; }");
  });
});

describe("generateHtmlPage spot shell", () => {
  it("keeps OG tags and embeds seo body", () => {
    const html = generateHtmlPage({
      title: "Spot · London, GB - Parkour·Spot",
      description: "Meta description",
      image: "https://example.com/img.jpg",
      url: "https://parkour.spot/gb/london/abc",
      siteName: "Parkour·Spot",
      isDynamic: true,
      pageType: "SportsActivityLocation",
      pageName: "Spot",
      pageDescription: "Meta description",
      pageGeo: {latitude: 1, longitude: 2},
      seoContent: {
        title: "Spot",
        jumpflixVideos: [{
          title: "Film",
          url: "https://www.jumpflix.tv/movie/film",
        }],
        features: [],
        goodFor: [],
        facilities: [],
        youtubeVideos: [],
        breadcrumbs: [],
      },
    });
    expect(html).toContain("og:title");
    expect(html).toContain("id=\"seo-content\"");
    expect(html).toContain("watch on Jumpflix");
    expect(html).toContain("GeoCoordinates");
  });
});

describe("event SEO HTML / JSON-LD", () => {
  it("renders when, website, and linked spots", () => {
    const html = renderSeoContentHtml({
      kind: "event",
      title: "Jam at the Castle",
      whenDisplay: "1 November 2026",
      description: "Bring shoes",
      websiteUrl: "https://example.com/jam",
      linkedSpots: [{title: "Castle Garden", url: "/nl/eindhoven/s1"}],
      features: [],
      goodFor: [],
      facilities: [],
      youtubeVideos: [],
      jumpflixVideos: [],
      breadcrumbs: [{name: "Home", url: "/"}],
    }, "parkour.spot");

    expect(html).toContain("<strong>When:</strong>");
    expect(html).toContain("1 November 2026");
    expect(html).toContain("href=\"https://example.com/jam\"");
    expect(html).toContain("Linked spots");
    expect(html).toContain("href=\"https://parkour.spot/nl/eindhoven/s1\"");
    expect(html).not.toContain("As seen in");
  });

  it("emits Event JSON-LD with startDate and location", () => {
    const script = generatePageTypeJsonLd({
      url: "https://parkour.spot/event/ev1",
      pageType: "Event",
      name: "Jam",
      description: "A jam",
      address: "Kastelenplein 19",
      geo: {latitude: 51.4, longitude: 5.4},
      startDate: "2026-11-01T10:00:00.000Z",
      endDate: "2026-11-01T14:00:00.000Z",
      eventWebsiteUrl: "https://example.com/jam",
      locationName: "Eindhoven, NL",
      image: "https://example.com/e.jpg",
    });
    const json = JSON.parse(script.replace(/<\/?script[^>]*>/g, "").trim());
    expect(json["@type"]).toBe("Event");
    expect(json.startDate).toBe("2026-11-01T10:00:00.000Z");
    expect(json.endDate).toBe("2026-11-01T14:00:00.000Z");
    expect(json.sameAs).toBe("https://example.com/jam");
    expect(json.location["@type"]).toBe("Place");
    expect(json.location.geo.latitude).toBe(51.4);
  });
});
