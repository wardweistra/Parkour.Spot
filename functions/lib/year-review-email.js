/* eslint-disable max-len */
/**
 * The yearly review ("Wrapped") email and the unsubscribe page, localized.
 *
 * The sentence and count labels come from year-review-copy.js so the email
 * says exactly what the card says. Public profiles get the square card and a
 * link to their shareable page (opened with ?share so it leads with sharing);
 * private profiles get their numbers and a
 * nudge, since their page and card are not public.
 *
 * HTML is table-based with inline styles: email clients ignore <style> and
 * modern layout.
 */

const {
  resolveCardLocale,
  countLabel,
  formatCount,
  leadSentence,
} = require("./year-review-copy");
const {yearReviewPath} = require("./year-review-request");

const PUBLIC_ORIGIN = "https://parkour.spot";
const SETTINGS_URL = `${PUBLIC_ORIGIN}/profile/settings`;
const ADD_SPOT_URL = `${PUBLIC_ORIGIN}/explore?tab=add`;

/** Signs the email's closing note; replies reach him (lib/brevo.js). */
const SIGNER = "Ward";

/** Parkour·Spot's first full calendar year, named in that year's note. */
const FIRST_FULL_YEAR = 2026;
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
  pageDark: "#0B1012",
  hairline: "#2E383D",
  footer: "#5F6B70",
});

