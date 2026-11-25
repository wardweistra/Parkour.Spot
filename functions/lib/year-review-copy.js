/* eslint-disable max-len */
/**
 * Localized text for the yearly review share card (lib/year-review-card.js).
 *
 * The card is rendered server-side, so its copy lives here rather than in the
 * Flutter ARB files. Count labels match the profile's `profileContributions*`
 * ARB keys; keep the two in sync.
 */

const SUPPORTED_LOCALES = Object.freeze(["en", "de", "nl", "fr", "es", "pt"]);
const SUPPORTED_LOCALE_SET = new Set(SUPPORTED_LOCALES);

/**
 * `one`/`other` pairs per counted kind, plus sentence templates.
 *
 * Lead templates take {name}, {count} (already pluralized with its noun, e.g.
 * "4 spots") and end before the place clause; {places} is appended with the
 * locale's "across"/"in" phrasing.
 */
const STRINGS = {
  en: {
    yearSoFar: "{year} so far",
    labels: {
      spotsAdded: ["spot added", "spots added"],
      spotsImproved: ["spot improved", "spots improved"],
      photosAdded: ["photo added", "photos added"],
      eventsCreated: ["event created", "events created"],
      eventsImproved: ["event improved", "events improved"],
      checkIns: ["check-in", "check-ins"],
      ratings: ["spot rated", "spots rated"],
      lists: ["list shared", "lists shared"],
    },
    nouns: {
      spot: ["spot", "spots"],
      photo: ["photo", "photos"],
      event: ["event", "events"],
    },
    lead: {
      spotsAdded: "In {year} {name} put {count} on the map",
      photosAdded: "In {year} {name} added {count} to the map",
      ratings: "In {year} {name} rated {count}",
      checkIns: "In {year} {name} trained at {count}",
      eventsCreated: "In {year} {name} created {count}",
      mixed: "In {year} {name} shaped {count}",
    },
    placesOne: " in {place}",
    placesMany: " across {places}",
    and: "and",
    caption: {
      spotsAdded: "Added {date}",
      photosAdded: "Photos added {date}",
      spotsImproved: "Improved {date}",
      checkIns: "Trained here {date}",
      ratings: "Rated {date}",
    },
    more: "+{count}",
  },
  de: {
    yearSoFar: "{year} bisher",
    labels: {
      spotsAdded: ["Spot hinzugefügt", "Spots hinzugefügt"],
      spotsImproved: ["Spot verbessert", "Spots verbessert"],
      photosAdded: ["Foto hinzugefügt", "Fotos hinzugefügt"],
      eventsCreated: ["Event erstellt", "Events erstellt"],
      eventsImproved: ["Event verbessert", "Events verbessert"],
      checkIns: ["Check-in", "Check-ins"],
      ratings: ["Spot bewertet", "Spots bewertet"],
      lists: ["Liste geteilt", "Listen geteilt"],
    },
    nouns: {
      spot: ["Spot", "Spots"],
      photo: ["Foto", "Fotos"],
      event: ["Event", "Events"],
    },
    lead: {
      spotsAdded: "{year} hat {name} {count} auf die Karte gebracht",
      photosAdded: "{year} hat {name} {count} zur Karte beigetragen",
      ratings: "{year} hat {name} {count} bewertet",
      checkIns: "{year} hat {name} an {count} trainiert",
      eventsCreated: "{year} hat {name} {count} erstellt",
      mixed: "{year} hat {name} {count} mitgestaltet",
    },
    placesOne: " in {place}",
    placesMany: " in {places}",
    and: "und",
    caption: {
      spotsAdded: "Hinzugefügt am {date}",
      photosAdded: "Fotos hinzugefügt am {date}",
      spotsImproved: "Verbessert am {date}",
      checkIns: "Hier trainiert am {date}",
      ratings: "Bewertet am {date}",
    },
    more: "+{count}",
  },
  nl: {
    yearSoFar: "{year} tot nu toe",
    labels: {
      spotsAdded: ["spot toegevoegd", "spots toegevoegd"],
      spotsImproved: ["spot verbeterd", "spots verbeterd"],
      photosAdded: ["foto toegevoegd", "foto's toegevoegd"],
      eventsCreated: ["event aangemaakt", "events aangemaakt"],
      eventsImproved: ["event verbeterd", "events verbeterd"],
      checkIns: ["check-in", "check-ins"],
      ratings: ["spot beoordeeld", "spots beoordeeld"],
      lists: ["lijst gedeeld", "lijsten gedeeld"],
    },
    nouns: {
      spot: ["spot", "spots"],
      photo: ["foto", "foto's"],
      event: ["event", "events"],
    },
    lead: {
      spotsAdded: "In {year} zette {name} {count} op de kaart",
      photosAdded: "In {year} voegde {name} {count} toe aan de kaart",
      ratings: "In {year} beoordeelde {name} {count}",
      checkIns: "In {year} trainde {name} op {count}",
      eventsCreated: "In {year} maakte {name} {count} aan",
      mixed: "In {year} gaf {name} vorm aan {count}",
    },
    placesOne: " in {place}",
    placesMany: " in {places}",
    and: "en",
    caption: {
      spotsAdded: "Toegevoegd op {date}",
      photosAdded: "Foto's toegevoegd op {date}",
      spotsImproved: "Verbeterd op {date}",
      checkIns: "Hier getraind op {date}",
      ratings: "Beoordeeld op {date}",
    },
    more: "+{count}",
  },
  fr: {
    yearSoFar: "{year} jusqu'ici",
    labels: {
      spotsAdded: ["spot ajouté", "spots ajoutés"],
      spotsImproved: ["spot amélioré", "spots améliorés"],
      photosAdded: ["photo ajoutée", "photos ajoutées"],
      eventsCreated: ["événement créé", "événements créés"],
      eventsImproved: ["événement amélioré", "événements améliorés"],
      checkIns: ["check-in", "check-ins"],
      ratings: ["spot noté", "spots notés"],
      lists: ["liste partagée", "listes partagées"],
    },
    nouns: {
      spot: ["spot", "spots"],
      photo: ["photo", "photos"],
      event: ["événement", "événements"],
    },
    lead: {
      spotsAdded: "En {year}, {name} a mis {count} sur la carte",
      photosAdded: "En {year}, {name} a ajouté {count} à la carte",
      ratings: "En {year}, {name} a noté {count}",
      checkIns: "En {year}, {name} s'est entraîné·e sur {count}",
      eventsCreated: "En {year}, {name} a créé {count}",
      mixed: "En {year}, {name} a façonné {count}",
    },
    placesOne: " à {place}",
    placesMany: " entre {places}",
    and: "et",
    caption: {
      spotsAdded: "Ajouté le {date}",
      photosAdded: "Photos ajoutées le {date}",
      spotsImproved: "Amélioré le {date}",
      checkIns: "Entraînement le {date}",
      ratings: "Noté le {date}",
    },
    more: "+{count}",
  },
  es: {
    yearSoFar: "{year} hasta ahora",
    labels: {
      spotsAdded: ["spot añadido", "spots añadidos"],
      spotsImproved: ["spot mejorado", "spots mejorados"],
      photosAdded: ["foto añadida", "fotos añadidas"],
      eventsCreated: ["evento creado", "eventos creados"],
      eventsImproved: ["evento mejorado", "eventos mejorados"],
      checkIns: ["check-in", "check-ins"],
      ratings: ["spot valorado", "spots valorados"],
      lists: ["lista compartida", "listas compartidas"],
    },
    nouns: {
      spot: ["spot", "spots"],
      photo: ["foto", "fotos"],
      event: ["evento", "eventos"],
    },
    lead: {
      spotsAdded: "En {year}, {name} puso {count} en el mapa",
      photosAdded: "En {year}, {name} añadió {count} al mapa",
      ratings: "En {year}, {name} valoró {count}",
      checkIns: "En {year}, {name} entrenó en {count}",
      eventsCreated: "En {year}, {name} creó {count}",
      mixed: "En {year}, {name} dio forma a {count}",
    },
    placesOne: " en {place}",
    placesMany: " entre {places}",
    and: "y",
    caption: {
      spotsAdded: "Añadido el {date}",
      photosAdded: "Fotos añadidas el {date}",
      spotsImproved: "Mejorado el {date}",
      checkIns: "Entrenó aquí el {date}",
      ratings: "Valorado el {date}",
    },
    more: "+{count}",
  },
  pt: {
    yearSoFar: "{year} até agora",
    labels: {
      spotsAdded: ["spot adicionado", "spots adicionados"],
      spotsImproved: ["spot melhorado", "spots melhorados"],
      photosAdded: ["foto adicionada", "fotos adicionadas"],
      eventsCreated: ["evento criado", "eventos criados"],
      eventsImproved: ["evento melhorado", "eventos melhorados"],
      checkIns: ["check-in", "check-ins"],
      ratings: ["spot avaliado", "spots avaliados"],
      lists: ["lista partilhada", "listas partilhadas"],
    },
    nouns: {
      spot: ["spot", "spots"],
      photo: ["foto", "fotos"],
      event: ["evento", "eventos"],
    },
    lead: {
      spotsAdded: "Em {year}, {name} pôs {count} no mapa",
      photosAdded: "Em {year}, {name} adicionou {count} ao mapa",
      ratings: "Em {year}, {name} avaliou {count}",
      checkIns: "Em {year}, {name} treinou em {count}",
      eventsCreated: "Em {year}, {name} criou {count}",
      mixed: "Em {year}, {name} deu forma a {count}",
    },
    placesOne: " em {place}",
    placesMany: " entre {places}",
    and: "e",
    caption: {
      spotsAdded: "Adicionado a {date}",
      photosAdded: "Fotos adicionadas a {date}",
      spotsImproved: "Melhorado a {date}",
      checkIns: "Treinou aqui a {date}",
      ratings: "Avaliado a {date}",
    },
    more: "+{count}",
  },
};

