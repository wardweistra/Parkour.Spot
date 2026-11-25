/* eslint-disable max-len */
/**
 * Yearly review share card: a contact sheet of the spots someone shaped that
 * year, one sentence naming the count and cities, and their counts.
 *
 * Direction (see .impeccable/surfaces/year-in-review.md): dark Community Atlas
 * ground, real spot photos in numbered frames, Fredoka 600 lead sentence with
 * the key figure in light teal. One spot becomes a single full-bleed hero
 * frame; many become a grid, with a "+N" tile past the last frame.
 *
 * Rendering: satori lays out the tree into SVG with text as outlines (no
 * system fonts needed), sharp rasterizes it to PNG.
 */

const fs = require("fs");
const path = require("path");
const sharp = require("sharp");
const {
  countLabel,
  leadSentence,
  yearLabel,
  heroCaption,
  moreLabel,
} = require("./year-review-copy");
let satoriRenderer = null;

/**
 * satori/wasm with the asm.js build of Yoga, initialised on first use: no
 * dynamic import() of the wasm binary and no cold-start fetch. Lazy so the
 * layout helpers stay importable where ES-module requires are unavailable
 * (Jest); Node 22 itself loads the ES-module Yoga build via require().
 * @return {Function} satori
 */
function getSatori() {
  if (!satoriRenderer) {
    const {default: satori, init} = require("satori/wasm");
    const initYoga = require("yoga-wasm-web/asm");
    init((initYoga.default || initYoga)());
    satoriRenderer = satori;
  }
  return satoriRenderer;
}

const FORMATS = Object.freeze({
  story: {width: 1080, height: 1920, padding: 64, maxCells: 9},
  square: {width: 1080, height: 1080, padding: 56, maxCells: 6},
});

const COLORS = Object.freeze({
  ground: "#13191C",
  ink: "#FFFFFF",
  muted: "rgba(255,255,255,0.72)",
  faint: "rgba(255,255,255,0.56)",
  hairline: "rgba(255,255,255,0.18)",
  accent: "#8ECFF2",
  moreTile: "#186584",
  frameFallback: "#24313A",
  tab: "rgba(19,25,28,0.72)",
});

const FRAME_GAP = 12;
const IMAGE_FETCH_TIMEOUT_MS = 8000;

/**
 * Rows of frame cells, top to bottom, for [count] cells (1..9). Uneven rows
 * keep a small sheet from reading as a sparse grid.
 * @param {number} count
 * @return {number[]}
 */
function frameRows(count) {
  const layouts = {
    1: [1],
    2: [2],
    3: [1, 2],
    4: [2, 2],
    5: [2, 3],
    6: [3, 3],
    7: [2, 2, 3],
    8: [3, 2, 3],
    9: [3, 3, 3],
  };
  return layouts[Math.max(1, Math.min(9, count))];
}

/**
 * Cells for one format: up to `maxCells`, the last becoming a "+N" tile when
 * more spots have photos than fit.
 * @param {Array<Object>} frames Frames with images, priority order.
 * @param {number} moreCount Spots with images beyond [frames].
 * @param {number} maxCells
 * @return {{photos: Array<Object>, more: number}}
 */
function planCells(frames, moreCount, maxCells) {
  const total = frames.length + moreCount;
  if (total <= maxCells) return {photos: frames.slice(0, maxCells), more: 0};
  const photos = frames.slice(0, maxCells - 1);
  return {photos, more: total - photos.length};
}

/**
 * Pixel boxes for each cell inside a field of [width] x [height].
 * @param {number} cellCount
 * @param {number} width
 * @param {number} height
 * @return {Array<{width: number, height: number, row: number}>}
 */
