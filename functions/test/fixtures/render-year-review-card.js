// Renders a year review card with synthetic data and prints its PNG metadata.
// Used by test/year-review.test.js in a child process (see the note there).
const sharp = require("sharp");
const {renderYearReviewCard} = require("../../lib/year-review-card");

const options = JSON.parse(process.argv[2] || "{}");
const photo = () => sharp({
  create: {
    width: 64,
    height: 48,
    channels: 3,
    background: {r: 120, g: 140, b: 160},
  },
}).png().toBuffer();
const data = {
  userId: "u1",
  year: 2026,
  name: "Noor",
  username: "noor",
  counts: [{key: "spotsAdded", count: 3}, {key: "ratings", count: 5}],
  lead: {kind: "mixed", count: 6},
  places: ["Utrecht"],
  frames: [1, 2, 3].map((i) => ({
    spotId: `s${i}`,
    kind: "spotsAdded",
    name: `Spot ${i}`,
    city: "Utrecht",
    imageUrl: `img${i}`,
  })),
  moreCount: 3,
};

(async () => {
  console.warn = () => {};
  const png = await renderYearReviewCard(data, {
    format: options.format,
    locale: options.locale,
    now: new Date("2026-12-02"),
    fetchImage: options.failImages ?
      async () => {
        throw new Error("offline");
      } :
      photo,
  });
  const {format, width, height} = await sharp(png).metadata();
  process.stdout.write(JSON.stringify({format, width, height}));
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
