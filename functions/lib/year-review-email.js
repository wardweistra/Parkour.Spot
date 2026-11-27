/* eslint-disable max-len */
/**
 * The yearly review ("Wrapped") email and the unsubscribe page, localized.
 *
 * The sentence and count labels come from year-review-copy.js so the email
 * says exactly what the card says. Public profiles get the square card and a
 * link to their shareable page; private profiles get their numbers and a
 * nudge, since their page and card are not public.
 *
 * HTML is table-based with inline styles: email clients ignore <style> and
 * modern layout.
 */

const {
  resolveCardLocale,
  countLabel,
  leadSentence,
  yearLabel,
} = require("./year-review-copy");
const {yearReviewPath} = require("./year-review-request");

const PUBLIC_ORIGIN = "https://parkour.spot";
const SETTINGS_URL = `${PUBLIC_ORIGIN}/profile/settings`;
const LOGO_URL = `${PUBLIC_ORIGIN}/icons/Icon-192.png`;

/**
 * Brand face (DESIGN.md) where the client loads web fonts (Apple Mail, iOS);
 * Gmail and Outlook fall back to system sans.
 */
const FONT = "Fredoka,system-ui,-apple-system,'Segoe UI',Arial,sans-serif";
const FONT_LINK = "<link href=\"https://fonts.googleapis.com/css2?family=Fredoka:wght@400;600;700&display=swap\" rel=\"stylesheet\">";

const COLORS = Object.freeze({
  ground: "#13191C",
  panel: "#1C2428",
  ink: "#FFFFFF",
  muted: "#B8C0C4",
  accent: "#8ECFF2",
  button: "#8ECFF2",
  buttonInk: "#13191C",
  page: "#EEF1F2",
  footer: "#5F6B70",
});