function cellBoxes(cellCount, width, height) {
  const rows = frameRows(cellCount);
  const rowHeight = Math.floor((height - FRAME_GAP * (rows.length - 1)) / rows.length);
  const boxes = [];
  rows.forEach((columns, row) => {
    const cellWidth = Math.floor((width - FRAME_GAP * (columns - 1)) / columns);
    for (let i = 0; i < columns; i++) boxes.push({width: cellWidth, height: rowHeight, row});
  });
  return boxes;
}

let fontCache = null;

/**
 * Fredoka (latin + latin-ext) at the weights the card uses.
 * @return {Array<Object>} satori font entries
 */
function loadFonts() {
  if (fontCache) return fontCache;
  const dir = path.dirname(require.resolve("@fontsource/fredoka/package.json"));
  fontCache = [];
  for (const weight of [400, 500, 600]) {
    for (const subset of ["latin", "latin-ext"]) {
      fontCache.push({
        name: "Fredoka",
        weight,
        style: "normal",
        data: fs.readFileSync(path.join(dir, "files", `fredoka-${subset}-${weight}-normal.woff`)),
      });
    }
  }
  return fontCache;
}

let wordmarkCache = null;

/**
 * @return {string} Data URI of the light-on-dark Parkour·Spot wordmark.
 */
function wordmarkDataUri() {
  if (!wordmarkCache) {
    const svg = fs.readFileSync(path.join(__dirname, "..", "assets", "brand", "logo-with-text-dark.svg"));
    wordmarkCache = `data:image/svg+xml;base64,${svg.toString("base64")}`;
  }
  return wordmarkCache;
}

/** Noto families for scripts Fredoka does not cover, by satori language code. */
const FALLBACK_FAMILIES = Object.freeze({
  "ko-KR": "Noto Sans KR",
  "ja-JP": "Noto Sans JP",
  "zh-CN": "Noto Sans SC",
  "zh-TW": "Noto Sans TC",
  "zh-HK": "Noto Sans HK",
  "th-TH": "Noto Sans Thai",
  "ar-AR": "Noto Sans Arabic",
  "he-IL": "Noto Sans Hebrew",
  "devanagari": "Noto Sans Devanagari",
  "bn-IN": "Noto Sans Bengali",
  "ta-IN": "Noto Sans Tamil",
});

/**
 * Fetches a Google Fonts subset containing exactly [text] (TrueType, which
 * satori reads). Spot and city names in other scripts still render.
 * @param {string} family
 * @param {string} text
 * @return {Promise<Buffer|null>}
 */
async function fetchFontSubset(family, text) {
  const cssUrl = `https://fonts.googleapis.com/css2?family=${encodeURIComponent(family)}:wght@600&text=${encodeURIComponent(text)}`;
  // An old user agent makes Google Fonts serve TrueType instead of WOFF2.
  const css = await (await fetch(cssUrl, {
    headers: {"User-Agent": "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/534.30 (KHTML, like Gecko) Safari/534.30"},
    signal: AbortSignal.timeout(IMAGE_FETCH_TIMEOUT_MS),
  })).text();
  const match = css.match(/src: url\((.+?)\) format\('(opentype|truetype)'\)/);
  if (!match) return null;
  const font = await fetch(match[1], {signal: AbortSignal.timeout(IMAGE_FETCH_TIMEOUT_MS)});
  return font.ok ? Buffer.from(await font.arrayBuffer()) : null;
}

/**
 * satori `loadAdditionalAsset`: fonts for non-Latin scripts; emoji dropped.
 * @param {string} code
 * @param {string} segment
 * @return {Promise<Array<Object>|string>}
 */
async function loadAdditionalAsset(code, segment) {
  if (code === "emoji") return "";
  const family = FALLBACK_FAMILIES[code] || "Noto Sans";
  try {
    const data = await fetchFontSubset(family, segment);
    return data ? [{name: family, data, weight: 600, style: "normal"}] : [];
  } catch (error) {
    console.warn("year review fallback font failed", {code, error: error && error.message});
    return [];
  }
}

