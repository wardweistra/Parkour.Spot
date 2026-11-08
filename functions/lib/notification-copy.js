/* eslint-disable max-len */
/**
 * Server-side push title/body. Inbox stays client-localized via ARB;
 * FCM must render strings at send time.
 *
 * Keep in sync with l10n/app_*.arb keys:
 *   notificationNearbyNewSpotTitle / Body
 *   notificationNearbyCheckInTitle / Body
 *   notificationNearbyTrainingPlanTitle / Body
 *   notificationNearbyNewEventTitle / Body
 *   notificationTrainingPlanCheckInReminderTitle / Body
 *   notificationsActorSomeone, notificationsSpotUntitled, notificationsEventUntitled
 *   notificationsListUntitled
 *   notificationSpotListInviteTitle / Body
 *   notificationSpotListInviteAcceptedTitle / Body
 */

const SUPPORTED_LOCALES = Object.freeze(["en", "de", "nl", "fr", "es", "pt"]);
const SUPPORTED_LOCALE_SET = new Set(SUPPORTED_LOCALES);

const STRINGS = {
  en: {
    actorSomeone: "Someone",
    spotUntitled: "Untitled spot",
    eventUntitled: "Untitled event",
    listUntitled: "Untitled list",
    nearby_new_spot: {
      title: "New spot nearby: {spotName}",
      body: "{actorName} added a new parkour spot near one of your saved locations.",
    },
    nearby_check_in: {
      title: "{actorName} is training now at {spotName}",
      body: "They’ve just checked in to this spot.",
    },
    nearby_training_plan: {
      title: "{actorName} planned a session at {spotName}",
      body: "They shared a public planned session near one of your saved locations.",
    },
    nearby_new_event: {
      title: "New event nearby: {eventName}",
      body: "An event was added near one of your saved locations.",
    },
    training_plan_check_in_reminder: {
      title: "Time to check in at {spotName}",
      body: "Your planned session has started. Tap to check in.",
    },
    spot_list_invite: {
      title: "{actorName} invited you to {listName}",
      body: "Accept to get access, or decline to dismiss the invite.",
    },
    spot_list_invite_accepted: {
      title: "{actorName} accepted your invite",
      body: "They can now access {listName}.",
    },
  },
  de: {
    actorSomeone: "Jemand",
    spotUntitled: "Unbenannter Spot",
    eventUntitled: "Unbenanntes Event",
    listUntitled: "Unbenannte Liste",
    nearby_new_spot: {
      title: "Neuer Spot in der Nähe: {spotName}",
      body: "{actorName} hat einen neuen Parkour-Spot in der Nähe eines deiner gespeicherten Orte hinzugefügt.",
    },
    nearby_check_in: {
      title: "{actorName} trainiert gerade bei {spotName}",
      body: "Gerade an diesem Spot eingecheckt.",
    },
    nearby_training_plan: {
      title: "{actorName} hat eine Session bei {spotName} geplant",
      body: "Öffentliche geplante Session in der Nähe eines deiner gespeicherten Orte.",
    },
    nearby_new_event: {
      title: "Neues Event in der Nähe: {eventName}",
      body: "Ein Event wurde in der Nähe eines deiner gespeicherten Orte hinzugefügt.",
    },
    training_plan_check_in_reminder: {
      title: "Zeit für Check-in bei {spotName}",
      body: "Deine geplante Session hat begonnen. Tippe zum Einchecken.",
    },
    spot_list_invite: {
      title: "{actorName} hat dich zu {listName} eingeladen",
      body: "Annehmen für Zugang, oder ablehnen zum Verwerfen.",
    },
    spot_list_invite_accepted: {
      title: "{actorName} hat deine Einladung angenommen",
      body: "Sie können jetzt auf {listName} zugreifen.",
    },
  },
  nl: {
    actorSomeone: "Iemand",
    spotUntitled: "Spot zonder naam",
    eventUntitled: "Evenement zonder naam",
    listUntitled: "Lijst zonder naam",
    nearby_new_spot: {
      title: "Nieuwe spot in de buurt: {spotName}",
      body: "{actorName} heeft een nieuwe parkourspot toegevoegd nabij een van je opgeslagen locaties.",
    },
    nearby_check_in: {
      title: "{actorName} traint nu bij {spotName}",
      body: "Net ingecheckt bij deze spot.",
    },
    nearby_training_plan: {
      title: "{actorName} plant een sessie bij {spotName}",
      body: "Ze deelden een openbare geplande sessie nabij een van je opgeslagen locaties.",
    },
    nearby_new_event: {
      title: "Nieuw evenement in de buurt: {eventName}",
      body: "Er is een evenement toegevoegd nabij een van je opgeslagen locaties.",
    },
    training_plan_check_in_reminder: {
      title: "Tijd om in te checken bij {spotName}",
      body: "Je geplande sessie is begonnen. Tik om in te checken.",
    },
    spot_list_invite: {
      title: "{actorName} heeft je uitgenodigd voor {listName}",
      body: "Accepteer voor toegang, of weiger om de uitnodiging te sluiten.",
    },
    spot_list_invite_accepted: {
      title: "{actorName} heeft je uitnodiging geaccepteerd",
      body: "Ze hebben nu toegang tot {listName}.",
    },
  },
  fr: {
    actorSomeone: "Quelqu’un",
    spotUntitled: "Spot sans titre",
    eventUntitled: "Événement sans titre",
    listUntitled: "Liste sans titre",
    nearby_new_spot: {
      title: "Nouveau spot à proximité : {spotName}",
      body: "{actorName} a ajouté un nouveau spot de parkour près d’un de vos lieux enregistrés.",
    },
    nearby_check_in: {
      title: "{actorName} s’entraîne maintenant à {spotName}",
      body: "Vient de s’enregistrer sur ce spot.",
    },
    nearby_training_plan: {
      title: "{actorName} a planifié une séance à {spotName}",
      body: "Une séance planifiée publique a été partagée près de l’un de vos lieux enregistrés.",
    },
    nearby_new_event: {
      title: "Nouvel événement à proximité : {eventName}",
      body: "Un événement a été ajouté près de l’un de vos lieux enregistrés.",
    },
    training_plan_check_in_reminder: {
      title: "C’est l’heure du check-in à {spotName}",
      body: "Votre séance prévue a commencé. Touchez pour vous enregistrer.",
    },
    spot_list_invite: {
      title: "{actorName} vous a invité à {listName}",
      body: "Acceptez pour obtenir l’accès, ou refusez pour ignorer l’invitation.",
    },
    spot_list_invite_accepted: {
      title: "{actorName} a accepté votre invitation",
      body: "Ils peuvent maintenant accéder à {listName}.",
    },
  },
  es: {
    actorSomeone: "Alguien",
    spotUntitled: "Spot sin título",
    eventUntitled: "Evento sin título",
    listUntitled: "Lista sin título",
    nearby_new_spot: {
      title: "Nuevo spot cerca: {spotName}",
      body: "{actorName} ha añadido un nuevo spot de parkour cerca de uno de tus lugares guardados.",
    },
    nearby_check_in: {
      title: "{actorName} está entrenando ahora en {spotName}",
      body: "Acaba de hacer check-in en este spot.",
    },
    nearby_training_plan: {
      title: "{actorName} ha planeado una sesión en {spotName}",
      body: "Han compartido una sesión planificada pública cerca de uno de tus lugares guardados.",
    },
    nearby_new_event: {
      title: "Evento nuevo cerca: {eventName}",
      body: "Se añadió un evento cerca de uno de tus lugares guardados.",
    },
    training_plan_check_in_reminder: {
      title: "Hora de hacer check-in en {spotName}",
      body: "Tu sesión planificada ya ha empezado. Toca para hacer check-in.",
    },
    spot_list_invite: {
      title: "{actorName} te invitó a {listName}",
      body: "Acepta para obtener acceso, o rechaza para descartar la invitación.",
    },
    spot_list_invite_accepted: {
      title: "{actorName} aceptó tu invitación",
      body: "Ya pueden acceder a {listName}.",
    },
  },
  pt: {
    actorSomeone: "Alguém",
    spotUntitled: "Spot sem nome",
    eventUntitled: "Evento sem nome",
    listUntitled: "Lista sem nome",
    nearby_new_spot: {
      title: "Novo spot por perto: {spotName}",
      body: "{actorName} adicionou um novo spot de parkour perto de um dos teus locais guardados.",
    },
    nearby_check_in: {
      title: "{actorName} está a treinar agora em {spotName}",
      body: "Acabou de fazer check-in neste spot.",
    },
    nearby_training_plan: {
      title: "{actorName} planeou uma sessão em {spotName}",
      body: "Partilharam uma sessão planeada pública perto de uma das suas localizações guardadas.",
    },
    nearby_new_event: {
      title: "Novo evento nas proximidades: {eventName}",
      body: "Foi adicionado um evento perto de uma das tuas localizações guardadas.",
    },
    training_plan_check_in_reminder: {
      title: "Hora de fazer check-in em {spotName}",
      body: "A tua sessão planeada já começou. Toca para fazer check-in.",
    },
    spot_list_invite: {
      title: "{actorName} convidou-te para {listName}",
      body: "Aceita para obter acesso, ou recusa para dispensar o convite.",
    },
    spot_list_invite_accepted: {
      title: "{actorName} aceitou o teu convite",
      body: "Já podem aceder a {listName}.",
    },
  },
};

