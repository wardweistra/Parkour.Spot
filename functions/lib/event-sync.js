const ical = require("node-ical");

/**
 * Coerces unknown input into a non-empty trimmed string.
 * @param {*} value
 * @return {string|null}
 */
function toNonEmptyString(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * Normalizes a potentially date-like value.
 * @param {*} value
 * @return {Date|null}
 */
function normalizeDate(value) {
  if (!value) return null;
  if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
  if (typeof value.toDate === "function") {
    const asDate = value.toDate();
    if (asDate instanceof Date && !Number.isNaN(asDate.getTime())) {
      return asDate;
    }
  }
  if (typeof value === "string") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }
  return null;
}

/**
 * Normalizes an iCal recurrence ID so it can be persisted.
 * @param {*} value
 * @return {string|null}
 */
function normalizeRecurrenceId(value) {
  const asDate = normalizeDate(value);
  if (asDate) return asDate.toISOString();
  return toNonEmptyString(value);
}

/**
 * Builds a unique key for one imported external event.
 * @param {string} uid
 * @param {string|null} recurrenceId
 * @return {string}
 */
function buildExternalEventKey(uid, recurrenceId) {
  const normalizedUid = toNonEmptyString(uid);
  if (!normalizedUid) {
    throw new Error("External event UID is required");
  }
  const normalizedRecurrenceId = normalizeRecurrenceId(recurrenceId);
  if (!normalizedRecurrenceId) return normalizedUid;
  return `${normalizedUid}::${normalizedRecurrenceId}`;
}

/**
 * Compares nullable strings while ignoring whitespace and empty-string/null.
 * @param {*} left
 * @param {*} right
 * @return {boolean}
 */
function nullableStringEqual(left, right) {
  const normalizedLeft = toNonEmptyString(left);
  const normalizedRight = toNonEmptyString(right);
  return normalizedLeft === normalizedRight;
}

/**
 * Compares a stored Firestore timestamp-like field against a Date value.
 * @param {*} storedValue
 * @param {Date|null} incomingDate
 * @return {boolean}
 */
function nullableDateEqual(storedValue, incomingDate) {
  const normalizedStoredDate = normalizeDate(storedValue);
  if (!normalizedStoredDate && !incomingDate) return true;
  if (!normalizedStoredDate || !incomingDate) return false;
  return normalizedStoredDate.getTime() === incomingDate.getTime();
}

/**
 * Checks whether a source-sync should update event content fields.
 * @param {Object} existingData
 * @param {Object} incomingData
 * @return {boolean}
 */
function hasExternalEventContentChanges(existingData, incomingData) {
  if (!nullableStringEqual(existingData.title, incomingData.title)) return true;
  if (
    !nullableStringEqual(existingData.description, incomingData.description)
  ) {
    return true;
  }
  if (!nullableStringEqual(existingData.websiteUrl, incomingData.websiteUrl)) {
    return true;
  }
  if (!nullableStringEqual(existingData.address, incomingData.address)) {
    return true;
  }
  if (!nullableDateEqual(existingData.startAt, incomingData.startAt)) {
    return true;
  }
  if (!nullableDateEqual(existingData.endAt, incomingData.endAt)) {
    return true;
  }
  if (
    !nullableStringEqual(existingData.eventSourceId, incomingData.eventSourceId)
  ) {
    return true;
  }
  if (
    !nullableStringEqual(
        existingData.eventSourceName,
        incomingData.eventSourceName,
    )
  ) {
    return true;
  }
  if (
    !nullableStringEqual(
        existingData.externalEventUid,
        incomingData.externalEventUid,
    )
  ) {
    return true;
  }
  if (
    !nullableStringEqual(
        existingData.externalEventRecurrenceId,
        incomingData.externalEventRecurrenceId,
    )
  ) {
    return true;
  }
  if (
    !nullableStringEqual(
        existingData.externalEventKey,
        incomingData.externalEventKey,
    )
  ) {
    return true;
  }
  return false;
}

/**
 * Parses VEVENT records from an ICS file into normalized event payloads.
 * @param {string} icsText
 * @param {Object} sourceMeta
 * @param {string} sourceMeta.sourceId
 * @param {string} sourceMeta.sourceName
 * @return {Array<Object>}
 */
function parseExternalEventsFromIcs(icsText, {sourceId, sourceName}) {
  const parsedCalendar = ical.sync.parseICS(icsText);
  const parsedEvents = [];

  for (const value of Object.values(parsedCalendar)) {
    if (!value || value.type !== "VEVENT") continue;

    const uid = toNonEmptyString(value.uid);
    if (!uid) continue;

    const startAt = normalizeDate(value.start);
    if (!startAt) continue;

    const recurrenceId = normalizeRecurrenceId(value.recurrenceid);
    parsedEvents.push({
      title: toNonEmptyString(value.summary) || "Untitled event",
      description: toNonEmptyString(value.description),
      websiteUrl: toNonEmptyString(value.url),
      address: toNonEmptyString(value.location),
      startAt,
      endAt: normalizeDate(value.end),
      eventSourceId: sourceId,
      eventSourceName: sourceName,
      externalEventUid: uid,
      externalEventRecurrenceId: recurrenceId,
      externalEventKey: buildExternalEventKey(uid, recurrenceId),
    });
  }

  return parsedEvents;
}

module.exports = {
  buildExternalEventKey,
  hasExternalEventContentChanges,
  parseExternalEventsFromIcs,
  normalizeRecurrenceId,
};