/**
 * Downloads an image and crops it to the exact frame size.
 * @param {string} url
 * @param {number} width
 * @param {number} height
 * @param {function(string): Promise<Buffer>=} fetchImage Test hook.
 * @return {Promise<string|null>} JPEG data URI, or null on failure.
 */
async function frameImageDataUri(url, width, height, fetchImage) {
  try {
    let buffer;
    if (fetchImage) {
      buffer = await fetchImage(url);
    } else {
      const response = await fetch(url, {signal: AbortSignal.timeout(IMAGE_FETCH_TIMEOUT_MS)});
      if (!response.ok) return null;
      buffer = Buffer.from(await response.arrayBuffer());
    }
    const jpeg = await sharp(buffer)
        .rotate()
        .resize(width, height, {fit: "cover", position: "attention"})
        .jpeg({quality: 82, mozjpeg: true})
        .toBuffer();
    return `data:image/jpeg;base64,${jpeg.toString("base64")}`;
  } catch (error) {
    console.warn("year review frame image failed", {url, error: error && error.message});
    return null;
  }
}

/**
 * Minimal element factory for satori's React-like tree.
 * @param {string} type
 * @param {Object} style
 * @param {*} children
 * @param {Object=} props
 * @return {Object}
 */
function h(type, style, children, props = {}) {
  return {type, props: {...props, style, children}};
}

/**
 * @param {Object} options
 * @return {Object} satori element
 */
function topBar({yearText, scale}) {
  return h("div", {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    height: 72 * scale,
  }, [
    h("img", {height: 52 * scale, width: Math.round(52 * scale * 2773 / 646)}, null, {src: wordmarkDataUri()}),
    h("div", {
      display: "flex",
      fontSize: 34 * scale,
      fontWeight: 500,
      color: COLORS.muted,
    }, yearText),
  ]);
}

/**
 * @param {Object} options
 * @return {Object} satori element
 */
function frameCell({box, imageUri, number, showTab}) {
  const radius = 16;
  const children = [];
  if (imageUri) {
    children.push(h("img", {position: "absolute", left: 0, top: 0, width: box.width, height: box.height}, null, {src: imageUri}));
  }
  if (showTab) {
    children.push(h("div", {
      position: "absolute",
      left: 14,
      bottom: 14,
      display: "flex",
      padding: "4px 12px",
      borderRadius: 8,
      backgroundColor: COLORS.tab,
      color: COLORS.ink,
      fontSize: 24,
      fontWeight: 600,
    }, String(number).padStart(2, "0")));
  }
  return h("div", {
    display: "flex",
    position: "relative",
    width: box.width,
    height: box.height,
    borderRadius: radius,
    overflow: "hidden",
    backgroundColor: COLORS.frameFallback,
  }, children);
}

/**
 * @param {Object} options
 * @return {Object} satori element
 */
function moreCell({box, label}) {
  return h("div", {
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    width: box.width,
    height: box.height,
    borderRadius: 16,
    backgroundColor: COLORS.moreTile,
    color: COLORS.ink,
    fontSize: Math.min(96, Math.round(box.height * 0.32)),
    fontWeight: 600,
  }, label);
}

/**
 * A single spot as the whole field, with its name and when it was touched.
 * @param {Object} options
 * @return {Object} satori element
 */
function heroFrame({width, height, imageUri, frame, caption}) {
  return h("div", {
    display: "flex",
    position: "relative",
    width,
    height,
    borderRadius: 24,
    overflow: "hidden",
    backgroundColor: COLORS.frameFallback,
  }, [
    imageUri ?
      h("img", {position: "absolute", left: 0, top: 0, width, height}, null, {src: imageUri}) :
      null,
    h("div", {
      position: "absolute",
      left: 0,
      right: 0,
      bottom: 0,
      display: "flex",
      flexDirection: "column",
      padding: "120px 40px 36px",
      backgroundImage: "linear-gradient(to bottom, rgba(19,25,28,0), rgba(19,25,28,0.82))",
    }, [
      h("div", {display: "flex", fontSize: 60, fontWeight: 600, color: COLORS.ink, lineHeight: 1.1}, frame.name),
      h("div", {display: "flex", marginTop: 10, fontSize: 32, fontWeight: 500, color: COLORS.muted}, [frame.city, caption].filter(Boolean).join(" · ")),
    ]),
  ].filter(Boolean));
}