const STRINGS = {
  en: {
    subject: "Your {year} on Parkour·Spot",
    heading: "Your {year} on Parkour·Spot",
    cta: "See and share your year",
    privateNote: "Your profile is private, so your year has no public page or card. Make your profile public in Settings to get one you can share.",
    privateCta: "Open settings",
    thanks: "Thanks for helping everyone find better places to train.",
    footer: "You get this email because you have a Parkour·Spot account.",
    unsubscribe: "Unsubscribe from newsletter emails",
    settings: "Email settings",
    pageTitle: "Unsubscribe",
    pageConfirm: "Stop newsletter emails, like your yearly review, from Parkour·Spot?",
    pageButton: "Unsubscribe",
    pageDone: "You are unsubscribed from newsletter emails. You can turn them back on in Settings.",
    pageInvalid: "This unsubscribe link is not valid. You can change your email settings in the app.",
    pageOpenApp: "Open Parkour·Spot",
  },
  de: {
    subject: "Dein {year} auf Parkour·Spot",
    heading: "Dein {year} auf Parkour·Spot",
    cta: "Dein Jahr ansehen und teilen",
    privateNote: "Dein Profil ist privat, darum hat dein Jahr keine öffentliche Seite und keine Karte. Mach dein Profil in den Einstellungen öffentlich, um sie teilen zu können.",
    privateCta: "Einstellungen öffnen",
    thanks: "Danke, dass du allen hilfst, bessere Trainingsorte zu finden.",
    footer: "Du bekommst diese E-Mail, weil du ein Parkour·Spot-Konto hast.",
    unsubscribe: "Newsletter-E-Mails abbestellen",
    settings: "E-Mail-Einstellungen",
    pageTitle: "Abbestellen",
    pageConfirm: "Keine Newsletter-E-Mails wie deinen Jahresrückblick mehr von Parkour·Spot bekommen?",
    pageButton: "Abbestellen",
    pageDone: "Du hast die Newsletter-E-Mails abbestellt. In den Einstellungen kannst du sie wieder einschalten.",
    pageInvalid: "Dieser Abbestell-Link ist ungültig. Deine E-Mail-Einstellungen kannst du in der App ändern.",
    pageOpenApp: "Parkour·Spot öffnen",
  },
  nl: {
    subject: "Jouw {year} op Parkour·Spot",
    heading: "Jouw {year} op Parkour·Spot",
    cta: "Bekijk en deel je jaar",
    privateNote: "Je profiel is privé, dus je jaar heeft geen openbare pagina of kaart. Maak je profiel openbaar in Instellingen om er een te krijgen die je kunt delen.",
    privateCta: "Instellingen openen",
    thanks: "Bedankt dat je iedereen helpt betere plekken te vinden om te trainen.",
    footer: "Je krijgt deze e-mail omdat je een Parkour·Spot-account hebt.",
    unsubscribe: "Afmelden voor nieuwsbrief-e-mails",
    settings: "E-mailinstellingen",
    pageTitle: "Afmelden",
    pageConfirm: "Geen nieuwsbrief-e-mails meer van Parkour·Spot, zoals je jaaroverzicht?",
    pageButton: "Afmelden",
    pageDone: "Je bent afgemeld voor nieuwsbrief-e-mails. Je kunt ze weer aanzetten in Instellingen.",
    pageInvalid: "Deze afmeldlink is niet geldig. Je kunt je e-mailinstellingen in de app aanpassen.",
    pageOpenApp: "Parkour·Spot openen",
  },
  fr: {
    subject: "Ton année {year} sur Parkour·Spot",
    heading: "Ton année {year} sur Parkour·Spot",
    cta: "Voir et partager ton année",
    privateNote: "Ton profil est privé : ton année n’a donc ni page publique ni carte. Rends ton profil public dans les Réglages pour en avoir une à partager.",
    privateCta: "Ouvrir les réglages",
    thanks: "Merci d’aider tout le monde à trouver de meilleurs lieux d’entraînement.",
    footer: "Tu reçois cet e-mail parce que tu as un compte Parkour·Spot.",
    unsubscribe: "Se désabonner des e-mails d’actualité",
    settings: "Réglages e-mail",
    pageTitle: "Désabonnement",
    pageConfirm: "Ne plus recevoir d’e-mails d’actualité de Parkour·Spot, comme ton bilan de l’année ?",
    pageButton: "Se désabonner",
    pageDone: "Tu es désabonné·e des e-mails d’actualité. Tu peux les réactiver dans les Réglages.",
    pageInvalid: "Ce lien de désabonnement n’est pas valide. Tu peux modifier tes réglages e-mail dans l’app.",
    pageOpenApp: "Ouvrir Parkour·Spot",
  },
  es: {
    subject: "Tu {year} en Parkour·Spot",
    heading: "Tu {year} en Parkour·Spot",
    cta: "Mira y comparte tu año",
    privateNote: "Tu perfil es privado, así que tu año no tiene página ni tarjeta públicas. Haz público tu perfil en Ajustes para tener una que puedas compartir.",
    privateCta: "Abrir ajustes",
    thanks: "Gracias por ayudar a todos a encontrar mejores lugares para entrenar.",
    footer: "Recibes este correo porque tienes una cuenta de Parkour·Spot.",
    unsubscribe: "Darse de baja de los correos informativos",
    settings: "Ajustes de correo",
    pageTitle: "Darse de baja",
    pageConfirm: "¿Dejar de recibir correos informativos de Parkour·Spot, como tu resumen del año?",
    pageButton: "Darse de baja",
    pageDone: "Te has dado de baja de los correos informativos. Puedes volver a activarlos en Ajustes.",
    pageInvalid: "Este enlace para darse de baja no es válido. Puedes cambiar tus ajustes de correo en la app.",
    pageOpenApp: "Abrir Parkour·Spot",
  },
  pt: {
    subject: "O teu {year} no Parkour·Spot",
    heading: "O teu {year} no Parkour·Spot",
    cta: "Vê e partilha o teu ano",
    privateNote: "O teu perfil é privado, por isso o teu ano não tem página nem cartão públicos. Torna o teu perfil público nas Definições para teres um que possas partilhar.",
    privateCta: "Abrir definições",
    thanks: "Obrigado por ajudares todos a encontrar melhores sítios para treinar.",
    footer: "Recebes este e-mail porque tens uma conta Parkour·Spot.",
    unsubscribe: "Cancelar e-mails informativos",
    settings: "Definições de e-mail",
    pageTitle: "Cancelar subscrição",
    pageConfirm: "Deixar de receber e-mails informativos do Parkour·Spot, como o resumo do teu ano?",
    pageButton: "Cancelar subscrição",
    pageDone: "Cancelaste os e-mails informativos. Podes voltar a ativá-los nas Definições.",
    pageInvalid: "Este link para cancelar não é válido. Podes alterar as definições de e-mail na app.",
    pageOpenApp: "Abrir Parkour·Spot",
  },
};

/**
 * @param {string} template
 * @param {Object<string, (string|number)>} values
 * @return {string}
 */
function fill(template, values) {
  return template.replace(/\{(\w+)\}/g, (match, key) =>
    Object.prototype.hasOwnProperty.call(values, key) ? String(values[key]) : match);
}

/**
 * @param {unknown} value
 * @return {string}
 */
