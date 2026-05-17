// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get tabExplore => 'Entdecken';

  @override
  String get tabAddSpot => 'Spot hinzufügen';

  @override
  String get tabAccount => 'Konto';

  @override
  String get profileSettingsTitle => 'Einstellungen';

  @override
  String get profileSettingsSubtitle =>
      'Sprache und Orte, die dir wichtig sind';

  @override
  String get profileSettingsLanguageLabel => 'Sprache';

  @override
  String get profileSettingsLanguageDescription =>
      'Sprache wählen oder Geräteeinstellung verwenden.';

  @override
  String get profileLanguageSystemDefault =>
      'Automatisch (Englisch, wenn nicht unterstützt)';

  @override
  String get profileLoadErrorDefault => 'Profil konnte nicht geladen werden.';

  @override
  String get profileRefreshPage => 'Seite neu laden';

  @override
  String get profileRetry => 'Erneut versuchen';

  @override
  String get profileSignInTitle =>
      'Melde dich an, um auf dein Konto zuzugreifen';

  @override
  String get profileSignInSubtitle =>
      'Melde dich an, um deine Spots zu verwalten und Orte zu bewerten.';

  @override
  String get profileSignInButton => 'Anmelden';

  @override
  String get profileOrDivider => 'ODER';

  @override
  String get profileCreateAccount => 'Konto erstellen';

  @override
  String get profileDefaultDisplayName => 'Nutzer';

  @override
  String get profileViewEditSubtitle => 'Profil ansehen und bearbeiten';

  @override
  String get notificationsTitle => 'Benachrichtigungen';

  @override
  String get notificationsSubtitle =>
      'Neue Spots in der Nähe, Trainingspläne, Check-ins und andere Updates für dich';

  @override
  String get notificationsEmptyTitle => 'Hier ist noch nichts los';

  @override
  String get notificationsEmptyBody =>
      'Wenn in der Nähe ein neuer Spot dazukommt, jemand Training plant oder dort eincheckt, wo du trainierst, siehst du es hier.';

  @override
  String get notificationsLoadError =>
      'Benachrichtigungen konnten nicht geladen werden. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get notificationsRetry => 'Erneut versuchen';

  @override
  String get notificationsOpenFailedSnackbar =>
      'Diese Benachrichtigung konnte nicht geöffnet werden. Bitte später erneut versuchen.';

  @override
  String get notificationsMarkAllRead => 'Alle als gelesen markieren';

  @override
  String get notificationsMarkAllReadFailed =>
      'Alle konnten nicht als gelesen markiert werden. Bitte erneut versuchen.';

  @override
  String get notificationsMarkAsReadFailed =>
      'Konnte nicht als gelesen markieren. Bitte erneut versuchen.';

  @override
  String get notificationsMarkAsUnreadFailed =>
      'Konnte nicht als ungelesen markieren. Bitte erneut versuchen.';

  @override
  String get notificationsMarkAsUnreadHint =>
      'Lange drücken, um als ungelesen zu markieren';

  @override
  String get notificationsMarkAsReadHint =>
      'Lange drücken, um als gelesen zu markieren';

  @override
  String get notificationsShowAll => 'Alle anzeigen';

  @override
  String get notificationsUnreadOnly => 'Nur ungelesen';

  @override
  String get notificationsEmptyFilteredTitle => 'Alles gelesen';

  @override
  String get notificationsEmptyFilteredBody =>
      'Zurzeit keine ungelesenen Benachrichtigungen.';

  @override
  String get notificationsTimeUnknown => 'Kürzlich';

  @override
  String notificationsOpenSemantic(String title) {
    return 'Benachrichtigung öffnen: $title';
  }

  @override
  String get notificationsActorSomeone => 'Jemand';

  @override
  String get notificationsSpotUntitled => 'Unbenannter Spot';

  @override
  String notificationNearbyNewSpotTitle(String spotName) {
    return 'Neuer Spot in der Nähe: $spotName';
  }

  @override
  String notificationNearbyNewSpotBody(String actorName) {
    return '$actorName hat einen neuen Parkour-Spot in der Nähe eines deiner gespeicherten Orte hinzugefügt.';
  }

  @override
  String notificationNearbyCheckInTitle(String actorName, String spotName) {
    return '$actorName trainiert gerade bei $spotName';
  }

  @override
  String get notificationNearbyCheckInBody =>
      'Gerade an diesem Spot eingecheckt.';

  @override
  String notificationNearbyTrainingPlanTitle(
    String actorName,
    String spotName,
  ) {
    return '$actorName hat Training bei $spotName geplant';
  }

  @override
  String get notificationNearbyTrainingPlanBody =>
      'Öffentliches Trainingsfenster in der Nähe eines deiner gespeicherten Orte.';

  @override
  String notificationTrainingPlanCheckInReminderTitle(String spotName) {
    return 'Zeit für Check-in bei $spotName';
  }

  @override
  String get notificationTrainingPlanCheckInReminderBody =>
      'Deine geplante Session hat begonnen. Tippe zum Einchecken.';

  @override
  String get profileModeratorSectionTitle => 'Moderation';

  @override
  String get profileModeratorToolsTitle => 'Moderations-Tools';

  @override
  String get profileModeratorToolsSubtitle =>
      'Eingehende Spot-Meldungen prüfen und bearbeiten';

  @override
  String get profileAdminSectionTitle => 'Administrator';

  @override
  String get profileAdminToolsTitle => 'Admin-Tools';

  @override
  String get profileAdminToolsSubtitle =>
      'Quellen und Verwaltungsaufgaben verwalten';

  @override
  String get profileSignOut => 'Abmelden';

  @override
  String get profileSignOutMessage => 'Möchtest du dich wirklich abmelden?';

  @override
  String get profileCancel => 'Abbrechen';

  @override
  String get profileLocationAlertsTitle => 'Standort-Benachrichtigungen';

  @override
  String get profileNotificationSettingsTitle =>
      'Benachrichtigungseinstellungen';

  @override
  String get profilePushNotificationsThisDeviceTitle =>
      'Push notifications on this browser/device';

  @override
  String get profilePushNotificationsUnsupported =>
      'Push notifications are not supported on this browser.';

  @override
  String get profilePushNotificationsLoading =>
      'Checking push notification status for this device...';

  @override
  String get profilePushNotificationsPermissionDenied =>
      'Push permission is blocked in your browser settings for this site.';

  @override
  String get profilePushNotificationsPermissionNotDetermined =>
      'Turn this on to ask for permission and subscribe this browser.';

  @override
  String get profilePushNotificationsEnabled =>
      'This browser is subscribed and can receive push alerts.';

  @override
  String get profilePushNotificationsPermissionGrantedButOff =>
      'Permission is granted, but this browser is currently unsubscribed.';

  @override
  String get profilePushNotificationsUnknown =>
      'Push status is currently unavailable. Try again shortly.';

  @override
  String get profilePushNotificationsError =>
      'We couldn\'t update push notifications on this browser. Please try again.';

  @override
  String get profileLocationAlertsDescription =>
      'Lege fest, welche Standorte für Benachrichtigungen in der Nähe verwendet werden – z. B. für Check-ins, neue Spots, Trainingspläne und künftige Events.';

  @override
  String get profileLocationAlertsShareLastKnownTitle =>
      'Letzten bekannten Standort verwenden';

  @override
  String get profileLocationAlertsShareLastKnownSubtitle =>
      'Speichere den letzten bekannten Standort deines Geräts in der Cloud, um passende Benachrichtigungen in der Nähe zu erhalten.';

  @override
  String get profileLocationAlertsNotifyNewSpotsTitle =>
      'Benachrichtigung über neue Spots in der Nähe';

  @override
  String get profileLocationAlertsNotifyNewSpotsSubtitle =>
      'Erhalte eine In-App-Benachrichtigung, wenn jemand einen Spot in etwa 5 km von einem aktiven gespeicherten Ort oder deinem letzten bekannten Standort hinzufügt.';

  @override
  String get profileLocationAlertsNotifyNearbyCheckInsTitle =>
      'Benachrichtigung über Check-ins in der Nähe';

  @override
  String get profileLocationAlertsNotifyNearbyCheckInsSubtitle =>
      'Erhalte eine In-App-Benachrichtigung, wenn jemand an einem Spot in etwa 5 km von einem aktiven gespeicherten Ort oder deinem letzten bekannten Standort eincheckt.';

  @override
  String get profileLocationAlertsNotifyTrainingPlansTitle =>
      'Benachrichtigung bei Trainingsplänen in der Nähe';

  @override
  String get profileLocationAlertsNotifyTrainingPlansSubtitle =>
      'Erhalte eine In-App-Benachrichtigung, wenn jemand ein öffentliches Trainingsfenster an einem Spot in etwa 5 km von einem aktiven gespeicherten Ort oder deinem letzten bekannten Standort teilt.';

  @override
  String get profileTrainingPlanCheckInReminderTitle =>
      'Erinnerung zum Einchecken bei geplanten Sessions';

  @override
  String get profileTrainingPlanCheckInReminderSubtitle =>
      'Erhalte eine In-App-Erinnerung, wenn dein geplantes Zeitfenster begonnen hat und du an diesem Spot noch nicht eingecheckt bist.';

  @override
  String get profileLocationAlertsSavedLocationsTitle =>
      'Meine Orte von Interesse';

  @override
  String get profileLocationAlertsAddLocationButton => 'Hinzufügen';

  @override
  String get profileLocationAlertsNoLocationsEnabledWarning =>
      'Du erhältst keine standortbasierten Benachrichtigungen, bis du „Letzten bekannten Standort verwenden“ aktivierst oder mindestens einen gespeicherten Ort einschaltest.';

  @override
  String get profileLocationAlertsEmptyState =>
      'Noch keine gespeicherten Orte. Füge z. B. Zuhause oder Arbeit hinzu.';

  @override
  String get profileLocationAlertsDefaultLabel => 'Gespeicherter Ort';

  @override
  String get profileLocationAlertsDisableTooltip => 'Deaktivieren';

  @override
  String get profileLocationAlertsEnableTooltip => 'Aktivieren';

  @override
  String get profileLocationAlertsEditTooltip => 'Bearbeiten';

  @override
  String get profileLocationAlertsDeleteTooltip => 'Löschen';

  @override
  String get profileLocationAlertsDeleteTitle => 'Gespeicherten Ort löschen?';

  @override
  String profileLocationAlertsDeleteMessage(String label) {
    return 'Möchtest du $label wirklich löschen?';
  }

  @override
  String get profileLocationAlertsDeleteConfirmButton => 'Löschen';

  @override
  String get profileLocationAlertsDialogAddTitle => 'Ort hinzufügen';

  @override
  String get profileLocationAlertsDialogEditTitle => 'Ort bearbeiten';

  @override
  String get profileLocationAlertsLabelFieldLabel => 'Bezeichnung';

  @override
  String get profileLocationAlertsLabelFieldPlaceholder => 'Zuhause';

  @override
  String get profileLocationAlertsEnabledLabel => 'Aktiviert';

  @override
  String get profileLocationAlertsLabelRequired =>
      'Bitte gib eine Bezeichnung ein';

  @override
  String get profileLocationAlertsLocationRequired =>
      'Bitte wähle einen Ort auf der Karte';

  @override
  String get profileAboutIntro =>
      'Parkour·Spot ist eine Community-App zum Entdecken und Teilen von Parkour- und Freerunning-Spots weltweit. Wir machen es einfach, gute Orte zu finden—egal, wo du trainierst.';

  @override
  String get profileReadMore => 'Mehr lesen';

  @override
  String get profileAboutStoryBeforeName => 'Gestartet von ';

  @override
  String get profileAboutStoryAfterName =>
      ' aus der Parkour-Community Utrecht: Die App bündelt lokales Wissen aus bestehenden Stadt- und Regionalkarten—ob auf Facebook, Instagram, Websites oder in eingestellten Apps—damit gute Spot-Daten nicht verloren gehen.';

  @override
  String get profileAboutMapMission =>
      'Das ist deine Karte. Füge neue Spots hinzu, bewerte vorhandene und ergänze Einträge mit Details. Je mehr wir beitragen, desto stärker wird das gemeinsame Wissen der Community.';

  @override
  String get profileAboutPrinciplesHeader => 'Unsere Prinzipien:';

  @override
  String get profileAboutPrincipleTransparency =>
      '• Transparenz: Du kannst die App ohne Konto durchsuchen, und jeder Spot zeigt, welche externen Quellen dazu beigetragen haben.';

  @override
  String get profileAboutPrinciplePortability =>
      '• Portabilität: Wir entwickeln Export-Tools, damit Spot-Daten auch außerhalb der App nutzbar sind.';

  @override
  String get profileAboutPrincipleOpenSource =>
      '• Open Source: Die App gehört der Community, nicht einer einzelnen Person.';

  @override
  String get profileAboutEnjoy =>
      'Viel Spaß beim Entdecken und Teilen von Spots mit Parkour.spot. Fragen oder Ideen? Tippe auf Kontakt—wir freuen uns auf deine Nachricht.';

  @override
  String get profileCreditsBy => 'Große Beiträge von ';

  @override
  String get profileCreditsDaphneArt => ' (Grafik), ';

  @override
  String get profileCreditsComma => ', ';

  @override
  String get profileCreditsEnd => ' und vielen anderen.';

  @override
  String get profileViewSourceCode => 'Quellcode ansehen';

  @override
  String get profileContactUs => 'Kontakt';

  @override
  String get profileReportIssue => 'Problem melden';

  @override
  String get profileHelpTranslate => 'Hilf beim Übersetzen der App';

  @override
  String get profileInstallBannerTitle => 'Parkour·Spot-App installieren';

  @override
  String get profileInstallBannerSubtitle => 'Die volle App-Erfahrung nutzen';

  @override
  String get profileInstallDialogTitle => 'Parkour·Spot installieren';

  @override
  String profileInstallIntro(String device) {
    return 'So installierst du Parkour·Spot auf deinem $device:';
  }

  @override
  String get profileInstallDeviceIphone => 'iPhone';

  @override
  String get profileInstallDeviceAndroid => 'Android-Gerät';

  @override
  String get profileInstallIosStep1 => 'Tippe unten auf den Teilen-Button';

  @override
  String get profileInstallIosStep2 =>
      'Scrolle nach unten und tippe auf „Zum Home-Bildschirm“';

  @override
  String get profileInstallIosStep3 => 'Tippe oben rechts auf „Hinzufügen“';

  @override
  String get profileInstallIosStep4 =>
      'Die App erscheint auf deinem Home-Bildschirm!';

  @override
  String get profileInstallAndroidStep1 => 'Tippe oben rechts auf das Menü (⋯)';

  @override
  String get profileInstallAndroidStep2 =>
      'Tippe auf „Zum Startbildschirm hinzufügen“';

  @override
  String get profileInstallAndroidStep3 => 'Tippe auf „App installieren“';

  @override
  String get profileInstallAndroidStep4 =>
      'Die App erscheint auf deinem Startbildschirm!';

  @override
  String get profileInstallGotIt => 'Verstanden';

  @override
  String get exploreMetaDefaultTitle => 'Parkour·Spot';

  @override
  String get exploreMetaDefaultDescription =>
      'Entdecke, kartiere und teile die besten Parkour-Spots weltweit mit Community-Fotos, Bewertungen und lokalen Tipps für dein nächstes Training.';

  @override
  String exploreMetaTitleCityCountry(String city, String country) {
    return 'Die besten Parkour-Spots in $city, $country';
  }

  @override
  String exploreMetaDescriptionCityCountry(String city, String country) {
    return 'Entdecke die besten Parkour-Spots in $city, $country. Finde Trainingsorte, teile deine Lieblings-Spots und vernetze dich mit der Parkour-Community.';
  }

  @override
  String exploreMetaTitleCountry(String country) {
    return 'Die besten Parkour-Spots in $country';
  }

  @override
  String exploreMetaDescriptionCountry(String country) {
    return 'Entdecke die besten Parkour-Spots in $country. Finde Trainingsorte, teile deine Lieblings-Spots und vernetze dich mit der Parkour-Community.';
  }

  @override
  String get exploreAddSpotTitle => 'Neuen Spot hinzufügen';

  @override
  String get exploreAddSpotSubtitle =>
      'Teile deine Lieblings-Parkour-Spots mit der Community';

  @override
  String get exploreSignInToAddSpot =>
      'Melde dich an, um einen Spot hinzuzufügen';

  @override
  String get exploreLoadingProfile => 'Profil wird geladen…';

  @override
  String get exploreSearchHint => 'Ort oder Spot suchen…';

  @override
  String get exploreFilterBy => 'Filtern nach';

  @override
  String get exploreFilterAmenities => 'Ausstattung';

  @override
  String get exploreFilterSources => 'Quellen';

  @override
  String get exploreSpotAccessTitle => 'Spot-Zugang';

  @override
  String get exploreSpotAccessSubtitle => 'Spots nach Zugangstyp filtern';

  @override
  String get exploreFilterAny => 'Beliebig';

  @override
  String get exploreSpotFacilitiesTitle => 'Spot-Ausstattung';

  @override
  String get exploreSpotFacilitiesSubtitle =>
      'Spots mit diesen Annehmlichkeiten anzeigen';

  @override
  String get exploreAttributesTitle => 'Mit einer dieser Eigenschaften';

  @override
  String get exploreAttributesSubtitle =>
      'Spots, die mindestens eine der gewählten Skills oder Features haben';

  @override
  String get exploreGoodForSegment => 'Geeignet für';

  @override
  String get exploreSpotFeaturesSegment => 'Spot-Features';

  @override
  String get exploreSpotSourceLabel => 'Spot-Quelle';

  @override
  String get exploreSourcesLoadError => 'Quellen konnten nicht geladen werden';

  @override
  String get exploreAllSources => 'Alle Quellen';

  @override
  String get exploreParkourSpotNative => 'Parkour·Spot (Native)';

  @override
  String get exploreAllFolders => 'Alle Ordner';

  @override
  String exploreLocationError(String error) {
    return 'Standort konnte nicht ermittelt werden: $error';
  }

  @override
  String get exploreCurrentLocationSnackbar =>
      'Das ist dein aktueller Standort';

  @override
  String get exploreCloseTooltip => 'Schließen';

  @override
  String get exploreClearSearchTooltip => 'Leeren';

  @override
  String get exploreFiltersTooltip => 'Filter';

  @override
  String get exploreFindingLocation => 'Standort wird gesucht…';

  @override
  String get exploreAddSpotHereTitle => 'Spot an diesem Ort hinzufügen?';

  @override
  String exploreMapRankedTotalBar(int total) {
    return '$total Spots';
  }

  @override
  String exploreMapSpotsFoundLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Spots gefunden',
      one: '1 Spot gefunden',
    );
    return '$_temp0';
  }

  @override
  String exploreMapBestShownParenthetical(int count) {
    return ' ($count beste angezeigt)';
  }

  @override
  String get exploreMapListModeSpots => 'Spots';

  @override
  String get exploreMapListModeEvents => 'Events';

  @override
  String get exploreNoEventsArea => 'Keine Events in diesem Gebiet';

  @override
  String get exploreNoEventsAreaHint =>
      'Karte verschieben oder später erneut prüfen';

  @override
  String get spotCardUpcomingEventBadge => 'Event';

  @override
  String get exploreEventLocate => 'Orten';

  @override
  String get exploreNoSpotsSearch => 'Keine Spots gefunden';

  @override
  String get exploreNoSpotsArea => 'Keine Spots in diesem Gebiet';

  @override
  String get exploreNoSpotsSearchHint => 'Passe deine Suchbegriffe an';

  @override
  String get exploreNoSpotsMapHint =>
      'Verschiebe die Karte, um andere Gebiete zu erkunden';

  @override
  String get exploreRefreshMapTooltip =>
      'Spots in der aktuellen Ansicht aktualisieren';

  @override
  String get exploreSwitchToMap => 'Zur Karte';

  @override
  String get exploreSwitchToSatellite => 'Zu Satellit';

  @override
  String get exploreLocationPermissionDenied => 'Standortzugriff verweigert';

  @override
  String get exploreCenterOnMyLocation => 'Auf meinen Standort zentrieren';

  @override
  String get exploreFiltersDialogTitle => 'Filter';

  @override
  String get exploreClearFilters => 'Zurücksetzen';

  @override
  String get exploreApplyFilters => 'Anwenden';

  @override
  String exploreSpotCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Spots',
      one: '1 Spot',
    );
    return '$_temp0';
  }

  @override
  String get explorePwaBannerInstall => 'Installieren';

  @override
  String get addSpotPickImagesFailed =>
      'Bilder konnten nicht ausgewählt werden. Bitte erneut versuchen.';

  @override
  String get addSpotTakePhotoFailed =>
      'Foto konnte nicht aufgenommen werden. Bitte erneut versuchen.';

  @override
  String get addSpotNeedPhoto =>
      'Bitte lade mindestens ein Foto des Spots hoch';

  @override
  String get addSpotNeedLocation =>
      'Warte auf den Standort oder wähle einen Ort auf der Karte';

  @override
  String addSpotCreateError(String error) {
    return 'Spot konnte nicht erstellt werden: $error';
  }

  @override
  String get addSpotNameLabel => 'Spot-Name *';

  @override
  String get addSpotNameRequired => 'Bitte gib einen Spot-Namen ein';

  @override
  String get addSpotDescriptionLabel => 'Beschreibung *';

  @override
  String get addSpotDescriptionRequired => 'Bitte gib eine Beschreibung ein';

  @override
  String get addSpotDescriptionMinLength =>
      'Die Beschreibung muss mindestens 10 Zeichen haben';

  @override
  String get addSpotCreating => 'Spot wird erstellt…';

  @override
  String get addSpotCreateButton => 'Spot erstellen';

  @override
  String get addSpotLocationSectionTitle => 'Spot-Standort wählen';

  @override
  String get addSpotGettingLocation => 'Standort wird ermittelt…';

  @override
  String get addSpotLocationNotAvailable => 'Standort nicht verfügbar';

  @override
  String get addSpotPickLocationHint => 'Ort wählen';

  @override
  String get addSpotImagesSectionTitle => 'Spot-Bilder wählen';

  @override
  String get addSpotGalleryButton => 'Galerie';

  @override
  String get addSpotCameraButton => 'Kamera';

  @override
  String get addSpotGoodForTitle => 'Geeignet für';

  @override
  String get addSpotGoodForSubtitle =>
      'Welche Parkour-Fähigkeiten kann man hier trainieren?';

  @override
  String get addSpotFeaturesTitle => 'Spot-Features';

  @override
  String get addSpotFeaturesSubtitle =>
      'Welche körperlichen Merkmale hat dieser Spot?';

  @override
  String get addSpotAccessTitle => 'Spot-Zugang';

  @override
  String get addSpotAccessSubtitle => 'Wie ist der Zugang zu diesem Spot?';

  @override
  String get addSpotFacilitiesFormTitle => 'Spot-Ausstattung';

  @override
  String get addSpotFacilitiesSubtitle =>
      'Welche Annehmlichkeiten gibt es an diesem Spot?';

  @override
  String get addSpotLongPressHintSkill =>
      'Lange auf eine Fähigkeit drücken für mehr Infos';

  @override
  String get addSpotLongPressHintFeature =>
      'Lange auf ein Feature drücken für mehr Infos';

  @override
  String get addSpotLongPressHintFacility =>
      'Lange auf eine Ausstattung drücken für mehr Infos';

  @override
  String get addSpotPickLocationAppBarTitle => 'Ort wählen';

  @override
  String get addSpotTipLongPressMobile =>
      'Tipp: Du kannst Spots auch auf der Explore-Karte per langem Tippen auf einen Ort hinzufügen.';

  @override
  String get addSpotTipRightClickDesktop =>
      'Tipp: Du kannst Spots auch auf der Explore-Karte per Rechtsklick auf einen Ort hinzufügen.';

  @override
  String get addSpotUseThisLocation => 'Diesen Ort verwenden';

  @override
  String get addSpotDirectionsTooltip => 'Route';

  @override
  String get addSpotGettingAddress => 'Adresse wird geladen…';

  @override
  String get noImagesYet => 'Noch keine Bilder';

  @override
  String get spotCardNoDescription => 'Noch keine Beschreibung';

  @override
  String get spotCardPartOfPrefix => 'Teil von ';

  @override
  String get spotCardRemoveFromListTooltip => 'Aus Liste entfernen';

  @override
  String get spotCardCopiedToClipboard => 'Spot in die Zwischenablage kopiert!';

  @override
  String spotCardShareFailed(String error) {
    return 'Spot konnte nicht geteilt werden: $error';
  }

  @override
  String spotCardShareClipboardText(String name, String url) {
    return '$name 👉 $url';
  }

  @override
  String get spotCardRemovedFromSource => 'Aus Quelle entfernt';

  @override
  String get spotCheckInUnnamedPerson => 'Diese Person';

  @override
  String spotCheckInTooltipPublic(String name, String time) {
    return '$name ist gerade hier bis $time';
  }

  @override
  String spotCheckInTooltipPrivate(String time) {
    return 'Du bist gerade hier bis $time — nur du siehst diesen Check-in';
  }

  @override
  String spotTrainingPlanTooltipPublic(String name, String timeRange) {
    return '$name plant, hier zu trainieren $timeRange';
  }

  @override
  String spotTrainingPlanTooltipPrivate(String timeRange) {
    return 'Du planst, hier zu trainieren $timeRange — nur du siehst diesen Plan';
  }

  @override
  String spotTrainingPlanTooltipPublicUntil(String name, String untilTime) {
    return '$name plant, hier bis $untilTime zu trainieren';
  }

  @override
  String spotTrainingPlanTooltipPrivateUntil(String untilTime) {
    return 'Du planst, hier bis $untilTime zu trainieren — nur du siehst diesen Plan';
  }

  @override
  String get spotDetailRouteErrorLoading => 'Fehler beim Laden des Spots';

  @override
  String get spotDetailRouteTryAgainLater => 'Bitte versuche es später erneut';

  @override
  String get spotDetailRouteNotFound => 'Spot nicht gefunden';

  @override
  String get spotDetailRouteGoToExplore => 'Zur Entdecken-Ansicht';

  @override
  String get spotDetailCheckInVerifyFailed =>
      'Check-ins konnten nicht geprüft werden';

  @override
  String get spotDetailCheckInEndPreviousFailed =>
      'Vorheriger Check-in konnte nicht beendet werden';

  @override
  String get spotDetailCheckInSuccess => 'Du bist eingecheckt';

  @override
  String get spotDetailCheckInFailed => 'Check-in fehlgeschlagen';

  @override
  String get spotDetailCheckInRemoved => 'Check-in entfernt';

  @override
  String get spotDetailCheckInDeleteFailed =>
      'Check-in konnte nicht gelöscht werden';

  @override
  String get spotDetailCheckInUpdated => 'Check-in aktualisiert';

  @override
  String get spotDetailCheckInUpdateFailed =>
      'Check-in konnte nicht aktualisiert werden';

  @override
  String get spotDetailCheckInFabTooltipSignIn => 'Zum Einchecken anmelden';

  @override
  String get spotDetailCheckInFabTooltipEdit => 'Check-in bearbeiten';

  @override
  String get spotDetailCheckInFabTooltipCheckIn => 'Einchecken';

  @override
  String spotDetailSpotCreatedOnDateBy(String date) {
    return 'Spot erstellt $date von ';
  }

  @override
  String get spotDetailSpotCreatedBy => 'Spot erstellt von ';

  @override
  String get spotDetailUnknownSource => 'Unbekannte Quelle';

  @override
  String spotDetailSpotImportedOnDateFrom(String date) {
    return 'Spot importiert $date von ';
  }

  @override
  String get spotDetailSpotImportedFrom => 'Spot importiert von ';

  @override
  String get spotDetailFromFolder => ' aus dem Ordner ';

  @override
  String get spotDetailImprovedByAfterComma => ', verbessert von ';

  @override
  String get spotDetailImprovedByAfterAnd => ' und verbessert von ';

  @override
  String get spotDetailUnknownUser => 'Unbekannt';

  @override
  String get spotDetailListJoinAnd => ' und ';

  @override
  String get spotDetailListJoinComma => ', ';

  @override
  String spotDetailLastUpdatedAfterCommaAnd(String date) {
    return ', zuletzt aktualisiert $date.';
  }

  @override
  String spotDetailLastUpdatedAfterAnd(String date) {
    return ' und zuletzt aktualisiert $date.';
  }

  @override
  String get spotDetailDateToday => 'heute';

  @override
  String get spotDetailDateYesterday => 'gestern';

  @override
  String get communityDateTomorrow => 'morgen';

  @override
  String communityActivityTrainSameDay(
    String startTime,
    String endTime,
    String day,
  ) {
    return 'Von $startTime bis $endTime $day';
  }

  @override
  String communityActivityTrainSpan(
    String startTime,
    String startDay,
    String endTime,
    String endDay,
  ) {
    return 'Von $startTime $startDay bis $endTime $endDay';
  }

  @override
  String get communityShareSpotFallbackName => 'diesem Spot';

  @override
  String communityShareCheckInNarrative(String spotName, String untilPhrase) {
    return 'Ich trainiere gerade bei $spotName bis etwa $untilPhrase';
  }

  @override
  String communityShareTrainingPlanNarrative(
    String spotName,
    String relativeDay,
    String startTime,
  ) {
    return 'Ich plane zu trainieren bei $spotName $relativeDay ab $startTime';
  }

  @override
  String get communityActivityShareCopiedToClipboard =>
      'Nachricht in die Zwischenablage kopiert!';

  @override
  String communityActivityShareFailed(String error) {
    return 'Teilen fehlgeschlagen: $error';
  }

  @override
  String spotDetailDateDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Tagen',
      one: 'vor 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Wochen',
      one: 'vor 1 Woche',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Monaten',
      one: 'vor 1 Monat',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Jahren',
      one: 'vor 1 Jahr',
    );
    return '$_temp0';
  }

  @override
  String spotDetailCopySpotFailed(String error) {
    return 'Spot konnte nicht kopiert werden: $error';
  }

  @override
  String get spotDetailAddressCopiedToClipboard =>
      'Adresse in die Zwischenablage kopiert!';

  @override
  String spotDetailCopyAddressFailed(String error) {
    return 'Adresse konnte nicht kopiert werden: $error';
  }

  @override
  String spotDetailOpenMapsFailed(String error) {
    return 'Karten-App konnte nicht geöffnet werden: $error';
  }

  @override
  String get spotDetailMoreActionsTooltip => 'Weitere Aktionen';

  @override
  String get spotDetailMenuLogin => 'Anmelden';

  @override
  String get spotDetailMenuLoginSubtitle =>
      'Zuerst anmelden, um Bearbeitungen mit deinem Konto zu verknüpfen';

  @override
  String get spotDetailMenuFlagDuplicate => 'Als Duplikat markieren';

  @override
  String get spotDetailMenuFlagDuplicateSubtitleYes =>
      'Dieser Spot ist ein Duplikat';

  @override
  String get spotDetailMenuFlagDuplicateSubtitleNo =>
      'Bereits als Duplikat markiert';

  @override
  String get spotDetailMenuSuggestPhoto => 'Foto vorschlagen';

  @override
  String get spotDetailMenuSuggestPhotoSubtitleYes =>
      'Fotos für diesen Spot einreichen';

  @override
  String get spotDetailMenuSuggestPhotoSubtitleNo =>
      'Keine Fotos für Duplikate möglich';

  @override
  String get spotDetailMenuSuggestEdit => 'Bearbeitung vorschlagen';

  @override
  String get spotDetailMenuSuggestEditSubtitleYes =>
      'Änderungen an diesem Spot vorschlagen';

  @override
  String get spotDetailMenuSuggestEditSubtitleNo =>
      'Keine Bearbeitungen für Duplikate möglich';

  @override
  String get spotDetailMenuReportSpot => 'Spot melden';

  @override
  String get spotDetailMenuReportSpotSubtitle =>
      'Hilf uns, diesen Spot zu prüfen';

  @override
  String get spotDetailMenuEditSpot => 'Spot bearbeiten';

  @override
  String get spotDetailMenuEditSpotSubtitleNative =>
      'Zuerst nativen Spot erstellen';

  @override
  String get spotDetailMenuEditSpotSubtitleMod => 'Nur Moderatoren';

  @override
  String get spotDetailMenuMarkDuplicate => 'Als Duplikat markieren';

  @override
  String get spotDetailMenuMarkDuplicateSubtitleDup =>
      'Bereits als Duplikat markiert';

  @override
  String get spotDetailMenuMarkDuplicateSubtitleMod => 'Nur Moderatoren';

  @override
  String get spotDetailMenuRemoveDuplicateStatus => 'Duplikat-Status entfernen';

  @override
  String get spotDetailMenuCreateNative => 'Nativen Spot erstellen';

  @override
  String get spotDetailMenuHideSpot => 'Spot ausblenden';

  @override
  String get spotDetailMenuUnhideSpot => 'Spot wieder anzeigen';

  @override
  String get spotDetailMenuDeleteSpot => 'Spot löschen';

  @override
  String get spotDetailMenuDeleteSubtitleAdmin => 'Nur Administratoren';

  @override
  String get spotDetailMenuTriggerResize => 'Bildgrößenänderung auslösen';

  @override
  String get spotDetailMenuTriggerResizeSubtitle =>
      'Neu skalierte Versionen erzeugen';

  @override
  String get spotDetailExternalSourceCannotEdit =>
      'Spots aus externen Quellen können nicht bearbeitet werden. Erstelle zuerst einen nativen Spot über „Als Duplikat markieren“ → „Nativen Spot erstellen“.';

  @override
  String get spotDetailOk => 'OK';

  @override
  String get spotDetailUnableEditNow =>
      'Dieser Spot kann gerade nicht bearbeitet werden.';

  @override
  String get spotDetailOnlyAdminsDelete =>
      'Nur Administratoren können Spots löschen.';

  @override
  String get spotDetailResizeAllHaveVersions =>
      'Alle Bilder haben bereits skalierte Versionen';

  @override
  String spotDetailResizeSummary(
    int triggered,
    int verified,
    String failedPart,
  ) {
    return 'Größe ändern: $triggered gestartet, $verified geprüft$failedPart';
  }

  @override
  String spotDetailResizeFailedPart(int failed) {
    return ', $failed fehlgeschlagen';
  }

  @override
  String spotDetailResizeTriggerFailed(String error) {
    return 'Größenänderung konnte nicht gestartet werden: $error';
  }

  @override
  String get spotDetailUnableFlagDuplicate =>
      'Dieser Spot kann gerade nicht als Duplikat gemeldet werden.';

  @override
  String get spotDetailThanksDuplicateReport =>
      'Danke! Deine Duplikat-Meldung wurde gesendet.';

  @override
  String get spotDetailUnableSuggestPhotos =>
      'Für diesen Spot können gerade keine Fotos vorgeschlagen werden.';

  @override
  String get spotDetailCannotSuggestPhotosDuplicate =>
      'Keine Fotos für Duplikat-Spots möglich.';

  @override
  String get spotDetailThanksPhotoSuggestion =>
      'Danke! Dein Foto-Vorschlag wurde zur Prüfung eingereicht.';

  @override
  String get spotDetailUnableSuggestEdits =>
      'Für diesen Spot können gerade keine Bearbeitungen vorgeschlagen werden.';

  @override
  String get spotDetailCannotSuggestEditsDuplicate =>
      'Keine Bearbeitungen für Duplikat-Spots möglich.';

  @override
  String get spotDetailThanksEditSuggestion =>
      'Danke! Dein Änderungsvorschlag wurde zur Prüfung eingereicht.';

  @override
  String get spotDetailUnableReportNow =>
      'Dieser Spot kann gerade nicht gemeldet werden.';

  @override
  String get spotDetailThanksReportSubmitted =>
      'Danke! Deine Meldung wurde gesendet.';

  @override
  String get spotDetailUnableAddToList =>
      'Dieser Spot kann gerade keiner Liste hinzugefügt werden.';

  @override
  String get spotDetailNoSpotListsAccess =>
      'Du hast keinen Zugriff auf Spot-Listen.';

  @override
  String get spotDetailListCreatedAndAdded =>
      'Liste erstellt und Spot hinzugefügt!';

  @override
  String get spotDetailSpotAddedToList => 'Spot zur Liste hinzugefügt!';

  @override
  String get spotDetailEditReportTooltip => 'Bearbeiten & melden';

  @override
  String get spotDetailShareTooltip => 'Teilen';

  @override
  String get spotDetailQuickActionSave => 'Speichern';

  @override
  String get spotDetailQuickActionEdit => 'Bearbeiten';

  @override
  String get spotDetailQuickActionShare => 'Teilen';

  @override
  String get spotDetailQuickActionRate => 'Bewerten';

  @override
  String get spotDetailRatingTooltip => 'Community-Bewertung und deine Sterne';

  @override
  String get spotDetailPresenceHereNow => 'Gerade hier';

  @override
  String get spotDetailCommunitySectionTitle => 'Community';

  @override
  String get spotDetailCommunitySectionSubtitle =>
      'Sieh, wer hier trainiert oder ein Training plant, und teile deine Session.';

  @override
  String get spotDetailCommunityNobodyHere =>
      'Noch niemand eingecheckt. Checke ein, damit andere Bescheid wissen.';

  @override
  String get spotDetailCommunityNobodyHereShort => 'Noch niemand hier.';

  @override
  String get spotDetailCommunityNobodySocialShort =>
      'Noch niemand hier oder mit Plan.';

  @override
  String get spotDetailCommunityActivityLoadError =>
      'Community-Aktivität konnte nicht geladen werden.';

  @override
  String get spotDetailCommunityActivityEmpty => 'Gerade nichts anzuzeigen.';

  @override
  String get spotDetailCommunityViewAll => 'Alle anzeigen';

  @override
  String get spotDetailCommunityCheckInButton => 'Einchecken';

  @override
  String get spotDetailCommunityEditCheckInButton => 'Check-in bearbeiten';

  @override
  String get spotDetailCommunitySignInToCheckInButton =>
      'Anmelden zum Einchecken';

  @override
  String get spotDetailCommunityPlanningVisitButton => 'Training planen';

  @override
  String get spotDetailCommunityPlanningVisitTooltip =>
      'Lege fest, wann du hier trainierst.';

  @override
  String get spotDetailCommunityCheckInButtonTooltip =>
      'Zeig anderen, dass du gerade hier bist.';

  @override
  String get spotDetailCommunityEditCheckInButtonTooltip =>
      'Check-in anpassen.';

  @override
  String get spotDetailCommunitySignInToCheckInButtonTooltip =>
      'Zum Einchecken anmelden.';

  @override
  String get spotDetailCommunityPlanningToTrain => 'Plant zu trainieren';

  @override
  String get spotDetailCommunityNobodyPlanningShort => 'Noch keine Pläne.';

  @override
  String get spotDetailCommunitySignInToPlanButton =>
      'Anmelden, um einen Besuch zu planen';

  @override
  String get spotDetailCommunityEditTrainingPlanButton => 'Plan bearbeiten';

  @override
  String get spotCheckInDialogTitle => 'Einchecken';

  @override
  String get spotCheckInDialogTitleEdit => 'Check-in bearbeiten';

  @override
  String get spotCheckInDialogIntroNew =>
      'Zeig anderen, dass du hier trainierst und ungefähr bis wann. Bei öffentlicher Freigabe erscheinst du auf dem Community-Bereich dieses Spots bis zu deiner Endzeit.';

  @override
  String get spotCheckInDialogIntroEdit =>
      'Passe Ankunfts- und Endzeit, Sichtbarkeit und Notiz an.';

  @override
  String get spotCheckInDialogSharePublic => 'Öffentlich teilen';

  @override
  String get spotCheckInDialogShareSub =>
      'Ausschalten, damit nur du diesen Check-in siehst.';

  @override
  String get spotCheckInDialogLabelArrived => 'Ankunft';

  @override
  String get spotCheckInDialogLabelHereUntil => 'Hier bis';

  @override
  String get spotCheckInDialogLabelUntil => 'Bis';

  @override
  String get spotCheckInDialogStillHere => 'Noch hier';

  @override
  String get spotCheckInDialogEndNow => 'Jetzt beenden';

  @override
  String get spotCheckInDialogCancel => 'Abbrechen';

  @override
  String get spotCheckInDialogSave => 'Speichern';

  @override
  String get spotCheckInDialogDelete => 'Löschen';

  @override
  String get spotCheckInDialogConfirmDeleteTitle => 'Check-in löschen?';

  @override
  String get spotCheckInDialogConfirmDeleteBody =>
      'Entfernt diesen Besuch aus deinem Verlauf. Der Spot bleibt in „War dort“, falls du ihn dort hattest.';

  @override
  String get spotCheckInDialogExtendBannerText =>
      'Du hast hier kürzlich einen abgelaufenen Check-in.';

  @override
  String get spotCheckInDialogExtendInstead =>
      'Stattdessen diesen Check-in verlängern';

  @override
  String spotCheckInDialogActiveElsewhereAtNamed(String spotName) {
    return 'Du bist aktuell bei $spotName eingecheckt. Ein Check-in hier beendet jenen Check-in.';
  }

  @override
  String get spotCheckInDialogActiveElsewhereUnnamed =>
      'Du bist an einem anderen Spot eingecheckt. Ein Check-in hier beendet jenen Check-in.';

  @override
  String get spotCheckInDialogActiveElsewhereMultiple =>
      'Du hast an anderen Spots aktive Check-ins. Ein Check-in hier beendet diese Check-ins.';

  @override
  String get spotCheckInDialogNudgeEarlier => '15 Minuten früher';

  @override
  String get spotCheckInDialogNudgeLater => '15 Minuten später';

  @override
  String get spotCheckInDialogTrainingPlanConversionBanner =>
      'Beim Speichern wird dein Plan durch diesen Check-in ersetzt. Dein geplantes Ende ist unten vorausgefüllt.';

  @override
  String get spotDetailSessionNoteLabel => 'Notiz (optional)';

  @override
  String get spotDetailSessionNoteHint => 'z. B. Skills oder Drills';

  @override
  String get spotTrainingPlanDialogTitle => 'Training hier planen';

  @override
  String get spotTrainingPlanDialogTitleEdit => 'Trainingsplan bearbeiten';

  @override
  String get spotTrainingPlanDialogCheckInCtaBody =>
      'Schon da? Check-in, damit andere wissen, dass du angekommen bist.';

  @override
  String get spotTrainingPlanDialogCheckInCtaBodyEarly =>
      'Schon vor Ort? Check-in, damit andere Bescheid wissen.';

  @override
  String get spotTrainingPlanDialogCheckInCtaButton => 'Check-in';

  @override
  String get spotTrainingPlanDialogBody =>
      'Lege Start und Ende deines Trainings fest. Öffentliche Pläne erscheinen auf dem Community-Bereich dieses Spots neben anderen, die geteilt haben.';

  @override
  String get spotTrainingPlanDialogSharePublic => 'Öffentlich teilen';

  @override
  String get spotTrainingPlanDialogShareSub =>
      'Ausschalten, damit nur du den Plan siehst.';

  @override
  String get spotTrainingPlanDialogStartLabel => 'Beginn';

  @override
  String get spotTrainingPlanDialogEndLabel => 'Ende';

  @override
  String get spotTrainingPlanDialogSave => 'Speichern';

  @override
  String get spotTrainingPlanDialogCancel => 'Abbrechen';

  @override
  String get spotTrainingPlanDialogDelete => 'Plan entfernen';

  @override
  String get spotTrainingPlanDialogDeleteTitle => 'Diesen Plan entfernen?';

  @override
  String get spotTrainingPlanDialogDeleteBody =>
      'Du kannst jederzeit einen neuen Plan anlegen.';

  @override
  String get spotTrainingPlanValidationOrder =>
      'Ende muss nach dem Start liegen.';

  @override
  String get spotTrainingPlanValidationMinDuration => 'Mindestens 15 Minuten.';

  @override
  String get spotTrainingPlanValidationMaxDuration => 'Höchstens 12 Stunden.';

  @override
  String get spotTrainingPlanValidationStartTooFar =>
      'Start darf höchstens 30 Tage in der Zukunft liegen.';

  @override
  String get spotTrainingPlanValidationEndNotFuture =>
      'Ende muss in der Zukunft liegen.';

  @override
  String get spotTrainingPlanValidationInvalid => 'Ungültiger Zeitraum.';

  @override
  String get spotDetailTrainingPlanSaved => 'Trainingsplan gespeichert';

  @override
  String get spotDetailTrainingPlanUpdated => 'Trainingsplan aktualisiert';

  @override
  String get spotDetailTrainingPlanFailed =>
      'Trainingsplan konnte nicht gespeichert werden';

  @override
  String get spotDetailTrainingPlanRemoved => 'Trainingsplan entfernt';

  @override
  String get spotDetailTrainingPlanDeleteFailed =>
      'Trainingsplan konnte nicht entfernt werden';

  @override
  String get spotTrainingPlanListDialogTitle => 'Plant zu trainieren';

  @override
  String get spotTrainingPlanListDialogSubtitle =>
      'Personen mit öffentlichem Plan für diesen Spot.';

  @override
  String get spotTrainingPlanListDialogClose => 'Schließen';

  @override
  String get spotTrainingPlanListEmpty => 'Noch keine öffentlichen Pläne.';

  @override
  String get spotTrainingPlanListLoadError =>
      'Trainingspläne konnten nicht geladen werden';

  @override
  String get spotTrainingPlanEditMine => 'Plan bearbeiten';

  @override
  String get spotTrainingPlanJoin => 'Mitmachen';

  @override
  String get spotTrainingPlanOnlyYou => 'Nur du';

  @override
  String get spotTrainingPlanUnnamedPerson => 'Jemand';

  @override
  String spotTrainingPlanTimeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get spotDetailHiddenBanner =>
      'Dieser Spot ist für die Öffentlichkeit ausgeblendet. Er existiert wahrscheinlich nicht mehr oder entspricht nicht unseren Richtlinien. Er erscheint nicht in Suchergebnissen oder auf der Karte.';

  @override
  String spotDetailSourceRemovedBanner(String source) {
    return 'Dieser Spot ist in $source nicht mehr gelistet. Angaben können veraltet sein—prüfe vor dem Besuch.';
  }

  @override
  String get spotDetailSourceRemovedUnknownSource =>
      'der ursprünglichen Quelle';

  @override
  String get spotDetailSectionFeatures => 'Merkmale';

  @override
  String get spotDetailSectionAccess => 'Zugang';

  @override
  String get spotDetailSectionFacilities => 'Ausstattung';

  @override
  String spotDetailJumpflixFetchFailed(String error) {
    return 'Jumpflix-Abruf fehlgeschlagen: $error';
  }

  @override
  String get spotDetailBrandYoutube => 'YouTube';

  @override
  String get spotDetailBrandJumpflix => 'Jumpflix';

  @override
  String get spotDetailBrandAsSeenIn => 'Wie zu sehen in';

  @override
  String get spotDetailLoading => 'Lädt…';

  @override
  String get spotDetailLoadingYourRating => 'Deine Bewertung wird geladen…';

  @override
  String get spotDetailRateThisSpot => 'Diesen Spot bewerten';

  @override
  String get spotDetailHeaderNoRatingsYet => 'Noch keine Bewertungen';

  @override
  String get spotDetailCouldNotLoadProfile =>
      'Profil konnte nicht geladen werden.';

  @override
  String get spotDetailRefreshPageToRate =>
      'Bitte die Seite aktualisieren, um zu bewerten.';

  @override
  String get spotDetailSignInToRateTitle => 'Zum Bewerten anmelden';

  @override
  String get spotDetailSignInToRateSubtitle =>
      'Melde dich an, um diesen Spot zu bewerten und anderen zu helfen.';

  @override
  String get spotDetailSignInButton => 'Anmelden';

  @override
  String get spotDetailCreateAccountButton => 'Konto erstellen';

  @override
  String get spotDetailMapSwitchToMap => 'Zur Karte';

  @override
  String get spotDetailMapSwitchToSatellite => 'Zur Satellitenansicht';

  @override
  String get spotDetailMapLocateOnMap => 'Auf der Karte anzeigen';

  @override
  String get spotDetailDuplicateOf => 'Duplikat von';

  @override
  String get spotDetailOriginalSpotFallback => 'Original-Spot';

  @override
  String get spotDetailAlsoBasedOn => 'Außerdem basierend auf';

  @override
  String spotDetailGalleryPageIndicator(int current, int total) {
    return '$current / $total';
  }

  @override
  String get spotDetailSaveMenuTooltip => 'Spot speichern';

  @override
  String get spotDetailSaveMenuSignInTitle =>
      'Zum Speichern von Spots anmelden';

  @override
  String get spotDetailSaveMenuSignInBody =>
      'Füge diesen Spot zu „Möchte ich besuchen“, „War ich schon“ oder eigenen Listen hinzu. Melde dich an oder erstelle ein kostenloses Konto.';

  @override
  String get spotDetailSaveMenuLogInOrCreate => 'Anmelden oder Konto erstellen';

  @override
  String get spotDetailSaveTooltipUpdating => 'Aktualisiert…';

  @override
  String get spotDetailSaveTooltipWantToVisit =>
      'Gespeichert: Möchte ich besuchen';

  @override
  String get spotDetailSaveTooltipBeenHere => 'Gespeichert: War ich schon';

  @override
  String get spotDetailSaveTooltipGeneric => 'Spot speichern';

  @override
  String get spotDetailRemovedFromWantToVisit =>
      'Aus „Möchte ich besuchen“ entfernt';

  @override
  String get spotDetailFailedToRemove => 'Entfernen fehlgeschlagen';

  @override
  String get spotDetailAddedToWantToVisit =>
      'Zu „Möchte ich besuchen“ hinzugefügt';

  @override
  String get spotDetailFailedToAdd => 'Hinzufügen fehlgeschlagen';

  @override
  String get spotDetailRemovedFromBeenHere => 'Aus „War ich schon“ entfernt';

  @override
  String get spotDetailAddedToBeenHere => 'Zu „War ich schon“ hinzugefügt';

  @override
  String get spotDetailWantToVisit => 'Möchte ich besuchen';

  @override
  String get spotDetailBeenHere => 'War ich schon';

  @override
  String get spotDetailViewFullListTooltip => 'Gesamte Liste anzeigen';

  @override
  String get spotDetailAddToCustomList => 'Zu eigener Liste hinzufügen';

  @override
  String get spotDetailAddToCustomListSubtitle => 'Liste wählen oder erstellen';

  @override
  String get spotDetailListNameEmpty => 'Listenname darf nicht leer sein';

  @override
  String get spotDetailFailedAddToListGeneric =>
      'Spot konnte nicht zur Liste hinzugefügt werden';

  @override
  String get spotDetailFailedCreateList => 'Liste konnte nicht erstellt werden';

  @override
  String get spotDetailFailedAddToSomeLists =>
      'Spot konnte nicht zu einigen Listen hinzugefügt werden';

  @override
  String spotDetailAddToListTitle(String name) {
    return 'Zu $name hinzufügen';
  }

  @override
  String get spotDetailSelectSections => 'Bereiche auswählen:';

  @override
  String spotDetailSectionEntryCount(int count) {
    return 'Bereich ($count Spots)';
  }

  @override
  String get spotDetailAddToNewSection => 'Zu neuem Bereich hinzufügen';

  @override
  String get spotDetailSectionNameOptional => 'Bereichsname (optional)';

  @override
  String get spotDetailNoteOptional => 'Notiz (optional)';

  @override
  String get spotDetailSkip => 'Überspringen';

  @override
  String get spotDetailAdd => 'Hinzufügen';

  @override
  String get spotDetailAddToListDialogTitle => 'Zur Liste hinzufügen';

  @override
  String get spotDetailAlreadyInLists => 'Bereits in diesen Listen:';

  @override
  String get spotDetailNoListsYet =>
      'Du hast noch keine Listen. Erstelle eine, um zu starten!';

  @override
  String get spotDetailSelectListsPrompt =>
      'Listen auswählen, zu denen dieser Spot hinzugefügt werden soll:';

  @override
  String get spotDetailCreateNewList => 'Neue Liste erstellen';

  @override
  String get spotDetailListNameLabel => 'Listenname';

  @override
  String get spotDetailListNameHint => 'z. B. Meine Lieblingsspots';

  @override
  String get spotDetailListDescriptionLabel => 'Beschreibung (optional)';

  @override
  String get spotDetailListDescriptionHint =>
      'Beschreibung für diese Liste hinzufügen';

  @override
  String get spotDetailVisibilityLabel => 'Sichtbarkeit';

  @override
  String get spotDetailCreateAndAdd => 'Erstellen & hinzufügen';

  @override
  String get spotDetailReportDuplicateTitle => 'Duplikat-Spot melden';

  @override
  String get spotDetailReportDuplicateIntro =>
      'Bitte wähle den Spot aus, dessen Duplikat dies ist.';

  @override
  String get spotDetailEmailInvalid =>
      'Bitte eine gültige E-Mail-Adresse eingeben.';

  @override
  String get spotDetailEmailRequired => 'Bitte eine E-Mail-Adresse angeben.';

  @override
  String get spotDetailSubmitReport => 'Meldung senden';

  @override
  String get spotDetailReportThisSpotTitle => 'Diesen Spot melden';

  @override
  String spotDetailReportIntro(String name) {
    return 'Sag uns, was mit $name nicht stimmt. Moderatoren prüfen deine Meldung bald.';
  }

  @override
  String get spotDetailReportWhatWrong => 'Was ist passiert?';

  @override
  String get spotDetailReportCategoryLabel => 'Kategorie auswählen';

  @override
  String get spotDetailReportCategoryHint => 'Meldekategorie wählen';

  @override
  String get spotDetailReportDescribeIssue => 'Problem beschreiben';

  @override
  String get spotDetailReportDescribeIssueHint =>
      'Sag uns, was nicht der Realität entspricht';

  @override
  String get spotDetailReportAdditionalDetails => 'Zusätzliche Details';

  @override
  String get spotDetailReportAdditionalDetailsHint =>
      'Noch etwas, das wir wissen sollten?';

  @override
  String get spotDetailReportEmailLabel => 'E-Mail-Adresse';

  @override
  String get spotDetailReportEmailHelper =>
      'Wir melden uns nur wegen dieser Meldung.';

  @override
  String spotDetailReportReachOutAt(String email) {
    return 'Bei Rückfragen kontaktieren wir dich unter $email.';
  }

  @override
  String get spotDetailReportReachOutAccount =>
      'Bei Rückfragen nutzen wir die E-Mail deines Kontos.';

  @override
  String get spotDetailReportCategoryOtherDescribe =>
      'Bitte das Problem beschreiben, wenn du „Sonstiges“ wählst.';

  @override
  String get spotDetailReportCategoryRequired =>
      'Bitte eine Kategorie auswählen.';

  @override
  String get spotDetailReportSendFailed =>
      'Meldung konnte nicht gesendet werden. Bitte erneut versuchen.';

  @override
  String get spotDetailReportCategoryClosed => 'Spot geschlossen oder entfernt';

  @override
  String get spotDetailReportCategoryInaccurate => 'Falsche Lage oder Angaben';

  @override
  String get spotDetailReportCategoryUnsafe => 'Unsichere Bedingungen';

  @override
  String get spotDetailReportCategoryNotASpot => 'Kein Spot';

  @override
  String get spotDetailReportCategoryOther => 'Sonstiges';

  @override
  String get spotDetailReportCategoryClosedDesc =>
      'Der Spot wurde dauerhaft geschlossen, abgerissen oder entfernt und ist nicht mehr zugänglich. Bitte mehr Details unten angeben.';

  @override
  String get spotDetailReportCategoryInaccurateDesc =>
      'Die Position auf der Karte stimmt nicht, oder Angaben wie Name, Beschreibung oder Adresse sind falsch. Bitte unten angeben, was korrigiert werden soll.';

  @override
  String get spotDetailReportCategoryUnsafeDesc =>
      'Der Spot ist durch Bausubstanz, Umwelt oder andere Risiken gefährlich geworden. Bitte unten angeben, was unsicher ist.';

  @override
  String get spotDetailReportCategoryNotASpotDesc =>
      'Nur für objektive Fälle wie Spam, ungültige Orte (z. B. Meeresmitte), Privatgrundstücke, ganze Städte oder eindeutig ungültige Einträge. Für Meinungen zur Spot-Qualität bitte eine Bewertung nutzen. Unten erklären, warum dies kein Spot ist.';

  @override
  String get spotDetailReportCategoryOtherDesc =>
      'Jedes andere Problem, das oben nicht passt. Bitte im Feld unten beschreiben.';

  @override
  String get spotDetailMarkDuplicateTitle => 'Als Duplikat markieren';

  @override
  String get spotDetailMarkDuplicateBody =>
      'Diesen Spot wirklich als Duplikat markieren? Das kann später rückgängig gemacht werden.';

  @override
  String get spotDetailMarkDuplicateAddToOriginal =>
      'Wähle, was zum Original-Spot hinzugefügt werden soll:';

  @override
  String get spotDetailMarkDuplicatePhotos => 'Fotos';

  @override
  String get spotDetailMarkDuplicateYoutube => 'YouTube-Links';

  @override
  String get spotDetailMarkDuplicateOverwrite =>
      'Wähle, was im Original-Spot überschrieben werden soll (falls gesetzt):';

  @override
  String get spotDetailMarkDuplicateName => 'Name';

  @override
  String get spotDetailMarkDuplicateDescription => 'Beschreibung';

  @override
  String get spotDetailMarkDuplicateLocation => 'Standort';

  @override
  String get spotDetailMarkDuplicateSpotAttributes => 'Spot-Eigenschaften';

  @override
  String get spotDetailConfirm => 'Bestätigen';

  @override
  String get spotDetailPickImagesFailed =>
      'Bilder konnten nicht ausgewählt werden. Bitte erneut versuchen.';

  @override
  String get spotDetailSelectAtLeastOnePhoto =>
      'Bitte mindestens ein Foto auswählen';

  @override
  String get spotDetailSuggestPhotosTitle => 'Fotos vorschlagen';

  @override
  String get spotDetailSuggestPhotosIntro =>
      'Schlag Fotos vor, die zu diesem Spot hinzugefügt werden sollen. Moderatoren prüfen sie vor der Veröffentlichung.';

  @override
  String get spotDetailSelectPhotos => 'Fotos auswählen';

  @override
  String get spotDetailPickPhotos => 'Fotos wählen';

  @override
  String get spotDetailAdditionalDetailsOptional =>
      'Zusätzliche Details (optional)';

  @override
  String get spotDetailAdditionalDetailsHint =>
      'Weitere Infos zu diesen Fotos…';

  @override
  String get spotDetailSuggestPhotosEmailHelper =>
      'Wir melden uns nur wegen dieses Vorschlags.';

  @override
  String get spotDetailSuggestPhotosSubmitFailed =>
      'Foto-Vorschlag konnte nicht gesendet werden. Bitte erneut versuchen.';

  @override
  String spotDetailSuggestPhotosSubmitError(String error) {
    return 'Fehler beim Foto-Vorschlag: $error';
  }

  @override
  String get spotDetailSuggestEditTitle => 'Bearbeitung vorschlagen';

  @override
  String get spotDetailSuggestEditIntro =>
      'Schlag Änderungen an diesem Spot vor. Moderatoren prüfen deine Vorschläge.';

  @override
  String get spotDetailSuggestEditSuggestChange =>
      'Bitte mindestens eine Änderung vorschlagen.';

  @override
  String get spotDetailSuggestEditSubmitFailed =>
      'Änderungsvorschlag konnte nicht gesendet werden. Bitte erneut versuchen.';

  @override
  String spotDetailSuggestEditSubmitError(String error) {
    return 'Fehler beim Änderungsvorschlag: $error';
  }

  @override
  String get spotDetailGeocoding => 'Geocoding…';

  @override
  String get spotDetailChangeLocationPicked => 'Standort ändern (gewählt)';

  @override
  String get spotDetailPickLocationOnMap =>
      'Anderen Standort auf der Karte wählen';

  @override
  String get spotDetailFieldTitle => 'Titel';

  @override
  String get spotDetailFieldTitleHint => 'Spot-Titel';

  @override
  String get spotDetailFieldDescription => 'Beschreibung';

  @override
  String get spotDetailFieldDescriptionHint => 'Spot-Beschreibung';

  @override
  String get spotDetailFieldSpotAttributes => 'Spot-Eigenschaften';

  @override
  String get spotDetailSuggestEditEmailHelper =>
      'Wir melden uns nur wegen dieses Vorschlags.';

  @override
  String get spotDetailMustBeLoggedInToRate =>
      'Zum Bewerten von Spots musst du angemeldet sein';

  @override
  String spotDetailRatingSubmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bewertung $count Sterne gesendet!',
      one: 'Bewertung 1 Stern gesendet!',
    );
    return '$_temp0';
  }

  @override
  String get spotDetailRatingSubmitFailed =>
      'Bewertung konnte nicht gesendet werden. Bitte erneut versuchen.';

  @override
  String spotDetailRatingSubmitError(String error) {
    return 'Fehler bei der Bewertung: $error';
  }

  @override
  String get spotDetailNotExternalSource =>
      'Dieser Spot stammt nicht von einer externen Quelle.';

  @override
  String get spotDetailMustBeLoggedInCreateNative =>
      'Zum Erstellen eines nativen Spots musst du angemeldet sein.';

  @override
  String get spotDetailCreateNativeDialogTitle => 'Nativen Spot erstellen';

  @override
  String get spotDetailCreateNativeDialogBody =>
      'Es wird ein neuer nativer Spot auf Basis dieses Spots erstellt und der aktuelle Spot als dessen Duplikat markiert. Alle Daten (Name, Beschreibung, Standort, Fotos, YouTube-Links, Eigenschaften) werden kopiert.\n\nHinweis: Admins können Spots löschen und Duplikat-Verknüpfungen bei Bedarf entfernen.';

  @override
  String get spotDetailCreateButton => 'Erstellen';

  @override
  String get spotDetailUnableCreateNativeNow =>
      'Nativer Spot kann gerade nicht erstellt werden.';

  @override
  String get spotDetailFailedCreateNativeSpot =>
      'Nativer Spot konnte nicht erstellt werden';

  @override
  String get spotDetailNativeCreatedDuplicateMarked =>
      'Nativer Spot erstellt und aktueller Spot als Duplikat markiert.';

  @override
  String get spotDetailFailedMarkDuplicateGeneric =>
      'Spot konnte nicht als Duplikat markiert werden';

  @override
  String spotDetailErrorCreatingNativeSpot(String error) {
    return 'Fehler beim Erstellen des nativen Spots: $error';
  }

  @override
  String get spotDetailUnableMarkDuplicateNow =>
      'Dieser Spot kann gerade nicht als Duplikat markiert werden.';

  @override
  String get spotDetailAlreadyMarkedDuplicate =>
      'Dieser Spot ist bereits als Duplikat markiert.';

  @override
  String get spotDetailSpotMarkedDuplicateSuccess =>
      'Spot als Duplikat markiert.';

  @override
  String spotDetailErrorMarkingDuplicateSpot(String error) {
    return 'Fehler beim Markieren als Duplikat: $error';
  }

  @override
  String get spotDetailModeratorsOnlyHideUnhide =>
      'Nur Moderatoren können Spots aus-/einblenden.';

  @override
  String get spotDetailHideSpotTitle => 'Spot ausblenden';

  @override
  String get spotDetailUnhideSpotTitle => 'Spot einblenden';

  @override
  String get spotDetailHideSpotMessage =>
      'Der Spot wird für die Öffentlichkeit ausgeblendet. Ausgeblendete Spots erscheinen nicht in Suche oder auf der Karte; Daten bleiben erhalten und können später wieder sichtbar gemacht werden.';

  @override
  String get spotDetailUnhideSpotMessage =>
      'Der Spot wird wieder öffentlich sichtbar und erscheint wieder in Suche und auf der Karte.';

  @override
  String get spotDetailActionHide => 'Ausblenden';

  @override
  String get spotDetailActionUnhide => 'Einblenden';

  @override
  String get spotDetailUnableHideUnhideNow =>
      'Dieser Spot kann gerade nicht aus-/eingeblendet werden.';

  @override
  String get spotDetailSpotHiddenSuccess => 'Spot ausgeblendet.';

  @override
  String get spotDetailSpotUnhiddenSuccess => 'Spot wieder sichtbar.';

  @override
  String get spotDetailFailedHideSpot =>
      'Spot konnte nicht ausgeblendet werden';

  @override
  String get spotDetailFailedUnhideSpot =>
      'Spot konnte nicht eingeblendet werden';

  @override
  String spotDetailErrorHidingSpot(String error) {
    return 'Fehler beim Ausblenden: $error';
  }

  @override
  String spotDetailErrorUnhidingSpot(String error) {
    return 'Fehler beim Einblenden: $error';
  }

  @override
  String get spotDetailNotMarkedAsDuplicate =>
      'Dieser Spot ist nicht als Duplikat markiert.';

  @override
  String get spotDetailModeratorsOnlyRemoveDuplicateStatus =>
      'Nur Moderatoren können den Duplikat-Status entfernen.';

  @override
  String get spotDetailRemoveDuplicateDialogBody =>
      'Der Duplikat-Status wird entfernt; der Spot gilt nicht mehr als Duplikat.\n\nFortfahren?';

  @override
  String get spotDetailRemoveButton => 'Entfernen';

  @override
  String get spotDetailUnableRemoveDuplicateStatusNow =>
      'Duplikat-Status kann gerade nicht entfernt werden.';

  @override
  String get spotDetailDuplicateStatusRemovedSuccess =>
      'Duplikat-Status entfernt.';

  @override
  String get spotDetailFailedRemoveDuplicateStatusGeneric =>
      'Duplikat-Status konnte nicht entfernt werden';

  @override
  String spotDetailErrorRemovingDuplicateStatus(String error) {
    return 'Fehler beim Entfernen des Duplikat-Status: $error';
  }

  @override
  String get spotDetailCheckingLinkedData => 'Verknüpfte Daten werden geprüft…';

  @override
  String get spotDetailDeleteSpotDialogTitle => 'Spot löschen';

  @override
  String get spotDetailDeleteSpotConfirmMessage =>
      'Diesen Spot wirklich löschen? Das kann nicht rückgängig gemacht werden.';

  @override
  String get spotDetailLinkedDataHeading => 'Dieser Spot hat verknüpfte Daten:';

  @override
  String spotDetailLinkedRatingsLine(int count) {
    return '• Bewertungen: $count';
  }

  @override
  String spotDetailLinkedReportsLine(int count) {
    return '• Spot-Meldungen: $count';
  }

  @override
  String spotDetailLinkedDuplicatesLine(int count) {
    return '• Duplikat-Spots: $count';
  }

  @override
  String get spotDetailResolveLinksBeforeDelete =>
      'Bitte diese Verknüpfungen auflösen, bevor du den Spot löschst.';

  @override
  String get spotDetailSpotDeletedSuccess => 'Spot gelöscht.';

  @override
  String get spotDetailFailedDeleteSpot => 'Spot konnte nicht gelöscht werden';

  @override
  String spotDetailErrorDeletingSpot(String error) {
    return 'Fehler beim Löschen des Spots: $error';
  }

  @override
  String get spotDetailFlagDuplicateDialogTitle => 'Als Duplikat melden';

  @override
  String get spotDetailFlagDuplicateIntro =>
      'Dieser Spot scheint ein Duplikat eines anderen zu sein. Bitte den Original-Spot unten auswählen.';

  @override
  String get spotDetailFlagDuplicateWhichQuestion =>
      'Von welchem Spot ist dies ein Duplikat?';

  @override
  String get spotDetailDuplicateSearchHint =>
      'Spot-URL einfügen oder Spot-ID eingeben';

  @override
  String get spotDetailSearch => 'Suchen';

  @override
  String get spotDetailNearbySpotsWithin50m =>
      'Spots in der Nähe (innerhalb ~50 m)';

  @override
  String get spotDetailFoundSpot => 'Gefundener Spot';

  @override
  String spotDetailSpotIdLabel(String id) {
    return 'Spot-ID: $id';
  }

  @override
  String get spotDetailRemoveSelectionTooltip => 'Auswahl entfernen';

  @override
  String get spotDetailImageFailedToLoad => 'Bild konnte nicht geladen werden';

  @override
  String get spotDetailClose => 'Schließen';

  @override
  String spotDetailExpandMoreCount(int count) {
    return 'noch $count';
  }

  @override
  String get spotDetailSubmit => 'Senden';

  @override
  String get spotDetailDuplicateReportSelectRequired =>
      'Bitte den Spot auswählen, dessen Duplikat dies ist.';

  @override
  String get spotDetailDuplicateSearchEmpty =>
      'Bitte Spot-ID oder URL eingeben';

  @override
  String get spotDetailDuplicateInvalidUrl => 'Ungültige Spot-ID oder URL';

  @override
  String get spotDetailDuplicateCannotSelectSelf =>
      'Ein Spot kann kein Duplikat von sich selbst sein';

  @override
  String get spotDetailDuplicateSpotNotFound => 'Spot nicht gefunden';

  @override
  String spotDetailDuplicateFailedLoadSpot(String error) {
    return 'Spot konnte nicht geladen werden: $error';
  }

  @override
  String get sourceDetailsLoadingSource => 'Quelle wird geladen...';

  @override
  String get sourceDetailsErrorTitle => 'Fehler';

  @override
  String get sourceDetailsNotFound => 'Quelle nicht gefunden';

  @override
  String get sourceDetailsTotalSpots => 'Spots gesamt';

  @override
  String get sourceDetailsFolders => 'Ordner';

  @override
  String get sourceDetailsGoToSource => 'Zur Quelle';

  @override
  String get sourceDetailsAdded => 'Hinzugefügt';

  @override
  String get sourceDetailsLastImported => 'Zuletzt importiert';

  @override
  String sourceDetailsRelativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Tagen',
      one: 'vor 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String sourceDetailsRelativeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Stunden',
      one: 'vor 1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String sourceDetailsRelativeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Minuten',
      one: 'vor 1 Minute',
    );
    return '$_temp0';
  }

  @override
  String get sourceDetailsRelativeJustNow => 'Gerade eben';

  @override
  String get eventSourceDetailsLoadingSource => 'Eventquelle wird geladen...';

  @override
  String get eventSourceDetailsTotalEvents => 'Events gesamt';

  @override
  String exploreEventCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Events',
      one: '1 Event',
    );
    return '$_temp0';
  }

  @override
  String spotTrackingSignInToViewList(String listName) {
    return 'Melde dich an, um deine Liste „$listName“ zu sehen';
  }

  @override
  String spotTrackingNoSpotsInList(String listName) {
    return 'Keine Spots in „$listName“';
  }

  @override
  String get spotListSaveTooltipSaveList => 'Liste speichern';

  @override
  String get spotListSaveTooltipSavedList => 'Liste gespeichert';

  @override
  String get spotListSaveSignInTitle => 'Anmelden, um Listen zu speichern';

  @override
  String get spotListSaveSignInBody =>
      'Speichere die Spot-Liste einer anderen Person in deinem Profil, damit du sie später wieder öffnen kannst.';

  @override
  String get spotListSaveSavedToProfile => 'Liste in deinem Profil gespeichert';

  @override
  String get spotListSaveCouldNotSaveList =>
      'Liste konnte nicht gespeichert werden';

  @override
  String get spotListSaveRemovedFromSavedLists =>
      'Aus gespeicherten Listen entfernt';

  @override
  String get spotListSaveCouldNotRemoveList =>
      'Liste konnte nicht entfernt werden';

  @override
  String get spotListSaveActionSaveList => 'Liste speichern';

  @override
  String get spotListSaveActionRemoveFromSaved => 'Aus Gespeichert entfernen';

  @override
  String get spotListSaveActionViewSavedLists => 'Gespeicherte Listen anzeigen';

  @override
  String get spotListDetailListNotFoundOrNotAccessible =>
      'Liste nicht gefunden oder nicht zugänglich';

  @override
  String get spotListDetailDeleteListTitle => 'Liste löschen';

  @override
  String spotListDetailDeleteListConfirmation(String name) {
    return 'Möchtest du „$name“ wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get spotListDetailDeleteAction => 'Löschen';

  @override
  String get spotListDetailListDeleted => 'Liste gelöscht';

  @override
  String get spotListDetailFailedToDeleteList =>
      'Liste konnte nicht gelöscht werden';

  @override
  String get spotListDetailNoSpotsInThisList => 'Keine Spots in dieser Liste';

  @override
  String get spotListDetailEditListTitle => 'Liste bearbeiten';

  @override
  String get spotListDetailMoreInfoLinkLabel =>
      'Link mit mehr Infos (optional)';

  @override
  String get spotListDetailMoreInfoLinkHint => 'https://…';

  @override
  String get spotListDetailMoreInfoLinkHelper =>
      'Eine Seite im Web mit mehr Informationen zu dieser Liste';

  @override
  String get spotListDetailMoreInfoLinkValidationError =>
      'Der Link mit mehr Infos muss eine gültige URL sein (http oder https), z. B. example.com oder https://example.com/page';

  @override
  String get spotListDetailSave => 'Speichern';

  @override
  String get spotListDetailListUpdated => 'Liste aktualisiert';

  @override
  String get spotListDetailFailedToUpdateList =>
      'Liste konnte nicht aktualisiert werden';

  @override
  String get spotListDetailVisibilityPublicList => 'Öffentliche Liste';

  @override
  String get spotListDetailVisibilityUnlistedList => 'Nicht gelistete Liste';

  @override
  String get spotListDetailVisibilityPrivateList => 'Private Liste';

  @override
  String get spotListDetailCouldNotOpenProfile =>
      'Profil konnte nicht geöffnet werden';

  @override
  String spotListDetailCreatedPart(String visibility, String date) {
    return '$visibility erstellt $date';
  }

  @override
  String get spotListDetailCreatedBySuffix => ' von ';

  @override
  String spotListDetailLastUpdatedPart(String date) {
    return ', zuletzt aktualisiert $date.';
  }

  @override
  String get spotListDetailMoreInformationOn => 'Mehr Informationen auf ';

  @override
  String get detailExternalLinkCaption => 'Mehr Informationen';

  @override
  String detailExternalLinkOpenSemantics(String host) {
    return '$host öffnen';
  }

  @override
  String get spotListDetailCopiedToClipboard =>
      'Liste in die Zwischenablage kopiert!';

  @override
  String spotListDetailCopyFailed(String error) {
    return 'Liste konnte nicht kopiert werden: $error';
  }

  @override
  String get spotListDetailHighlightListOnMap => 'Liste auf Karte hervorheben';

  @override
  String get spotListDetailEditListTooltip => 'Liste bearbeiten';

  @override
  String get spotListDetailMenuListSettings => 'Listeneinstellungen';

  @override
  String get spotListDetailMenuOrganizeList => 'Liste organisieren';

  @override
  String get spotListDetailMenuDeleteList => 'Liste löschen';

  @override
  String get spotListDetailPageTitle => 'Spot-Liste';

  @override
  String get spotListDetailListNotFound => 'Liste nicht gefunden';

  @override
  String spotListDetailMetaDescriptionFallback(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Parkour-Spots',
      one: '1 Parkour-Spot',
    );
    return 'Eine kuratierte Liste mit $_temp0 auf Parkour·Spot';
  }

  @override
  String get publicProfilePageTitle => 'Profil';

  @override
  String get publicProfileShareProfileTooltip => 'Profil teilen';

  @override
  String get publicProfileErrorLoadingProfile =>
      'Fehler beim Laden des Profils';

  @override
  String get publicProfilePleaseTryAgainLater =>
      'Bitte versuche es später erneut';

  @override
  String publicProfileMetaDescription(String name, String defaultDescription) {
    return 'Sieh dir die Parkour-Spots und Listen von $name auf Parkour·Spot an — $defaultDescription';
  }

  @override
  String get publicProfileProfileNotFound => 'Profil nicht gefunden';

  @override
  String get publicProfileNotFoundOrPrivate =>
      'Dieses Profil existiert nicht oder ist privat.';

  @override
  String publicProfileMemberSince(String date) {
    return 'Mitglied seit $date';
  }

  @override
  String get publicProfileEditProfileTooltip => 'Profil bearbeiten';

  @override
  String get publicProfileSpotTracking => 'Spot-Tracking';

  @override
  String get publicProfileNoSpotsYet => 'Noch keine Spots';

  @override
  String get publicProfileAddSpotsFromSpotDetailPages =>
      'Füge Spots von Spot-Detailseiten hinzu';

  @override
  String get publicProfileBeenTo => 'Schon besucht';

  @override
  String get publicProfileMyCheckIns => 'Meine Trainingsaktivität';

  @override
  String get publicProfileMyCheckInsSubtitle =>
      'Anstehende Trainingspläne und deine Check-in-Historie';

  @override
  String get myCheckInsSignInPrompt =>
      'Melde dich an, um deine Check-ins und Trainingspläne zu sehen';

  @override
  String get myCheckInsLoadMore => 'Mehr laden';

  @override
  String get myCheckInsEmptyTitle => 'Noch keine Besuche oder Pläne';

  @override
  String get myCheckInsEmptyDescription =>
      'Öffne einen Spot, um einzuchecken oder Training zu planen. Bis zur von dir gesetzten Endzeit sehen andere dich dort als „gerade hier“, sofern du es nicht privat hältst.';

  @override
  String get myCheckInsIntro =>
      'Trainingspläne zeigen anstehende Sessions, die du an Spots geplant hast. Ein Check-in speichert einen Besuch – wann du angekommen bist und bis wann du voraussichtlich bleibst. Öffentliche Einträge können dich auf einem Spot bis zu deiner Endzeit zeigen; private sind nur für dich sichtbar.';

  @override
  String get myCheckInsUpcomingPlansTitle => 'Geplantes Training';

  @override
  String get myCheckInsPastCheckInsTitle => 'Check-ins';

  @override
  String get myCheckInsNoCheckInsYet => 'Noch keine Check-ins erfasst.';

  @override
  String get myCheckInsCheckInsLoadFailed =>
      'Check-ins konnten nicht geladen werden.';

  @override
  String get myCheckInsSpotFallback => 'Spot';

  @override
  String get myCheckInsPrivateOnlyYou => 'Privat — nur du kannst das sehen';

  @override
  String myCheckInsDurationDaysShort(int count) {
    return '${count}T';
  }

  @override
  String myCheckInsDurationHoursShort(int count) {
    return '${count}Std';
  }

  @override
  String myCheckInsDurationMinutesShort(int count) {
    return '${count}Min';
  }

  @override
  String get publicProfileSpotLists => 'Spot-Listen';

  @override
  String get publicProfileYours => 'Deine';

  @override
  String get publicProfileCreateYourFirstList => 'Erstelle deine erste Liste';

  @override
  String get publicProfileSaved => 'Gespeichert';

  @override
  String get publicProfilePublicSpotLists => 'Öffentliche Spot-Listen';

  @override
  String get publicProfileNoSavedListsYet => 'Noch keine gespeicherten Listen';

  @override
  String get publicProfileSaveListsHint =>
      'Speichere Listen, die du auf Listenseiten anderer Nutzer findest';

  @override
  String get publicProfileSavedListsUnavailable =>
      'Deine gespeicherten Listen sind nicht mehr verfügbar oder wurden entfernt.';

  @override
  String get publicProfileListCreatedSuccessfully =>
      'Liste erfolgreich erstellt';

  @override
  String get publicProfileChangeProfilePicture => 'Profilbild ändern';

  @override
  String get publicProfileChooseFromGallery => 'Aus Galerie wählen';

  @override
  String get publicProfileTakePhoto => 'Foto aufnehmen';

  @override
  String get publicProfileRemovePicture => 'Bild entfernen';

  @override
  String publicProfileErrorPickingImage(String error) {
    return 'Fehler beim Auswählen des Bildes: $error';
  }

  @override
  String publicProfileErrorTakingPhoto(String error) {
    return 'Fehler beim Aufnehmen des Fotos: $error';
  }

  @override
  String get publicProfileProcessingImage => 'Bild wird verarbeitet...';

  @override
  String get publicProfileReadingImage => 'Bild wird gelesen...';

  @override
  String get publicProfileUploading => 'Wird hochgeladen...';

  @override
  String get publicProfileFinishing => 'Wird abgeschlossen...';

  @override
  String get publicProfileUpdatingProfile => 'Profil wird aktualisiert...';

  @override
  String get publicProfileProfilePictureUpdatedSuccessfully =>
      'Profilbild erfolgreich aktualisiert';

  @override
  String get publicProfileFailedToUpdateProfilePicture =>
      'Profilbild konnte nicht aktualisiert werden';

  @override
  String publicProfileErrorUploadingProfilePicture(String error) {
    return 'Fehler beim Hochladen des Profilbildes: $error';
  }

  @override
  String get publicProfileRemoveProfilePicture => 'Profilbild entfernen';

  @override
  String get publicProfileRemoveProfilePictureConfirmation =>
      'Möchtest du dein Profilbild wirklich entfernen?';

  @override
  String get publicProfileProfilePictureRemovedSuccessfully =>
      'Profilbild erfolgreich entfernt';

  @override
  String get publicProfileFailedToRemoveProfilePicture =>
      'Profilbild konnte nicht entfernt werden';

  @override
  String publicProfileErrorRemovingProfilePicture(String error) {
    return 'Fehler beim Entfernen des Profilbildes: $error';
  }

  @override
  String get publicProfileProfileCopiedToClipboard =>
      'Profil in die Zwischenablage kopiert!';

  @override
  String publicProfileFailedToCopyProfile(String error) {
    return 'Profil konnte nicht kopiert werden: $error';
  }

  @override
  String get publicProfileStatsSpots => 'Spots';

  @override
  String get publicProfileStatsRatings => 'Bewertungen';

  @override
  String get publicProfileSettingsTitle => 'Profileinstellungen';

  @override
  String get publicProfileEmailLabel => 'E-Mail';

  @override
  String get publicProfileEmailNotShownHint =>
      'Deine E-Mail wird nicht öffentlich angezeigt.';

  @override
  String get publicProfileDisplayNameLabel => 'Anzeigename';

  @override
  String get publicProfileNoDisplayNameSet => 'Kein Anzeigename gesetzt';

  @override
  String get publicProfileEditAction => 'Bearbeiten';

  @override
  String get publicProfileDisplayNameHint => 'Gib deinen Namen ein';

  @override
  String publicProfileDisplayNameHelper(int max) {
    return 'So wird dein Name anderen angezeigt';
  }

  @override
  String publicProfileDisplayNameMaxLengthError(int max) {
    return 'Der Anzeigename darf höchstens 50 Zeichen haben';
  }

  @override
  String get publicProfileDisplayNameUpdated => 'Anzeigename aktualisiert';

  @override
  String get publicProfileDisplayNameRemoved => 'Anzeigename entfernt';

  @override
  String get publicProfileDisplayNameUpdateFailed =>
      'Anzeigename konnte nicht aktualisiert werden';

  @override
  String get publicProfileSaveAction => 'Speichern';

  @override
  String get publicProfileUsernameLabel => 'Benutzername';

  @override
  String get publicProfileNoUsernameSet => 'Kein Benutzername gesetzt';

  @override
  String get publicProfileUsernameHint => 'Gib einen Benutzernamen ein';

  @override
  String get publicProfileUsernameHelper =>
      'Eindeutig und Teil deiner Profil-URL';

  @override
  String get publicProfileUsernameEmpty => 'Benutzername darf nicht leer sein';

  @override
  String get publicProfileUsernameTaken =>
      'Dieser Benutzername ist bereits vergeben';

  @override
  String get publicProfileUsernameUpdated => 'Benutzername aktualisiert';

  @override
  String get publicProfileUsernameUpdateFailed =>
      'Benutzername konnte nicht aktualisiert werden';

  @override
  String get publicProfileInstagramLabel => 'Instagram';

  @override
  String get publicProfileNoInstagramSet => 'Kein Instagram gesetzt';

  @override
  String get publicProfileAddAction => 'Hinzufügen';

  @override
  String get publicProfileInstagramLinkLabel => 'Instagram-Link';

  @override
  String get publicProfileInstagramLinkHint => 'https://instagram.com/deinname';

  @override
  String get publicProfileInstagramLinkHelper =>
      'Vollständige URL zu deinem Instagram-Profil';

  @override
  String get publicProfileInstagramInvalid =>
      'Bitte gib eine gültige Instagram-URL ein';

  @override
  String get publicProfileInstagramRemoved => 'Instagram-Link entfernt';

  @override
  String get publicProfileInstagramUpdated => 'Instagram-Link aktualisiert';

  @override
  String get publicProfileInstagramUpdateFailed =>
      'Instagram-Link konnte nicht aktualisiert werden';

  @override
  String get publicProfilePrivacyTitle => 'Privatsphäre';

  @override
  String get publicProfilePrivacyPublicLabel => 'Öffentliches Profil';

  @override
  String get publicProfilePrivacyPrivateLabel => 'Privates Profil';

  @override
  String get publicProfilePrivacyPublicDescription =>
      'Jeder kann dein Profil und öffentliche Listen sehen.';

  @override
  String get publicProfilePrivacyPrivateDescription =>
      'Nur du kannst dein Profil sehen.';

  @override
  String get publicProfilePrivacyNowPublic =>
      'Dein Profil ist jetzt öffentlich';

  @override
  String get publicProfilePrivacyNowPrivate => 'Dein Profil ist jetzt privat';

  @override
  String get publicProfileFailedToUpdateProfilePrivacy =>
      'Profil-Privatsphäre konnte nicht aktualisiert werden';

  @override
  String get eventDetailRouteErrorLoading => 'Fehler beim Laden des Events';

  @override
  String get eventDetailRouteTryAgainLater => 'Bitte versuche es später erneut';

  @override
  String get eventDetailRouteNotFound => 'Event nicht gefunden';

  @override
  String get eventDetailRouteGoToExplore => 'Zur Entdecken-Ansicht';

  @override
  String get eventDetailStartsLabel => 'Beginn';

  @override
  String get eventDetailEndsLabel => 'Ende';

  @override
  String get eventDetailLocationLabel => 'Ort';

  @override
  String get eventDetailOpenInMaps => 'In Karten öffnen';

  @override
  String get eventDetailLinkedSpotsLabel => 'Verknüpfte Spots';

  @override
  String get eventDetailNoLinkedSpots => 'Keine verknüpften Spots gefunden.';

  @override
  String get eventDetailLinkedSpotListsLabel => 'Verknüpfte Spot-Listen';

  @override
  String get eventDetailNoLinkedSpotLists =>
      'Keine verknüpften Spot-Listen gefunden.';

  @override
  String get adminEventEditTitle => 'Event bearbeiten';

  @override
  String get adminEventEditSave => 'Änderungen speichern';

  @override
  String get adminEventExternalSyncWarningTitle => 'Externes Kalender-Event';

  @override
  String get adminEventExternalSyncWarningBody =>
      'Die nächste Synchronisation kann Titel, Zeitplan, Beschreibung und Veranstaltungsort aus dem externen Feed überschreiben. Verknüpfte Spots und Spot-Listen werden hier verwaltet und werden durch die Synchronisation nicht gelöscht.';

  @override
  String get adminEventLinkedSpotListsTitle => 'Verknüpfte Spot-Listen';

  @override
  String get adminEventAddSpotList => 'Liste hinzufügen';

  @override
  String get adminEventNoLinkedSpotLists => 'Noch keine Spot-Listen ausgewählt';

  @override
  String get adminSpotListSelectionTitle => 'Spot-Liste auswählen';

  @override
  String get adminSpotListSelectionInputLabel => 'Listen-ID oder URL';

  @override
  String get adminSpotListSelectionInputHint =>
      'listen-id oder https://parkour.spot/list/…';

  @override
  String get adminSpotListSelectionLookup => 'Suchen';

  @override
  String get adminSpotListSelectionSelect => 'Auswählen';

  @override
  String get adminSpotListSelectionInvalidInput =>
      'Listen-ID oder /list/…-URL eingeben';

  @override
  String get adminSpotListSelectionNotFound =>
      'Spot-Liste nicht gefunden oder nicht zugänglich';

  @override
  String get adminSpotListSelectionPrivateList =>
      'Private Listen können nicht mit Events verknüpft werden';

  @override
  String get adminSpotListSelectionLoadFailed =>
      'Spot-Liste konnte nicht geladen werden';

  @override
  String adminSpotListSelectionFoundSubtitle(String visibility, int count) {
    return '$visibility · $count Spots';
  }

  @override
  String get eventDetailAdminEditEvent => 'Event bearbeiten';

  @override
  String get eventDetailMenuEditEventSubtitleNative =>
      'Zuerst natives Event erstellen';

  @override
  String get eventDetailMenuEditEventSubtitleMod => 'Nur Moderator';

  @override
  String get eventDetailExternalSourceCannotEdit =>
      'Events aus externen Quellen können nicht bearbeitet werden. Erstelle zuerst ein natives Event über „Als Duplikat markieren“ → „Natives Event erstellen“.';

  @override
  String get eventDetailSourceLabel => 'Quelle';

  @override
  String get eventDetailAdminMenuTooltip => 'Admin';

  @override
  String get eventDetailStaffMenuTooltip => 'Team';

  @override
  String get eventDetailMenuCreateNative => 'Natives Event erstellen';

  @override
  String get eventDetailCreateNativeDialogTitle => 'Natives Event erstellen';

  @override
  String get eventDetailCreateNativeDialogBody =>
      'Dadurch wird ein neues natives Event auf Basis dieses Events erstellt und das aktuelle Event als Duplikat markiert. Eventdaten (Titel, Beschreibung, Zeitplan, Ort, Bilder, Website und verknüpfte Spots) werden in das neue native Event kopiert.';

  @override
  String get eventDetailNotExternalSource =>
      'Dieses Event stammt nicht aus einer externen Quelle.';

  @override
  String get eventDetailMustBeLoggedInCreateNative =>
      'Du musst angemeldet sein, um ein natives Event zu erstellen.';

  @override
  String get eventDetailUnableCreateNativeNow =>
      'Natives Event kann gerade nicht erstellt werden.';

  @override
  String get eventDetailFailedCreateNative =>
      'Natives Event konnte nicht erstellt werden';

  @override
  String get eventDetailNativeCreatedDuplicateMarked =>
      'Natives Event erstellt und aktuelles Event als Duplikat markiert.';

  @override
  String get eventDetailMarkDuplicateNativeOnlyHint =>
      'Nur native Events können ausgewählt werden. Um ein natives Event aus einem externen Event zu erstellen, nutze „Natives Event erstellen“ im Event-Menü.';

  @override
  String eventDetailEventCreatedOnDateBy(String date) {
    return 'Event erstellt $date von ';
  }

  @override
  String get eventDetailEventCreatedBy => 'Event erstellt von ';

  @override
  String eventDetailEventCreatedOnDate(String date) {
    return 'Event erstellt $date';
  }

  @override
  String eventDetailEventImportedOnDateFrom(String date) {
    return 'Event importiert $date von ';
  }

  @override
  String get eventDetailEventImportedFrom => 'Event importiert von ';

  @override
  String get eventDetailOriginalEventFallback => 'Original-Event';

  @override
  String get eventDetailMarkDuplicateStaffOnly =>
      'Nur Teammitglieder können Event-Duplikate verwalten.';

  @override
  String get eventDetailMarkDuplicatePickNativeTitle =>
      'Als Duplikat eines nativen Events markieren';

  @override
  String get eventDetailMarkDuplicateSearchHint => 'Event-URL oder -ID';

  @override
  String get eventDetailMarkDuplicateNotFoundOrInvalid =>
      'Gib eine gültige Event-ID oder einen /event/…-Link ein.';

  @override
  String get eventDetailMarkDuplicateTargetNotNative =>
      'Dieses Event ist kein natives parkour.spot-Event. Nur native Events können das Original sein.';

  @override
  String get eventDetailMarkDuplicateTargetIsDuplicate =>
      'Dieses Event ist bereits als Duplikat eines anderen Events markiert.';

  @override
  String get eventDetailMarkDuplicateUseButton => 'Dieses Event verwenden';

  @override
  String get eventDetailMarkDuplicateSuggestionsHeader =>
      'Aktuelle native Events';

  @override
  String get eventDetailMarkDuplicateNoSuggestions =>
      'Keine Vorschläge verfügbar.';

  @override
  String eventDetailMarkDuplicateConfirmBody(String title) {
    return 'Dieses Event als Duplikat von „$title“ markieren?';
  }

  @override
  String get eventDetailMarkDuplicateSuccess => 'Event als Duplikat markiert.';

  @override
  String get eventDetailRemoveDuplicateConfirmBody =>
      'Duplikatstatus von diesem Event entfernen? Es verweist dann nicht mehr auf ein anderes Event als Original.';

  @override
  String get eventDetailRemoveDuplicateSuccess => 'Duplikatstatus entfernt.';

  @override
  String get eventDetailCopiedToClipboard =>
      'Event in die Zwischenablage kopiert!';

  @override
  String eventDetailShareFailed(String error) {
    return 'Teilen fehlgeschlagen: $error';
  }
}