/**
 * The lead sentence; the count phrase carries the accent colour.
 * @param {Object} options
 * @return {Object} satori element
 */
function leadBlock({sentence, fontSize}) {
  const words = (text, color) => text.split(/(\s+)/).filter((part) => part && !/^\s+$/.test(part))
      .map((word) => h("span", {color, marginRight: "0.26em"}, word));
  // The count phrase ("1 spot") never breaks across lines.
  const emphasis = sentence.emphasis ?
    [h("span", {color: COLORS.accent, marginRight: "0.26em", whiteSpace: "nowrap"}, sentence.emphasis)] :
    [];
  return h("div", {
    display: "flex",
    flexWrap: "wrap",
    fontSize,
    fontWeight: 600,
    lineHeight: 1.15,
    color: COLORS.ink,
  }, [
    ...words(sentence.before, COLORS.ink),
    ...emphasis,
    ...words(sentence.after, COLORS.ink),
  ]);
}

/**
 * @param {Object} options
 * @return {Object} satori element
 */
function countsRow({counts, locale}) {
  // Equal columns on one line; long labels (de, pt) wrap inside their column
  // instead of pushing the last count onto a second row.
  return h("div", {
    display: "flex",
    borderTop: `2px solid ${COLORS.hairline}`,
    paddingTop: 28,
  }, counts.map(({key, count}) => h("div", {
    display: "flex",
    flexDirection: "column",
    flexGrow: 1,
    flexBasis: 0,
    paddingRight: 20,
  }, [
    h("div", {display: "flex", fontSize: 64, fontWeight: 600, color: COLORS.ink, lineHeight: 1.05}, String(count)),
    h("div", {display: "flex", fontSize: 28, fontWeight: 500, color: COLORS.muted, marginTop: 4, lineHeight: 1.2}, countLabel(locale, key, count)),
  ])));
}

/**
 * True when the only count says what the lead sentence already says
 * ("put 1 spot on the map" over "1 spot added").
 * @param {Array<{key: string, count: number}>} counts
 * @param {{kind: string, count: number}} lead
 * @return {boolean}
 */
function countsRepeatLead(counts, lead) {
  return counts.length === 1 &&
    counts[0].key === lead.kind &&
    counts[0].count === lead.count;
}

/**
 * Public link printed on the card: the review page for people with a
 * username, the site otherwise.
 * @param {Object} data
 * @return {string}
 */
function cardUrl(data) {
  // A raw user id is noise on a story, where the link is not tappable anyway.
  if (!data.username) return "parkour.spot";
  return `parkour.spot/year/${data.year}/@${data.username}`;
}

/**
 * Builds the satori tree and fetches frame images.
 * @param {Object} data From buildYearReviewData.
 * @param {Object} options
 * @param {"story"|"square"} options.format
 * @param {string} options.locale
 * @param {Date=} options.now
 * @param {function(string): Promise<Buffer>=} options.fetchImage Test hook.
 * @return {Promise<Object>} satori element
 */