/** Which noun a lead template counts. */
const LEAD_NOUN = Object.freeze({
  spotsAdded: "spot",
  photosAdded: "photo",
  ratings: "spot",
  checkIns: "spot",
  eventsCreated: "event",
  mixed: "spot",
});

/**
 * @param {unknown} value e.g. "nl", "pt-BR", "de_DE"
 * @return {string} A supported locale, falling back to "en".
 */
function resolveCardLocale(value) {
  if (typeof value !== "string") return "en";
  const base = value.trim().toLowerCase().split(/[-_]/)[0];
  return SUPPORTED_LOCALE_SET.has(base) ? base : "en";
}

/**
 * @param {string} template
 * @param {Object<string, string|number>} values
 * @return {string}
 */
function fill(template, values) {
  return template.replace(/\{(\w+)\}/g, (match, key) =>
    Object.prototype.hasOwnProperty.call(values, key) ? String(values[key]) : match,
  );
}

/**
 * @param {string} locale
 * @param {number} count
 * @param {[string, string]} forms one/other
 * @return {string}
 */
function plural(locale, count, forms) {
  const category = new Intl.PluralRules(locale).select(count);
  return category === "one" ? forms[0] : forms[1];
}

/**
 * Count label after a number, e.g. "spots added".
 * @param {string} locale
 * @param {string} key A `userStats` key.
 * @param {number} count
 * @return {string}
 */