/**
 * @param {string} template
 * @param {Object<string, string>} vars
 * @return {string}
 */
function interpolate(template, vars) {
  return template.replace(/\{(\w+)\}/g, (match, key) => {
    if (Object.prototype.hasOwnProperty.call(vars, key)) {
      return vars[key];
    }
    return match;
  });
}

/**
 * @param {*} raw
 * @return {string|null} en|de|nl|fr|es|pt or null
 */
function normalizeLocale(raw) {
  if (typeof raw !== "string") {
    return null;
  }
  const code = raw.trim().toLowerCase().split(/[-_]/)[0];
  if (SUPPORTED_LOCALE_SET.has(code)) {
    return code;
  }
  return null;
}

/**
 * Subscription locale first, then the user's preferred language, then English.
 * @param {*} subscriptionLocale
 * @param {*} preferredLanguageCode
 * @return {string}
 */
function resolvePushLocale(subscriptionLocale, preferredLanguageCode) {
  return normalizeLocale(subscriptionLocale) ||
      normalizeLocale(preferredLanguageCode) ||
      "en";
}

/**
 * @param {*} raw
 * @param {string} fallback
 * @return {string}
 */
function labelOrFallback(raw, fallback) {
  if (typeof raw !== "string") {
    return fallback;
  }
  const trimmed = raw.trim();
  return trimmed || fallback;
}

/**
 * @param {object} options
 * @param {string} options.notificationKind
 * @param {object} [options.templateArgs]
 * @param {string} options.locale already-resolved locale code
 * @return {{title: string, body: string}}
 */
function localizedNotificationCopy({
  notificationKind,
  templateArgs,
  locale,
}) {
  const pack = STRINGS[locale] || STRINGS.en;
  const kindCopy = pack[notificationKind] || STRINGS.en[notificationKind];
  if (!kindCopy) {
    return {title: "ParkourSpot", body: ""};
  }
  const args = templateArgs || {};
  const vars = {
    actorName: labelOrFallback(args.actorName, pack.actorSomeone),
    spotName: labelOrFallback(args.spotName, pack.spotUntitled),
    eventName: labelOrFallback(args.eventName, pack.eventUntitled),
    listName: labelOrFallback(args.listName, pack.listUntitled),
  };
  return {
    title: interpolate(kindCopy.title, vars),
    body: interpolate(kindCopy.body, vars),
  };
}

module.exports = {
  SUPPORTED_LOCALES,
  normalizeLocale,
  resolvePushLocale,
  localizedNotificationCopy,
};