async function buildCardTree(data, {format, locale, now = new Date(), fetchImage}) {
  const spec = FORMATS[format] || FORMATS.story;
  const {width, height, padding} = spec;
  const innerWidth = width - padding * 2;
  const soFar = now.getTime() < Date.UTC(data.year + 1, 0, 1);
  const sentence = leadSentence({
    locale,
    year: data.year,
    name: data.name,
    kind: data.lead.kind,
    count: data.lead.count,
    places: data.places,
  });

  const {photos, more} = planCells(data.frames, data.moreCount, spec.maxCells);
  const isStory = format !== "square";
  const fieldHeight = photos.length === 0 ? 0 : (isStory ? (photos.length === 1 ? 1120 : 1040) : 560);

  let field = null;
  if (photos.length === 1 && more === 0) {
    const frame = photos[0];
    const imageUri = await frameImageDataUri(frame.imageUrl, innerWidth, fieldHeight, fetchImage);
    field = heroFrame({
      width: innerWidth,
      height: fieldHeight,
      imageUri,
      frame,
      caption: isStory ? heroCaption(locale, frame.kind, frame.date) : "",
    });
  } else if (photos.length > 0) {
    const cellCount = photos.length + (more > 0 ? 1 : 0);
    const boxes = cellBoxes(cellCount, innerWidth, fieldHeight);
    const imageUris = await Promise.all(photos.map((frame, i) =>
      frameImageDataUri(frame.imageUrl, boxes[i].width, boxes[i].height, fetchImage)));
    const cells = boxes.map((box, i) => (i < photos.length ?
      frameCell({box, imageUri: imageUris[i], number: i + 1, showTab: isStory}) :
      moreCell({box, label: moreLabel(locale, more)})));
    const rows = [];
    for (const [i, box] of boxes.entries()) {
      if (!rows[box.row]) rows[box.row] = [];
      rows[box.row].push(cells[i]);
    }
    field = h("div", {display: "flex", flexDirection: "column", width: innerWidth, height: fieldHeight},
        rows.map((row, i) => h("div", {
          display: "flex",
          justifyContent: "space-between",
          marginTop: i === 0 ? 0 : FRAME_GAP,
        }, row)));
  }

  const leadSize = photos.length === 0 ? (isStory ? 104 : 80) : (isStory ? 68 : 52);
  const showCounts = isStory && !countsRepeatLead(data.counts, data.lead);
  const scale = isStory ? 1 : 0.9;
  return h("div", {
    display: "flex",
    flexDirection: "column",
    width,
    height,
    padding,
    backgroundColor: COLORS.ground,
    fontFamily: "Fredoka",
    color: COLORS.ink,
  }, [
    topBar({yearText: yearLabel(locale, data.year, soFar), scale}),
    field ? h("div", {display: "flex", marginTop: isStory ? 40 : 32}, field) : null,
    h("div", {
      display: "flex",
      flexDirection: "column",
      flexGrow: 1,
      marginTop: field ? (isStory ? 48 : 32) : 0,
    }, [
      // Without photos the sentence is the card: centre it in the space.
      field ? null : h("div", {display: "flex", flexGrow: 1}, null),
      leadBlock({sentence, fontSize: leadSize}),
      h("div", {display: "flex", flexGrow: 1}, null),
      showCounts ? countsRow({counts: data.counts, locale}) : null,
      h("div", {
        display: "flex",
        marginTop: isStory ? 28 : 0,
        fontSize: isStory ? 30 : 28,
        fontWeight: 500,
        color: COLORS.faint,
      }, cardUrl(data)),
    ].filter(Boolean)),
  ].filter(Boolean));
}

/**
 * Renders the card to PNG.
 * @param {Object} data From buildYearReviewData.
 * @param {Object} options See buildCardTree.
 * @return {Promise<Buffer>}
 */
async function renderYearReviewCard(data, options) {
  const spec = FORMATS[options.format] || FORMATS.story;
  const tree = await buildCardTree(data, options);
  const svg = await getSatori()(tree, {
    width: spec.width,
    height: spec.height,
    fonts: loadFonts(),
    loadAdditionalAsset,
  });
  return sharp(Buffer.from(svg)).png({compressionLevel: 9}).toBuffer();
}

module.exports = {
  FORMATS,
  frameRows,
  planCells,
  cellBoxes,
  cardUrl,
  countsRepeatLead,
  buildCardTree,
  renderYearReviewCard,
};