function escapeHtml(value) {
  return String(value == null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
}

/**
 * @param {string} locale A supported locale.
 * @return {Object<string, string>}
 */
function emailStrings(locale) {
  return STRINGS[resolveCardLocale(locale)];
}

/**
 * @param {string} href
 * @param {string} label
 * @return {string}
 */
function buttonHtml(href, label) {
  return `<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:8px 0 0"><tr><td style="border-radius:999px;background:${COLORS.button}">` +
    `<a href="${escapeHtml(href)}" style="display:inline-block;padding:14px 26px;font-family:${FONT};font-size:16px;font-weight:700;color:${COLORS.buttonInk};text-decoration:none;border-radius:999px">${escapeHtml(label)}</a>` +
    "</td></tr></table>";
}

/**
 * Subject, HTML and plain text for one person's yearly review email.
 *
 * @param {Object} data From buildYearReviewDataForUser.
 * @param {Object} options
 * @param {string} options.locale
 * @param {string} options.unsubscribeUrl
 * @param {Date=} options.now
 * @param {string=} options.cacheKey Appended to the card URL so mail-proxy
 *     caches pick up this send's numbers, not an earlier render.
 * @return {{subject: string, html: string, text: string, locale: string}}
 */
function buildYearReviewEmail(data, {locale: rawLocale, unsubscribeUrl, now = new Date(), cacheKey = ""}) {
  const locale = resolveCardLocale(rawLocale);
  const s = STRINGS[locale];
  const soFar = now.getTime() < Date.UTC(data.year + 1, 0, 1);
  const sentence = leadSentence({
    locale,
    year: data.year,
    name: data.name || "",
    kind: data.lead.kind,
    count: data.lead.count,
    places: data.places || [],
  });
  const sentenceText = `${sentence.before}${sentence.emphasis}${sentence.after}`.replace(/\s+/g, " ").trim();
  const subject = fill(s.subject, {year: data.year});
  const heading = fill(s.heading, {year: yearLabel(locale, data.year, soFar)});
  const counts = (data.counts || []).map(({key, count}) => ({count, label: countLabel(locale, key, count)}));

  const pageUrl = `${PUBLIC_ORIGIN}${yearReviewPath(data)}`;
  const cardUrl = `${PUBLIC_ORIGIN}${yearReviewPath(data, "square.jpg")}` +
    `?locale=${locale}${cacheKey ? `&v=${encodeURIComponent(cacheKey)}` : ""}`;
  const isPublic = data.isPublicProfile !== false;
  const ctaUrl = isPublic ? pageUrl : SETTINGS_URL;
  const ctaLabel = isPublic ? s.cta : s.privateCta;

  const countCells = counts.map(({count, label}) =>
    `<td valign="top" style="padding:12px 8px;text-align:center;font-family:${FONT}">` +
    `<div style="font-size:28px;font-weight:700;color:${COLORS.accent};line-height:1.1">${escapeHtml(count)}</div>` +
    `<div style="font-size:13px;color:${COLORS.muted};line-height:1.3;padding-top:4px">${escapeHtml(label)}</div></td>`,
  ).join("");

  // The card prints the sentence itself (and carries it as alt text), so
  // only private profiles, who get no card, get it as a headline.
  const headlineHtml = `<tr><td style="padding:10px 28px 16px;font-family:${FONT};font-size:26px;font-weight:700;line-height:1.25;color:${COLORS.ink}">${escapeHtml(sentence.before)}<span style="color:${COLORS.accent}">${escapeHtml(sentence.emphasis)}</span>${escapeHtml(sentence.after)}</td></tr>`;
  const cardHtml = isPublic ?
    `<tr><td style="padding:8px 28px 0"><a href="${escapeHtml(pageUrl)}"><img src="${escapeHtml(cardUrl)}" width="484" alt="${escapeHtml(sentenceText)}" style="display:block;width:100%;max-width:484px;height:auto;border:0;border-radius:16px;font-family:${FONT};font-size:15px;color:${COLORS.muted}"></a></td></tr>` :
    `<tr><td style="padding:8px 28px 0;font-family:${FONT};font-size:15px;line-height:1.5;color:${COLORS.muted}">${escapeHtml(s.privateNote)}</td></tr>`;

  const html = `<!doctype html>
<html lang="${locale}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="dark light">${FONT_LINK}<title>${escapeHtml(subject)}</title></head>
<body style="margin:0;padding:0;background:${COLORS.page}">
<div style="display:none;max-height:0;overflow:hidden;opacity:0">${escapeHtml(sentenceText)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:${COLORS.page}"><tr><td align="center" style="padding:24px 12px">
<table role="presentation" width="540" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:540px;background:${COLORS.ground};border-radius:24px">
<tr><td style="padding:28px 28px 0"><img src="${LOGO_URL}" width="40" height="40" alt="Parkour·Spot" style="display:block;border:0;border-radius:10px"></td></tr>
<tr><td style="padding:20px 28px 0;font-family:${FONT};font-size:14px;font-weight:700;letter-spacing:0.04em;text-transform:uppercase;color:${COLORS.muted}">${escapeHtml(heading)}</td></tr>
${isPublic ? "" : headlineHtml}
${cardHtml}
${countCells ? `<tr><td style="padding:16px 20px 0"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:${COLORS.panel};border-radius:16px"><tr>${countCells}</tr></table></td></tr>` : ""}
<tr><td style="padding:20px 28px 0">${buttonHtml(ctaUrl, ctaLabel)}</td></tr>
<tr><td style="padding:20px 28px 28px;font-family:${FONT};font-size:15px;line-height:1.5;color:${COLORS.muted}">${escapeHtml(s.thanks)}</td></tr>
</table>
<table role="presentation" width="540" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:540px"><tr><td style="padding:20px 28px;font-family:${FONT};font-size:12px;line-height:1.6;color:${COLORS.footer};text-align:center">
${escapeHtml(s.footer)}<br>
<a href="${escapeHtml(unsubscribeUrl)}" style="color:${COLORS.footer};text-decoration:underline">${escapeHtml(s.unsubscribe)}</a> · <a href="${SETTINGS_URL}" style="color:${COLORS.footer};text-decoration:underline">${escapeHtml(s.settings)}</a>
</td></tr></table>
</td></tr></table>
</body></html>`;

  const text = [
    heading,
    "",
    sentenceText,
    "",
    ...counts.map(({count, label}) => `${count} ${label}`),
    "",
    isPublic ? `${s.cta}: ${pageUrl}` : `${s.privateNote}\n${s.privateCta}: ${SETTINGS_URL}`,
    "",
    s.thanks,
    "",
    "--",
    s.footer,
    `${s.unsubscribe}: ${unsubscribeUrl}`,
    `${s.settings}: ${SETTINGS_URL}`,
  ].join("\n");

  return {subject, html, text, locale};
}

/**
 * The unsubscribe landing page. `state` is "confirm" (a form that POSTs back
 * to the same URL: link scanners follow GET links, so GET never unsubscribes),
 * "done" or "invalid".
 * @param {Object} options
 * @param {string} options.locale
 * @param {string} options.state
 * @param {string=} options.actionUrl Same URL with its query, for the form.
 * @return {string}
 */
function unsubscribePageHtml({locale: rawLocale, state, actionUrl = ""}) {
  const locale = resolveCardLocale(rawLocale);
  const s = STRINGS[locale];
  let body;
  if (state === "confirm") {
    body = `<p>${escapeHtml(s.pageConfirm)}</p>` +
      `<form method="post" action="${escapeHtml(actionUrl)}"><button type="submit">${escapeHtml(s.pageButton)}</button></form>`;
  } else if (state === "done") {
    body = `<p>${escapeHtml(s.pageDone)}</p><p><a href="${SETTINGS_URL}">${escapeHtml(s.settings)}</a></p>`;
  } else {
    body = `<p>${escapeHtml(s.pageInvalid)}</p><p><a href="${PUBLIC_ORIGIN}">${escapeHtml(s.pageOpenApp)}</a></p>`;
  }
  return `<!doctype html>
<html lang="${locale}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex">${FONT_LINK}<title>${escapeHtml(s.pageTitle)} · Parkour·Spot</title>
<style>
:root{color-scheme:light dark;--bg:#EEF1F2;--card:#FFFFFF;--ink:#13191C;--muted:#4A565B;--accent:#186584;--accent-ink:#FFFFFF}
@media (prefers-color-scheme:dark){:root{--bg:#13191C;--card:#1C2428;--ink:#FFFFFF;--muted:#B8C0C4;--accent:#8ECFF2;--accent-ink:#13191C}}
body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:var(--bg);color:var(--ink);font:16px/1.5 ${FONT};padding:16px;box-sizing:border-box}
main{background:var(--card);border-radius:20px;padding:28px;max-width:440px;width:100%;box-sizing:border-box}
img{display:block;border-radius:10px;margin-bottom:16px}
p{margin:0 0 16px;color:var(--muted)}p:first-of-type{color:var(--ink);font-size:18px}
button{font:inherit;font-weight:700;border:0;border-radius:999px;padding:12px 24px;background:var(--accent);color:var(--accent-ink);cursor:pointer}
a{color:var(--accent)}
</style></head>
<body><main><img src="${LOGO_URL}" width="40" height="40" alt="Parkour·Spot">${body}</main></body></html>`;
}

module.exports = {
  EMAIL_STRINGS: STRINGS,
  SETTINGS_URL,
  escapeHtml,
  emailStrings,
  buildYearReviewEmail,
  unsubscribePageHtml,
};