const STRINGS = {
  en: {
    subject: "Your {year} on Parkour·Spot: {count}",
    thanksTitle: "Thank you, {name}",
    thanksTitleNoName: "Thank you",
    thanksBody: "Everything you added in {year} is on a free, open map, so anyone can find a good place to train.",
    shareTitle: "Share your year",
    shareBody: "Post your card to your story, so the people you train with find these spots too and maybe add a few of their own.",
    cta: "Share your card",
    stillTime: "There's still time: add a spot before 31 December and it shows up on your card.",
    addSpot: "Add a spot",
    saveStory: "Save the story image",
    squareLead: "Square version for a post:",
    downloadSquare: "Square (1:1)",
    privateNote: "Your profile is private, so your year has no public page or card. Make your profile public in Settings to get one you can share.",
    privateCta: "Open settings",
    senderName: "Ward from Parkour·Spot",
    letterFirstYear: "{year} was the first full year of Parkour·Spot, a side project I build for our community. Thank you for being part of it and for making it better.",
    letterIntro: "Parkour·Spot is a side project I build for our community. Thank you for being part of it and for making it better.",
    letterReply: "Have feedback, an idea or a question? Just reply to this email. It comes straight to me, and I read every reply.",
    signoff: "See you at the spots,",
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
    subject: "Dein {year} auf Parkour·Spot: {count}",
    thanksTitle: "Danke, {name}",
    thanksTitleNoName: "Danke",
    thanksBody: "Alles, was du {year} beigetragen hast, steht auf einer freien, offenen Karte. So findet jeder einen guten Ort zum Trainieren.",
    shareTitle: "Teile dein Jahr",
    shareBody: "Poste deine Karte in deiner Story, damit die Leute, mit denen du trainierst, diese Spots auch finden und vielleicht selbst ein paar hinzufügen.",
    cta: "Deine Karte teilen",
    stillTime: "Noch ist Zeit: Trag bis zum 31. Dezember einen Spot ein, dann erscheint er auf deiner Karte.",
    addSpot: "Spot hinzufügen",
    saveStory: "Story-Bild speichern",
    squareLead: "Quadratisch für einen Post:",
    downloadSquare: "Quadrat (1:1)",
    privateNote: "Dein Profil ist privat, darum hat dein Jahr keine öffentliche Seite und keine Karte. Mach dein Profil in den Einstellungen öffentlich, um sie teilen zu können.",
    privateCta: "Einstellungen öffnen",
    senderName: "Ward von Parkour·Spot",
    letterFirstYear: "{year} war das erste volle Jahr von Parkour·Spot, einem Nebenprojekt, das ich für unsere Community baue. Danke, dass du dabei bist und es besser machst.",
    letterIntro: "Parkour·Spot ist ein Nebenprojekt, das ich für unsere Community baue. Danke, dass du dabei bist und es besser machst.",
    letterReply: "Hast du Feedback, eine Idee oder eine Frage? Antworte einfach auf diese E-Mail. Sie landet direkt bei mir, und ich lese jede Antwort.",
    signoff: "Bis bald beim Training,",
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
    subject: "Jouw {year} op Parkour·Spot: {count}",
    thanksTitle: "Bedankt, {name}",
    thanksTitleNoName: "Bedankt",
    thanksBody: "Alles wat je in {year} hebt toegevoegd staat op een gratis, open kaart, zodat iedereen een goede plek vindt om te trainen.",
    shareTitle: "Deel je jaar",
    shareBody: "Zet je kaart in je story, zodat de mensen met wie je traint deze spots ook vinden en misschien zelf een paar toevoegen.",
    cta: "Deel je kaart",
    stillTime: "Er is nog tijd: voeg vóór 31 december een spot toe en hij komt op je kaart.",
    addSpot: "Spot toevoegen",
    saveStory: "Story-afbeelding bewaren",
    squareLead: "Vierkant voor een post:",
    downloadSquare: "Vierkant (1:1)",
    privateNote: "Je profiel is privé, dus je jaar heeft geen openbare pagina of kaart. Maak je profiel openbaar in Instellingen om er een te krijgen die je kunt delen.",
    privateCta: "Instellingen openen",
    senderName: "Ward van Parkour·Spot",
    letterFirstYear: "{year} was het eerste volle jaar van Parkour·Spot, een zijproject dat ik voor onze community bouw. Bedankt dat je erbij bent en het beter maakt.",
    letterIntro: "Parkour·Spot is een zijproject dat ik voor onze community bouw. Bedankt dat je erbij bent en het beter maakt.",
    letterReply: "Heb je feedback, een idee of een vraag? Beantwoord gewoon deze e-mail. Hij komt rechtstreeks bij mij binnen en ik lees elke reactie.",
    signoff: "Tot op de spots,",
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
    subject: "Ton année {year} sur Parkour·Spot : {count}",
    thanksTitle: "Merci, {name}",
    thanksTitleNoName: "Merci",
    thanksBody: "Tout ce que tu as ajouté en {year} est sur une carte libre et gratuite, pour que chacun·e trouve un bon endroit où s’entraîner.",
    shareTitle: "Partage ton année",
    shareBody: "Publie ta carte en story : les personnes avec qui tu t’entraînes découvriront ces spots, et en ajouteront peut-être quelques-uns.",
    cta: "Partager ta carte",
    stillTime: "Il reste du temps : ajoute un spot avant le 31 décembre et il apparaîtra sur ta carte.",
    addSpot: "Ajouter un spot",
    saveStory: "Enregistrer l’image story",
    squareLead: "Version carrée pour un post :",
    downloadSquare: "Carré (1:1)",
    privateNote: "Ton profil est privé : ton année n’a donc ni page publique ni carte. Rends ton profil public dans les Réglages pour en avoir une à partager.",
    privateCta: "Ouvrir les réglages",
    senderName: "Ward de Parkour·Spot",
    letterFirstYear: "{year} était la première année complète de Parkour·Spot, un projet perso que je construis pour notre communauté. Merci d’en faire partie et de l’améliorer.",
    letterIntro: "Parkour·Spot est un projet perso que je construis pour notre communauté. Merci d’en faire partie et de l’améliorer.",
    letterReply: "Un retour, une idée ou une question ? Réponds simplement à cet e-mail. Il m’arrive directement, et je lis chaque réponse.",
    signoff: "À bientôt sur les spots,",
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
    subject: "Tu {year} en Parkour·Spot: {count}",
    thanksTitle: "Gracias, {name}",
    thanksTitleNoName: "Gracias",
    thanksBody: "Todo lo que añadiste en {year} está en un mapa abierto y gratuito, para que cualquiera encuentre un buen lugar para entrenar.",
    shareTitle: "Comparte tu año",
    shareBody: "Publica tu tarjeta en tu historia para que la gente con la que entrenas descubra estos spots, y quizá añada algunos.",
    cta: "Compartir tu tarjeta",
    stillTime: "Aún hay tiempo: añade un spot antes del 31 de diciembre y saldrá en tu tarjeta.",
    addSpot: "Añadir un spot",
    saveStory: "Guardar la imagen de historia",
    squareLead: "Versión cuadrada para una publicación:",
    downloadSquare: "Cuadrada (1:1)",
    privateNote: "Tu perfil es privado, así que tu año no tiene página ni tarjeta públicas. Haz público tu perfil en Ajustes para tener una que puedas compartir.",
    privateCta: "Abrir ajustes",
    senderName: "Ward de Parkour·Spot",
    letterFirstYear: "{year} fue el primer año completo de Parkour·Spot, un proyecto personal que construyo para nuestra comunidad. Gracias por formar parte de él y por hacerlo mejor.",
    letterIntro: "Parkour·Spot es un proyecto personal que construyo para nuestra comunidad. Gracias por formar parte de él y por hacerlo mejor.",
    letterReply: "¿Tienes comentarios, una idea o una pregunta? Responde a este correo. Me llega directamente y leo cada respuesta.",
    signoff: "Nos vemos en los spots,",
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
    subject: "O teu {year} no Parkour·Spot: {count}",
    thanksTitle: "Obrigado, {name}",
    thanksTitleNoName: "Obrigado",
    thanksBody: "Tudo o que adicionaste em {year} está num mapa aberto e gratuito, para que qualquer pessoa encontre um bom sítio para treinar.",
    shareTitle: "Partilha o teu ano",
    shareBody: "Publica o teu cartão na tua story para que as pessoas com quem treinas descubram estes spots, e talvez adicionem alguns.",
    cta: "Partilhar o teu cartão",
    stillTime: "Ainda vais a tempo: adiciona um spot até 31 de dezembro e ele aparece no teu cartão.",
    addSpot: "Adicionar um spot",
    saveStory: "Guardar a imagem da story",
    squareLead: "Versão quadrada para uma publicação:",
    downloadSquare: "Quadrado (1:1)",
    privateNote: "O teu perfil é privado, por isso o teu ano não tem página nem cartão públicos. Torna o teu perfil público nas Definições para teres um que possas partilhar.",
    privateCta: "Abrir definições",
    senderName: "Ward do Parkour·Spot",
    letterFirstYear: "{year} foi o primeiro ano completo do Parkour·Spot, um projeto paralelo que construo para a nossa comunidade. Obrigado por fazeres parte dele e por o tornares melhor.",
    letterIntro: "O Parkour·Spot é um projeto paralelo que construo para a nossa comunidade. Obrigado por fazeres parte dele e por o tornares melhor.",
    letterReply: "Tens feedback, uma ideia ou uma pergunta? Responde a este e-mail. Chega diretamente a mim e leio todas as respostas.",
    signoff: "Vemo-nos nos spots,",
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
 * @param {{outlined: (boolean|undefined)}=} options
 * @return {string}
 */
function buttonHtml(href, label, {outlined = false} = {}) {
  // Padding sits on the cell, so Outlook (which ignores padding on links)
  // still draws a full-size button.
  const fill = outlined ? COLORS.ground : COLORS.button;
  const ink = outlined ? COLORS.accent : COLORS.buttonInk;
  const border = outlined ? `border:2px solid ${COLORS.accent};` : "";
  return `<table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr><td bgcolor="${fill}" style="border-radius:999px;background:${fill};${border}padding:14px 26px;mso-padding-alt:14px 26px">` +
    `<a href="${escapeHtml(href)}" style="display:inline-block;font-family:${FONT};font-size:16px;font-weight:700;line-height:20px;color:${ink};text-decoration:none">${escapeHtml(label)}</a>` +
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
 * @return {{subject: string, html: string, text: string, locale: string, senderName: string}}
 */
function buildYearReviewEmail(data, {locale: rawLocale, unsubscribeUrl, now = new Date(), cacheKey = ""}) {
  const locale = resolveCardLocale(rawLocale);
  const s = STRINGS[locale];
  const soFar = now.getTime() < Date.UTC(data.year + 1, 0, 1);
  const sentenceOptions = {
    locale,
    year: data.year,
    name: data.name || "",
    kind: data.lead.kind,
    count: data.lead.count,
    places: data.places || [],
  };
  const plain = ({before, emphasis, after}) => `${before}${emphasis}${after}`.replace(/\s+/g, " ").trim();
  // The card speaks about its owner; the email speaks to them.
  const cardSentence = leadSentence(sentenceOptions);
  const sentence = leadSentence({...sentenceOptions, person: "second"});
  const sentenceText = plain(sentence);
  const subject = fill(s.subject, {year: data.year, count: sentence.emphasis});
  const name = (data.name || "").trim();
  const thanksTitle = name ? fill(s.thanksTitle, {name}) : s.thanksTitleNoName;
  const thanksBody = fill(s.thanksBody, {year: data.year});
  const counts = (data.counts || []).map(({key, count}) => ({count: formatCount(locale, count), label: countLabel(locale, key, count)}));

  const pageUrl = `${PUBLIC_ORIGIN}${yearReviewPath(data)}`;
  // ?share leads the page with the share buttons: the owner usually opens
  // this in a mail app's browser where they are signed out.
  const shareUrl = `${pageUrl}?share=1`;
  const cardQuery = `?locale=${locale}${cacheKey ? `&v=${encodeURIComponent(cacheKey)}` : ""}`;
  const cardUrl = `${PUBLIC_ORIGIN}${yearReviewPath(data, "square.jpg")}${cardQuery}`;
  const storyUrl = `${PUBLIC_ORIGIN}${yearReviewPath(data, "story.jpg")}${cardQuery}`;
  const isPublic = data.isPublicProfile !== false;

  const p = (text, {size = 15, color = COLORS.muted, pad = "0 28px"} = {}) =>
    `<tr><td style="padding:${pad};font-family:${FONT};font-size:${size}px;line-height:1.5;color:${color}">${text}</td></tr>`;
  const heading = (text, {size, pad}) =>
    `<tr><td style="padding:${pad}"><h${size > 24 ? 1 : 2} style="margin:0;font-family:${FONT};font-size:${size}px;font-weight:700;line-height:1.25;color:${COLORS.ink}">${text}</h${size > 24 ? 1 : 2}></td></tr>`;
  const link = (href, label) =>
    `<a href="${escapeHtml(href)}" style="color:${COLORS.accent};font-weight:700;text-decoration:underline;white-space:nowrap">${escapeHtml(label)}</a>`;

  // Thanks first: the email exists to say it.
  const thanksHtml =
    heading(escapeHtml(thanksTitle), {size: 28, pad: "24px 28px 0"}) +
    p(escapeHtml(thanksBody), {size: 16, pad: "8px 28px 0"});

  let bodyHtml;
  if (isPublic) {
    // The card carries the sentence and the counts (and the sentence as its
    // alt text), so the email adds no stat panel of its own.
    bodyHtml =
      `<tr><td style="padding:24px 28px 0"><a href="${escapeHtml(shareUrl)}"><img src="${escapeHtml(cardUrl)}" width="484" alt="${escapeHtml(plain(cardSentence))}" style="display:block;width:100%;max-width:484px;height:auto;border:0;border-radius:16px;font-family:${FONT};font-size:15px;color:${COLORS.muted}"></a></td></tr>` +
      heading(escapeHtml(s.shareTitle), {size: 20, pad: "32px 28px 0"}) +
      p(escapeHtml(s.shareBody), {pad: "6px 28px 0"}) +
      `<tr><td style="padding:16px 28px 0">${buttonHtml(shareUrl, s.cta)}</td></tr>` +
      `<tr><td style="padding:12px 28px 0">${buttonHtml(storyUrl, s.saveStory, {outlined: true})}</td></tr>` +
      p(`${escapeHtml(s.squareLead)} ${link(cardUrl, s.downloadSquare)}`, {size: 14, pad: "14px 28px 0"});
  } else {
    const countCells = counts.map(({count, label}) =>
      `<td valign="top" style="padding:12px 8px;text-align:center;font-family:${FONT}">` +
      `<div style="font-size:28px;font-weight:700;color:${COLORS.ink};line-height:1.1">${escapeHtml(count)}</div>` +
      `<div style="font-size:13px;color:${COLORS.muted};line-height:1.3;padding-top:4px">${escapeHtml(label)}</div></td>`,
    ).join("");
    const countsHtml = countCells ?
      `<tr><td style="padding:16px 20px 0"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:${COLORS.panel};border-radius:16px"><tr>${countCells}</tr></table></td></tr>` :
      "";
    // No card for private profiles: the sentence and counts stand in for it.
    bodyHtml =
      `<tr><td style="padding:24px 28px 0;font-family:${FONT};font-size:20px;font-weight:700;line-height:1.3;color:${COLORS.ink}">${escapeHtml(sentence.before)}<span style="color:${COLORS.accent}">${escapeHtml(sentence.emphasis)}</span>${escapeHtml(sentence.after)}</td></tr>` +
      countsHtml +
      p(escapeHtml(s.privateNote), {pad: "24px 28px 0"}) +
      `<tr><td style="padding:16px 28px 0">${buttonHtml(SETTINGS_URL, s.privateCta)}</td></tr>`;
  }

  // In December the year is still open: invite one more spot.
  const stillTimeHtml = soFar ?
    `<tr><td style="padding:28px 28px 0"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-top:1px solid ${COLORS.hairline}"><tr><td style="padding-top:20px;font-family:${FONT};font-size:15px;line-height:1.5;color:${COLORS.muted}">${escapeHtml(s.stillTime)} ${link(ADD_SPOT_URL, s.addSpot)}</td></tr></table></td></tr>` :
    "";

  // A personal note closes the email: who makes this, and that replies
  // reach a person.
  const letterIntro = data.year === FIRST_FULL_YEAR ?
    fill(s.letterFirstYear, {year: data.year}) :
    s.letterIntro;
  const letterHtml =
    p(escapeHtml(letterIntro), {pad: "28px 28px 0"}) +
    p(escapeHtml(s.letterReply), {pad: "12px 28px 0"}) +
    p(`${escapeHtml(s.signoff)}<br><strong style="font-weight:700;color:${COLORS.ink}">${escapeHtml(SIGNER)}</strong>`, {pad: "20px 28px 28px"});

  // Zero-width padding keeps clients from pulling body text into the
  // inbox preview after the preheader.
  const preheaderPad = "&#847;&zwnj;&nbsp;".repeat(60);
  const html = `<!doctype html>
<html lang="${locale}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="dark light"><meta name="supported-color-schemes" content="dark light">${FONT_LINK}<title>${escapeHtml(subject)}</title>
<style>@media (prefers-color-scheme:dark){.yr-page{background:${COLORS.pageDark}!important}.yr-footer{color:${COLORS.muted}!important}.yr-footer a{color:${COLORS.muted}!important}}</style></head>
<body class="yr-page" style="margin:0;padding:0;background:${COLORS.page}">
<div style="display:none;mso-hide:all;max-height:0;overflow:hidden;opacity:0">${escapeHtml(`${thanksTitle}. ${sentenceText}.`)}${preheaderPad}</div>
<table class="yr-page" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="${COLORS.page}" style="background:${COLORS.page}"><tr><td align="center" style="padding:24px 12px">
<table role="presentation" width="540" cellpadding="0" cellspacing="0" border="0" bgcolor="${COLORS.ground}" style="width:100%;max-width:540px;background:${COLORS.ground};border-radius:24px">
<tr><td style="padding:28px 28px 0"><img src="${LOGO_URL}" width="40" height="40" alt="Parkour·Spot" style="display:block;border:0;border-radius:10px"></td></tr>
${thanksHtml}
${bodyHtml}
${stillTimeHtml}
${letterHtml}
</table>
<table role="presentation" width="540" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:540px"><tr><td class="yr-footer" style="padding:20px 28px;font-family:${FONT};font-size:13px;line-height:1.6;color:${COLORS.footer};text-align:center">
${escapeHtml(s.footer)}<br>
<a href="${escapeHtml(unsubscribeUrl)}" style="color:${COLORS.footer};text-decoration:underline">${escapeHtml(s.unsubscribe)}</a> · <a href="${SETTINGS_URL}" style="color:${COLORS.footer};text-decoration:underline">${escapeHtml(s.settings)}</a>
</td></tr></table>
</td></tr></table>
</body></html>`;

  const text = [
    thanksTitle,
    thanksBody,
    "",
    `${sentenceText}.`,
    "",
    ...counts.map(({count, label}) => `${count} ${label}`),
    "",
    ...(isPublic ?
      [s.shareTitle, s.shareBody, `${s.cta}: ${shareUrl}`, `${s.saveStory}: ${storyUrl}`, `${s.downloadSquare}: ${cardUrl}`] :
      [s.privateNote, `${s.privateCta}: ${SETTINGS_URL}`]),
    ...(soFar ? ["", `${s.stillTime} ${ADD_SPOT_URL}`] : []),
    "",
    letterIntro,
    "",
    s.letterReply,
    "",
    s.signoff,
    SIGNER,
    "",
    "--",
    s.footer,
    `${s.unsubscribe}: ${unsubscribeUrl}`,
    `${s.settings}: ${SETTINGS_URL}`,
  ].join("\n");

  return {subject, html, text, locale, senderName: s.senderName};
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