function countLabel(locale, key, count) {
  const forms = STRINGS[locale].labels[key];
  return forms ? plural(locale, count, forms) : key;
}

/**
 * @param {string} locale
 * @param {string[]} items
 * @return {string} "A", "A and B", "A, B and C"
 */
function joinPlaces(locale, items) {
  if (items.length <= 1) return items[0] || "";
  const and = STRINGS[locale].and;
  return `${items.slice(0, -1).join(", ")} ${and} ${items[items.length - 1]}`;
}

/**
 * The lead sentence, split so the count phrase can carry the accent colour.
 * @param {Object} options
 * @param {string} options.locale
 * @param {number} options.year
 * @param {string} options.name
 * @param {string} options.kind A LEAD_NOUN key.
 * @param {number} options.count
 * @param {string[]} options.places Up to three city names.
 * @return {{before: string, emphasis: string, after: string}}
 */
function leadSentence({locale, year, name, kind, count, places}) {
  const copy = STRINGS[locale];
  const template = copy.lead[kind] || copy.lead.mixed;
  const noun = copy.nouns[LEAD_NOUN[kind] || "spot"];
  const emphasis = `${count} ${plural(locale, count, noun)}`;
  let placeClause = "";
  if (places.length === 1) {
    placeClause = fill(copy.placesOne, {place: places[0]});
  } else if (places.length > 1) {
    placeClause = fill(copy.placesMany, {places: joinPlaces(locale, places)});
  }
  const marker = "\u0000";
  const filled = fill(template, {year, name, count: marker});
  const [before, after = ""] = filled.split(marker);
  return {before, emphasis, after: `${after}${placeClause}`};
}

/**
 * @param {string} locale
 * @param {number} year
 * @param {boolean} soFar True until the year is over.
 * @return {string}
 */
function yearLabel(locale, year, soFar) {
  return soFar ? fill(STRINGS[locale].yearSoFar, {year}) : String(year);
}

/**
 * Caption under a single hero photo, e.g. "Added 5 June".
 * @param {string} locale
 * @param {string} kind
 * @param {Date|null} date
 * @return {string}
 */
function heroCaption(locale, kind, date) {
  const template = STRINGS[locale].caption[kind];
  if (!template || !date) return "";
  const formatted = new Intl.DateTimeFormat(locale, {
    day: "numeric",
    month: "long",
    timeZone: "UTC",
  }).format(date);
  return fill(template, {date: formatted});
}

/**
 * @param {string} locale
 * @param {number} count
 * @return {string}
 */
function moreLabel(locale, count) {
  return fill(STRINGS[locale].more, {count});
}

module.exports = {
  SUPPORTED_LOCALES,
  resolveCardLocale,
  countLabel,
  leadSentence,
  yearLabel,
  heroCaption,
  moreLabel,
  joinPlaces,
};
